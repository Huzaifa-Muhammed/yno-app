// Second actor for the device pass: a disposable host + a lobby match the
// phone can join by code. Self-hosting (accounts:signUp), same trick as
// otp_delivery_send.mjs — no admin credentials, no pre-existing account.
import fs from 'node:fs';
const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';
const FS = 'https://firestore.googleapis.com/v1/projects/yno-app-e96f5/databases/(default)/documents';
const IDT = 'https://identitytoolkit.googleapis.com/v1';
const S = new URL('./match_state.json', import.meta.url).pathname.replace(/^\//, '');

const SEED = String(Math.floor(Math.random() * 9000) + 1000);
const CODE = 'DEV' + SEED;
const MID  = 'test_devicepass_' + SEED;
const HOST_EMAIL = `yno.devhost.${SEED}@example.com`;
const HOST_PW = 'Dev!' + SEED + 'xQ';

const str = (s) => ({ stringValue: s });
const int = (n) => ({ integerValue: String(n) });
const bool = (b) => ({ booleanValue: b });

const su = await fetch(`${IDT}/accounts:signUp?key=${API_KEY}`, {
  method: 'POST', headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ email: HOST_EMAIL, password: HOST_PW, returnSecureToken: true }),
});
const s = await su.json();
if (!su.ok) { console.error('host signUp failed:', s.error?.message); process.exit(1); }
const H = { authorization: `Bearer ${s.idToken}`, 'content-type': 'application/json' };
console.log(`host ${HOST_EMAIL} (${s.localId})`);

// The host needs a profile or the lobby shows a nameless admin.
await fetch(`${FS}/users/${s.localId}`, { method: 'PATCH', headers: H,
  body: JSON.stringify({ fields: {
    name: str('Dev Host'), firstName: str('Dev'), lastName: str('Host'),
    email: str(HOST_EMAIL), autoCreated: bool(false), sportProfileDone: bool(true),
    points: int(0), matchesPlayed: int(0), careerGoals: int(0),
  }}) });

const mk = await fetch(`${FS}/matches/${MID}`, { method: 'PATCH', headers: H,
  body: JSON.stringify({ fields: {
    code: str(CODE), codeA: str(CODE), codeB: str(CODE + 'B'),
    status: str('lobby'), name: str('Device pass — C11 leave test'),
    teamAName: str('Test Falcons'), teamBName: str('Team B'),
    adminUid: str(s.localId), format: str('5v5'), durationMin: int(45),
    scoreA: int(0), scoreB: int(0), isPublic: bool(false),
    playerUids: { arrayValue: { values: [str(s.localId)] } },
  }}) });
if (!mk.ok) { console.error('match create failed', mk.status, (await mk.text()).slice(0,300)); process.exit(1); }

// Host joins their own match as a player, as the app does.
await fetch(`${FS}/matches/${MID}/players/${s.localId}`, { method: 'PATCH', headers: H,
  body: JSON.stringify({ fields: {
    uid: str(s.localId), name: str('Dev Host'), team: str('A'),
    goals: int(0), assists: int(0), isGuest: bool(false), captain: bool(true),
  }}) });

fs.writeFileSync(S, JSON.stringify({ SEED, CODE, MID, HOST_EMAIL, HOST_PW, hostUid: s.localId }, null, 2));
console.log(`match ${MID} is in LOBBY`);
console.log(`JOIN CODE -> ${CODE}`);
