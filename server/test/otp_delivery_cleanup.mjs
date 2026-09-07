// OTP DELIVERY PROOF — part 3: remove every document and account the test made.
// Subcollections do NOT cascade over the REST API, so each one is named.
import fs from 'node:fs';
const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const PROJECT = 'yno-app-e96f5';
const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const IDT = 'https://identitytoolkit.googleapis.com/v1';
const S = new URL('./otp_state.json', import.meta.url).pathname.replace(/^\//, '');
const st = JSON.parse(fs.readFileSync(S, 'utf8'));

const signIn = async (email, password) => {
  const r = await fetch(`${IDT}/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password, returnSecureToken: true }),
  });
  const b = await r.json();
  return r.ok ? b : null;
};

const host = await signIn(st.HOST_EMAIL, st.HOST_PW);
if (!host) { console.error('cannot sign in as the disposable host — aborting'); process.exit(1); }
const auth = () => ({ authorization: `Bearer ${host.idToken}` });

const del = async (path) => {
  const r = await fetch(`${FS_BASE}/${path}`, { method: 'DELETE', headers: auth() });
  console.log(`  ${r.ok ? 'gone' : 'FAIL ' + r.status}  ${path}`);
};

console.log('firestore:');
await del(`matches/${st.MID}/players/${st.targetUid}`);
await del(`matches/${st.MID}/pending/${st.targetUid}`);
await del(`matches/${st.MID}`);
await del(`users/${st.targetUid}/notifications/${st.targetUid}`);
await del(`users/${st.targetUid}`);
await del(`users/${st.hostUid}/notifications/${st.targetUid}`);
await del(`users/${st.hostUid}`);

console.log('auth accounts:');
// 🔑 Only ever delete an account THIS test created. huzm651@gmail.com is the
// super-admin in firestore.rules, the Firebase CLI login and the Resend account
// owner — a stray delete there is unrecoverable.
if (st.isNewAccount !== true) {
  console.error(`  REFUSED  ${st.TARGET} pre-existed this test — not deleting it.`);
  process.exit(1);
}
// The claimed account still takes the well-known host-created password.
const target = await signIn(st.TARGET, '123456');
if (target) {
  const d = await fetch(`${IDT}/accounts:delete?key=${API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ idToken: target.idToken }),
  });
  console.log(`  ${d.ok ? 'gone' : 'FAIL ' + d.status}  ${st.TARGET} (${st.targetUid})`);
} else {
  console.log(`  SKIP  ${st.TARGET} — password sign-in refused; delete by hand if it survives`);
}
const d2 = await fetch(`${IDT}/accounts:delete?key=${API_KEY}`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ idToken: host.idToken }),
});
console.log(`  ${d2.ok ? 'gone' : 'FAIL ' + d2.status}  ${st.HOST_EMAIL} (${st.hostUid})`);

console.log('\nleft alone on purpose: emailOtps/* (Worker-only, deleted on verify, 10-min TTL)');
