# YNO website — Join page, Live match page, and how shared links route

**Status:** specification, nothing built yet (except a reference implementation,
see §0.3). Written 2026-08-20.

**How this document is used.** Copy this file into the root of the
**nellab.org website project** — the repo that already holds the live site. When
asked to build these pages, read this file *from there*: it is deliberately
**self-contained**, because inside that repo the Flutter source is not available.
Every colour, font, field name, query and string needed to build both pages is
written out below.

---

## Build order — read this first

Confirmed by the user on 2026-08-20:

| | Scope | Status |
|---|---|---|
| **Phase 1** | The two website pages — §1–§4 and §6 | 👉 **Build this now** |
| **Phase 2** | Deep links / App Links routing — §5 | ⏸ **Deferred.** Recorded, not built. Starts once Phase 1 ships |

Phase 1 is self-contained: both pages work as ordinary web pages that anyone can
open, with or without the app. Nothing in §5 has to exist for them to ship.

**Do not start §5 work — including the `AndroidManifest.xml` intent-filter, the
`app_links` dependency or `assetlinks.json` — until the pages are live.**

## 0. Decisions this document assumes

### 0.1 The pages live on the existing site, not on a separate subdomain

You asked for one project and one deploy, with no extra setup. That means the
two pages ship as part of the existing nellab.org site:

| | |
|---|---|
| Join page | `https://nellab.org/join` |
| Live page | `https://nellab.org/live` |
| Shared match link | `https://nellab.org/join?code=ABC123` |
| Shared referral link | `https://nellab.org/join?ref=XYZ789` |

⚠️ **This supersedes `join.nellab.org`.** The app currently builds links from
`kJoinBaseUrl = 'https://join.nellab.org'` (`lib/links.dart`). Moving to the
existing site means:

- **one line changes in the app** — `kJoinBaseUrl` becomes
  `https://nellab.org/join`. It is deliberately the only place the domain is
  written, and `test/links_test.dart` guards that;
- **no DNS work at all** — no new record, no new custom domain, no certificate
  wait. This is the whole reason to prefer it;
- the standalone `nellab-join` Firebase Hosting site created on 2026-08-20
  becomes redundant and can be deleted, or kept as a staging copy.

✅ **Confirmed by the user, 2026-08-20.** `join.nellab.org` is dropped; no DNS
work is needed for either page.

⚠️ **Sequencing:** leave the app's `kJoinBaseUrl` pointing where it does until
the pages are actually deployed, then flip it in the same pass (§7 item 4).
Changing it early only moves the app's dead links from one dead URL to another.

### 0.2 What "Join" means on the website

⚠️ **REVERSED 2026-08-20 (see §61).** This section originally said the website
was spectate-only. The client then asked for real guest joining, so the Join page
now collects **name + email + code** and actually adds the visitor to the match;
they appear in the host’s lobby exactly as an in-app guest does. Watching without
joining is still offered (“Just watching? Skip this”) and still goes to /live.

🔑 **The join is performed by the Worker’s `/guest-join` endpoint, never by writing
to Firestore from the browser.** Two reasons, both load-bearing:

- the host’s “new player joined” bell entry lives under
  `users/{adminUid}/notifications`, which rules gate on `signedIn()` — a web
  guest never is, so a browser-side join would add the player and **tell nobody**;
- a join writes three documents that must land together and must match
  `MatchRepository.guestJoin` field for field. One server-side implementation is
  the only way that stays true.

### 0.3 A working reference implementation already exists

`join_site/public/index.html` in the Flutter repo is a finished, tested join page
(42 passing tests). It already does code resolution, the brand theme, EN/AR with
RTL, and the match card. **Port from it rather than starting over** — the parts
worth reusing are marked ♻️ below.

---

## 1. Brand kit

Taken from `lib/theme/app_colors.dart` and `lib/theme/app_text.dart`. Both pages
must look like the app, not like the marketing site.

### 1.1 Colour tokens

