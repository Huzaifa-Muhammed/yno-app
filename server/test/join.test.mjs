// Unit tests for the pure parts of the website join path. Run: npm test
//
// No network, no Firestore, no service account. What is covered here is the
// shape of the documents the join writes — because a wrong shape is not a
// crash, it is a player the app renders blank, and nothing fails loudly.

import assert from 'node:assert/strict';
import { test } from 'node:test';

import { ALPHABET, randomCode } from '../src/codes.js';
import { firstNameOf, profileFields, profileWrite, AUTO_ACCOUNT_PASSWORD }
    from '../src/account.js';
import { v } from '../src/firestore.js';

// ---- codes ---------------------------------------------------------------

test('randomCode uses the app alphabet and never emits ambiguous characters', () => {
  for (let i = 0; i < 500; i++) {
    const code = randomCode(10);
    assert.equal(code.length, 10);
    for (const ch of code) {
      assert.ok(ALPHABET.includes(ch), `unexpected character ${ch}`);
    }
    // 0/O and 1/I are excluded on purpose — these ids get read aloud and typed.
    assert.ok(!/[01IO]/.test(code), `ambiguous character in ${code}`);
  }
});

test('randomCode honours the requested length', () => {
  assert.equal(randomCode(6).length, 6);
  assert.equal(randomCode().length, 6); // referral-code default
});

// ---- value encoders ------------------------------------------------------

test('v.nul writes a real stored null, not an absent field', () => {
  assert.deepEqual(v.nul(), { nullValue: null });
});

test('v.arr and v.map encode empties the way Firestore expects', () => {
  assert.deepEqual(v.arr([]), { arrayValue: { values: [] } });
  assert.deepEqual(v.map({}), { mapValue: { fields: {} } });
  assert.deepEqual(v.arr([v.str('a')]),
      { arrayValue: { values: [{ stringValue: 'a' }] } });
});

// ---- name splitting ------------------------------------------------------

test('firstNameOf mirrors name.trim().split(" ").first', () => {
  assert.equal(firstNameOf('Ahmed Al Mansouri'), 'Ahmed');
  assert.equal(firstNameOf('  Ahmed  '), 'Ahmed');
  assert.equal(firstNameOf('Ahmed'), 'Ahmed');
  assert.equal(firstNameOf(''), '');
  assert.equal(firstNameOf(null), '');
  // Two spaces between words must not produce an empty first name.
  assert.equal(firstNameOf('Ahmed  Ali'), 'Ahmed');
});

// ---- the users/{uid} document -------------------------------------------
//
// This list is `AppUser.toMap()` in lib/services/models.dart. If a field is
// added there, this test is what should fail.

const APP_USER_FIELDS = [
  'name', 'email', 'username', 'usernameLower', 'firstName', 'lastName',
  'phone', 'dob', 'dobLocked', 'gender', 'language', 'photoUrl',
  'photoPublicId', 'position', 'preferredFoot', 'skillLevel',
  'sportProfileDone', 'points', 'referralCode', 'referredBy', 'autoCreated',
  'socialLinks', 'socialVisibility', 'fcmTokens', 'following',
  'followersCount', 'tcAcceptedAt', 'careerGoals', 'careerAssists',
  'matchesPlayed', 'wins', 'losses', 'draws', 'motmCount', 'communityCount',
  'currentStreak', 'bestStreak', 'unbeatenStreak', 'hatTricks',
  'bestScoringMatch', 'formLast5', 'goalsBySurface', 'goalsByFormat',
  'notifyMatchAlerts', 'notifyFriendActivity', 'contactSync', 'profilePublic',
  'deactivated', 'reactivateAt',
];

test('profileFields writes every AppUser.toMap field and no others', () => {
  const f = profileFields({ name: 'Ahmed Ali', email: 'ahmed@example.com' });
  const written = Object.keys(f).sort();
  const expected = [...APP_USER_FIELDS].sort();
  assert.deepEqual(written, expected);
  // createdAt is deliberately absent: it is a server timestamp and travels as a
  // transform, the same way FieldValue.serverTimestamp() does in the app.
  assert.ok(!('createdAt' in f));
});

test('profileFields marks the account auto-created so it stays claimable', () => {
  const f = profileFields({ name: 'Ahmed', email: 'a@example.com' });
  assert.deepEqual(f.autoCreated, { booleanValue: true });
  // /request-otp refuses anything that is not autoCreated, so this flag IS the
  // claim path. Without it the person can never take the account over.
});

test('profileFields splits the display name the way the app does', () => {
  const f = profileFields({ name: '  Ahmed Al Mansouri ', email: 'a@example.com' });
  assert.deepEqual(f.name, { stringValue: 'Ahmed Al Mansouri' });
  assert.deepEqual(f.firstName, { stringValue: 'Ahmed' });
  assert.deepEqual(f.lastName, { stringValue: '' });
});

