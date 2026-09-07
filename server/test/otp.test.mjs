// Unit tests for the pure OTP logic. Run: npm test
// No network, no Firestore, no service account — these cover the parts that are
// pure functions, which is exactly the part a bug would be invisible in.

import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  generateCode,
  hashCode,
  isEmail,
  isSixDigits,
  timingSafeEqual,
  OTP_LENGTH,
} from '../src/otp.js';

const env = { OTP_PEPPER: 'test-pepper-do-not-use-in-production' };

test('generateCode returns exactly 6 digits, leading zeros preserved', () => {
  for (let i = 0; i < 2000; i++) {
    const code = generateCode();
    assert.equal(code.length, OTP_LENGTH);
    assert.match(code, /^[0-9]{6}$/);
  }
});

test('generateCode spans the full range and is not obviously biased', () => {
  // 20k samples over 10 buckets: a uniform generator lands near 2000 each.
  // Rejection sampling should keep every bucket well inside +/-20%.
  const buckets = new Array(10).fill(0);
  const n = 20000;
  for (let i = 0; i < n; i++) {
    buckets[Math.floor(Number(generateCode()) / 100000)]++;
  }
  for (const count of buckets) {
    assert.ok(count > n / 10 * 0.8, `bucket too small: ${count}`);
    assert.ok(count < n / 10 * 1.2, `bucket too large: ${count}`);
  }
});

test('hashCode is deterministic and never returns the code', async () => {
  const a = await hashCode(env, 'Player@Example.com', '123456');
  const b = await hashCode(env, 'Player@Example.com', '123456');
  assert.equal(a, b);
  assert.equal(a.length, 64); // SHA-256 hex
  assert.ok(!a.includes('123456'));
});

test('hashCode is case-insensitive on the email', async () => {
  const upper = await hashCode(env, 'Player@Example.com', '123456');
  const lower = await hashCode(env, 'player@example.com', '123456');
  assert.equal(upper, lower);
});

test('hashCode binds the code to the address', async () => {
  const one = await hashCode(env, 'a@example.com', '123456');
  const two = await hashCode(env, 'b@example.com', '123456');
  assert.notEqual(one, two);
});

test('hashCode changes with the pepper', async () => {
  const one = await hashCode(env, 'a@example.com', '123456');
  const two = await hashCode({ OTP_PEPPER: 'different' }, 'a@example.com', '123456');
  assert.notEqual(one, two);
});

test('hashCode refuses to run without a pepper', async () => {
  await assert.rejects(() => hashCode({}, 'a@example.com', '123456'),
      /OTP_PEPPER/);
});

test('timingSafeEqual matches only identical strings', () => {
  assert.ok(timingSafeEqual('abc123', 'abc123'));
  assert.ok(!timingSafeEqual('abc123', 'abc124'));
  assert.ok(!timingSafeEqual('abc123', 'abc12'));   // length differs
  assert.ok(!timingSafeEqual('', 'a'));
  assert.ok(timingSafeEqual('', ''));
  assert.ok(!timingSafeEqual(null, 'a'));
  assert.ok(!timingSafeEqual(undefined, undefined));
});

test('isSixDigits accepts only a plain 6-digit string', () => {
  assert.ok(isSixDigits('000000'));
  assert.ok(isSixDigits('999999'));
  assert.ok(!isSixDigits('12345'));
  assert.ok(!isSixDigits('1234567'));
  assert.ok(!isSixDigits('12345a'));
  assert.ok(!isSixDigits(' 123456'));
  assert.ok(!isSixDigits(123456));
  assert.ok(!isSixDigits(null));
});

test('isEmail accepts real addresses and rejects junk', () => {
  assert.ok(isEmail('player@example.com'));
  assert.ok(isEmail('  player@example.com  '));
  assert.ok(isEmail('a.b+tag@sub.example.co.uk'));
  assert.ok(!isEmail('player@example'));
  assert.ok(!isEmail('player.example.com'));
  assert.ok(!isEmail('a b@example.com'));
  assert.ok(!isEmail(''));
  assert.ok(!isEmail(null));
  assert.ok(!isEmail(`${'a'.repeat(250)}@example.com`)); // over 254 chars
});

// ---- purpose routing (account deletion, §60) -------------------------------
//
// These two helpers decide whether a code can delete an account. A bug here is
// not a broken feature — it is a claim code that erases someone's profile.

import { otpDocId, purposeOf, PURPOSE_CLAIM, PURPOSE_DELETE } from '../src/index.js';

test('purposeOf defaults to claim for anything that is not exactly "delete"', () => {
  assert.equal(purposeOf(null), PURPOSE_CLAIM);
  assert.equal(purposeOf({}), PURPOSE_CLAIM);
  assert.equal(purposeOf({ purpose: 'claim' }), PURPOSE_CLAIM);
  assert.equal(purposeOf({ purpose: 'Delete' }), PURPOSE_CLAIM); // case-sensitive
  assert.equal(purposeOf({ purpose: 'DELETE' }), PURPOSE_CLAIM);
  assert.equal(purposeOf({ purpose: 'delete ' }), PURPOSE_CLAIM);
  assert.equal(purposeOf({ purpose: true }), PURPOSE_CLAIM);
  assert.equal(purposeOf({ purpose: 'delete' }), PURPOSE_DELETE);
});

test('deletion codes are stored under a different id from claim codes', () => {
  const email = 'player@example.com';
  const claim = otpDocId(email, PURPOSE_CLAIM);
  const del = otpDocId(email, PURPOSE_DELETE);
  assert.equal(claim, email);
  assert.equal(del, `del_${email}`);
  assert.notEqual(
    claim,
    del,
    'a pending claim code and a pending delete code for the same address must ' +
      'not overwrite one another'
  );
});

test('an unknown purpose can never reach the deletion id', () => {
  for (const p of ['claim', 'DELETE', 'del', '', undefined, null]) {
    assert.equal(otpDocId('a@b.com', p), 'a@b.com');
  }
});