```css
:root{
  /* surfaces — dark, stepped for depth */
  --bg:#0C0F0A;        /* page background          */
  --bg-deep:#070906;   /* deepest, behind cards    */
  --surface:#161A14;   /* card                     */
  --surface2:#1E241A;  /* elevated card / input    */
  --surface3:#282F22;  /* highest / pressed        */

  /* hairline borders */
  --line:#252B21;      /* divider / card border    */
  --line2:#39412F;     /* stronger / focused       */

  /* text */
  --txt:#F1F4F2;       /* primary                  */
  --dim:#8B948F;       /* secondary                */
  --dim2:#5B635E;      /* tertiary / hints         */

  /* accent — volt green, the logo colour */
  --volt:#D4FF00;
  --volt-deep:#B0D400; /* pressed                  */
  --ink:#0C0F0A;       /* text ON a volt fill      */

  /* semantic match states */
  --win:#3DE27A;
  --loss:#FF4D5E;      /* also the LIVE dot        */
  --gold:#FFC53D;      /* also the PAUSED dot      */
  --cyan:#38E0E0;
}
```

Page background carries two soft volt glows:

```css
background-image:
  radial-gradient(70% 45% at 50% -8%, rgba(212,255,0,.10), transparent 70%),
  radial-gradient(50% 30% at 50% 108%, rgba(212,255,0,.05), transparent 70%);
background-attachment: fixed;
```

### 1.2 Typography

| Role | Family | Notes |
|---|---|---|
| Body / UI | **Barlow** | 400–800 |
| Display / headings / score / timer | **Barlow Condensed** | 700–800, usually UPPERCASE, tight tracking |
| Arabic fallback | **Cairo** | Barlow has no Arabic glyphs; list Cairo in the fallback stack for both |

```html
<link href="https://fonts.googleapis.com/css2?family=Barlow:wght@400;500;600;700;800;900&family=Barlow+Condensed:wght@600;700;800&family=Cairo:wght@400;600;700;800&display=swap" rel="stylesheet">
```

```css
font-family:'Barlow', 'Cairo', system-ui, sans-serif;          /* body    */
font-family:'Barlow Condensed', 'Cairo', system-ui, sans-serif;/* display */
```

### 1.3 Shape and components

- Card: `background:var(--surface); border:1px solid var(--line); border-radius:16px; padding:20px`
- Input: `background:var(--surface2); border:1px solid var(--line2); border-radius:11px; padding:14px`, focus → `border-color:var(--volt)`
- Primary button: volt fill, `--ink` text, `border-radius:11px`, weight 800
- Eyebrow label: 11px, weight 800, `letter-spacing:1.6px`, uppercase, `--dim2`
- Status pill: `border-radius:99px`, 11px/800, uppercase, with a 6px round dot
- Mobile first. Content column `max-width:470px`, centred. Most visitors arrive
  from WhatsApp on a phone.

### 1.4 Language

Both pages ship **English and Arabic**, following `navigator.language`, with a
toggle in the header, remembered in `localStorage` under `yno_lang`
(`'0'` = EN, `'1'` = AR). Arabic sets `<html dir="rtl" lang="ar">`.

Scores, timers and match codes must stay **LTR** inside an RTL page:

```css
.score,.timer,.code{ direction:ltr; unicode-bidi:isolate; }
```

All copy is in §6. Strings that already exist in the app's `lib/l10n/` are marked
✅ and are **copied verbatim** — the site and the app must not word the same idea
two different ways.

---

## 2. Data access

### 2.1 Project and key

```js
const PROJECT = 'yno-app-e96f5';
const API_KEY = 'AIzaSyAC0lgsD_K86fhmpwaZWpEoFE6rVjMLafU';   // web API key
```

⚠️ Note this is the **app's** Firebase project (`yno-app-e96f5`), which is *not*
the project that hosts the website (`yalla-nellab-12650`). That is fine — the
browser talks to Firestore directly and cross-project reads need nothing special.

