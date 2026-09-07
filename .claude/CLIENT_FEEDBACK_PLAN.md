# YNO — Client feedback plan (2026-08-18)

21 points from the client, each traced through the current code before being
sized. Numbering **C1–C21** follows the client's own list order.

Read `.claude/SESSION_PROGRESS.md` §2a first — it is the current build state.

**Headline:** 6 points are small copy/UI fixes, 1 is an outright **bug found
while checking** (C5), 3 are already partly built and need finishing, and 2
(C7 accounts, C12 website) are genuinely new features that need a decision
about backend architecture before anyone writes code.

---

## 1. Verdict table

| # | Client point | Current state in code | Verdict | Size |
|---|---|---|---|---|
| C1 | "Yalla Nellab" spelt properly | `home_screen.dart:579` = `'YALLA NELLAB'` | ⚠️ **Reversal** — this exact spelling was chosen by us over the design's "Yalla Nel'ab" (§39). Need the target spelling | S |
| C2 | Matches page → burger, with draft count | Matches page **deleted** (§39). `draft_screen` is drawer-only with a red **dot**, not a number. **One draft max** | 🔨 Rebuild page + numeric badge | M–L |
| C3 | Community page removed as it is | `community_screen` = Friends leaderboard + Global (off) + Contacts | 🔨 Removable, but **must rehome Contacts** | M |
| C4 | Remove "decide later" on game invites | `home_screen.dart:270` renders `match.challengeLater` in the invite dialog | ✅ Trivial | S |
| C5 | In-app join popups not appearing on my phone | **BUG FOUND — see §2** | 🐛 **Real defect** | S fix |
| C6 | Fix design: adding your own team when making a match | Unlabelled chips under Team A; **renders nothing at all if you own no teams** | 🔨 Redesign | M |
| C7 | Claim account, email OTP, set password at registration | **No verification of any kind.** Signup creates the account instantly | 🆕 **New feature + backend decision** | XL |
| C8 | Can view a team but not join it | `TeamRepository` has **no join/request method**. Entry is invite-only or by code | 🆕 New flow | M |
| C9 | On a draw, non-admins must wait for the admin's decision | `live_match_screen.dart:78-83` sends non-creators **straight to the scorecard** while the admin is still on the outcome picker | 🐛 Confirmed | M |
| C10 | Admin can leave the lobby, game saved as draft | **Already works** — no `PopScope`, backing out leaves `status: lobby`, which is a draft | ✅ Verify + discoverability (C2) | S |
| C11 | Users can leave the lobby anytime | No self-leave. `removePlayer` is manager-only | 🆕 New method + button | S–M |
| C12 | Website link to join a game | `lobby_screen.dart:41` already shares `https://yno.app/join?code=…` — **the domain does not exist**. The in-app equivalent (`guest_join_screen`) is fully built | 🆕 Build + host page | M–L |
| C13 | Not clear you can add your own team | Same root cause as C6 | 🔨 With C6 | — |
| C14 | Even once a team is made, still not clear | Same root cause as C6 | 🔨 With C6 | — |
| C15 | Challenge-by-code design not understandable | Dim 12px label + code field + button, tucked below the opponent name | 🔨 Redesign | M |
| C16 | "Unlimited" → "Custom", move to top, describe it | `match_create_screen.dart:32` — `Unlimited` is **last**; formats start at **4v4** (1v1/2v2/3v3 removed in §35) | ✅ Easy, but see §3 D4 | S |
| C17 | Going back with keyboard open is slow | Cannot be diagnosed statically | 🔍 Reproduce + profile | S–M |
| C18 | Guest without email: no feedback | Validation **exists** (`lobby_screen.dart:916`) but fires a toast on the sheet context, and the fields have **no `onSubmitted`** — so pressing Enter genuinely does nothing | 🐛 Confirmed | S |
| C19 | Penalty shootout as a third option, enter score | Penalties exist **only** after choosing "extra time played", and capture **no score** | 🔨 Promote + add score | M |
| C20 | Draw ends the match instantly — confirm first | `_finish(method:'draw')` fires on tap, no confirm | ✅ Trivial | S |
| C21 | Remove code regeneration entirely | `regenerateCode` (match, lobby) + `regenerateInviteCode` (team) | ✅ Easy, scope question | S |

Sizes: **S** ≤ 2h · **M** ½–1 day · **L** 2–4 days · **XL** 1 week+

---

## 2. 🐛 C5 — the popup bug (found while checking; worth reading)

