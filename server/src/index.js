// YNO email-OTP service.
//
//   POST /request-otp  { email, purpose?, idToken? }        -> { ok: true }
//   POST /verify-otp   { email, code, purpose?, idToken? }  -> claim:  { ok, customToken, uid }
//                                                              delete: { ok, deleted: true }
//   POST /guest-join   { code, name, email?, phone? }       -> { ok, uid, isGuest,
//                                                              isNewAccount, pending,
//                                                              customToken? }
//   GET  /health                                            -> { ok: true }
//
// /guest-join resolves the email to an identity before joining: an existing
// account joins as itself — under its own profile name and position — and an
// unknown address gets an auto-created account (`autoCreated: true`, password
// `123456`) exactly as an in-app host-added player does.
//
// `isGuest` mirrors `autoCreated`, which is the app's own rule from
// `addTeamRoster`: a profile nobody has filled in yet is a guest however real
// its uid is, and it stops being one when the owner claims the account.
//
// `customToken` comes back ONLY for an account that request just created — see
// the note at the end of guest.js for why that limit is load-bearing on a
// public endpoint.
//
// Two purposes share one code path:
//
//   claim  (default) — an account a host created, being taken over by its owner.
//   delete           — permanent account deletion, and it additionally requires a
//                      valid Firebase ID TOKEN. The OTP alone must never be
//                      enough to destroy an account: the token proves the caller
//                      is signed in as that user, so the code is a second factor
//                      rather than the only one.
//
// The one load-bearing decision: /verify-otp returns a Firebase **custom
// token**, not { ok: true }. A boolean would leave the app deciding who gets in,
// so a repackaged APK could skip the call entirely. Returning a credential means
// possession of the OTP is what produces the login.

import { customToken } from './google.js';
import {
  deleteDoc,
  deleteSubcollection,
  fields,
  findUserByEmail,
  getDoc,
  setDoc,
  v,
} from './firestore.js';
import { deleteAuthUser, userFromIdToken } from './identity.js';
import { guestJoin } from './guest.js';
import { sendPush } from './push.js';
import { generateCode, hashCode, isEmail, isSixDigits, timingSafeEqual } from './otp.js';
import { sendOtpEmail } from './email.js';

const COLLECTION = 'emailOtps';

export const PURPOSE_CLAIM = 'claim';
export const PURPOSE_DELETE = 'delete';

/**
 * Document id for a pending code.
 *
 * Deletion codes are namespaced so they cannot collide with a claim code
 * for the same address — otherwise requesting one would silently burn the
 * other, and worse, a claim code could be replayed against deletion.
 */
export const otpDocId = (emailKey, purpose) =>
    purpose === PURPOSE_DELETE ? `del_${emailKey}` : emailKey;

export const purposeOf = (body) =>
    body && body.purpose === PURPOSE_DELETE ? PURPOSE_DELETE : PURPOSE_CLAIM;

// Limits. Deliberately tight — an unthrottled endpoint is an open spam relay
// that will burn the Resend quota in an afternoon and get the domain flagged.
const OTP_TTL_SEC = 600;          // 10 minutes
const RESEND_COOLDOWN_SEC = 60;   // between two sends to the same address
const SEND_WINDOW_SEC = 900;      // 15-minute window ...
const MAX_SENDS_PER_WINDOW = 3;   // ... allows this many sends per address
const MAX_ATTEMPTS = 5;           // wrong guesses before the code is burned

const CORS = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, GET, OPTIONS',
  'access-control-allow-headers': 'content-type',
  'access-control-max-age': '86400',
};

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...CORS, ...extra },
  });
}

function fail(error, status, message, extra = {}) {
  return json({ ok: false, error, message, ...extra }, status);
}

const now = () => Date.now();
const secs = (ms) => Math.max(0, Math.ceil(ms / 1000));

/**
 * Per-IP limit via the Workers rate-limiting binding. If the binding is not
 * configured the request is allowed through — the per-address limits below are
 * enforced in Firestore and are the authoritative ones, so a missing binding
 * degrades the service rather than opening it.
 */
async function ipAllowed(env, request) {
  const limiter = env.IP_LIMITER;
  if (!limiter || typeof limiter.limit !== 'function') return true;
  const ip = request.headers.get('cf-connecting-ip') || 'unknown';
  try {
    const { success } = await limiter.limit({ key: ip });
    return success;
  } catch (_) {
    return true;
  }
}

async function readJson(request) {
  try {
    const body = await request.json();
    return body && typeof body === 'object' ? body : null;
  } catch (_) {
    return null;
  }
}

