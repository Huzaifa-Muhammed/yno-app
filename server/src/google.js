// Google service-account auth, implemented on WebCrypto.
//
// WHY NOT firebase-admin: it needs gRPC and Node internals and does not run on
// Cloudflare Workers. Everything the OTP service needs from it is two signed
// JWTs, so we sign them ourselves with crypto.subtle (RS256) and talk to
// Firestore over REST. No Node polyfills, no bundled SDK.

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const CUSTOM_TOKEN_AUD =
    'https://identitytoolkit.googleapis.com/google.identity.identitytoolkit.v1.IdentityToolkit';

// Module scope survives between requests in a warm isolate, so a minted access
// token is reused instead of re-signing on every call.
let _keyPromise = null;
const _tokens = new Map(); // scope -> { token, expiresAt }

export const SCOPE_FIRESTORE = 'https://www.googleapis.com/auth/datastore';

function b64url(bytes) {
  let bin = '';
  const arr = new Uint8Array(bytes);
  for (let i = 0; i < arr.length; i++) bin += String.fromCharCode(arr[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function utf8(str) {
  return new TextEncoder().encode(str);
}

/** Parse the service-account JSON out of the secret, with a clear error. */
export function serviceAccount(env) {
  const raw = env.SERVICE_ACCOUNT_JSON;
  if (!raw) throw new Error('SERVICE_ACCOUNT_JSON is not set');
  let sa;
  try {
    sa = JSON.parse(raw);
  } catch (_) {
    throw new Error('SERVICE_ACCOUNT_JSON is not valid JSON');
  }
  if (!sa.client_email || !sa.private_key) {
    throw new Error('SERVICE_ACCOUNT_JSON is missing client_email/private_key');
  }
  return sa;
}

/** PKCS#8 PEM -> CryptoKey. Cached for the life of the isolate. */
function privateKey(env) {
  if (_keyPromise) return _keyPromise;
  _keyPromise = (async () => {
    const pem = serviceAccount(env).private_key;
    const body = pem
        .replace(/-----BEGIN PRIVATE KEY-----/, '')
        .replace(/-----END PRIVATE KEY-----/, '')
        .replace(/\s+/g, '');
    const bin = atob(body);
    const buf = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
    return crypto.subtle.importKey(
        'pkcs8', buf.buffer,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  })();
  return _keyPromise;
}

async function signJwt(env, payload) {
  const key = await privateKey(env);
  const header = b64url(utf8(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const body = b64url(utf8(JSON.stringify(payload)));
  const data = `${header}.${body}`;
  const sig = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5', key, utf8(data));
  return `${data}.${b64url(sig)}`;
}

/**
 * OAuth2 access token via the JWT-bearer grant, cached per scope until ~5
 * minutes before it expires. Defaults to Firestore; the account-rotation script
 * asks for the Identity Toolkit scope instead.
 */
export async function accessToken(env, scope = SCOPE_FIRESTORE) {
  const now = Math.floor(Date.now() / 1000);
  const cached = _tokens.get(scope);
  if (cached && cached.expiresAt - 300 > now) return cached.token;

  const sa = serviceAccount(env);
  const assertion = await signJwt(env, {
    iss: sa.client_email,
    scope,
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600,
  });
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!res.ok) {
    throw new Error(`token exchange failed: ${res.status} ${await res.text()}`);
  }
  const json = await res.json();
  _tokens.set(scope, {
    token: json.access_token,
    expiresAt: now + (json.expires_in || 3600),
  });
  return json.access_token;
}

/**
 * A Firebase **custom token** for [uid] — a self-signed JWT the client hands to
 * signInWithCustomToken. This is the whole security model of the service: the
 * credential is produced by the server on proof of the OTP, so a repackaged APK
 * cannot mint one by skipping the call.
 */
export async function customToken(env, uid, claims) {
  const sa = serviceAccount(env);
  const now = Math.floor(Date.now() / 1000);
  return signJwt(env, {
    iss: sa.client_email,
    sub: sa.client_email,
    aud: CUSTOM_TOKEN_AUD,
    iat: now,
    exp: now + 3600, // Google caps custom tokens at 1 hour.
    uid,
    ...(claims ? { claims } : {}),
  });
}