The web API key is a **public identifier, not a secret**. The same key already
ships inside the Android APK. Access is governed by security rules, not by
hiding the key.

### 2.2 Why unauthenticated reads are allowed

`firestore.rules` in the app repo:

```
match /matches/{mid} {
  allow read: if true;           // guest code lookup + public web scoreboard
  allow write: if signedIn();
  match /{document=**} {
    allow read: if true;         // players, goals, pending
    allow write: if true;
  }
}
```

Reads of the match document **and every subcollection** are open by design — this
is the rule that already lets an accountless guest look up a code in the app.
**Verified working from a browser with no auth on 2026-08-20.**

🔒 **The website must never write.** The rules would permit it; the design does
not. See §0.2.

### 2.3 Realtime strategy

The live page needs push updates, not polling.

**Preferred:** Firebase JS SDK (modular), three `onSnapshot` listeners — the
match document, the `players` subcollection, the `goals` subcollection. Works
unauthenticated. If the site has no bundler, import from the CDN:

```js
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-app.js';
import { getFirestore, doc, collection, onSnapshot, query, orderBy }
  from 'https://www.gstatic.com/firebasejs/10.12.0/firebase-firestore.js';
```

**Fallback**, if the SDK cannot be added: poll the REST endpoint in §2.4 every
**5 seconds**. Acceptable but visibly laggier on goals.

Decide once the website project's stack is visible.

### 2.4 REST (used by the Join page's lookup; ♻️ already written)

```
POST https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents:runQuery?key={API_KEY}
Content-Type: application/json

{"structuredQuery":{
  "from":[{"collectionId":"matches"}],
  "where":{"fieldFilter":{
    "field":{"fieldPath":"code"},"op":"EQUAL",
    "value":{"stringValue":"ABC123"}}},
  "limit":1}}
```

Response is an array; a hit has `[{document:{name, fields}}]`, a miss has
`[{readTime}]`. Values are typed wrappers — `{"stringValue":"x"}`,
`{"integerValue":"3"}` (**a string**, cast it), `{"timestampValue":"...ISO..."}`,
`{"arrayValue":{"values":[...]}}`, `{"nullValue":null}`.

### 2.5 Resolving a code → a match  ♻️

Mirror the app's `MatchRepository.findByCode` **exactly**, or the site will
disagree with the app about which team a code joins:

```
normalise: trim, UPPERCASE
for field in ['code', 'codeA', 'codeB']:      # in this order, first hit wins
    query matches where field == code, limit 1
    if hit: return it
return null                                    # → "No match found for that code."
```

Side is derived from the result, not from which query hit:

```
side = (doc.codeB === code) ? 'b' : 'a'
```

So the shared `code` always lands on **side A**, which is what the app does —
`guest_join_screen` has no side picker. Verified against 13 real codes on
2026-08-20.

### 2.6 Schema

**`matches/{matchId}`** — the fields these pages use:

| Field | Type | Meaning |
|---|---|---|
| `code` | string | Shared join code |
| `codeA`, `codeB` | string? | Per-side join codes (separate-teams matches) |
| `status` | string | `lobby` · `live` · `ended` · `abandoned` |
| `name` | string | Match title, often empty |
| `teamAName`, `teamBName` | string | Team names |
| `scoreA`, `scoreB` | int | Live score |
| `format` | string | `5v5`, `7v7`, … |
| `durationMin` | int | Planned length |
| `location` | string | Often empty (removed from creation in §35) |
| `playerUids` | array | Registered players; **guests are not in it** — count `players` instead |
| `timingMode` | string | `none` · `full` · `halves` |
| `startedAt` | timestamp? | Kickoff |
| `endsAt` | timestamp? | When the clock hits zero |
| `pausedAt` | timestamp? | Non-null ⇒ clock frozen |
| `currentHalf` | int | 1 or 2 |
| `halfTime` | bool | Explicit half-time flag |
| `endedAt` | timestamp? | Full time |
| `scheduledAt` | timestamp? | **May be absent** — guard it |