The client says join-game popups "don't appear on my main phone" and reads it as
a device problem. **It is not a device problem — it is per-account, and once
triggered it is permanent.**

`home_screen.dart:60` and `:190`, in both `_maybePopChallenge` and
`_maybePopInvite`:

```dart
if (_promptedPosition && user != null && !user.sportProfileDone) return;
```

The intent was "let the pick-your-position prompt own the screen right after
signup". The effect is different. `sportProfileDone` is set to `true` **only** by
`UserRepository.completeSportProfile` (`user_repository.dart:163`), so any user
who saw the position prompt and **backed out without choosing a position** keeps
`sportProfileDone == false` forever — while `_promptedPosition` is set to `true`
again on **every mount of Home**. From then on that account never sees a
challenge or match-invite popup again, on any device.

The persistent banner still renders, which fits the report exactly: the client
sees something, but never the popup.

**Fix:** gate on whether the position route is actually on screen right now,
rather than on a flag that can never clear:

```dart
if (_positionRouteOpen) return;   // set true on push, cleared on pop
```

Two things to check on the same device run, because they look identical from
the outside:

- **Push has never worked** — the FCM admin key only landed today (2026-08-18).
  If the client expected a *notification* rather than an in-app dialog, that was
  the cause; now fixed but unproven.
- Android battery optimisation suspends Firestore listeners in the background on
  some OEM builds (Xiaomi/Oppo/Samsung are the usual offenders).

---

## 3. What has to be decided before coding

These change the work materially. None of them block Phase 1.