// ---- POST /request-otp ---------------------------------------------------
async function requestOtp(env, request) {
  const body = await readJson(request);
  if (!body || !isEmail(body.email)) {
    return fail('invalid_request', 400, 'A valid email address is required.');
  }
  const email = body.email.trim();
  const key = email.toLowerCase();
  const purpose = purposeOf(body);
  const docId = otpDocId(key, purpose);
  const t = now();

  // Only an auto-created account can be claimed. A real account already has a
  // password and must use the normal reset flow.
  //
  // This answers "does a host-created account exist for this address?" to
  // anyone who asks, which the claim screen needs in order to say so. It leaks
  // nothing new: `users` is world-readable and the app's own
  // UserRepository.findByEmail already performs exactly this lookup client-side.
  let user;
  if (purpose === PURPOSE_DELETE) {
    // Deletion is gated on being signed in as the account, not on knowing its
    // address. Without this, anyone could start a deletion for any email — the
    // code would not arrive for them, but it is a spam vector aimed at a real
    // person's inbox that says "your account is being deleted".
    const owner = await userFromIdToken(env, body.idToken);
    if (!owner) {
      return fail('unauthorised', 401, 'Sign in again and retry.');
    }
    if (owner.email.toLowerCase() !== key) {
      return fail('unauthorised', 403,
          'You can only delete the account you are signed in to.');
    }
    user = { uid: owner.uid, email: owner.email };
  } else {
    user = await findUserByEmail(env, email);
    const claimable = !!user && user.autoCreated === true;
    if (!claimable) {
      return fail('not_claimable', 404,
          'No account created by a host was found for that email.');
    }
  }

  const existing = fields(await getDoc(env, COLLECTION, docId));
  const lastSentAt = existing.lastSentAt || 0;
  const windowStart = existing.windowStart || 0;
  let sendCount = existing.sendCount || 0;

  if (lastSentAt && t - lastSentAt < RESEND_COOLDOWN_SEC * 1000) {
    const retry = secs(RESEND_COOLDOWN_SEC * 1000 - (t - lastSentAt));
    return fail('rate_limited', 429, 'Please wait before requesting another code.',
        { retryAfter: retry });
  }
  if (windowStart && t - windowStart < SEND_WINDOW_SEC * 1000) {
    if (sendCount >= MAX_SENDS_PER_WINDOW) {
      const retry = secs(SEND_WINDOW_SEC * 1000 - (t - windowStart));
      return fail('rate_limited', 429, 'Too many codes requested. Try again later.',
          { retryAfter: retry });
    }
  } else {
    sendCount = 0; // window rolled over
  }

  const code = generateCode();
  const codeHash = await hashCode(env, key, code);

  await setDoc(env, COLLECTION, docId, {
    email: v.str(key),
    uid: v.str(user.uid),
    purpose: v.str(purpose),
    codeHash: v.str(codeHash),
    expiresAt: v.int(t + OTP_TTL_SEC * 1000),
    attempts: v.int(0),
    sendCount: v.int(sendCount + 1),
    windowStart: v.int(windowStart && t - windowStart < SEND_WINDOW_SEC * 1000
        ? windowStart : t),
    lastSentAt: v.int(t),
  });

  await sendOtpEmail(env, user.email || email, code, OTP_TTL_SEC / 60, purpose);

  return json({
    ok: true,
    expiresInSeconds: OTP_TTL_SEC,
    resendAfterSeconds: RESEND_COOLDOWN_SEC,
  });
}