**`matches/{matchId}/players/{uid}`** — `name` (string), `team`, `joinedAt`.
Used only for the per-side head counts.

🔴 **`team` is UPPERCASE `'A'` / `'B'`** — see `TeamSideX.id` in the app's
`models.dart`. Comparing against `'b'` files every Team B player and every Team B
goal under Team A: it renders perfectly and is simply wrong. Mirror the app's
`fromId`, which is strict — `v == 'B' ? b : a`, so anything else is side A.

⚠️ Do **not** `orderBy('joinedAt')`: it is a server timestamp, and the query
would silently drop any document whose write has not resolved yet. Order does
not matter for a count.

**`matches/{matchId}/goals/{goalId}`** — `scorerName` (string), `assistName`
(string?), `team` (**`'A'`/`'B'`**, as above), `minute` (int), `at` (timestamp),
`scoreAAfter`/`scoreBAfter` (int). Sort **client-side** by `minute` then `at`, and
**render newest first** — same server-timestamp trap as `players`.

🔒 **Never render player names on the website beyond goal scorers and assisters.**
The app shows a full roster; a public web page listing everyone who turned up is
more personal data than this page needs. Counts only.

---

## 3. Page 1 — Join (`/join`)

### 3.1 Purpose

Take a match code and hand the visitor to the live page. Also the landing page
for referral links (§5) and for anyone who opens the bare URL.

### 3.2 Entry points

| URL | Behaviour |
|---|---|
| `/join?code=ABC123` | Resolve immediately, skip straight to §3.4 |
| `/join?ref=XYZ789` | Referral mode — §5.5 |
| `/join` | Empty form |
| `/join/ABC123` | Same as `?code=` (accept a bare path segment, 4–12 alphanumerics) ♻️ |

Accept `?c=` as an alias of `?code=`.

### 3.3 Empty / entry state

- Header: `YN` + volt `O` wordmark, `YALLA NELLAB` beneath it; language toggle right.
- H1 `landingTitle`, sub `landingSub`.
- Card: eyebrow `haveCode`, a single uppercase input (placeholder `codeHint`,
  `maxlength=12`, `autocapitalize=characters`, `spellcheck=false`), and a volt
  **Join** button.
- **Enter must submit.** (In the app this exact omission was client bug C18 — the
  field had no submit handler and pressing enter did nothing. Do not repeat it.)
- Empty submit → inline error `enterMatchCode`. Do not navigate.
- Below: the **Get the app** card (§3.6).

### 3.4 Resolving

Show a volt spinner and `checking`. Then:

| Outcome | Result |
|---|---|
| Found | Go to `/live?code=ABC123` (§4). Keep it a real navigation so Back works. |
| No match | Return to the form, inline error `noMatchForCode`, code left in the input for editing |
| Network/HTTP error | Same, with `couldNotLookup` |

Optionally show the match card (status pill, team names, format, which side the
code joins) as a confirmation step before the live page — ♻️ that card already
exists in the reference implementation. **Default: skip it**, go straight to the
live screen, which is what you asked for.

### 3.5 Ended matches

Still navigate to the live page — it shows the final score. Do not present an
ended match as an error.

### 3.6 Get the app card

- If `PLAY_STORE_URL` is set → a volt **Download YNO** button.
- If it is `null` → honest text `notOnStores`, no dead button.

```js
// TODO: replace with the real listing once the app is approved.
// The id at the end is the app's applicationId — see §7 blocker 1.
const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=org.nellab.yno';
```

### 3.7 "Open in the app" escape hatch

If the visitor has the app but arrived in a browser anyway (WhatsApp's in-app
browser can swallow App Links — §5.6), offer a secondary button that fires the
Android intent directly:

```
intent://nellab.org/join?code=ABC123#Intent;scheme=https;package=org.nellab.yno;S.browser_fallback_url=https%3A%2F%2Fnellab.org%2Fjoin%3Fcode%3DABC123;end
```

