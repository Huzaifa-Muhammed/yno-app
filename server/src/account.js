// Creating a player account from the server.
//
// ⚠️ This is a port of `AuthRepository.createPlayerAccount` (app,
// `lib/services/auth_repository.dart:349`). The app creates the account through
// a secondary Firebase app so the admin doing it is not signed out; here there
// is no session to protect, so it is the Identity Toolkit REST API directly —
// the same route `identity.js` already uses to delete an account.
//
// The two must write the SAME `users/{uid}` document. A field this file forgets
// is a field `AppUser.fromDoc` reads back as a default, and the difference only
// shows up as a profile that looks subtly wrong weeks later.
//
// 🔴 The password is `123456`, deliberately. That is the client's decision
// (see the note on `kAutoAccountPassword` in the app): a correct claim OTP
// signs the user in with email + this password rather than with the custom
// token the server hands back. Do not "fix" it here in isolation — the app
// side has to move first, or claiming breaks for every host-created player.

import { randomCode } from './codes.js';
import { docPath, serverTime, v } from './firestore.js';
import { accessToken } from './google.js';
import { SCOPE_IDENTITY } from './identity.js';

/** Mirrors `kAutoAccountPassword` in `auth_repository.dart`. */
export const AUTO_ACCOUNT_PASSWORD = '123456';

/** `name.trim().split(' ').first`, as the app stores it. */
export function firstNameOf(name) {
  return String(name || '').trim().split(/\s+/)[0] || '';
}

/**
 * The `users/{uid}` document for a freshly auto-created player.
 *
 * Every field `AppUser.toMap()` writes, including the ones left at their
 * defaults, so the document is indistinguishable from one the app wrote.
 * `createdAt` is absent here on purpose — it is a server timestamp and travels
 * as a transform, exactly as `FieldValue.serverTimestamp()` does.
 *
 * Pure, so the shape can be tested without a network or a service account.
 */
export function profileFields({ name, email, position = null, referralCode }) {
  const clean = String(name || '').trim();
  return {
    name: v.str(clean),
    email: v.str(String(email || '').trim()),
    username: v.str(''),
    usernameLower: v.str(''),
    firstName: v.str(firstNameOf(clean)),
    lastName: v.str(''),
    phone: v.nul(),
    dob: v.nul(),
    dobLocked: v.bool(false),
    gender: v.nul(),
    language: v.str('English'),
    photoUrl: v.nul(),
    photoPublicId: v.nul(),
    position: position ? v.str(String(position)) : v.nul(),
    preferredFoot: v.nul(),
    skillLevel: v.nul(),
    sportProfileDone: v.bool(false),
    points: v.int(0),
    referralCode: v.str(referralCode || randomCode(6)),
    referredBy: v.nul(),
    autoCreated: v.bool(true),
    socialLinks: v.map({}),
    socialVisibility: v.map({}),
    fcmTokens: v.arr([]),
    following: v.arr([]),
    followersCount: v.int(0),
    tcAcceptedAt: v.nul(),
    careerGoals: v.int(0),
    careerAssists: v.int(0),
    matchesPlayed: v.int(0),
    wins: v.int(0),
    losses: v.int(0),
    draws: v.int(0),
    motmCount: v.int(0),
    communityCount: v.int(0),
    currentStreak: v.int(0),
    bestStreak: v.int(0),
    unbeatenStreak: v.int(0),
    hatTricks: v.int(0),
    bestScoringMatch: v.int(0),
    formLast5: v.arr([]),
    goalsBySurface: v.map({}),
    goalsByFormat: v.map({}),
    notifyMatchAlerts: v.bool(true),
    notifyFriendActivity: v.bool(false),
    contactSync: v.bool(false),
    profilePublic: v.bool(true),
    deactivated: v.bool(false),
    reactivateAt: v.nul(),
  };
}

/** The `:commit` write that creates the profile document. */
export function profileWrite(env, uid, args) {
  return {
    update: {
      name: docPath(env, `users/${uid}`),
      fields: profileFields(args),
    },
    updateTransforms: [serverTime('createdAt')],
  };
}

async function identityCall(env, path, body) {
  const pid = env.FIREBASE_PROJECT_ID;
  if (!pid) throw new Error('FIREBASE_PROJECT_ID is not set');
  const token = await accessToken(env, SCOPE_IDENTITY);
  const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${pid}/${path}`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${token}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify(body),
      });
  return res;
}

/** Admin lookup of an auth account by address. Returns the uid, or null. */
export async function authUidForEmail(env, email) {
  const res = await identityCall(env, 'accounts:lookup', { email: [email] });
  if (!res.ok) return null;
  const body = await res.json().catch(() => null);
  const user = body && body.users && body.users[0];
  return user && user.localId ? user.localId : null;
}

/**
 * Create the Firebase Auth account for [email].
 *
 * @returns {Promise<{uid: string, created: boolean}>} `created` is false when
 *   the auth account already existed — which happens when someone has an auth
 *   account but no `users` document (a sign-up that died between the two
 *   writes). The caller uses it to decide whether to write a profile and, more
 *   importantly, whether a credential may be handed back.
 */
export async function createAuthAccount(env, email, name) {
  const res = await identityCall(env, 'accounts', {
    email,
    password: AUTO_ACCOUNT_PASSWORD,
    displayName: String(name || '').trim(),
    emailVerified: false,
  });

  if (res.ok) {
    const body = await res.json().catch(() => null);
    const uid = body && body.localId;
    if (!uid) throw new Error('accounts create returned no localId');
    return { uid, created: true };
  }

  const text = await res.text();
  // The address was taken between our lookup and this call, or an auth account
  // exists with no profile behind it. Either way the uid is the answer, not an
  // error — this mirrors createPlayerAccount's `email-already-in-use` branch.
  if (text.includes('EMAIL_EXISTS')) {
    const uid = await authUidForEmail(env, email);
    if (uid) return { uid, created: false };
  }
  throw new Error(`account create failed: ${res.status} ${text}`);
}
