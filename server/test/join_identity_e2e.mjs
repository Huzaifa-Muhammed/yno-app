// End-to-end test of the ACCOUNT-BACKED website join, against DISPOSABLE matches.
//
// A real client match is not a test fixture — a stray player in someone's lobby
// is a support question — so this creates its own matches and its own account,
// checks every document the app will later read, and then deletes all of it.
//
// Two matches, because the whole point is the two identity branches and the
// duplicate guard would collide them:
//   match 1: an email nobody has  -> an account is created, and joins
//   match 2: the SAME email again -> the existing account joins as itself
import { createDisposableHost } from './_disposable_host.mjs';

const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const PROJECT = 'yno-app-e96f5';
const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const IDT = 'https://identitytoolkit.googleapis.com/v1';
const WORKER = 'https://yno-otp.yno-otp-server.workers.dev';

// The host is created per run and destroyed at the end. It used to be read
// from a session scratchpad, which stopped existing — see _disposable_host.mjs.
const host = await createDisposableHost(API_KEY, FS_BASE);

// The throwaway doubles as the host: rules need a signed-in user to create or
// delete a match document.
let { idToken, refreshToken, localId } = host;

async function refresh() {
  const r = await fetch(`https://securetoken.googleapis.com/v1/token?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: `grant_type=refresh_token&refresh_token=${refreshToken}`,
  });
  if (!r.ok) throw new Error('token refresh failed: ' + (await r.text()).slice(0, 200));
  idToken = (await r.json()).id_token;
  console.log('   (host id token refreshed)');
}

const auth = () => ({ authorization: `Bearer ${idToken}`, 'content-type': 'application/json' });

// Transient ECONNRESETs happen against workers.dev; a flaky socket must not
// read as a failing feature.
async function rfetch(url, init, tries = 4) {
  let lastErr;
  for (let i = 0; i < tries; i++) {
    try { return await fetch(url, init); } catch (e) {
      lastErr = e;
      await new Promise((r) => setTimeout(r, 600 * (i + 1)));
    }
  }
  throw lastErr;
}

const str = (s) => ({ stringValue: s });
const int = (n) => ({ integerValue: String(n) });
const bool = (b) => ({ booleanValue: b });

let pass = 0, fail = 0;
const check = (label, ok, detail) => {
  ok ? pass++ : fail++;
  console.log(`  ${ok ? 'PASS' : 'FAIL'}  ${label}${detail !== undefined ? ' -> ' + detail : ''}`);
};

const get = async (path, withAuth = false) => {
  const r = await fetch(`${FS_BASE}/${path}` + (withAuth ? '' : `?key=${API_KEY}`),
      withAuth ? { headers: auth() } : {});
  return { ok: r.ok, status: r.status, body: r.ok ? await r.json() : null };
};
const val = (f) => !f ? null
  : ('stringValue' in f ? f.stringValue
  : ('integerValue' in f ? Number(f.integerValue)
  : ('booleanValue' in f ? f.booleanValue
  : ('timestampValue' in f ? f.timestampValue
  : ('arrayValue' in f ? (f.arrayValue.values || [])
  : ('mapValue' in f ? (f.mapValue.fields || {})
  : ('nullValue' in f ? null : undefined)))))));

const post = (body) => rfetch(`${WORKER}/guest-join`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify(body),
});

const SEED = String(Math.floor(Math.random() * 9000) + 1000);
const CODE1 = 'TSTA' + SEED.slice(0, 2);
const CODE2 = 'TSTB' + SEED.slice(2, 4);
const M1 = 'test_join_a_' + SEED;
const M2 = 'test_join_b_' + SEED;
const NEW_EMAIL = `web.newbie.${SEED}@example.com`;

const makeMatch = (id, code, teamA) => fetch(`${FS_BASE}/matches/${id}`, {
  method: 'PATCH',
  headers: auth(),
  body: JSON.stringify({
    fields: {
      code: str(code), codeA: str(code), codeB: str(code + 'B'),
      status: str('lobby'), name: str('Identity join test'),
      teamAName: str(teamA), teamBName: str('Test Eagles'),
      adminUid: str(localId), format: str('5v5'), durationMin: int(45),
      scoreA: int(0), scoreB: int(0), isPublic: bool(false),
      playerUids: { arrayValue: { values: [] } },
    },
  }),
});

await refresh();

// ---- 0. disposable matches -------------------------------------------------
const [c1, c2] = await Promise.all([
  makeMatch(M1, CODE1, 'Test Falcons'),
  makeMatch(M2, CODE2, 'Test Wolves'),
]);
console.log(`0. matches ${M1} (${CODE1}) -> ${c1.status}, ${M2} (${CODE2}) -> ${c2.status}`);
if (!c1.ok || !c2.ok) { console.log(await c1.text()); process.exit(1); }

// ---------------------------------------------------------------------------
console.log('\n1. BRANCH B — an email with no account behind it');
// ---------------------------------------------------------------------------
const r1 = await post({ code: CODE1, name: 'Web Newbie', email: NEW_EMAIL });
const j1 = await r1.json();
console.log('   POST /guest-join ->', r1.status, JSON.stringify({ ...j1, customToken: j1.customToken ? '<token>' : undefined }));
check('join accepted', r1.ok && j1.ok === true);
check('reports a NEW account was created', j1.isNewAccount === true, j1.isNewAccount);
// 🔑 A stub profile IS a guest — the app's own addTeamRoster rule.
check('a brand-new account joins as a GUEST', j1.isGuest === true, j1.isGuest);
check('uid is a real Firebase uid, not a g_ id', /^[A-Za-z0-9]{20,}$/.test(j1.uid || ''), j1.uid);
check('a custom token was returned for the silent sign-in', typeof j1.customToken === 'string' && j1.customToken.length > 100);
check('lands on side A for the shared code', j1.team === 'A', j1.team);
check('team name returned', j1.teamName === 'Test Falcons', j1.teamName);
check('not pending for a lobby match', j1.pending === false);

const NEW_UID = j1.uid;

// -- the auth account really exists, with the app's password ----------------
const pwSignIn = await fetch(`${IDT}/accounts:signInWithPassword?key=${API_KEY}`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: NEW_EMAIL, password: '123456', returnSecureToken: true }),
});
const pwBody = await pwSignIn.json();
check('the auth account exists and takes the app password', pwSignIn.ok && pwBody.localId === NEW_UID,
  pwSignIn.status + ' ' + (pwBody.localId || pwBody.error?.message));
const newAccountIdToken = pwBody.idToken;

// -- the custom token is a working credential -------------------------------
const ctSignIn = await fetch(`${IDT}/accounts:signInWithCustomToken?key=${API_KEY}`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ token: j1.customToken, returnSecureToken: true }),
});
const ctBody = await ctSignIn.json();
// ⚠️ accounts:signInWithCustomToken returns idToken/refreshToken but NOT
// localId — the uid is a claim inside the ID token. Checking `body.localId`
// here reads `undefined` and fails a working token.
const uidFromIdToken = (tok) => {
  try {
    const p = JSON.parse(Buffer.from(String(tok).split('.')[1], 'base64url').toString());
    return p.user_id || p.sub;
  } catch (_) { return null; }
};
check('the custom token signs in as that same account',
  ctSignIn.ok && uidFromIdToken(ctBody.idToken) === NEW_UID,
  ctSignIn.status + ' ' + (uidFromIdToken(ctBody.idToken) || ctBody.error?.message));

// -- the users/{uid} profile ------------------------------------------------
const APP_USER_FIELDS = [
  'autoCreated', 'bestScoringMatch', 'bestStreak', 'careerAssists', 'careerGoals',
  'communityCount', 'contactSync', 'createdAt', 'currentStreak', 'deactivated',
  'dob', 'dobLocked', 'draws', 'email', 'fcmTokens', 'firstName', 'followersCount',
  'following', 'formLast5', 'gender', 'goalsByFormat', 'goalsBySurface', 'hatTricks',
  'language', 'lastName', 'losses', 'matchesPlayed', 'motmCount', 'name',
  'notifyFriendActivity', 'notifyMatchAlerts', 'phone', 'photoPublicId', 'photoUrl',
  'points', 'position', 'preferredFoot', 'profilePublic', 'reactivateAt',
  'referralCode', 'referredBy', 'skillLevel', 'socialLinks', 'socialVisibility',
  'sportProfileDone', 'tcAcceptedAt', 'unbeatenStreak', 'username', 'usernameLower',
  'wins',
].sort();

const profile = await get(`users/${NEW_UID}`);
check('users/{uid} profile written', profile.ok, 'HTTP ' + profile.status);
if (profile.ok) {
  const f = profile.body.fields;
  const keys = Object.keys(f).sort();
  check('profile has EVERY field AppUser.toMap writes',
    JSON.stringify(keys) === JSON.stringify(APP_USER_FIELDS),
    keys.length + ' fields; missing=' +
      JSON.stringify(APP_USER_FIELDS.filter((k) => !keys.includes(k))) +
      ' extra=' + JSON.stringify(keys.filter((k) => !APP_USER_FIELDS.includes(k))));
  check('name', val(f.name) === 'Web Newbie', val(f.name));
  check('firstName split like the app does', val(f.firstName) === 'Web', val(f.firstName));
  check('email stored', val(f.email) === NEW_EMAIL, val(f.email));
  check('autoCreated true — this is what makes it claimable', val(f.autoCreated) === true);
  check('referralCode generated', /^[A-Z2-9]{6}$/.test(val(f.referralCode) || ''), val(f.referralCode));
  check('createdAt is a real server timestamp', !!val(f.createdAt), val(f.createdAt));
  check('points start at 0', val(f.points) === 0, val(f.points));
  check('sportProfileDone false', val(f.sportProfileDone) === false);
}

// -- the player document ----------------------------------------------------
const p1 = await get(`matches/${M1}/players/${NEW_UID}`);
check('player document created under the real uid', p1.ok, 'HTTP ' + p1.status);
if (p1.ok) {
  const f = p1.body.fields;
  const keys = Object.keys(f).sort().join(',');
  check('player has EVERY field the app writes',
    keys === 'assists,goals,isAdmin,isCaptain,isGuest,joinedAt,joinedVia,name,position,team', keys);
  check('team is UPPERCASE A', val(f.team) === 'A', val(f.team));
  check("joinedVia is 'link'", val(f.joinedVia) === 'link', val(f.joinedVia));
  check('isGuest TRUE — the profile is a stub', val(f.isGuest) === true, val(f.isGuest));
  check('position is null — nobody has picked one yet', val(f.position) === null, val(f.position));
  check('joinedAt is a real server timestamp', !!val(f.joinedAt), val(f.joinedAt));
}

const m1doc = await get(`matches/${M1}`);
const uids1 = m1doc.ok ? (val(m1doc.body.fields.playerUids) || []).map((x) => x.stringValue) : [];
// ⚠️ In playerUids DESPITE isGuest — the array tracks real uids, not guest
// status. addTeamRoster does exactly this for auto-created team members.
check('playerUids contains the uid even though isGuest is true',
  uids1.includes(NEW_UID), JSON.stringify(uids1));

const noGuest = await get(`guests/${NEW_UID}`);
check('NO guests/ record — that collection is for accountless g_ ids',
  !noGuest.ok, 'HTTP ' + noGuest.status);

const note1 = await get(`users/${localId}/notifications/${NEW_UID}`, true);
check('host was notified in the bell', note1.ok, 'HTTP ' + note1.status);
if (note1.ok) {
  const f = note1.body.fields;
  check('notification names the player and team',
    String(val(f.body)).includes('Web Newbie') && String(val(f.body)).includes('Test Falcons'),
    val(f.body));
  check('notification routes to the lobby', val(f.route) === '/lobby', val(f.route));
}

// ---------------------------------------------------------------------------
console.log('\n2. THE DUPLICATE GUARD — joining the same match twice');
// ---------------------------------------------------------------------------
// Score first, so a rewritten player document is visible as data loss rather
// than as an identical document.
await fetch(`${FS_BASE}/matches/${M1}/players/${NEW_UID}?updateMask.fieldPaths=goals`, {
  method: 'PATCH', headers: auth(), body: JSON.stringify({ fields: { goals: int(3) } }),
});
const rDup = await post({ code: CODE1, name: 'Web Newbie', email: NEW_EMAIL });
const jDup = await rDup.json();
check('a second join reports "already"', rDup.ok && jDup.already === true, JSON.stringify(jDup.already));
check('and returns the same uid', jDup.uid === NEW_UID, jDup.uid);
check('and does NOT mint a token for an account it did not create',
  jDup.customToken === undefined, jDup.customToken ? '<token returned!>' : 'none');
const p1again = await get(`matches/${M1}/players/${NEW_UID}`);
check('the player document was NOT rewritten — goals survived',
  p1again.ok && val(p1again.body.fields.goals) === 3,
  p1again.ok ? val(p1again.body.fields.goals) : 'HTTP ' + p1again.status);

// ---------------------------------------------------------------------------
console.log('\n3. BRANCH A — the same email, now that the account is CLAIMED');
// ---------------------------------------------------------------------------
// Simulate the owner claiming it and filling in their profile: a name of their
// own, a position, and autoCreated cleared — which is exactly what
// `completeSportProfile` + the claim flow do. Branch A must now join them as a
// REAL player, under their own name and position, without rewriting anything.
await fetch(
  `${FS_BASE}/users/${NEW_UID}?updateMask.fieldPaths=name&updateMask.fieldPaths=position&updateMask.fieldPaths=autoCreated`, {
    method: 'PATCH', headers: auth(),
    body: JSON.stringify({ fields: {
      name: str('Renamed By Owner'),
      position: str('Midfielder'),
      autoCreated: bool(false),
    } }),
  });
const r2 = await post({ code: CODE2, name: 'Typed Something Else', email: NEW_EMAIL.toUpperCase() });
const j2 = await r2.json();
console.log('   POST /guest-join ->', r2.status, JSON.stringify({ ...j2, customToken: j2.customToken ? '<token>' : undefined }));
check('join accepted', r2.ok && j2.ok === true);
check('joins as the SAME existing uid', j2.uid === NEW_UID, j2.uid);
check('reports it did NOT create an account', j2.isNewAccount === false, j2.isNewAccount);
check('a CLAIMED account is NOT a guest', j2.isGuest === false, j2.isGuest);
check('🔑 NO custom token for an account that already existed',
  j2.customToken === undefined, j2.customToken ? '<TOKEN LEAKED>' : 'none');
check('a mixed-case address still finds the account',
  j2.uid === NEW_UID, NEW_EMAIL.toUpperCase());
check('the PROFILE name wins over what was typed into the form',
  j2.name === 'Renamed By Owner', j2.name);

const profile2 = await get(`users/${NEW_UID}`);
check('the existing profile was NOT overwritten',
  profile2.ok && val(profile2.body.fields.name) === 'Renamed By Owner',
  profile2.ok ? val(profile2.body.fields.name) : 'HTTP ' + profile2.status);

const p2 = await get(`matches/${M2}/players/${NEW_UID}`);
check('player document created on the second match', p2.ok, 'HTTP ' + p2.status);
if (p2.ok) {
  const f = p2.body.fields;
  check('isGuest false — a claimed account is a real player', val(f.isGuest) === false, val(f.isGuest));
  check('the saved POSITION was carried over, as the in-app join does',
    val(f.position) === 'Midfielder', val(f.position));
  check('the player document uses the profile name, not the typed one',
    val(f.name) === 'Renamed By Owner', val(f.name));
}
const note2 = await get(`users/${localId}/notifications/${NEW_UID}`, true);
if (note2.ok) {
  check('the host bell entry uses the profile name too',
    String(val(note2.body.fields.body)).includes('Renamed By Owner'),
    val(note2.body.fields.body));
}
const m2doc = await get(`matches/${M2}`);
const uids2 = m2doc.ok ? (val(m2doc.body.fields.playerUids) || []).map((x) => x.stringValue) : [];
check('and is in playerUids', uids2.includes(NEW_UID), JSON.stringify(uids2));

// ---------------------------------------------------------------------------
console.log('\n4. MATCH STATE — ended refuses, live queues');
// ---------------------------------------------------------------------------
const setStatus = (id, s) => fetch(`${FS_BASE}/matches/${id}?updateMask.fieldPaths=status`, {
  method: 'PATCH', headers: auth(), body: JSON.stringify({ fields: { status: str(s) } }),
});

await setStatus(M1, 'ended');
const rOver = await post({ code: CODE1, name: 'Too Late', email: `late.${SEED}@example.com` });
const over = await rOver.json();
check('an ended match refuses the join', rOver.status === 409 && over.error === 'match_over',
  rOver.status + ' ' + over.error);
const strayAccount = await fetch(`${IDT}/accounts:signInWithPassword?key=${API_KEY}`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: `late.${SEED}@example.com`, password: '123456', returnSecureToken: true }),
});
check('a refused join creates NO account — state is checked before identity',
  !strayAccount.ok, 'HTTP ' + strayAccount.status);

await setStatus(M2, 'live');
const LATE_EMAIL = `late.arrival.${SEED}@example.com`;
const rLive = await post({ code: CODE2, name: 'Late Arrival', email: LATE_EMAIL });
const jLive = await rLive.json();
check('a live match returns pending', rLive.ok && jLive.pending === true, JSON.stringify(jLive.pending));
const LATE_UID = jLive.uid;
if (LATE_UID) {
  const pend = await get(`matches/${M2}/pending/${LATE_UID}`);
  check('and writes a pending document keyed by the uid', pend.ok, 'HTTP ' + pend.status);
  if (pend.ok) {
    check('pending isGuest true — brand-new account, stub profile',
      val(pend.body.fields.isGuest) === true, val(pend.body.fields.isGuest));
  }
  const asPlayer = await get(`matches/${M2}/players/${LATE_UID}`);
  check('mid-game joiner is NOT on the roster yet', !asPlayer.ok, 'HTTP ' + asPlayer.status);
  const m2b = await get(`matches/${M2}`);
  const uids2b = m2b.ok ? (val(m2b.body.fields.playerUids) || []).map((x) => x.stringValue) : [];
  check('and NOT in playerUids yet', !uids2b.includes(LATE_UID), JSON.stringify(uids2b));
  const rDupLive = await post({ code: CODE2, name: 'Late Arrival', email: LATE_EMAIL });
  const jDupLive = await rDupLive.json();
  check('a second mid-game join is caught by the guard too', jDupLive.already === true, jDupLive.already);
}

// ---------------------------------------------------------------------------
console.log('\n5. VALIDATION');
// ---------------------------------------------------------------------------
const rBadEmail = await post({ code: CODE1, name: 'Someone', email: 'not-an-email' });
const badEmail = await rBadEmail.json();
check('a malformed email is refused', rBadEmail.status === 400 && badEmail.error === 'invalid_email',
  rBadEmail.status + ' ' + badEmail.error);
const rBadName = await post({ code: CODE1, name: 'A', email: 'a@example.com' });
const badName = await rBadName.json();
check('a one-character name is refused', rBadName.status === 400 && badName.error === 'invalid_name',
  rBadName.status + ' ' + badName.error);
const rNoMatch = await post({ code: 'ZZZZ99', name: 'Someone', email: 'a@example.com' });
check('an unknown code is refused', rNoMatch.status === 404, rNoMatch.status);

// ---------------------------------------------------------------------------
console.log('\n6. cleaning up');
// ---------------------------------------------------------------------------
await refresh();
const del = async (path) => {
  const r = await fetch(`${FS_BASE}/${path}`, { method: 'DELETE', headers: auth() });
  return r.ok || r.status === 404;
};
const removed = [];
removed.push(['player1', await del(`matches/${M1}/players/${NEW_UID}`)]);
removed.push(['player2', await del(`matches/${M2}/players/${NEW_UID}`)]);
removed.push(['note1', await del(`users/${localId}/notifications/${NEW_UID}`)]);
removed.push(['profile', await del(`users/${NEW_UID}`)]);
if (LATE_UID) {
  removed.push(['pending', await del(`matches/${M2}/pending/${LATE_UID}`)]);
  removed.push(['note2', await del(`users/${localId}/notifications/${LATE_UID}`)]);
  removed.push(['profile2', await del(`users/${LATE_UID}`)]);
}
removed.push(['match1', await del(`matches/${M1}`)]);
removed.push(['match2', await del(`matches/${M2}`)]);

// The auth accounts too — a test that leaves logins behind is a test that
// quietly fills the client's project with junk.
const killAuth = async (email) => {
  const s = await fetch(`${IDT}/accounts:signInWithPassword?key=${API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email, password: '123456', returnSecureToken: true }),
  });
  if (!s.ok) return true; // never existed
  const { idToken: tok } = await s.json();
  const d = await fetch(`${IDT}/accounts:delete?key=${API_KEY}`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ idToken: tok }),
  });
  return d.ok;
};
removed.push(['auth:newbie', await killAuth(NEW_EMAIL)]);
removed.push(['auth:late', await killAuth(LATE_EMAIL)]);
removed.push(['auth:stray', await killAuth(`late.${SEED}@example.com`)]);
removed.push(['auth:host', await host.destroy()]);

console.log('   ' + removed.map(([k, ok]) => `${k}:${ok ? 'gone' : 'FAILED'}`).join('  '));
check('everything this test created was removed', removed.every(([, ok]) => ok));

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
