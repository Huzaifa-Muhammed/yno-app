// OTP DELIVERY PROOF — part 1: set up a disposable match and send one real code.
//
// Deliberately self-contained: it creates its OWN host account via the public
// accounts:signUp, so it does not depend on the lost del_state.json refresh
// token of the throwaway account (SESSION_PROGRESS §69, priority 3).
// Rules allow it: matches/{mid} and users/{uid} are `allow write: if signedIn()`.
import fs from 'node:fs';

const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const PROJECT = 'yno-app-e96f5';
const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const IDT = 'https://identitytoolkit.googleapis.com/v1';
const WORKER = 'https://yno-otp.yno-otp-server.workers.dev';
const STATE = new URL('./otp_state.json', import.meta.url).pathname.replace(/^\//, '');

const TARGET = process.argv[2];
if (!TARGET) { console.error('usage: node otp_send.mjs <email>'); process.exit(1); }

const SEED = String(Math.floor(Math.random() * 9000) + 1000);
const CODE = 'OTP' + SEED;
const MID  = 'test_otpdelivery_' + SEED;
const HOST_EMAIL = `yno.otphost.${SEED}@example.com`;
const HOST_PW = 'Hst!' + SEED + 'xQ';

const str = (s) => ({ stringValue: s });
const int = (n) => ({ integerValue: String(n) });
const bool = (b) => ({ booleanValue: b });

async function rfetch(url, init, tries = 4) {
  let last;
  for (let i = 0; i < tries; i++) {
    try { return await fetch(url, init); }
    catch (e) { last = e; await new Promise(r => setTimeout(r, 600 * (i + 1))); }
  }
  throw last;
}

// ---- 1. a disposable host --------------------------------------------------
const su = await fetch(`${IDT}/accounts:signUp?key=${API_KEY}`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: HOST_EMAIL, password: HOST_PW, returnSecureToken: true }),
});
const sub = await su.json();
if (!su.ok) { console.error('1. host signUp FAILED', su.status, sub.error?.message); process.exit(1); }
const idToken = sub.idToken, hostUid = sub.localId;
console.log(`1. disposable host created -> ${HOST_EMAIL} (${hostUid})`);

const auth = () => ({ authorization: `Bearer ${idToken}`, 'content-type': 'application/json' });

// ---- 2. a disposable match -------------------------------------------------
const mk = await fetch(`${FS_BASE}/matches/${MID}`, {
  method: 'PATCH', headers: auth(),
  body: JSON.stringify({ fields: {
    code: str(CODE), codeA: str(CODE), codeB: str(CODE + 'B'),
    status: str('lobby'), name: str('OTP delivery proof'),
    teamAName: str('Test Falcons'), teamBName: str('Test Eagles'),
    adminUid: str(hostUid), format: str('5v5'), durationMin: int(45),
    scoreA: int(0), scoreB: int(0), isPublic: bool(false),
    playerUids: { arrayValue: { values: [] } },
  }}),
});
if (!mk.ok) { console.error('2. match create FAILED', mk.status, (await mk.text()).slice(0, 300)); process.exit(1); }
console.log(`2. disposable match ${MID} created with code ${CODE}`);

// ---- 3. the website join creates the claimable account ---------------------
const gj = await rfetch(`${WORKER}/guest-join`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ code: CODE, name: 'OTP Delivery Test', email: TARGET }),
});
const g = await gj.json();
console.log('3. POST /guest-join ->', gj.status,
    JSON.stringify({ ...g, customToken: g.customToken ? '<token>' : undefined }));
if (!gj.ok || !g.ok) { console.error('   guest-join FAILED — stopping'); process.exit(1); }
const targetUid = g.uid;
console.log(`   isNewAccount=${g.isNewAccount} isGuest=${g.isGuest} uid=${targetUid}`);

fs.writeFileSync(STATE, JSON.stringify(
  { SEED, CODE, MID, HOST_EMAIL, HOST_PW, hostUid, TARGET, targetUid,
    isNewAccount: g.isNewAccount }, null, 2));

// ---- 4. the real send ------------------------------------------------------
const ro = await rfetch(`${WORKER}/request-otp`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: TARGET }),
});
const o = await ro.json();
console.log('4. POST /request-otp ->', ro.status, JSON.stringify(o));
if (!ro.ok || !o.ok) { console.error('   request-otp FAILED — stopping'); process.exit(1); }

console.log('\n=== SENT ===');
console.log(`A 6-digit code was accepted for sending to ${TARGET}.`);
console.log(`Code valid ${o.expiresInSeconds}s. State saved to otp_state.json.`);
console.log('Check the inbox AND the spam folder.');
