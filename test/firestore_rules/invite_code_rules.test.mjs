// Adversarial test for firestore.rules: can anyone who shouldn't get at a
// team's invite code? The code is a secret (it grants joining AND challenging),
// but team docs are world-readable — so the code lives in
// `teams/{id}/private/meta` (manager-read only) and resolves via
// `teamCodes/{CODE}` (get allowed, list denied).
//
// Run (needs Java 21+ for current firebase-tools; JDK 17 works on @13.x):
//   cd test/firestore_rules && npm install
//   cd ../.. && npx firebase-tools@13.35.1 emulators:exec --only firestore \
//     --project yno-rules-test "node test/firestore_rules/invite_code_rules.test.mjs"
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import {
  doc, getDoc, setDoc, deleteDoc, collection, getDocs, query, where,
} from 'firebase/firestore';

const RULES = resolve(dirname(fileURLToPath(import.meta.url)), '../../firestore.rules');

const TEAM = 'team1';
const CODE = 'ABC123';

const env = await initializeTestEnvironment({
  projectId: 'yno-rules-test',
  firestore: {
    rules: readFileSync(RULES, 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

// Seed: a team owned by `owner`, captained by `captain`, with `member` on the
// roster and `stranger` unrelated. Written with rules disabled.
await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'teams', TEAM), {
    name: 'Desert Wolves',
    nameLower: 'desert wolves',
    ownerUid: 'owner',
    captainUid: 'captain',
    memberUids: ['owner', 'captain', 'member'],
    isPublic: true,
    disbanded: false,
  });
  await setDoc(doc(db, 'teams', TEAM, 'private', 'meta'), { inviteCode: CODE });
  await setDoc(doc(db, 'teamCodes', CODE), { teamId: TEAM });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();

const results = [];
const check = async (name, promise) => {
  try {
    await promise;
    results.push(['PASS', name]);
  } catch (e) {
    results.push(['FAIL', `${name} :: ${e.message}`]);
  }
};

const privateMeta = (db) => getDoc(doc(db, 'teams', TEAM, 'private', 'meta'));
const codeDoc = (db) => getDoc(doc(db, 'teamCodes', CODE));

// --- The code must NOT be readable by non-managers -------------------------
await check('captain CAN read the code',
  assertSucceeds(privateMeta(as('captain'))));
await check('owner CAN read the code',
  assertSucceeds(privateMeta(as('owner'))));
await check('a plain MEMBER cannot read the code',
  assertFails(privateMeta(as('member'))));
await check('a stranger cannot read the code',
  assertFails(privateMeta(as('stranger'))));
await check('an anonymous user cannot read the code',
  assertFails(privateMeta(anon())));

// --- The team doc itself stays public, and carries no code ----------------
await check('team doc is still world-readable',
  assertSucceeds(getDoc(doc(anon(), 'teams', TEAM))));
await check('team doc carries no inviteCode field', (async () => {
  const snap = await getDoc(doc(anon(), 'teams', TEAM));
  if (snap.data().inviteCode !== undefined) throw new Error('inviteCode leaked on team doc!');
})());

// --- Code resolution: get allowed, enumeration denied ----------------------
await check('a stranger holding the code CAN resolve it (get)',
  assertSucceeds(codeDoc(as('stranger'))));
await check('nobody can LIST teamCodes (no harvesting)',
  assertFails(getDocs(collection(as('stranger'), 'teamCodes'))));
await check('nobody can query teamCodes by teamId (no reverse lookup)',
  assertFails(getDocs(query(collection(as('stranger'), 'teamCodes'),
    where('teamId', '==', TEAM)))));
await check('an anonymous user cannot resolve a code',
  assertFails(codeDoc(anon())));

// --- Nobody can hijack or vandalise a code --------------------------------
await check('a stranger cannot repoint an existing code at their own team',
  assertFails(setDoc(doc(as('stranger'), 'teamCodes', CODE), { teamId: 'evilteam' })));
await check('a stranger cannot delete a code',
  assertFails(deleteDoc(doc(as('stranger'), 'teamCodes', CODE))));
await check('a stranger cannot overwrite the private code doc',
  assertFails(setDoc(doc(as('stranger'), 'teams', TEAM, 'private', 'meta'),
    { inviteCode: 'HACKED' })));
await check('a plain member cannot overwrite the private code doc',
  assertFails(setDoc(doc(as('member'), 'teams', TEAM, 'private', 'meta'),
    { inviteCode: 'HACKED' })));
await check('the captain CAN rotate the code',
  assertSucceeds(setDoc(doc(as('captain'), 'teams', TEAM, 'private', 'meta'),
    { inviteCode: 'NEW999' })));
await check('the captain CAN publish a new code doc',
  assertSucceeds(setDoc(doc(as('captain'), 'teamCodes', 'NEW999'), { teamId: TEAM })));
await check('the captain CAN delete the retired code doc',
  assertSucceeds(deleteDoc(doc(as('captain'), 'teamCodes', CODE))));

await env.cleanup();

for (const [status, name] of results) {
  console.log(`${status === 'PASS' ? '  ok' : 'FAIL'}  ${name}`);
}
const failed = results.filter(([s]) => s === 'FAIL').length;
console.log(`\n${results.length - failed}/${results.length} rules assertions passed`);
process.exit(failed ? 1 : 0);
