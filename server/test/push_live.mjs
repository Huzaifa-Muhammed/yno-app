// Live checks for POST /send-push against the deployed Worker.
//
// Delivery to a real handset cannot be asserted from here — that needs a phone
// with a registered FCM token — but everything up to the FCM call can be, and
// those are the parts that silently break: the auth gate, the uid lookup, and
// the Firestore array read (`fcmTokens` is an arrayValue, which the shared
// `fields()` helper flattens to null — see push.js).
import { createDisposableHost } from './_disposable_host.mjs';

const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const PROJECT = 'yno-app-e96f5';
const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const WORKER = 'https://yno-otp.yno-otp-server.workers.dev';

let pass = 0, fail = 0;
const check = (label, ok, detail) => {
  ok ? pass++ : fail++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}${detail !== undefined ? ' -> ' + detail : ''}`);
};

const post = (body) => fetch(`${WORKER}/send-push`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});

const host = await createDisposableHost(API_KEY, FS);
console.log(`sender: ${host.email} (${host.localId})\n`);

// ---------------------------------------------------------------------------
console.log('1. THE AUTH GATE — without it this is an open spam relay');
// ---------------------------------------------------------------------------
let r = await post({ uid: host.localId, title: 'x', body: 'y' });
check('no idToken is refused', r.status === 401, r.status);

r = await post({ idToken: 'not-a-token', uid: host.localId, title: 'x', body: 'y' });
check('a garbage idToken is refused', r.status === 401, r.status);

r = await post({ idToken: host.idToken, title: 'x', body: 'y' });
check('a missing recipient uid is refused', r.status === 400, r.status);

r = await post({ idToken: host.idToken, uid: host.localId });
check('empty title AND body is refused', r.status === 400, r.status);

// ---------------------------------------------------------------------------
console.log('\n2. RECIPIENT LOOKUP');
// ---------------------------------------------------------------------------
r = await post({ idToken: host.idToken, uid: host.localId, title: 'Hi', body: 'There' });
let b = await r.json();
check('a signed-in caller is accepted', r.ok && b.ok === true, r.status);
check('a user with no devices is a success, not an error', b.sent === 0 && b.failed === 0,
    JSON.stringify(b));

r = await post({ idToken: host.idToken, uid: 'no_such_user_1234567890', title: 'Hi', body: 'There' });
b = await r.json();
check('an unknown recipient does not error', r.ok && b.ok === true && b.sent === 0,
    JSON.stringify(b));

// ---------------------------------------------------------------------------
console.log('\n3. THE ARRAY READ — a fake token proves fcmTokens is parsed');
// ---------------------------------------------------------------------------
// 🔑 If `fcmTokens` were read with the shared fields()/plain() helper it would
// come back null and this would report sent:0/failed:0 — indistinguishable from
// "no devices". A bogus token must therefore be ATTEMPTED and fail at FCM.
await fetch(`${FS}/users/${host.localId}?updateMask.fieldPaths=fcmTokens`, {
  method: 'PATCH',
  headers: { authorization: `Bearer ${host.idToken}`, 'content-type': 'application/json' },
  body: JSON.stringify({ fields: { fcmTokens: { arrayValue: { values: [
    { stringValue: 'definitely-not-a-real-fcm-token' },
  ] } } } }),
});

r = await post({ idToken: host.idToken, uid: host.localId, title: 'Hi', body: 'There' });
b = await r.json();
check('the bogus token was actually attempted (failed:1, not sent:0/failed:0)',
    b.failed === 1 && b.sent === 0, JSON.stringify(b));

// ---------------------------------------------------------------------------
console.log('\n4. cleanup');
// ---------------------------------------------------------------------------
check('the disposable sender was removed', await host.destroy());

console.log(`\n${fail === 0 ? 'ALL GREEN' : 'FAILURES'}  ${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