test('profileFields trims the email but preserves its casing', () => {
  // createPlayerAccount stores the email trimmed and NOT lowercased; matching
  // that is what lets findUserByEmail's two-candidate IN query keep working.
  const f = profileFields({ name: 'A B', email: '  Player@Example.com ' });
  assert.deepEqual(f.email, { stringValue: 'Player@Example.com' });
});

test('profileFields gives every account a distinct referral code', () => {
  const codes = new Set();
  for (let i = 0; i < 200; i++) {
    const f = profileFields({ name: 'A B', email: 'a@example.com' });
    const code = f.referralCode.stringValue;
    assert.equal(code.length, 6);
    codes.add(code);
  }
  assert.ok(codes.size > 190, `referral codes are not random: ${codes.size}/200`);
});

test('profileFields starts every counter at zero and every list empty', () => {
  const f = profileFields({ name: 'A B', email: 'a@example.com' });
  for (const key of ['points', 'careerGoals', 'careerAssists', 'matchesPlayed',
    'wins', 'losses', 'draws', 'motmCount', 'communityCount', 'currentStreak',
    'bestStreak', 'unbeatenStreak', 'hatTricks', 'bestScoringMatch',
    'followersCount']) {
    assert.deepEqual(f[key], { integerValue: '0' }, `${key} should start at 0`);
  }
  assert.deepEqual(f.fcmTokens, { arrayValue: { values: [] } });
  assert.deepEqual(f.formLast5, { arrayValue: { values: [] } });
  assert.deepEqual(f.goalsBySurface, { mapValue: { fields: {} } });
});

test('profileFields defaults the preferences the app defaults', () => {
  const f = profileFields({ name: 'A B', email: 'a@example.com' });
  assert.deepEqual(f.notifyMatchAlerts, { booleanValue: true });
  assert.deepEqual(f.notifyFriendActivity, { booleanValue: false });
  assert.deepEqual(f.contactSync, { booleanValue: false });
  assert.deepEqual(f.profilePublic, { booleanValue: true });
  assert.deepEqual(f.deactivated, { booleanValue: false });
  assert.deepEqual(f.language, { stringValue: 'English' });
  assert.deepEqual(f.sportProfileDone, { booleanValue: false });
});

test('profileWrite targets users/{uid} and stamps createdAt server-side', () => {
  const env = { FIREBASE_PROJECT_ID: 'yno-app-e96f5' };
  const w = profileWrite(env, 'UID123', { name: 'A B', email: 'a@example.com' });
  assert.equal(
    w.update.name,
    'projects/yno-app-e96f5/databases/(default)/documents/users/UID123'
  );
  assert.deepEqual(w.updateTransforms,
      [{ fieldPath: 'createdAt', setToServerValue: 'REQUEST_TIME' }]);
});

test('the auto-account password still matches the app', () => {
  // 🔴 Not an accident. `kAutoAccountPassword` in auth_repository.dart is the
  // client's decision, and the claim flow signs in with it. If this ever needs
  // to change, the app moves first — otherwise every host-created player is
  // locked out of claiming.
  assert.equal(AUTO_ACCOUNT_PASSWORD, '123456');
});

// ---- the guest rule ------------------------------------------------------
//
// 🔑 `isGuest` mirrors `autoCreated`. One comparison, but it is the one that
// decides whether a player earns career stats: `endMatch` sends every
// `!isGuest` player to `users.applyMatchStats` and every guest to a
// `guests/{id}` stats document instead.

import { isGuestProfile } from '../src/guest.js';

test('a stub profile is a guest, a completed one is not', () => {
  // Lifted from the app: `isGuest: u?.autoCreated ?? false` in addTeamRoster.
  assert.equal(isGuestProfile({ autoCreated: true }), true);
  assert.equal(isGuestProfile({ autoCreated: false }), false);
});

test('anything that is not exactly true is NOT a guest', () => {
  // Firestore's `plain()` returns null for an absent field, and an older
  // account predating the flag has no `autoCreated` at all. Treating those as
  // guests would strip career stats from real players.
  for (const user of [{}, { autoCreated: null }, { autoCreated: undefined },
    { autoCreated: 'true' }, { autoCreated: 1 }]) {
    assert.equal(isGuestProfile(user), false, JSON.stringify(user));
  }
});

test('a missing user is not a guest — it is not anyone', () => {
  assert.equal(isGuestProfile(null), false);
  assert.equal(isGuestProfile(undefined), false);
});

test('a freshly written profile is auto-created, so it joins as a guest', () => {
  // The two halves have to agree: account.js stamps autoCreated true, and the
  // rule above reads it back. If profileFields ever stopped setting it, a new
  // web joiner would silently become a full player.
  const f = profileFields({ name: 'Web Newbie', email: 'w@example.com' });
  assert.deepEqual(f.autoCreated, { booleanValue: true });
  assert.equal(isGuestProfile({ autoCreated: f.autoCreated.booleanValue }), true);
});
