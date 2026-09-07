# YNO email-OTP service

A Cloudflare Worker that issues 6-digit email codes and, on a correct code,
mints a **Firebase custom token**. It exists because Firebase Auth cannot send a
6-digit code — only sign-in links — so claiming an auto-created account needs a
server.

```
POST /request-otp   { email }         -> { ok, expiresInSeconds, resendAfterSeconds }
                                      -> 404 { error: "not_claimable" }
POST /verify-otp    { email, code }   -> { ok, customToken, uid }
GET  /health                          -> { ok }
```

`/request-otp` answers **`not_claimable`** when no host-created account exists
for the address, so the claim screen can say so instead of asking for a code
that will never arrive. That does confirm whether an address has a host-created
account, which is deliberate: `users` is world-readable and the app's own
`UserRepository.findByEmail` already performs the same lookup client-side, so
this exposes nothing new.

## What the custom token is for

`/verify-otp` returns a Firebase **custom token**. A boolean would leave the
*app* deciding who gets in, so a repackaged APK could skip the call entirely.

⚠️ **The app does not currently use it.** By product decision (2026-08-18) the
claim screen signs in with `email` + the shared `123456` instead, which means
that pair also still works on the normal login screen — the OTP guards the claim
path only, not the account. The token keeps being returned so that closing this
is a one-line change in `lib/services/otp_service.dart` plus randomising
`kAutoAccountPassword`; nothing here has to move.

## Why there is no `firebase-admin`

It needs gRPC and Node internals and does not run on Workers. Everything needed
from it is two signed JWTs, so `src/google.js` signs them with WebCrypto
(RS256) and `src/firestore.js` talks to Firestore over REST. No Node polyfills,
no `nodejs_compat` flag, no bundled SDK.

## Layout

| File | What it does |
|---|---|
| `src/index.js` | Router, rate limits, both endpoints |
| `src/google.js` | PKCS#8 import, RS256 signing, OAuth access token, custom token |
| `src/firestore.js` | REST get/set/delete + the case-insensitive user lookup |
| `src/otp.js` | Code generation, peppered hashing, constant-time compare |
| `src/email.js` | Resend send + the branded HTML template |

## State

`emailOtps/{email-lowercased}` in Firestore, holding the **hash** of the code
(never the code), `uid`, `expiresAt`, `attempts`, and the send-throttle
counters. Rules are `allow read, write: if false` — the Admin service account
bypasses rules, so only this service ever sees it.

## Limits

| Limit | Value | Where enforced |
|---|---|---|
| Code lifetime | 10 min | Firestore doc |
| Resend cooldown | 60 s per address | Firestore doc |
| Sends per address | 3 per 15 min | Firestore doc |
| Wrong guesses | 5, then the code is burned | Firestore doc |
| Requests per IP | 20 per 60 s | Workers rate-limit binding |

The per-address limits are authoritative and live in Firestore, so if the IP
binding is missing the service degrades rather than opening up.

## Deploy

```bash
cd server
npm install

# One-time login (opens a browser).
npx wrangler login

# Secrets — never in wrangler.toml, never in the repo.
npx wrangler secret put SERVICE_ACCOUNT_JSON   # paste the whole JSON file
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put OTP_PEPPER             # any long random string

npx wrangler deploy
```

`SERVICE_ACCOUNT_JSON` must be a **separate** service account from the one in
`assets/firebase_admin_key/` — generate a fresh key in
Firebase Console → Project Settings → Service Accounts so the two revoke
independently.

Generate a pepper with:

```bash
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

## Local development

Put the same three values in `server/.dev.vars` (gitignored):

```
SERVICE_ACCOUNT_JSON={"type":"service_account", ... }
RESEND_API_KEY=re_...
OTP_PEPPER=...
```

then `npm run dev`. Watch a deployed Worker with `npm run tail`.

## Sender domain

✅ **Verified and proven in production.** `MAIL_FROM` is
`YNO <no-reply@nellab.org>`; `nellab.org` is verified in Resend (DKIM on
`resend._domainkey`, return path on `send.`). A real code was observed arriving
in a third-party inbox — **not** spam — on 2026-08-29 (SESSION_PROGRESS §70).

Before that, this section described the shared test sender
(`onboarding@resend.dev`), which only ever delivered to the address owning the
Resend account. That stage is over; do not revert to it.

⚠️ **Never touch the root MX or add a second root `v=spf1`** — the client's live
email runs on this domain. Resend records go on `send` and `resend._domainkey`
only.

## Proving delivery again

`test/otp_delivery_send.mjs` builds its own disposable host + match, so it needs
**no pre-existing account** and no admin credentials — rules allow any signed-in
user to write `matches/{mid}` and `users/{uid}`.

```
node test/otp_delivery_send.mjs you+tag@gmail.com   # sends one real code
node test/otp_delivery_verify.mjs 123456            # spends it
node test/otp_delivery_cleanup.mjs                  # removes every artefact
```

Run it with `npm run tail` streaming. Notes:

- The target **must not already have an account** — `/request-otp` only serves
  profiles with `autoCreated: true`, so a real account gets `not_claimable` 404
  and no mail is sent. Gmail plus-addressing gives a fresh Firebase account on
  an inbox you can read.
- Check spam before calling it a failure.
- Cleanup refuses to delete any account the test did not create itself.

## Changing the pepper

Rotating `OTP_PEPPER` invalidates every code in flight. Harmless — they expire
in 10 minutes anyway — but do it when nobody is mid-signup.
