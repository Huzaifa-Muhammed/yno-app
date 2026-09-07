// A signed-in throwaway account for the live harnesses.
//
// 🔑 Why this exists: both live harnesses used to read a refresh token from an
// absolute path inside a *session scratchpad*
// (`…/ca529d78-…/scratchpad/del_state.json`). Scratchpads do not survive, that
// file vanished, and both harnesses stopped running — SESSION_PROGRESS §70/§71.
// Nothing here needs a *particular* account, only *an* account, so each run now
// makes its own and deletes it again.
//
// Legal without any admin credential because the live rules are permissive
// enough (`firestore.rules`):
//   match /matches/{mid} { allow write: if signedIn(); }
//   match /users/{uid}   { allow write: if signedIn(); }
const IDT = 'https://identitytoolkit.googleapis.com/v1';

/**
 * Sign up a disposable host. Returns its credentials plus `destroy()`, which
 * removes the profile and the auth account. Always call `destroy()` in the
 * harness's cleanup step — a harness that leaves logins behind quietly fills
 * the client's project with junk.
 */
export async function createDisposableHost(apiKey, projectFsBase, { profile = true } = {}) {
  const seed = String(Math.floor(Math.random() * 9000) + 1000);
  const email = `yno.harness.${seed}@example.com`;
  const password = `Hns!${seed}xQ`;

  const r = await fetch(`${IDT}/accounts:signUp?key=${apiKey}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const b = await r.json();
  if (!r.ok) throw new Error('disposable host signUp failed: ' + (b.error?.message || r.status));

  const { idToken, refreshToken, localId } = b;
  const auth = () => ({ authorization: `Bearer ${idToken}`, 'content-type': 'application/json' });

  if (profile && projectFsBase) {
    // A host with no profile shows as a nameless admin anywhere the app reads
    // one. Cheap to add, and cleanup removes it.
    await fetch(`${projectFsBase}/users/${localId}`, {
      method: 'PATCH', headers: auth(),
      body: JSON.stringify({ fields: {
        name: { stringValue: 'Harness Host' },
        firstName: { stringValue: 'Harness' },
        lastName: { stringValue: 'Host' },
        email: { stringValue: email },
        autoCreated: { booleanValue: false },
        sportProfileDone: { booleanValue: true },
        points: { integerValue: '0' },
        matchesPlayed: { integerValue: '0' },
      }}),
    });
  }

  async function destroy() {
    // Sign in fresh: the harness has been running for a while and this token
    // may have aged out.
    const s = await fetch(`${IDT}/accounts:signInWithPassword?key=${apiKey}`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    });
    if (!s.ok) return false;
    const { idToken: tok } = await s.json();
    if (projectFsBase) {
      await fetch(`${projectFsBase}/users/${localId}`, {
        method: 'DELETE', headers: { authorization: `Bearer ${tok}` },
      });
    }
    const d = await fetch(`${IDT}/accounts:delete?key=${apiKey}`, {
      method: 'POST', headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ idToken: tok }),
    });
    return d.ok;
  }

  return { email, password, idToken, refreshToken, localId, destroy };
}