**D1 — C1: what is the correct spelling?** We deliberately picked `YALLA NELLAB`
over the design bundle's `Yalla Nel'ab` (§39, at the user's instruction). Need
the exact string the client wants, so this doesn't ping-pong a third time.

**D2 — C2: does "number of drafts" mean more than one draft is allowed?** Today
one draft per user is a **hard product rule** (§39): `openCreateMatch` blocks a
second and offers "Open & Continue / Delete it & start new". A count badge that
can only ever read "1" is odd, so the client probably wants that rule gone.
Also: does "Matches page" mean the full **Ongoing / Drafts / Played** list back,
or the existing Draft page relabelled?

→ *Recommendation:* drop the one-draft rule and restore a **My Matches** page.
It also answers C10 and C11 — all three are really "I left my match, where did
it go?"

**D3 — C3: what happens to the friends leaderboard?** Deleting Community as-is
also deletes the **Contacts** tab, currently one of only two ways to add a
friend (the Global board was disabled in §44, and there is still no username
search on Home). `friends_screen` already has requests, **search**, and the same
contact matcher.

→ *Recommendation:* point Home's **Friends** button at `Routes.friends`, delete
`community_screen`, and decide separately whether the friends **leaderboard**
moves to the profile or is dropped.

**D4 — C16: what does "Custom" mean, and does 3v3 come back?** The client's
phrasing ("before 3v3, 4v4, 5v5") implies 3v3 exists — it was **removed in §35**
along with 1v1 and 2v2. `Custom` is also a name we retired in that same pass.
Need: (a) re-add the small formats? (b) does Custom mean "no squad limit" (what
`Unlimited` does today) or "type your own number"? (c) the description text.

**D5 — C7: this needs a backend, and there is a security hole to close.**
Firebase Auth **cannot send a 6-digit email OTP** — it only sends links.

| Option | How | Cost | Verdict |
|---|---|---|---|
| **A. Cloud Functions (Blaze)** | Server generates + verifies the OTP, sends via an email provider | Pay-as-you-go; free tier covers this comfortably | ✅ **Recommended.** Also lets us move FCM sending server-side and **delete the bundled admin key**, which today ships full project-admin rights inside every APK |
| **B. Bundled email API key** | App calls Resend/Brevo directly, holds the code in memory to compare | Free tier | ⚠️ Works and matches the project's existing posture, but the check is client-side and bypassable |
| **C. Firebase verification link** | Built-in `sendEmailVerification()` | Free | ⚠️ Not an OTP; and email-**link sign-in** on mobile depended on Dynamic Links, which Google shut down in 2025 |

Urgent either way: **auto-created accounts use the password `123456`, and
`showAccountExistsDialog` reveals it to anyone who types that email address.**
Anyone who knows a player's email can sign in as them today. The claim-by-OTP
flow the client is asking for is exactly what closes this.

**D6 — C12: who owns `yno.app`, and where does it host?** The link is already
being shared and is dead. Firebase Hosting on the same project is the obvious
target (free tier). ⚠️ **Only the join page may be hosted** — the Flutter web
build is the super-admin dashboard with credentials baked in (§23) and must
never be published.

**D7 — C8: open join, or request-and-approve?** Teams already carry a
public/private flag. *Recommendation:* public teams get **Request to join** →
owner/captain approves from the bell (mirrors team invites, §26); private teams
stay code-only.

**D8 — C21: does "remove code regeneration" include team invite codes?** The
match code and the team code are separate features. Removing team regeneration
means a leaked team code can never be revoked.

**D9 — C19: does a shootout win count as a win in career stats?** Today
`resultFor` treats a `winnerSide` override as a full win/loss. Also: should the
shootout score appear on the scorecard and in match history?

---

## 4. Phased plan

### Phase 0 — Run it on a device (½ day) · do this first
The app has **still never run against live Firebase** (§2a). C5, C17 and half of
C10 cannot be honestly closed without it, and push is testable for the first
time today. Use the AVD `Medium_Phone_API_36.1`, plus the client's own handset
for C5. Collect the "add to the first device run" checks scattered through
§34–§43 before starting.

### Phase 1 — Quick wins (~2 days)
C1 · C4 · C16 · C18 · C20 · C21 · **C5 fix** · C10 verification.
All low-risk and independently shippable — gets the client visible movement fast.

### Phase 2 — Match flow correctness (~3 days)
- **C9** — hold non-admins in a waiting state. Change `_redirectToResults` so a
  level score with `outcomeMethod == null` shows a "the host is deciding…" panel
  instead of the scorecard, then moves on reactively once the field is written.
- **C19** — promote **Penalty shootout** to a top-level option on the outcome
  screen with a score entry; persist `penaltyA`/`penaltyB` and render them on
  the scorecard.
- **C11** — `MatchRepository.leaveMatch(matchId, uid)` plus a Leave button for
  non-admin players. Must clear the armband if a captain leaves, or `_start`
  blocks forever.

### Phase 3 — Navigation restructure (~4 days) · needs D2, D3
- **C2** — rebuild **My Matches** (Ongoing / Drafts / Played) in the drawer;
  swap the red dot for a count badge on both the burger and the row.
- **C3** — remove Community, rehome Contacts, repoint Home's Friends button.
- Follow the project rule: **before deleting a nav entry, grep for repo methods
  its screen is the sole caller of.** This has already bitten us twice (§43).

### Phase 4 — Create-match redesign (~3 days) · needs D4
C6 + C13 + C14 + C15, the C16 layout change, and C17.

The core change is making team selection **explicit** instead of implicit: a
labelled "Your team" picker with a real empty state ("You don't have a team yet
→ Create one"), and the opponent presented as a clear two-way choice (*type a
name* / *challenge by code*) rather than a dim label under a text field. §34
already flagged the zero-teams empty state as a known gap — the client has now
independently reported it.

### Phase 5 — Team joining (~2 days) · needs D7
**C8** — `requestToJoin` + notification to owner/captain + Accept/Decline in the
bell + a **Join** button on the team profile and in team discovery.

### Phase 6 — Accounts & web (~8+ days) · needs D5, D6
- **C7** — OTP registration, password setup, account claiming. Sequence: pick
  the backend → build OTP send/verify → wire into signup → wire into claim →
  **remove the `123456` password reveal**.
- **C12** — static join page on Firebase Hosting, mirroring `guest_join_screen`.

**Rough total: 20–25 working days**, excluding turnaround on the Phase 6
backend decision. Phases 1, 2 and 5 are independent and can run in parallel.

---

## 5. Risks

- **No git history.** Every removal is permanent — archive l10n strings to
  `.claude/l10n_removed_keys.md` before deleting (project rule).
- **Phase 3 orphan risk.** Removing Community without rehoming Contacts would
  leave almost no way to add a friend. See D3.
- **The bundled FCM admin key** ships project-admin rights in every APK. Phase 6
  Option A is the opportunity to remove it — worth weighing when D5 is decided.
- **`applicationId` is still `com.example.ynoapp`.** Play will reject it, and
  changing it costs a new Firebase Android app, a new `google-services.json` and
  re-registering all four SHAs. Deferred by the user, but it lands before
  release and should be scheduled, not discovered.
- **C17 may not be ours.** Keyboard-dismiss jank is frequently the OEM keyboard.
  Profile before committing to a fix.