Show it only on Android (`/android/i.test(navigator.userAgent)`). If the app is
missing, the fallback URL returns them to this page — harmless.

---

## 4. Page 2 — Live match (`/live`)

A faithful web port of the app's `LiveScoreboardScreen`. Read-only. The app even
mocks this page up inside itself with a fake browser chrome, so the two are meant
to look alike.

### 4.1 Entry

`/live?code=ABC123` (resolve via §2.5) or `/live?id=<matchId>` (direct document
read). Prefer `?code=` — it is shareable and survives a refresh.

No code, or an unresolvable one → the empty state: 📺, `noMatchSelected`,
`openShareLink`, and a **Download YNO** button.

### 4.2 Layout, top to bottom

**1 · Status line** — centred: an 8px dot plus a label.

| Condition | Dot | Label |
|---|---|---|
| `status` is `ended` or `abandoned` | `--loss` | `fullTime` ("FULL TIME") |
| `pausedAt != null` | `--gold` | `paused` |
| `status == 'live'` | `--loss` | `live` ("LIVE") |
| otherwise | `--loss` | `lobby` |

**2 · Timer** — 26px Barlow Condensed 800, only while `status == 'live'`. §4.3.

**3 · Scoreline** — a three-column row:
`[ team A block ] [ "3 : 1" ] [ team B block ]`.
The score is 52px Barlow Condensed 800, `line-height:.8`, format `A : B` with
spaces. Each team block is a 50×50 rounded square (`--surface`, `--line` border,
radius 16) containing the letter **A** or **B**, then the team name UPPERCASE
(14px condensed 700, max 2 lines, ellipsis), then `N players` in 10px `--dim2`
(`player` singular when N is 1).

**4 · Goals** — eyebrow `goals`, then newest first. Empty → `noGoals`.

Each goal is a card (`--surface`, `--line`, radius 16, 9px gap):

```
[ 12'  ] [ ⚽ ] [ Scorer Name            ]
                [ Goal · Falcons · assist Other Name ]
```

- Minute is `${minute}'` in a fixed 30px column, condensed 700, `--dim`
- Title: `scorerName`, 14px Barlow 700
- Subtitle 12px `--dim2`: `Goal · <team name>`, and when `assistName` is present
  `Goal · <team name> · assist <assistName>`

**5 · Download YNO** — the primary CTA, or the honest note from §3.6.

### 4.3 The clock — must match the app exactly

Port of `_timerText`. Tick locally **once per second**; recompute from the
server fields, never by incrementing a local counter.

```
now      = pausedAt ?? Date.now()        # frozen while paused
expired  = endsAt != null && now > endsAt
atHalf   = timingMode == 'halves' && (halfTime || (currentHalf == 1 && expired))

if status != 'live':            → ''            (no timer at all)
if atHalf:                      → "HALF TIME"   (uppercased)
if timingMode == 'none':
    if startedAt == null        → ''
    else                        → mm:ss of (now - startedAt)        # counts UP
else:
    if endsAt == null           → ''
    diff = endsAt - now
    if diff < 0                 → "+" + mm:ss of |diff|             # stoppage
    else                        → mm:ss of diff                     # counts DOWN
```

`mm:ss` is zero-padded on both parts.

Three things that are easy to get wrong:

- **`pausedAt` freezes the clock.** A watcher must never see time run down while
  play is stopped.
- **Overtime shows as `+MM:SS`**, not a negative number.
- The clock is **advisory** and derived from the viewer's device time — exactly
  as in the app. A skewed device clock shows a skewed timer. Do not try to
  correct it; matching the app matters more.

Timestamps arrive as ISO strings over REST and as `Timestamp` objects via the
SDK. Normalise to epoch milliseconds once, at the edge.

### 4.4 Behaviour

- Live updates for score, goals, team names, player counts, status and pause.
- A goal appearing may animate in gently; nothing that jumps the scroll position.
- Full time: keep the final score and the goal list on screen; the timer
  disappears (the app stops rendering it once `status != 'live'`).
