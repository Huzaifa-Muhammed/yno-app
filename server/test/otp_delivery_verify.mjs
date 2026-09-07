// OTP DELIVERY PROOF — part 2: spend the code the user read out of their inbox.
import fs from 'node:fs';
const WORKER = 'https://yno-otp.yno-otp-server.workers.dev';
const IDT = 'https://identitytoolkit.googleapis.com/v1';
const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const S = new URL('./otp_state.json', import.meta.url).pathname.replace(/^\//, '');
const st = JSON.parse(fs.readFileSync(S, 'utf8'));
const CODE = (process.argv[2] || '').trim();
if (!/^\d{6}$/.test(CODE)) { console.error('usage: node otp_verify.mjs <6 digits>'); process.exit(1); }

let pass = 0, fail = 0;
const check = (l, ok, d) => { ok ? pass++ : fail++; console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${l}${d !== undefined ? ' -> ' + d : ''}`); };

const r = await fetch(`${WORKER}/verify-otp`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: st.TARGET, code: CODE }),
});
const b = await r.json();
console.log('POST /verify-otp ->', r.status,
    JSON.stringify({ ...b, customToken: b.customToken ? '<token>' : undefined }));

check('the emailed code was accepted', r.ok && b.ok === true, b.error || '');
check('a custom token was returned, not {ok:true}', typeof b.customToken === 'string' && b.customToken.length > 100);
check('the token is for the account the join created', b.uid === st.targetUid, b.uid);

if (b.customToken) {
  // 🔑 The whole point of returning a token: it must actually sign in.
  const ct = await fetch(`${IDT}/accounts:signInWithCustomToken?key=${API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ token: b.customToken, returnSecureToken: true }),
  });
  const cb = await ct.json();
  // ⚠️ signInWithCustomToken returns idToken/refreshToken but NOT localId —
  // the uid is a claim inside the ID token. Reading cb.localId fails a working
  // token. Same trap documented at join_identity_e2e.mjs:149.
  const uidFromIdToken = (tok) => {
    try {
      const p = JSON.parse(Buffer.from(String(tok).split('.')[1], 'base64url').toString());
      return p.user_id || p.sub;
    } catch (_) { return null; }
  };
  check('the custom token really signs in', ct.ok && uidFromIdToken(cb.idToken) === st.targetUid,
      ct.status + ' ' + (uidFromIdToken(cb.idToken) || cb.error?.message));
}

// The code must be single-use — it is burned before the token is minted.
const again = await fetch(`${WORKER}/verify-otp`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: st.TARGET, code: CODE }),
});
const ab = await again.json();
check('the same code cannot be spent twice', again.status === 400 && ab.ok !== true, ab.error);

console.log(`\n${fail === 0 ? 'ALL GREEN' : 'FAILURES'}  ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
