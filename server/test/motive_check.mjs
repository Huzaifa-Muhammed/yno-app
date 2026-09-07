// Does the website meet the two stated motives, field for field?
//
//   MOTIVE 1  no account  -> joins "the same way as we add a guest in matches",
//                            i.e. the lobby's Add Player (name + email), which
//                            is `addNewPlayer` -> createPlayerAccount + joinMatch.
//   MOTIVE 2  has account -> joins "like an actual player", i.e. the in-app
//                            join-by-code, which is joinMatch with the profile's
//                            own name and position.
//
// Both expectations below are derived from the Dart source, not from what the
// server happens to return — that is the point. `MatchPlayer.toMap()` in
// models.dart, called from `addNewPlayer` (match_repository.dart) and from
// `match_actions.dart`'s code join.
import { createDisposableHost } from './_disposable_host.mjs';

const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const PROJECT = 'yno-app-e96f5';
const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const IDT = 'https://identitytoolkit.googleapis.com/v1';
const WORKER = 'https://yno-otp.yno-otp-server.workers.dev';

// Made per run and destroyed at the end; this used to read a refresh token
// from a session scratchpad that no longer exists — see _disposable_host.mjs.
const host = await createDisposableHost(API_KEY, FS_BASE);
let idToken;
const HOST = host.localId;

async function refresh() {
  const r = await fetch(`https://securetoken.googleapis.com/v1/token?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=refresh_token&refresh_token=${host.refreshToken}`,
  });
  if (!r.ok) throw new Error('refresh failed');
  idToken = (await r.json()).id_token;
}
const auth = () => ({ authorization: `Bearer ${idToken}`, 'content-type': 'application/json' });
const str = (s) => ({ stringValue: s });
const int = (n) => ({ integerValue: String(n) });
const bool = (b) => ({ booleanValue: b });
const val = (f) => !f ? null
  : ('stringValue' in f ? f.stringValue
  : ('integerValue' in f ? Number(f.integerValue)
  : ('booleanValue' in f ? f.booleanValue
  : ('timestampValue' in f ? 'TIMESTAMP'
  : ('arrayValue' in f ? (f.arrayValue.values || []).map((x) => x.stringValue)
  : ('nullValue' in f ? null : undefined))))));

