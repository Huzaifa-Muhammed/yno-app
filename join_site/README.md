# join.nellab.org — the web join page

The page a shared match link lands on. Closes the hosting half of client point
**C12**; the app has pointed at this URL since §50 (`lib/links.dart`).

One static file, `public/index.html` — no build step, no dependencies, no
framework. Fonts come from Google Fonts; everything else is inline.

## What it does

| Visitor arrives with | They see |
|---|---|
| `?code=ABC123` (from the lobby's share sheet) | The real match — status, team names, format, players joined — plus the code, a copy button, and how to join |
| `?code=` a **side** code (`codeA`/`codeB`) | The same, plus which team the code puts them on |
| a code for a **live** match | The score, and the app's own warning that the admin approves them first |
| a code for an **ended** match | The final score, with the code and the join steps removed — there is nothing to join |
| an unknown code | The app's wording, `No match found for that code.`, and an input to retry |
| the **bare domain** (the referral share text in `misc.shareMsgB`) | A short landing page and a code entry field |

English and Arabic, RTL included: it follows the browser's language, and the
choice is remembered. Strings that already exist in `lib/l10n/` are copied
verbatim so the page and the app say the same thing.

## How it finds the match

Firestore's **REST** API, unauthenticated, from the browser. `firestore.rules`
has `match /matches/{mid} { allow read: if true }` — the rule that already lets
an accountless guest look a code up in the app.

It mirrors `MatchRepository.findByCode`: query `code`, then `codeA`, then
`codeB`, first hit wins, and side B is inferred only from `codeB` — so the
shared code lands on side A exactly as `guest_join_screen` does (that screen has
no side picker).

The Firebase **web API key in the page is a public identifier**, not a secret —
the same key already ships inside the Android app. Read access is governed by
the rules, not the key.

⚠️ **The page never writes.** It hands the visitor a code and stops. Joining
happens in the app, where `guestJoin` does it in one place with the capacity and
mid-game rules attached.

## Tests

```bash
npm test        # 42 assertions, no network: stub DOM + fixtures
npm run test:live   # optional: resolves real codes against the live database
```

`test/render_test.mjs` seeds a stub DOM from the real markup, so a
`getElementById` that does not match an element in the page fails the run. It
covers each match status, the unknown-code path, the bare visit, and that every
translated string has Arabic copy.

## Deploying

Firebase Hosting, project **`yalla-nellab-12650`** — the same project that
already serves `nellab.org`, on its own **site** (`nellab-join`) so the existing
pages are untouched.

```bash
cd join_site
npx firebase deploy --only hosting --project yalla-nellab-12650
```

`firebase.json` pins `"site": "nellab-join"`, so a deploy from this folder can
only ever write to this site. Live at **https://nellab-join.web.app**.

### Attaching the custom domain

`nellab.org`'s DNS is at **Hostinger** (`ns1/ns2.dns-parking.com`), not
Cloudflare — see `.claude/SESSION_PROGRESS.md` §50b.

1. Firebase console → Hosting → the **nellab-join** site → *Add custom domain* →
   `join.nellab.org`.
2. It prints a `TXT` (ownership) and an `A` record. Add both in Hostinger's
   hPanel → Domains → DNS Zone.
3. The certificate issues within an hour or so of the records propagating.

⚠️ These are new records on a **subdomain**. The root `A` record that points
`nellab.org` at its existing site is not touched.

## Two things left in the page itself

- **`STORE_URL` is `null`** (top of the script). The app is not on any store yet
  — `applicationId` is still `com.example.ynoapp` — so the page says so honestly
  instead of showing a dead button. Set the constant and the download button
  appears by itself.
- **No `og:image`.** Link previews in WhatsApp show the title and description
  but no picture; that needs a 1200×630 PNG, which is a design asset.