- Respect `prefers-reduced-motion`.
- No polling faster than 5s if using the REST fallback.

---

## 5. How shared links route — ⏸ PHASE 2, DEFERRED

> **Do not build any of this yet.** Recorded on 2026-08-20 so the design is not
> lost, and because two of its constraints shape decisions made earlier in this
> document. Work starts after the Phase 1 pages are live.
>
> The Phase 1 pages do **not** depend on it: without App Links every visitor
> simply lands on the website, which is the correct fallback anyway.

### 5.1 The two link shapes

| Shared from | URL |
|---|---|
| A match lobby's share sheet | `https://nellab.org/join?code=ABC123` |
| The referral screen / profile | `https://nellab.org/join?ref=XYZ789` |

⚠️ The referral link **does not carry the code today** — `misc.shareMsgB` shares
the bare domain and the code is typed by hand. Adding `?ref=` is an app change,
listed in §5.7.

### 5.2 The routing table

This is the behaviour you asked for, in full:

| Link | App installed | Signed in | What happens |
|---|---|---|---|
| `?code=` | **yes** | either | **App opens** on Home, with the join-by-code sheet open and the code pre-filled |
| `?code=` | **no** | — | Browser opens `nellab.org/join?code=` → resolves → the **live match page** |
| `?ref=` | **yes** | **no** | **App opens** on **Sign-up**, referral code pre-filled and validated |
| `?ref=` | **yes** | **yes** | **App opens** on Home, then a popup: you already have an account, a referral cannot be applied now |
| `?ref=` | **no** | — | Browser opens the page → **Play Store** |

### 5.3 The mechanism: Android App Links

There is no way for a web page to detect whether an app is installed. The OS does
it. A **verified Android App Link** means: tapping the `https://` URL opens the
app if it is installed and verified, and falls through to the browser if it is
not. That single mechanism produces every row above.

Two halves have to agree:

**a) The website hosts a digital-asset-links file** at exactly:

```
https://nellab.org/.well-known/assetlinks.json
```

```json
[{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "org.nellab.yno",
    "sha256_cert_fingerprints": [
      "7D:3A:5A:21:25:D1:03:48:04:F8:E9:8E:0A:9E:80:F7:86:A7:1D:90:DD:A9:0E:A3:AA:C6:80:85:0D:30:FE:58",
      "18:14:8A:A8:77:CB:94:46:59:FA:7A:E6:AF:B3:93:D1:97:33:27:CE:72:5B:8C:D2:6E:FE:36:FD:B1:AC:FF:99"
    ]
  }
}]
```

Those are the app's **release** and **debug** SHA-256 fingerprints (debug is
there so the link can be tested before release; drop it later if you prefer).

🔴 **Three ways this file silently fails — check all three:**

1. **Firebase Hosting hides dotfiles.** The default `firebase.json` carries
   `"ignore": ["**/.*"]`, which excludes `.well-known/` from the deploy. Remove
   that pattern or add an explicit exception, then confirm the URL really returns
   the JSON after deploying.
2. **It must be served as `application/json`**, HTTP 200, no redirect.
3. **Play App Signing re-signs the app.** If you publish through Play with app
   signing enabled — the default — Google signs the shipped APK with *its* key,
   not your upload key, and the fingerprint above stops matching. Add the
   **App signing key certificate SHA-256** from Play Console → Setup → App
   signing to the array. (This is the same trap already flagged for Google
   sign-in in §45 item 3 of `SESSION_PROGRESS.md`.)

**b) The app declares the filter.** In `AndroidManifest.xml`, on the main
activity:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https"
        android:host="nellab.org"
        android:pathPrefix="/join" />