let pass = 0, fail = 0;
const check = (label, ok, detail) => {
  ok ? pass++ : fail++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}${detail !== undefined ? '  ->  ' + detail : ''}`);
};

async function rfetch(url, init, tries = 4) {
  let e;
  for (let i = 0; i < tries; i++) {
    try { return await fetch(url, init); } catch (err) {
      e = err; await new Promise((r) => setTimeout(r, 600 * (i + 1)));
    }
  }
  throw e;
}
const post = (body) => rfetch(`${WORKER}/guest-join`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});
const get = async (path) => {
  const r = await fetch(`${FS_BASE}/${path}`, { headers: auth() });
  return r.ok ? await r.json() : null;
};

/** The player document the APP writes. MatchPlayer.toMap(), models.dart:740. */
const appPlayerDoc = ({ name, team, position, joinedVia, isAdmin, isGuest, isCaptain }) => ({
  name, team, position, goals: 0, assists: 0,
  joinedVia, isAdmin, isGuest, isCaptain, joinedAt: 'TIMESTAMP',
});

const asPlain = (doc) => {
  const out = {};
  for (const [k, v] of Object.entries(doc.fields)) out[k] = val(v);
  return out;
};

const diff = (actual, expected) => {
  const keys = new Set([...Object.keys(actual), ...Object.keys(expected)]);
  const bad = [];
  for (const k of keys) {
    if (JSON.stringify(actual[k]) !== JSON.stringify(expected[k])) {
      bad.push(`${k}: got ${JSON.stringify(actual[k])} want ${JSON.stringify(expected[k])}`);
    }
  }
  return bad;
};

await refresh();
const seed = String(Math.floor(Math.random() * 9000) + 1000);
const CODE = 'MOTV' + seed.slice(0, 2);
const MID = 'test_motive_' + seed;
const NEW_EMAIL = `motive.new.${seed}@example.com`;
const OLD_EMAIL = `motive.has.${seed}@example.com`;

await fetch(`${FS_BASE}/matches/${MID}`, {
  method: 'PATCH', headers: auth(),
  body: JSON.stringify({ fields: {
    code: str(CODE), codeA: str(CODE), codeB: str(CODE + 'B'),
    status: str('lobby'), name: str('Motive check'),
    teamAName: str('Falcons'), teamBName: str('Eagles'),
    adminUid: str(HOST), format: str('5v5'), durationMin: int(45),
    scoreA: int(0), scoreB: int(0), isPublic: bool(false),
    playerUids: { arrayValue: { values: [] } },
  } }),
});

// ===========================================================================
console.log('\nMOTIVE 1 — no account: joins the way the lobby "Add Player" does');
console.log('           (app path: addNewPlayer -> createPlayerAccount + joinMatch)');
// ===========================================================================
const r1 = await post({ code: CODE, name: 'Nobody Yet', email: NEW_EMAIL });
const j1 = await r1.json();
const NEW_UID = j1.uid;
check('the join succeeds', r1.ok && j1.ok === true);

const p1 = await get(`matches/${MID}/players/${NEW_UID}`);
check('a player document exists', !!p1);
if (p1) {
  // What addNewPlayer produces today: profile name (== typed, the account is
  // brand new), no position, isGuest from autoCreated == true.
  const want = appPlayerDoc({
    name: 'Nobody Yet', team: 'A', position: null, joinedVia: 'link',
    isAdmin: false, isGuest: true, isCaptain: false,
  });
  const bad = diff(asPlain(p1), want);
  check('the player document matches the app\'s, field for field', bad.length === 0,
    bad.length ? bad.join(' | ') : '10/10 fields identical');
}
check('shows the GUEST badge in the lobby (isGuest true)',
  p1 && val(p1.fields.isGuest) === true);

const u1 = await get(`users/${NEW_UID}`);
check('a real account was created for them', !!u1);
check('flagged autoCreated, so it stays claimable', u1 && val(u1.fields.autoCreated) === true);
check('their email is on it, so the claim flow can find them',
  u1 && val(u1.fields.email) === NEW_EMAIL, u1 && val(u1.fields.email));
const pw = await fetch(`${IDT}/accounts:signInWithPassword?key=${API_KEY}`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: NEW_EMAIL, password: '123456', returnSecureToken: true }),
});
check('they can sign in with the app password, like any host-added player', pw.ok);

const m1 = await get(`matches/${MID}`);
check('in playerUids — same as addNewPlayer, so the match counts as theirs',
  (val(m1.fields.playerUids) || []).includes(NEW_UID));
check('the host was notified', !!(await get(`users/${HOST}/notifications/${NEW_UID}`)));

// ===========================================================================
console.log('\nMOTIVE 2 — has an account: joins like an actual player');
console.log('           (app path: joinMatch with the profile\'s own name + position)');
// ===========================================================================
// Build a fully real account: created, then claimed and filled in.
const mk = await post({ code: CODE + 'B', name: 'Temp', email: OLD_EMAIL });
const mkb = await mk.json();
const OLD_UID = mkb.uid;
await fetch(`${FS_BASE}/users/${OLD_UID}?updateMask.fieldPaths=name&updateMask.fieldPaths=position&updateMask.fieldPaths=autoCreated`, {
  method: 'PATCH', headers: auth(),
  body: JSON.stringify({ fields: {
    name: str('Real Player'), position: str('Striker'), autoCreated: bool(false),
  } }),
});
// Clear the seeding join so this is a clean first join on side A.
await fetch(`${FS_BASE}/matches/${MID}/players/${OLD_UID}`, { method: 'DELETE', headers: auth() });

const r2 = await post({ code: CODE, name: 'ignore this typed name', email: OLD_EMAIL });
const j2 = await r2.json();
check('the join succeeds', r2.ok && j2.ok === true);
check('joins as their own uid, not a new one', j2.uid === OLD_UID, j2.uid);
check('no account was created', j2.isNewAccount === false);
check('🔑 no credential handed out for an existing account',
  j2.customToken === undefined, j2.customToken ? 'TOKEN LEAKED' : 'none');

const p2 = await get(`matches/${MID}/players/${OLD_UID}`);
check('a player document exists', !!p2);
if (p2) {
  // What the in-app code join produces: me.name, me.position, isGuest false.
  const want = appPlayerDoc({
    name: 'Real Player', team: 'A', position: 'Striker', joinedVia: 'link',
    isAdmin: false, isGuest: false, isCaptain: false,
  });
  const bad = diff(asPlain(p2), want);
  check('the player document matches the app\'s, field for field', bad.length === 0,
    bad.length ? bad.join(' | ') : '10/10 fields identical');
}
check('NOT a guest — no badge, full player',
  p2 && val(p2.fields.isGuest) === false);
check('their saved position came across', p2 && val(p2.fields.position) === 'Striker');
check('their profile name won over the typed one', p2 && val(p2.fields.name) === 'Real Player');

const u2 = await get(`users/${OLD_UID}`);
check('their profile was not touched', u2 && val(u2.fields.name) === 'Real Player');
const m2 = await get(`matches/${MID}`);
check('in playerUids, so the match counts towards their career',
  (val(m2.fields.playerUids) || []).includes(OLD_UID));

// ===========================================================================
console.log('\nBOTH — the one field that differs from an in-app join');
// ===========================================================================
check("joinedVia is 'link' (in-app would be 'added' / 'code')",
  p1 && val(p1.fields.joinedVia) === 'link' && p2 && val(p2.fields.joinedVia) === 'link',
  'provenance label only — grep confirms nothing in lib/ ever reads it');

// ---------------------------------------------------------------------------
console.log('\ncleaning up');
await refresh();
const del = async (p) => {
  const r = await fetch(`${FS_BASE}/${p}`, { method: 'DELETE', headers: auth() });
  return r.ok || r.status === 404;
};
const gone = [];
for (const uid of [NEW_UID, OLD_UID]) {
  gone.push(await del(`matches/${MID}/players/${uid}`));
  gone.push(await del(`users/${HOST}/notifications/${uid}`));
  gone.push(await del(`users/${uid}`));
}
gone.push(await del(`matches/${MID}`));
for (const email of [NEW_EMAIL, OLD_EMAIL]) {
  const s = await fetch(`${IDT}/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password: '123456', returnSecureToken: true }),
  });
  if (!s.ok) { gone.push(true); continue; }
  const { idToken: tok } = await s.json();
  const d = await fetch(`${IDT}/accounts:delete?key=${API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ idToken: tok }),
  });
  gone.push(d.ok);
}
// The host this run made for itself goes too.
gone.push(await host.destroy());
check('everything this test created was removed', gone.every(Boolean));

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
