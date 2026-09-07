// Random codes, ported from the app's `lib/services/codes.dart`.
//
// Shared by the guest id (`g_` + 10) and a new account's referral code (6), the
// same two uses the app has. Kept in its own module because two copies of an
// alphabet is exactly the kind of thing that drifts by one character and then
// generates ids the app cannot read back.

/** Matches `codes.dart`: no ambiguous 0/O/1/I. */
export const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/** Mirrors `randomCode(length)`. */
export function randomCode(length = 6) {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  let out = '';
  for (const b of bytes) out += ALPHABET[b % ALPHABET.length];
  return out;
}
