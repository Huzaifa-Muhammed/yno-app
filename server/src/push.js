// Sending FCM notifications, server-side.
//
// 🔑 WHY THIS EXISTS. The app used to send push **from the device**, using a
// Firebase Admin service-account key bundled into the APK
// (`assets/firebase_admin_key/service_account.json`). Two problems, both fatal
// once the app is on a public store:
//
//   1. Anyone who downloads the APK can unzip it and read a full project-admin
//      private key — read/write every document, delete any account, bypass all
//      rules. Rotating it later does not help: shipped builds keep the old key.
//   2. Even without extracting it, a repackaged APK could send arbitrary push
//      to any user, impersonating YNO to the whole user base.
//
// Moving the send here fixes both. The key never leaves the Worker, and the
// caller has to prove who they are.
//
// ⚠️ The recipient's device tokens are looked up HERE, by uid. The caller does
// not supply them and must never be allowed to: accepting caller-supplied
// tokens would let anyone who scraped a token (the `users` collection is
// world-readable) push to that device directly, which is the same
// impersonation hole in a new place.
import { accessToken } from './google.js';
import { getDoc } from './firestore.js';
import { userFromIdToken } from './identity.js';

export const SCOPE_FCM = 'https://www.googleapis.com/auth/firebase.messaging';

const MAX_LEN = 512;         // title/body cap — FCM's own limit is far higher
const MAX_TOKENS = 20;       // devices per user we will fan out to

const clip = (v) =>
    typeof v === 'string' ? v.slice(0, MAX_LEN) : '';

/**
 * Read a user's registered device tokens from their profile.
 * Returns [] for a missing user or a profile with no tokens — both are normal.
 */
async function tokensFor(env, uid) {
  const doc = await getDoc(env, 'users', uid);
  if (!doc || !doc.fields) return [];
  // ⚠️ Read the raw Firestore shape, NOT `fields()`. Its `plain()` helper has
  // no `arrayValue` branch and returns null for arrays, so `fields(doc)
  // .fcmTokens` is silently null and nothing would ever send.
  const values = doc.fields.fcmTokens?.arrayValue?.values;
  if (!Array.isArray(values)) return [];
  return values
      .map((v) => (v && typeof v.stringValue === 'string' ? v.stringValue : ''))
      .filter((t) => t.length > 0)
      .slice(0, MAX_TOKENS);
}

/**
 * POST /send-push
 *
 * Body: { idToken, uid, title, body, route?, arg? }
 *   idToken — the SENDER's Firebase ID token. Proves the caller is a signed-in
 *             user. Without it this endpoint is an open spam relay pointed at
 *             real people's phones.
 *   uid     — the RECIPIENT. Tokens are resolved from their profile here.
 *
 * Returns { ok, sent, failed }. Push is best-effort by design: the bell
 * notification in Firestore is the durable record, and the app already treats
 * a failed send as non-fatal. A dead device token is normal and is not an
 * error worth failing the request over.
 */
export async function sendPush(env, body) {
  if (!body || typeof body !== 'object') {
    return { status: 400, body: { ok: false, error: 'invalid_request' } };
  }
  const { idToken, uid } = body;
  if (typeof uid !== 'string' || uid.length < 6) {
    return { status: 400, body: { ok: false, error: 'invalid_request' } };
  }

  // Gate 1: the caller must be signed in as somebody.
  const sender = await userFromIdToken(env, idToken);
  if (!sender) {
    return { status: 401, body: { ok: false, error: 'unauthorised' } };
  }

  const title = clip(body.title);
  const text = clip(body.body);
  if (!title && !text) {
    return { status: 400, body: { ok: false, error: 'invalid_request' } };
  }

  const tokens = await tokensFor(env, uid);
  if (tokens.length === 0) {
    // Nothing to send to is a success, not a failure — the user simply has no
    // device registered, which is the normal state for a web-only account.
    return { status: 200, body: { ok: true, sent: 0, failed: 0 } };
  }

  const access = await accessToken(env, SCOPE_FCM);
  const pid = env.FIREBASE_PROJECT_ID;
  const url = `https://fcm.googleapis.com/v1/projects/${pid}/messages:send`;

  const data = {};
  if (typeof body.route === 'string' && body.route) data.route = clip(body.route);
  if (typeof body.arg === 'string' && body.arg) data.arg = clip(body.arg);

  let sent = 0, failed = 0;
  await Promise.all(tokens.map(async (token) => {
    try {
      const r = await fetch(url, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${access}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({
          message: {
            token,
            notification: { title, body: text },
            data,
          },
        }),
      });
      if (r.ok) { sent++; return; }
      failed++;
      // A stale token is the common case and not worth logging loudly.
      if (r.status !== 404) {
        console.error('fcm send failed', r.status, (await r.text()).slice(0, 200));
      }
    } catch (err) {
      failed++;
      console.error('fcm send threw', err && err.message);
    }
  }));

  return { status: 200, body: { ok: true, sent, failed } };
}