</intent-filter>
```

⚠️ **Keep `pathPrefix="/join"`.** Without it, verifying `nellab.org` would make
*every* page of the marketing site try to open the app.

The app has **no intent-filter at all today** beyond LAUNCHER — verified
2026-08-20. This is new work.

### 5.4 `?code=` — match links

- **App installed:** Android opens the app; the website is never reached. The app
  reads `code`, lands on **Home**, opens the join-by-code entry with the code
  pre-filled, and lets the user confirm. Do not silently join them — the app
  makes joining a deliberate tap, and so should this.
- **Not installed:** the browser loads `/join?code=` → §3.4 → the live page.

### 5.5 `?ref=` — referral links

- **App installed, signed out:** open **Sign-up** with the referral pre-filled.
  The field already self-validates against `findByReferralCode` and blocks
  submission if the code is not real, so an invalid code degrades gracefully.
- **App installed, signed in:** go **Home** and show a dismissible popup —
  `refAlreadyHaveAccount` (§6). Say plainly that referral credit only applies to
  a brand-new account, so the user is not left wondering.
- **Not installed:** the website page shows a short "Get YNO" panel and sends
  them to `PLAY_STORE_URL`. Prefer a visible button over an automatic redirect —
  a silent jump to the Play Store from a tapped link reads as hostile, and iOS
  and desktop visitors would be sent somewhere useless. Auto-redirect only on
  Android, after a beat, if you want it.
- Referral mode must **not** show the match-code form as the primary element. It
  is a different intent; the code field can sit lower on the page.

### 5.6 WhatsApp's in-app browser

WhatsApp usually honours verified App Links, but on some Android versions and
some link previews it opens its own WebView instead, which bypasses them. That is
why §3.7's explicit **Open in the app** button exists. Treat App Links as the
happy path and the button as the guaranteed fallback; do not rely on user-agent
sniffing to decide.

### 5.7 App-side work this requires

Not part of the website build, but the routing does not work without it:

1. **A new Flutter dependency** — `app_links` (or equivalent). Unavoidable:
   nothing in the current `pubspec.yaml` can receive a deep link. Worth stating
   plainly because the OTP work in §50 was deliberately built with none.
2. The `AndroidManifest.xml` intent-filter in §5.3b.
3. A link handler covering **both** cold start (app launched by the link) and
   warm resume (app already running) — missing the second is the classic bug.
4. Routing per §5.2, including the signed-in-vs-signed-out branch.
5. `lib/links.dart`: `kJoinBaseUrl` → `https://nellab.org/join`, plus a
   `referralLink(code)` helper. `test/links_test.dart` will need its expectation
   updated.
6. `misc.shareMsgB` (EN + AR) and `profile_screen._shareReferral` to share
   `referralLink(code)` instead of the bare domain.
7. Two new l10n keys for the already-have-an-account popup (§6).
8. iOS is **out of scope** for now. The same shape applies later:
   `apple-app-site-association` at `/.well-known/`, plus associated-domains
   entitlements.

---

## 6. Copy — English and Arabic

✅ = already in the app's `lib/l10n/`, copy verbatim. Others are new.

### Shared / Join page

| key | English | العربية | |
|---|---|---|---|
| `brandSub` | Yalla Nellab | يلا نلعب | |
| `landingTitle` | Football, organised. | كرة القدم، منظّمة. | |
| `landingSub` | Create matches, pick teams, keep score and track every player's stats. | أنشئ المباريات، اختر الفرق، سجّل النتائج، وتابع إحصائيات كل لاعب. | |
| `haveCode` | Have a match code? | لديك رمز مباراة؟ | |
| `matchCode` | Match code | رمز المباراة | ✅ |
| `codeHint` | e.g. AB12CD | مثال: AB12CD | ✅ |
| `joinBtn` | Join | انضم | |
| `checking` | Checking the code… | جارٍ التحقق من الرمز… | |
| `enterMatchCode` | Enter the match code. | أدخل رمز المباراة. | ✅ |
| `noMatchForCode` | No match found for that code. | لا توجد مباراة بهذا الرمز. | ✅ |
| `couldNotLookup` | Could not look up that code. | تعذّر البحث عن هذا الرمز. | ✅ |
| `openInApp` | Open in the app | افتح في التطبيق | |
| `getTheApp` | Get the app | احصل على التطبيق | |
| `downloadYno` | Download YNO | حمّل YNO | ✅ |
| `notOnStores` | The app is not published to the app stores yet — ask whoever invited you to send you the install file. | لم يُنشر التطبيق على المتاجر بعد — اطلب ملف التثبيت ممّن دعاك. | |

