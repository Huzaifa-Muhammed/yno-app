// Remove a throwaway app account and everything it created in the client's
// live Firebase. Usage: node sweep_account.mjs <email> <password> [--dry]
//
// Subcollections do NOT cascade over REST, so each is listed and walked.
const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const PROJECT = 'yno-app-e96f5';
const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const IDT = 'https://identitytoolkit.googleapis.com/v1';

const [EMAIL, PW] = process.argv.slice(2);
const DRY = process.argv.includes('--dry');
if (!EMAIL || !PW) { console.error('usage: node sweep_account.mjs <email> <password> [--dry]'); process.exit(1); }

const si = await fetch(`${IDT}/accounts:signInWithPassword?key=${API_KEY}`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: EMAIL, password: PW, returnSecureToken: true }),
});
const s = await si.json();
if (!si.ok) { console.error('sign-in failed:', s.error?.message); process.exit(1); }
const { idToken, localId: uid } = s;
console.log(`signed in as ${EMAIL} (${uid})${DRY ? '  [DRY RUN]' : ''}\n`);

const H = { authorization: `Bearer ${idToken}`, 'content-type': 'application/json' };
const del = async (path) => {
  if (DRY) { console.log(`  would delete  ${path}`); return; }
  const r = await fetch(`${FS}/${path}`, { method: 'DELETE', headers: H });
  console.log(`  ${r.ok ? 'gone' : 'FAIL ' + r.status}  ${path}`);
};
const listIds = async (parentPath, coll) => {
  const r = await fetch(`${FS}/${parentPath}/${coll}?pageSize=300`, { headers: H });
  if (!r.ok) return [];
  const b = await r.json();
  return (b.documents || []).map((d) => d.name.split('/').pop());
};

// -- matches this account created -------------------------------------------
const q = await fetch(`${FS}:runQuery`, {
  method: 'POST', headers: H,
  body: JSON.stringify({ structuredQuery: {
    from: [{ collectionId: 'matches' }],
    where: { fieldFilter: { field: { fieldPath: 'adminUid' }, op: 'EQUAL',
             value: { stringValue: uid } } },
    limit: 100,
  }}),
});
const rows = q.ok ? (await q.json()).filter((r) => r.document) : [];
console.log(`matches created by this account: ${rows.length}`);
for (const r of rows) {
  const mid = r.document.name.split('/').pop();
  for (const sub of ['players', 'pending', 'goals', 'events', 'votes']) {
    for (const id of await listIds(`matches/${mid}`, sub)) await del(`matches/${mid}/${sub}/${id}`);
  }
  await del(`matches/${mid}`);
}

// -- the profile -------------------------------------------------------------
console.log('\nprofile:');
for (const sub of ['notifications', 'playedWith']) {
  for (const id of await listIds(`users/${uid}`, sub)) await del(`users/${uid}/${sub}/${id}`);
}
await del(`users/${uid}`);

// -- teams this account owns -------------------------------------------------
const tq = await fetch(`${FS}:runQuery`, {
  method: 'POST', headers: H,
  body: JSON.stringify({ structuredQuery: {
    from: [{ collectionId: 'teams' }],
    where: { fieldFilter: { field: { fieldPath: 'ownerUid' }, op: 'EQUAL',
             value: { stringValue: uid } } },
    limit: 50,
  }}),
});
const teams = tq.ok ? (await tq.json()).filter((r) => r.document) : [];
console.log(`\nteams owned: ${teams.length}`);
for (const r of teams) {
  const tid = r.document.name.split('/').pop();
  for (const sub of ['members', 'invites', 'joinRequests', 'private']) {
    for (const id of await listIds(`teams/${tid}`, sub)) await del(`teams/${tid}/${sub}/${id}`);
  }
  await del(`teams/${tid}`);
}

// -- the auth account --------------------------------------------------------
console.log('\nauth:');
if (DRY) { console.log(`  would delete auth account ${EMAIL}`); }
else {
  const d = await fetch(`${IDT}/accounts:delete?key=${API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ idToken }),
  });
  console.log(`  ${d.ok ? 'gone' : 'FAIL'}  ${EMAIL} (${uid})`);
}