// ---- POST /verify-otp ----------------------------------------------------
async function verifyOtp(env, request) {
  const body = await readJson(request);
  if (!body || !isEmail(body.email) || !isSixDigits(body.code)) {
    return fail('invalid_request', 400, 'Email and a 6-digit code are required.');
  }
  const key = body.email.trim().toLowerCase();
  const purpose = purposeOf(body);
  const docId = otpDocId(key, purpose);
  const t = now();

  const doc = await getDoc(env, COLLECTION, docId);
  const f = fields(doc);
  if (!doc || !f.codeHash) {
    return fail('invalid_code', 400, 'That code is not valid.');
  }
  if (!f.expiresAt || t > f.expiresAt) {
    await deleteDoc(env, COLLECTION, docId);
    return fail('code_expired', 400, 'That code has expired. Request a new one.');
  }
  const attempts = f.attempts || 0;
  if (attempts >= MAX_ATTEMPTS) {
    await deleteDoc(env, COLLECTION, docId);
    return fail('too_many_attempts', 429,
        'Too many incorrect attempts. Request a new code.');
  }

  const candidate = await hashCode(env, key, body.code);
  if (!timingSafeEqual(candidate, f.codeHash)) {
    await setDoc(env, COLLECTION, docId, {
      email: v.str(key),
      uid: v.str(f.uid || ''),
      purpose: v.str(purpose),
      codeHash: v.str(f.codeHash),
      expiresAt: v.int(f.expiresAt),
      attempts: v.int(attempts + 1),
      sendCount: v.int(f.sendCount || 0),
      windowStart: v.int(f.windowStart || 0),
      lastSentAt: v.int(f.lastSentAt || 0),
    });
    return fail('invalid_code', 400, 'That code is not valid.',
        { attemptsLeft: Math.max(0, MAX_ATTEMPTS - attempts - 1) });
  }

  if (!f.uid) {
    return fail('server_error', 500, 'This account can no longer be claimed.');
  }

  // A code stored for one purpose must never be spendable on the other, even
  // though the ids are already namespaced. Belt and braces: this is the check
  // that stops a claim code deleting an account if the id scheme ever changes.
  if ((f.purpose || PURPOSE_CLAIM) !== purpose) {
    return fail('invalid_code', 400, 'That code is not valid.');
  }

  // Burn the code before acting on it — neither a credential nor a deletion
  // may be obtainable twice from one code, even if the step below fails.
  await deleteDoc(env, COLLECTION, docId);

  if (purpose === PURPOSE_DELETE) {
    // Re-check ownership at the moment of action, not just when the code was
    // requested. The two calls are minutes apart and the token may have been
    // revoked in between.
    const owner = await userFromIdToken(env, body.idToken);
    if (!owner || owner.uid !== f.uid) {
      return fail('unauthorised', 401, 'Sign in again and retry.');
    }
    return await deleteAccount(env, f.uid);
  }

  const token = await customToken(env, f.uid, { claimedByOtp: true });
  return json({ ok: true, customToken: token, uid: f.uid });
}

// ---- account deletion ----------------------------------------------------

/**
 * Erase the account. Called only after both gates have passed: a valid ID
 * token AND a correct one-time code.
 *
 * Order matters. **Auth first**, because that is the irreversible,
 * security-critical step and the one the user actually asked for — if the
 * data sweep then fails, the account is already unreachable and support can
 * finish the cleanup. Doing it the other way round can leave a working login
 * attached to a profile that no longer exists, which the app has no state for.
 *
 * Match records are deliberately NOT deleted. They belong to every other
 * participant as much as to this user, and the privacy policy says so
 * explicitly: the match still shows that it happened and how it ended.
 */
async function deleteAccount(env, uid) {
  await deleteAuthUser(env, uid);

  // Subcollections do not go with the parent over REST — deleting only the
  // user document would leave these readable to anyone who knows the path.
  let cleanupOk = true;
  try {
    await deleteSubcollection(env, `users/${uid}`, 'notifications');
    await deleteSubcollection(env, `users/${uid}`, 'playedWith');
    await deleteDoc(env, 'users', uid);
  } catch (err) {
    cleanupOk = false;
    console.error('account data cleanup failed for', uid, err);
  }

  return json({ ok: true, deleted: true, dataCleanupPending: !cleanupOk });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS });
    }
    if (url.pathname === '/health') {
      return json({ ok: true, service: 'yno-otp' });
    }
    if (request.method !== 'POST') {
      return fail('invalid_request', 405, 'Method not allowed.');
    }
    if (!(await ipAllowed(env, request))) {
      return fail('rate_limited', 429, 'Too many requests. Slow down.',
          { retryAfter: 60 });
    }
    try {
      if (url.pathname === '/request-otp') return await requestOtp(env, request);
      if (url.pathname === '/verify-otp') return await verifyOtp(env, request);
      if (url.pathname === '/send-push') {
        const body = await readJson(request);
        const { status, body: out } = await sendPush(env, body);
        return json(out, status);
      }
      if (url.pathname === '/guest-join') {
        const body = await readJson(request);
        if (!body) {
          return fail('invalid_request', 400, 'A JSON body is required.');
        }
        const { status, body: out } = await guestJoin(env, body);
        return json(out, status);
      }
      return fail('invalid_request', 404, 'Not found.');
    } catch (err) {
      // Never leak internals to the caller; the detail goes to `wrangler tail`.
      console.error('otp service error:', err && err.stack ? err.stack : err);
      return fail('server_error', 500, 'Something went wrong. Try again.');
    }
  },
};