### Live page

| key | English | العربية | |
|---|---|---|---|
| `liveTitle` | Live | بث مباشر | ✅ |
| `live` | LIVE | مباشر | ✅ |
| `paused` | PAUSED | متوقفة | ✅ |
| `lobby` | LOBBY | الردهة | ✅ |
| `fullTime` | Full Time | نهاية المباراة | ✅ |
| `halfTime` | Half Time | الاستراحة | ✅ |
| `goals` | GOALS | الأهداف | ✅ |
| `noGoals` | No goals yet. | لا أهداف بعد. | ✅ |
| `goal` | Goal | هدف | ✅ |
| `assist` | assist | صناعة | ✅ |
| `player` | PLAYER | لاعب | ✅ |
| `players` | PLAYERS | لاعبين | ✅ |
| `noMatchSelected` | No match selected | لم تُحدَّد مباراة | ✅ |
| `openShareLink` | Open a match’s share link to watch it live here. | افتح رابط مشاركة مباراة لمتابعتها مباشرة هنا. | ✅ |

### Referral (new app strings, listed here so both sides match)

| key | English | العربية |
|---|---|---|
| `refWelcome` | You've been invited to YNO | لقد تمت دعوتك إلى YNO |
| `refGetApp` | Install the app to claim your invite — you both earn points. | ثبّت التطبيق للحصول على دعوتك — كلاكما يكسب نقاطًا. |
| `refAlreadyHaveAccount` | You already have a YNO account, so this referral cannot be applied. Referral points are only awarded when a brand-new account is created. | لديك حساب YNO بالفعل، لذا لا يمكن تطبيق هذه الإحالة. تُمنح نقاط الإحالة فقط عند إنشاء حساب جديد. |

⚠️ Arabic strings marked ✅ are lifted from the app. The three new referral
strings and a few new page strings are my translations — **have a native speaker
read them once** before they go live.

---

## 7. Status, blockers and open questions

### Decided 2026-08-20

**✅ `applicationId` = `org.nellab.yno`.** Replaces the placeholder
`com.example.ynoapp`. Phase 2 work, not Phase 1 — but it is a fixed value now, so
`assetlinks.json` and the Play Store URL can both be written against it.
⚠️ Changing it in the app is **not** a one-line edit: it needs a **new Firebase
Android app**, a fresh `google-services.json`, and **all four SHA fingerprints
re-registered**. Budget it properly when Phase 2 starts.

**✅ Pages at `nellab.org/join` and `/live`** (§0.1).
**✅ Spectate-only** (§0.2).

### Open for Phase 1

**1. Where is the website project?** Point me at the folder and I will read this
file from there and build. Its stack — plain HTML, React, something else — is the
one thing I cannot guess, and it decides SDK-vs-REST (§2.3) and how routes are
declared.

**2. Arabic review.** Strings marked ✅ in §6 are lifted verbatim from the app.
The rest are mine and should get a native-speaker read before they go live.

**3. `og:image`.** Link previews in WhatsApp show a title and description but no
picture. Needs a 1200×630 PNG — a design asset, not code. Worth having: it is the
first thing anyone sees of a shared match.

### Waiting on Phase 1 finishing

**4. Flip `kJoinBaseUrl`** in `lib/links.dart` to `https://nellab.org/join`,
and update `test/links_test.dart`. One line, done the day the pages go live so
the app never advertises a URL that 404s.

**5. Retire the `nellab-join` Hosting site** created in §51 of
`SESSION_PROGRESS.md`, or keep it as a staging copy. Superseded by §0.1.

**6. Play Store URL** — placeholder until the listing exists. One constant, and
the id inside it is now known: `org.nellab.yno`.
