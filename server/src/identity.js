// Firebase Authentication (Identity Toolkit) over REST.
//
// There is no firebase-admin here — it needs gRPC and Node internals and does
// not run on Workers — so the two things account deletion requires are done
// against the REST API directly.

import { accessToken } from './google.js';

export const SCOPE_IDENTITY =
    'https://www.googleapis.com/auth/identitytoolkit';

/**
 * Verify a Firebase ID token and return who it belongs to.
 *
 * Uses the public `accounts:lookup` endpoint with the web API key rather than
 * verifying the JWT ourselves: Google checks the signature, the expiry and the
 * issuer, so we do not have to fetch and cache the JWKS or hand-roll RS256
 * verification. An invalid, expired or revoked token comes back as an error.
 *
 * This is what makes deletion safe to expose. Possession of an ID token proves
 * the caller is signed in AS that account, so nobody can start a deletion for
 * an address that is not theirs — the OTP that follows is the second factor,
 * not the only one.
 *
 * @returns {Promise<{uid: string, email: string}|null>}
 */
export async function userFromIdToken(env, idToken) {
  const key = env.FIREBASE_API_KEY;
  if (!key) throw new Error('FIREBASE_API_KEY is not set');
  if (typeof idToken !== 'string' || idToken.length < 20) return null;

  const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${key}`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ idToken }),
      });
  if (!res.ok) return null; // expired / malformed / revoked

  const body = await res.json();
  const user = body && body.users && body.users[0];
  if (!user || !user.localId) return null;
  return { uid: user.localId, email: (user.email || '').trim() };
}

/**
 * Permanently delete a Firebase Auth account.
 *
 * Admin-authenticated, so it works regardless of how long ago the user signed
 * in — the client SDK's `user.delete()` fails with `requires-recent-login`,
 * which is exactly the sharp edge that makes in-app deletion unreliable.
 */
export async function deleteAuthUser(env, uid) {
  const pid = env.FIREBASE_PROJECT_ID;
  if (!pid) throw new Error('FIREBASE_PROJECT_ID is not set');
  const token = await accessToken(env, SCOPE_IDENTITY);

  const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/projects/${pid}/accounts:delete`, {
        method: 'POST',
        headers: {
          authorization: `Bearer ${token}`,
          'content-type': 'application/json',
        },
        body: JSON.stringify({ localId: uid }),
      });

  if (!res.ok) {
    const text = await res.text();
    // Already gone is a success from the caller's point of view.
    if (res.status === 400 && text.includes('USER_NOT_FOUND')) return;
    throw new Error(`auth delete failed: ${res.status} ${text}`);
  }
}
