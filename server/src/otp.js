// OTP generation, hashing and comparison.
//
// The plaintext code exists only in memory and in the email that carries it —
// Firestore stores a salted hash, so a leak of the collection reveals nothing
// usable. The pepper is a Worker secret, so a Firestore leak alone is not
// enough to brute-force a 6-digit code offline.

export const OTP_LENGTH = 6;

/** Cryptographically random 6-digit code, rejection-sampled to avoid modulo bias. */
export function generateCode() {
  const max = 10 ** OTP_LENGTH;            // 1_000_000
  const limit = Math.floor(0xffffffff / max) * max;
  const buf = new Uint32Array(1);
  let n;
  do {
    crypto.getRandomValues(buf);
    n = buf[0];
  } while (n >= limit);
  return String(n % max).padStart(OTP_LENGTH, '0');
}

export async function hashCode(env, email, code) {
  const pepper = env.OTP_PEPPER;
  if (!pepper) throw new Error('OTP_PEPPER is not set');
  const data = new TextEncoder().encode(`${pepper}:${email.toLowerCase()}:${code}`);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return [...new Uint8Array(digest)]
      .map((b) => b.toString(16).padStart(2, '0'))
      .join('');
}

/** Constant-time string compare — never short-circuit on the first bad char. */
export function timingSafeEqual(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export function isSixDigits(code) {
  return typeof code === 'string' && /^[0-9]{6}$/.test(code);
}

// Basic shape check — deliberately permissive, the account lookup is the real
// gate. Just enough to reject junk before it costs a Firestore read.
export function isEmail(email) {
  return typeof email === 'string' &&
      email.length <= 254 &&
      /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email.trim());
}
