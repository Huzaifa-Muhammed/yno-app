# YNO App — Session Progress

_Last updated: 2026-08-29 (§79 — Play Store readiness audit)_

> 👉 **NEXT SESSION: START AT §79 — the Play Store readiness audit.** It is the
> current truth and supersedes §75 as "start here" (which superseded §70–§74 and
> §69/§66/§64/§62/§58/§49). Everything else below is history.
>
> **A signed release bundle already exists** —
> `build/app/outputs/bundle/release/app-release.aab`, 48 MB, 2026-08-29. The
> remaining code work is small and named in §79: **the default Flutter launcher
> icon and the `ynoapp` label**, and **backing the keystore up off this machine**
> before the first upload makes `org.nellab.yno` permanent. Most of what is left
> is Play Console paperwork, not Dart.
>
> ✅ **Rules are deployed and in sync** — §50's `emailOtps` rule was released to
> `cloud.firestore` on 2026-08-18, after §48's `joinRequests`. Nothing pending.
> The OTP service is **deployed and delivery is PROVEN** (§70); §50a's runbook is
> done, don't re-run it.
>
> ⚠️ **Read §50's first section — and §79's `123456` box — before touching the
> claim flow.** The client overruled the original security design mid-build and
> deliberately kept `123456` as a working login. That is a decision, not a bug —
> do not silently "fix" it. §79 explains what changes about it at publication and
> what it would cost to close, so it can go back to the client as a launch
> decision.
>
> Still unproven on a device: **C9 + C19 and C8** (need a second actor —
> `server/test/device_second_actor.mjs`), and **Google sign-in on
> `org.nellab.yno`** (one tap settles it — §77).

A running log of what's been built so the next session can pick up without
re-deriving anything.

---

## 1. Current state — read this first

YNO is a **Flutter football match app on a live Firebase backend** (Auth +
Firestore + FCM), feature-complete against `.claude/Features and Logics YNO.docx`.
All ~35 screens are wired to real data. Fully localised **EN + Arabic with RTL**.

**Design: dark theme, volt accent `#D4FF00`, Barlow / Barlow Condensed**, from
**`.claude/design/design.html`** (§39 — it supersedes the older
`.claude/design/YNO App.html`, which is still the reference for screen *layouts*
but has the old `#C6FF3A` accent). NOTE: the historical log below (§2b–§3)
describes a black-&-white **wireframe** phase — **that was abandoned and
reverted in §11**. There is no wireframe; ignore any wireframe language there.

Locked product decisions that still hold:
- 🔌 Everything on Firebase (Auth + Firestore); **Hybrid auth** (email/pw + Google).
- 🔗 **Code-based** joining, referral and team challenges (Dynamic Links is dead —
  no deep-link install attribution, by decision).
- 📣 **Client-side FCM** (bundled admin key, no Cloud Functions) · **Cloudinary**
  uploads.
- 🧭 **No bottom nav** (deleted §39). **Home is the hub**: top bar (avatar →
  Profile · coins → Refer & Earn · bell → Notifications · burger → drawer),
  a يلا نلعب button opening a **Create Match / Join by Code** sheet, and two
  shortcuts — **Friends → `Routes.community`** and **My Teams → Teams**.
  Everything else is in the side drawer. No sport selector (football only), no
  Stats page (folded into Profile), **no OVR** (§10).
- 📝 **One draft match at a time** (§39) — a created-but-never-started match.
  It lives on the drawer-only **My Matches** page (`Routes.matches`, §48) with
  a **red dot** (never a count — §48a) and self-deletes after 2 days.
- 🔑 **No code in the app ever rotates** (§48, §48b). A match code and a team
  invite code are each issued once and live for the lifetime of the thing they
  belong to. Both repo methods survive uncalled. ⚠️ A team code is also its
  **challenge** code and is now **unrevocable** — accepted trade.
- ⚽ A level match is settled by **draw · extra time · penalty shootout**
  (§48); a shootout records its score and its winner takes a real win.
- ❌ Football News on Home excluded. **Global leaderboard disabled** until ~500
  users (§44) — a flag, not a deletion.
- 🎖️ Points: +20 community award, +30 MOTM, +10 referral (both parties).

### Conventions worth knowing before you edit
- **Destructive actions are red** — `kDangerColor` / `danger: true` in
  `widgets/buttons.dart`, which documents the rule. Red = *loses data*, NOT
  merely "negative" (declining an invite, signing out, a red card stay neutral).
  Confirming is a **separate axis**: `showConfirm(...)` in `widgets/confirm.dart`
  is the app's one yes/no dialog and can be non-danger (see §20, §21).
- **Navigation** passes `matchId`/`teamId`/`uid` as a **String route argument**
  (`Navigator.pushNamed(ctx, Routes.x, arguments: id)`), read via
  `ModalRoute.of(context)!.settings.arguments as String`. Screens never import
  each other — that's what makes parallel-agent work on them safe.
- **The team invite code is a secret** and is NOT on the team doc (team docs are
  world-readable). It lives in `teams/{id}/private/meta` (manager-read only) and
  resolves via `teamCodes/{CODE}` (`get` allowed, `list` denied). Read it with
  `TeamRepository.watchInviteCode`. See §16 — do not move it back.
- **l10n**: `tr('key')` + per-cluster `lib/l10n/tr_*.dart` maps `{key: [en, ar]}`.
  Add to the right cluster; missing keys fall back to English. **This project has
  no git history**, so a removed string is gone — archive it to
  `.claude/l10n_removed_keys.md` before deleting, and re-run the §36 sweep after
  (it catches both undefined keys and new orphans; mind `tr('…$…')`).
- **Colour lives in `theme/app_colors.dart` only.** Flipping the palette is a
  one-file edit *provided* nothing hard-codes a hex — three files had, and were
  fixed in §39. Grep for a bare hex before assuming a re-skin took.
- **Turn features off with a documented `const` flag, don't delete them** —
  `kGlobalLeaderboardEnabled` (§44) is the pattern: the code stays compiled and
  referenced, so re-enabling is one `bool`. Where a list of things can be
  filtered like this, dispatch on a **named enum, not an index** (§44), or
  hiding one entry silently re-points the others.
- **Anything a screen can do must have a way in.** Twice now a removal has
  orphaned real functionality — §43 (the only accept-friend-request UI) and
  the near-miss in §39. Before deleting a nav entry, grep for the repo methods
  its screen is the sole caller of.

---

## 2. Status & how to verify

| Check | Command | Last result |
|---|---|---|
| Static analysis | `flutter analyze` | **No issues found!** (whole project) |
| Unit + widget tests | `flutter test` | **44/44 pass** |
| l10n key sweep | see §36 | no undefined keys; 2 intentional orphans |
| Firestore rules | see below | **18/18 assertions pass** |
| Release APK | `flutter build apk --release` | **√ Built, 55.2MB** (§45), signed with the release key — verify with `apksigner verify --print-certs` |
| Debug APK | `flutter build apk --debug` | **√ Built** (§46) with the refreshed `google-services.json` |

Test files: `test/widget_test.dart` (Firebase-free model/logic units),
`test/match_permissions_test.dart` (`canManageSide`/`canLogLive`/invites/pause —
the pure permission functions in `models.dart`), `test/danger_button_test.dart` +
`test/confirm_dialog_test.dart` (the destructive-action convention, pumped for
real), `test/account_exists_dialog_test.dart` (the reveal-password-only-if-
auto-created contract), `test/firestore_rules/` (adversarial rules suite —
invite-code secrecy).

**The repo layer is not unit-testable** (Firestore-dependent) — every repo
method is logic-verified only. That is why the sections below end with explicit
"add to the first device run" checks.

Rules suite (needs the emulator; local JDK is 17 so firebase-tools is pinned —
drop the pin once JDK 21+ is installed):
```
cd test/firestore_rules && npm install
cd ../.. && npx firebase-tools@13.35.1 emulators:exec --only firestore \
  --project yno-rules-test "node test/firestore_rules/invite_code_rules.test.mjs"
```

**Firebase project `yno-app-e96f5`. Rules + indexes ARE DEPLOYED** (§17,
2026-07-14): rules released to cloud.firestore; **7 composite indexes live**.
`firebase.json` now has the `firestore` block, so this works:
`firebase deploy --only firestore:rules,firestore:indexes --project yno-app-e96f5`

Devices here: Windows desktop, Chrome, Edge — **plus an Android AVD**
`Medium_Phone_API_36.1` (`flutter emulators --launch Medium_Phone_API_36.1`).
The long-standing "no Android emulator" note was **wrong as of §47**. Note the
**web build is the admin dashboard**, not the player app, so Chrome/Edge cannot
test player Google sign-in — that needs the AVD or a physical device, and the
image must carry **Google Play services** or Google sign-in fails on it.

---

## 2a. ⚠️ Open gaps — the real list (supersedes §5 and §7, which are stale)

**The one that matters:**
- 🔴 **The app has NEVER been run against live Firebase.** Every claim in this
  doc is backed by `flutter analyze`, the 48 tests, and the 18 emulator rules
  assertions — never by the app actually reading/writing as a user. A real
  `flutter run` is the highest-value next step, and where surprises will surface
  (challenge lookup, captain push, home popup). Each recent section ends with an
  "Add to the first device run" line — collect those before running.
  **§48 raised the stakes:** push (the FCM key is new and has never sent a real
  notification), the C5 popup fix, team join requests, the shootout flow,
  holding non-admins on a level result, and leaving a lobby are ALL unproven on
  a device.
- ~~`package_info_plus` has not been built~~ — **built in §45**
  (`flutter build apk --release` → 55.2MB, all native plugins link).

**Needed before that first run:**
- ~~Google sign-in needs a SHA-1 in the Firebase console~~ — **DONE, §46–§47.**
  All four fingerprints registered, `google-services.json` refreshed and
  build-tested, **provider enabled** by the user in the console, and the Dart
  side already uses the google_sign_in v6 API that needs no `serverClientId`.
  Google sign-in is **fully configured**; all that is missing is a live sign-in
  to prove it. (Provider state is **not machine-verifiable** — see §47.)
- ~~Push needs the **admin key**~~ — **INSTALLED 2026-08-18.**
  `assets/firebase_admin_key/service_account.json` is in place (service account
  `firebase-adminsdk-fbsvc@yno-app-e96f5...`, RSA 2048). Verified beyond a file
  check: the PEM parses, the key **mints an OAuth token** for the
  `firebase.messaging` scope against Google, and a `validate_only` FCM v1 send
  returns `400 INVALID_ARGUMENT` on a deliberately fake device token — i.e. auth
  and send permission are good (a bad key/role gives 401/403). No pubspec change
  was needed; `assets/firebase_admin_key/` was already declared. **Still
  unproven: an actual push to a real device token.**
  ⚠️ Every build from now on ships full project-admin credentials inside the
  APK — the §45 release APK predates the key and does NOT contain it.
- (Rules + indexes are already deployed — §17.)
- ⚠️ **`applicationId` is still the placeholder `com.example.ynoapp`** and the
  Firebase Android app is registered under exactly that. Google Play rejects
  `com.example.*`, so this must change before release — and when it does, it
  means a **new Firebase Android app, a new `google-services.json`, and
  re-registering both SHAs**. User's call, deliberately deferred (§45).

**Product gaps:**
- 🔴 **The `123456` password on auto-created accounts is revealed to anyone who
  types that email** (`showAccountExistsDialog`) — so knowing a player's email is
  enough to sign in as them. **§49's OTP claim flow is what closes this**; until
  then it is the app's worst security hole. (Second worst: the bundled FCM admin
  key, same section.)
- 🔴 **There is no username/name search on the friends hub.** It exists only on
  `friends_screen`, which §43 took out of the drawer (it is still routed, and a
  friend-request notification opens it); "Your Friends" (`community_screen`) has
  no search field, and §44 disabled the Global tab that carried the other
  add-friend button. Adding someone you are not already playing with now means:
  the **Contacts** tab, a **public profile** reached from a match or team, or
  answering a request on the bell. If players are meant to add each other by
  handle, the Friends tab needs a search box. **Flagged three times (§43, §44,
  §49) and still not decided.**
- Per-team-per-player stats (top scorer *within* a team) — no data source; team
  pages show team-level aggregates only.
- Time-window leaderboards (weekly/monthly) — labels only; repos aggregate
  all-time. (Profile DOES window personal stats by re-reading matches.)
- Career/team stats only aggregate at `finalizeMatch` — matches finished before
  that code existed are not backfilled; stats read 0 until a match completes.
- A new **Google** user's `gender` isn't persisted (`updateProfile` has no param).
  Username + referral + foot ARE handled (fixed in §10).
- Contact matching is best-effort on the raw stored `phone` string — no E.164
  normalisation at sign-up (`normalisePhone` in `services/contact_matcher.dart`
  casts a wide net to compensate).
- **Contact sync is a two-step opt-in**: the Settings toggle is a *preference*
  and does not request the OS contacts permission; the Friends page asks when it
  actually reads the address book (§41).
- The About screen has **no copyright line** — it went with "Made in Dubai"
  (§42). Add a plain `© 2026 YNO` back if that matters for release.
- Email change / username cooldown are surfaced but not enforced server-side.
- Regenerating a team code invalidates any code a friend holds — to join *or* to
  challenge. Accepted trade-off of one code (§14); now confirmed (§21).
- An admin whose challenge is declined can't re-challenge from the lobby.
- `TeamRepository.addMember` is dead code — adding is invite-only by decision.
- 🕐 **Removing a team's captain leaves the team captain-less, with no prompt to
  pick a replacement.** `TeamRepository.removeMember` sets `'captainUid': null`
  when the removed member was the captain (`team_repository.dart:309`); nothing
  asks the owner to nominate someone new. Only the owner keeps `canManage`, so
  the team still works — it just quietly has no captain. `_adoptTeamCaptain`'s
  `ownerUid` fallback (§34c) covers the match side of this, so it's cosmetic
  rather than blocking. **Deferred by the user (2026-07-20) — revisit next
  session if it proves annoying in practice.**

**Polish / infra:**
- No launcher icon, no native splash; fonts load via `google_fonts` (network on
  first run) — bundle for full offline.
- Settings notification toggles persist and DO gate push (`emit` checks prefs).
- `minSdk` 23 + core-library desugaring are required (Firebase +
  flutter_local_notifications) — already set in `android/app/build.gradle.kts`.
- Remove-member / leave / delete-team are confirmed; a few normal-flow actions
  intentionally are not (§21).

---

> **Everything below (§2b–§13) is a HISTORICAL log**, kept for context on why
> things are the way they are. It contains an abandoned wireframe phase and gap
> lists that are now out of date. **§2a above is the current truth.**
> §14–§21 (2026-07-14) are current.

---


## 2b. Correction (2026-07-02): true lo-fi wireframe

The first "wireframe" pass was really a polished black-&-white *themed* app
(filled black buttons, 14–16px rounded corners, Barlow condensed-uppercase
type, gray surface fills, red badge, ripples). The user actually wanted a
**pure lo-fi wireframe** — flat outlined boxes only, no fills/shadows/elevation.
Locked choices: **sharp 0px corners**, **monospace font (Roboto Mono)**,
buttons are **outlined (no fill)**, avatars = plain outlined squares.

Done centrally in the shared design layer so all 27 screens flattened at once
(`flutter analyze` clean, `flutter test` passes):
- `app_colors.dart` — all surfaces → white; `line`/`line2` → pure black
  hairlines; `primary`/`ink` → black; `primaryGlow()`/`winGlow()`/etc → fully
  transparent. Collapsing these auto-flattened every inline gray fill/glow.
- `app_text.dart` — all three cuts → `GoogleFonts.robotoMono`; heavy weights
  clamped to ≤w500.
- `app_theme.dart` — Roboto Mono text theme; `NoSplash`, transparent
  splash/highlight/hover; zero-elevation card/appbar/dialog themes.
- `buttons.dart` — Primary & Secondary are flat outlined boxes (sharp);
  BackChip/IconChip sharp, badge → outlined; glow/color params kept but ignored.
- `inputs.dart` / `common.dart` / `header.dart` / `bottom_nav.dart` /
  `side_drawer.dart` — sharp corners, white fills, no shadows; SurfaceCard forces
  radius 0; InitialsAvatar → square; SegmentedTabs selected = outline not fill;
  center "+" nav → outlined square; toast flat.
- Screens: most inline styling flattened automatically via the palette. Direct
  inline offenders fixed by hand: `signup` (progress bar, method/otp/dob boxes,
  photo placeholder → square, check chips → outlined squares, success circle →
  square, Google-blue/WhatsApp-green → black), `forgot_password`,
  `match_outcome` & `post_match` (filled black badges → outlined). Core match
  flow (`live_match`, `match_create`, `lobby`) was already flat.
- Kept: tiny ≤9px status/LIVE dots remain small circles (decorative).

---

## 3. What was built this phase

### Wireframe skin (Milestone A)
- `theme/app_colors.dart` — rewritten to **light grayscale**: white surfaces,
  `#111` ink text/accent, gray fills, hairline borders. All colour *names* kept
  so every screen re-skinned at once. `primary` = black, `ink` = white (text on
  the black accent). `win/loss/gold/cyan` collapse to mono.
- `theme/app_theme.dart` — now a **light** M3 theme (kept the getter name
  `AppTheme.dark` for call-site compatibility); dark status-bar icons.
- `widgets/yno_scaffold.dart` — radial glows no longer painted (param kept).
- `widgets/buttons.dart` — `PrimaryButton.glow` defaults to `false` (flat).

### Backend layer — `lib/services/`
- `models.dart` — `AppUser`, `MatchModel`, `MatchPlayer`, `GoalEvent`,
  `TeamModel`, `AppNotification`; enums `TeamSide` (a/b), `MatchStatus`
  (lobby/live/ended). fromDoc/toMap + `initials` helpers.
- `auth_repository.dart` — `AuthRepository.instance`: signUp (creates
  `users/{uid}` doc + credits referrer +10), signIn, signOut,
  sendPasswordReset, ensureProfile, **createPlayerAccount** (secondary
  FirebaseApp `playerCreator`, pw `123456`, keeps admin session). Also
  `authErrorMessage(e)` + consts `kAutoAccountPassword`, `kReferralPoints`.
- `user_repository.dart` — watchUser/getUser, updateProfile, addPoints,
  findByReferralCode, countReferrals, watchTopUsers (leaderboard by points).
- `match_repository.dart` — createMatch, watch/getMatch, findByCode,
  watch/getPlayers, watchGoals, watchUserMatches, watchOpenMatches, joinMatch,
  addNewPlayer, start/extend/endMatch, recordGoal, submitRatings, watchHasRated,
  **finalizeAwards** (community player = top avg rating +20; MOTM per team by
  `rating*2 + goals` +30; idempotent via `awardsDone`). Consts
  `kCommunityPlayerPoints=20`, `kManOfMatchPoints=30`.
- `team_repository.dart` — createTeam, watchUserTeams, watchTeam, add/removeMember.
- `notification_repository.dart` — watch, add, markRead.
- `codes.dart` — `randomCode(len)` (unambiguous alphabet).

### Firestore schema
- `users/{uid}` (+ `notifications/{id}`), `matches/{id}` (+ `players/{uid}`,
  `goals/{id}`, `ratings/{raterUid}` with `scores` map), `teams/{id}`.
- Match doc also stores `playerUids` (array) for participant queries.

### Wired screens (all 27)
- **Auth:** splash (auth gate), welcome, login (email/pw), signup (multi-step,
  captures email/pw/name/referral → creates account), forgot (reset email),
  football_profile (saves position).
- **Match flow:** home (real user + points + Join-with-Code), match_create
  (team names + duration → creates match), lobby (code/share, teams, add-player,
  start), live_match (timer, +5/+10/custom, record goal, end), match_outcome
  (result), post_match (star ratings → finalizeAwards + awards + scorecard).
- **Guest/referral:** guest_join (code → create account + join), referral
  (real code, copy/share, counts).
- **Profile/teams:** profile (Stats/Matches/Teams tabs, drawer), stats,
  edit_profile, public_profile, teams, team_create, team_profile, team_manage.
- **Social/misc:** community (points leaderboard), find_match (open matches →
  join), notifications, settings (**Sign Out**), live_scoreboard (read-only,
  reads matchId arg; still exports `BrowserChrome`), side_drawer + bottom_nav.

### Navigation convention
- `matchId` / `teamId` / (public profile) `uid` passed as a **String route
  argument**: `Navigator.pushNamed(ctx, Routes.x, arguments: id)`, read via
  `ModalRoute.of(context)!.settings.arguments as String`.
- Flow: create→lobby→live→outcome→postMatch each carry the matchId.

### Security rules
- `firestore.rules` (project root) — prototype-permissive: `matches` (+subs)
  publicly **readable** (guest code lookup + public scoreboard), writes require
  auth; `users`/`teams` require auth for read & write (needed for cross-user
  point awards). **Deploy** via Firebase console or `firebase deploy --only
  firestore:rules`. Tighten for production (move point-awarding to Cloud
  Functions).

### Editable input
- `widgets/inputs.dart` gained `YnoTextField` (real TextField styled like the
  static `FieldBox`) — used across all forms.

---

## 4. Method

Milestones A→E. Foundation (theme skin + `services/` + auth screens + the whole
core match flow: create→lobby→live→outcome→postMatch, plus guest_join &
referral) built directly. The three peripheral clusters — **profile**
(profile/stats/edit/public), **teams** (teams/create/profile/manage), and
**social/misc** (community/find_match/notifications/settings/live_scoreboard +
drawer/nav) — were wired by 3 parallel `fork` agents that inherited the repo
APIs. Verified centrally with `flutter analyze` + `flutter test` + a debug APK
build.

---

## 4b. Functionality-completion pass (2026-07-02)

Closed the three functional gaps that remained after the core build. Product
decisions taken this pass: **assists** → capture them; **cards (yellow/red)** →
dropped; **team stats** → link matches to saved teams.

- **Data model** (`models.dart`): `AppUser` gained denormalised career counters
  (`careerGoals, careerAssists, matchesPlayed, wins, losses, draws, motmCount,
  communityCount, currentStreak, bestStreak`) + getters `winRate`,
  `goalsPerMatch`, plus prefs (`notifyMatchAlerts` default true,
  `notifyFriendActivity`, `contactSync`). `MatchPlayer` gained `assists`.
  `GoalEvent` gained `assistUid/assistName`. `MatchModel` gained
  `teamAId/teamBId` (+ `teamId(side)`). `TeamModel` gained
  `matchesPlayed/wins/draws/losses/goalsFor`.
- **Repos:** `recordGoal(..., MatchPlayer? assist)` stores the assist + tallies
  the assister. `createMatch(..., teamAId, teamBId)` links saved teams.
  `finalizeAwards` now (once, under the `awardsDone` guard) folds each player's
  goals/assists/result into career counters (`UserRepository.applyMatchStats`,
  read-modify-write for streaks), rolls up saved-team stats
  (`TeamRepository.applyMatchStats`), and writes award notifications.
  `UserRepository.updatePrefs` persists settings toggles.
- **Notification writes** (feed is now alive, all best-effort/try-caught):
  `joinMatch` → notifies admin; `finalizeAwards` → notifies community
  player + MOTMs; `signUp` → notifies the referrer on referral bonus.
- **Screens:** live_match adds a second "who assisted?" sheet (teammates + "no
  assist"); match_create adds optional saved-team chips per side; stats/profile/
  public_profile bind the career counters (**Yellow/Red card tiles removed**);
  team_profile binds team counters; settings loads + persists the 3 toggles.
- Verified: `flutter analyze` → **No issues found!**, `flutter test` → passes.
  Screen bindings done by 4 parallel `fork` agents over the shared repo APIs.

## 5. Known gaps / next steps

> ⚠️ **STALE (2026-07-02) — superseded by §2a.** Several of these are fixed:
> rules are deployed (§17) and push infrastructure exists (§6). Kept as a record
> of what was open at the time.

- **Not yet run against live Firebase** on a device — needs a manual run
  (`flutter run`) to confirm reads/writes end-to-end. Deploy `firestore.rules`
  first. (Rules already permit the new cross-user notification/stat writes.)
- Career/team stats show real numbers **only for matches finished *after* this
  pass** (they aggregate at `finalizeAwards`); older matches aren't backfilled.
  Stats read `0` until a match completes its post-match ratings.
- Settings toggles now persist but are **preference flags only** — no push
  infrastructure yet, so they don't gate real push notifications.
- Deep-link install attribution intentionally omitted (code-based only).
- No launcher icon / native splash; Roboto Mono + emoji still via
  `google_fonts` (network on first run) — bundle for full offline.
- `minSdk` bumped to 23 (Firebase requirement) in `android/app/build.gradle.kts`.

> Background/context also in Claude memory: `yno-app-project.md`,
> `yno-app-architecture.md`.

---

## 6. Full final-feature build (2026-07-04)

Implemented the **entire** `.claude/Features and Logics YNO.docx` spec against a
new backend contract. Plan + phase map: `.claude/IMPLEMENTATION_PLAN.md`. Locked
infra decisions: `yno-final-scope-decisions.md` (memory) — **Hybrid auth**
(email/pw + Google), **client-side FCM** (bundled admin key, no Cloud
Functions), **Cloudinary** uploads, code-based join + share sheet, cards back in.

**Method:** Phase 0 (foundation) built directly + verified, then Phases 1–10
fanned out to 9 parallel general-purpose agents against the frozen Phase 0 APIs
(screens navigate by route name, never import each other → clean parallelism).
Result: **`flutter analyze` → No issues found!** across the whole project;
**`flutter test` → 8/8 pass** (new Firebase-free unit tests for OVR/winRate/
resultFor/codes; the old splash smoke test was replaced since splash now
auth-gates against live Firebase).

**Phase 0 (foundation, frozen contract):**
- `services/models.dart` — big overhaul: `AppUser` (+username/name parts/dob/
  gender/language/photoUrl/foot/skill/social links+visibility/fcmTokens/
  following/form/goalsBySurface+Format/getters incl `ovr`), `MatchModel`
  (+all Section-5 settings, timing/half state, outcome/winnerSide, captains,
  two codes, vote/edit windows), `MatchPlayer` (+yellows/reds/isGuest/isCaptain),
  new `CardEvent`/`SubEvent`/`PendingPlayer`/`VoteRecord`, `TeamModel` (+badge/
  privacy/inviteCode/captain/vices/roles/guests/disband/richer stats),
  `TeamInvite`, `FriendEdge`, `RivalEdge`, typed `AppNotification`, `PlayedWith`;
  enums TeamSide/MatchStatus/JoiningMethod/TimingMode/CardType/TeamRole/
  FriendStatus/NotifCategory.
- `services/storage_service.dart` — Cloudinary `uploadImage(File,{folder,pngOnly})`.
- `services/push_service.dart` — FCM v1 client sender via bundled admin key
  (`assets/firebase_admin_key/service_account.json`, projectId `yno-app-e96f5`),
  token registration, foreground local-notif, tap-routing via navigatorKey.
- Repos extended/added: `user` (username check/search/follow/played-with stats/
  surface+format goals/hat-tricks), `team` (roles/invites/discovery/disband/
  stats), `match` (all creation settings/two-code join/pending+mid-game/cards/
  subs/timing/half-time/quit-restart/outcome/community voting/algorithm-MOTM
  `finalizeMatch`/`resolveCommunityAward`/24h edit/guest claim), NEW
  `friend_repository` (friends/rivals/played-with/friends leaderboard),
  `notification_repository` (typed + `emit()` = bell doc + push, prefs-gated),
  `auth_repository` (Google sign-in, full onboarding signUp, both-parties
  referral, fcm register).
- `routes.dart` +play/friends/friendCompare/teamDiscover/deletedTeams/help/about;
  `app.dart` navigatorKey + all routes; `main.dart` push init + bg handler.
- `firestore.rules` (opened guest-join surface + new collections) +
  `firestore.indexes.json` (teams/friendships/guests/matches composite indexes).
- `widgets/common.dart` `InitialsAvatar` gained `photoUrl` (network photo).
- `pubspec.yaml` +firebase_messaging, flutter_local_notifications, google_sign_in,
  googleapis_auth, image_picker, http, http_parser, share_plus, url_launcher,
  intl; assets/firebase_admin_key/ declared.

**Phases 1–10 (all screens rewired to the new APIs):** auth splash auto-gate +
16-step signup wizard + Google + forgot + sport-profile; home (@username/OVR/
bell badge/points flash) + Sport Selector + 5-tab nav + drawer + settings/help/
about; teams 4-step create + roles + invites + discovery + disband/restore +
Section-9 stats; friends/rivals/compare/friends-leaderboard; match create (all
settings + team-setup options) + lobby (two codes/pending/admin powers/captain
gating) + guest join + find match; live logging (timing modes/half-time/two
goal buttons/cards/subs/feed/quit-restart/mid-game) + level outcome + read-only
scoreboard; FIFA 3-layer post-match (algorithm MOTM + 24h community vote + guest
conversion + add-friend rows + 24h edit); stats (filters/form/streaks/
contributions/by surface+format) + profile (About/played-with/historical teams)
+ public profile + edit profile; typed notifications; referral (WhatsApp share +
per-referral list).

## 7. Residual known gaps (small; next session)

> ⚠️ **STALE (2026-07-04) — superseded by §2a.** Fixed since: contact sync (§8),
> Google username/referral (§10), rules + indexes deployed (§17), **SHA-1 +
> Google sign-in fully configured (§45–§47)**. Still open: per-team-per-player
> stats, time-window leaderboards, Google `gender`, email change / username
> cooldown, **and the FCM admin key** — which is now the only missing credential.

- **Per-team-per-player stats** (top scorer/assist in a team, per-member
  goals-for-this-team) — no data source; team pages show team-level aggregates.
- **Time-window leaderboards** (weekly/monthly) — labels only; repos aggregate
  all-time (no date-ranged query). Stats screen DOES window personal stats by
  re-reading matches.
- **Google onboarding**: `updateProfile` has no `gender`/`tcAcceptedAt`/
  `referredBy` params, so a *new Google* user's gender + referral aren't
  persisted (email signup path handles all three).
- **Contact sync**: no contacts package — the matching query runs against an
  empty list (plumbing only).
- **Email change / username cooldown** are surfaced but not enforced server-side.
- **Native build config**: Google sign-in needs a SHA-1 in the Firebase console;
  push needs the admin key dropped in assets. Deploy `firestore.rules` +
  `firestore.indexes.json` before first run.

**Verified:** `flutter build apk --debug` → **√ Built app-debug.apk** after enabling
core-library desugaring in `android/app/build.gradle.kts`
(`isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.2`), which
`flutter_local_notifications` requires. All native plugins link.

## 8. Post-build refinements (2026-07-04)

- **Lobby — captains can add AND remove on their own team.** Previously the
  `＋ Add player` button and the player action sheet were admin-only (both teams).
  Now in `lobby_screen.dart` each side's **confirmed captain**
  (`match.captainAUid`/`captainBUid == myUid`) can, **on their own team card**:
  (a) add players (`＋ Add player`), and (b) tap a player row to **remove** them
  (`_playerActions(..., isAdminViewer:false)` shows a **remove-only** sheet — no
  make-captain / move-team, which stay admin-only). A captain can't remove the
  admin or themselves (guarded, so the team isn't stranded without a captain).
  Gate is `amAdmin || amCaptain<side>`. Approve-pending / regenerate-code /
  invite-friend / Start remain admin-only. (Captains are designated by the admin
  via the action sheet, so this composes with the existing captain flow.)
- **Arabic localization + RTL (full).** Added `flutter_localizations` (bumped
  `intl` to ^0.20.2 to satisfy its pin) → automatic RTL layout flip for Arabic.
  Custom lightweight i18n in `lib/l10n/`: `L` (ValueNotifier<Locale> in l10n.dart)
  + top-level `tr('key')`; strings live in per-cluster `tr_*.dart` maps
  (`{key: [en, ar]}`) merged by `L` — this let 8+ parallel agents translate
  without touching a shared file. `MaterialApp` wrapped in
  `ValueListenableBuilder(L.locale)` (rebuilds + flips LTR/RTL live) with the
  Global*Localizations delegates + `supportedLocales [en, ar]`. Arabic glyphs:
  `AppText` styles gained a Cairo `fontFamilyFallback` (Roboto Mono has no Arabic)
  so Arabic renders in Cairo, Latin stays monospace. Locale loads from the user's
  saved `language` on splash; **Settings → Language** is a live en/ar picker
  (persists via updateProfile), and the signup language step calls
  `L.setLanguage(...)`. **Every screen** (~30) localized to EN + MSA Arabic across
  8 clusters (common/nav/drawer/role/result seeded in tr_common; auth ~150,
  teams ~128, match ~150, live ~157, profile ~131, social 67, home 46, misc 33
  keys). Untranslated fallbacks degrade to English gracefully. NOTE: the first
  agent sweep was interrupted by a session limit mid-screen; a second completion
  sweep finished wiring the screens (the tr_*.dart maps had largely survived).
  `flutter analyze` clean project-wide, `flutter test` 8/8.
- **Native Material AppBar on all pages (replaces custom in-body back buttons).**
  `YnoScaffold` gained AppBar support: `appBarTitle` / `appBarActions` /
  `appBarLeading` / `showBackButton` → renders a flat wireframe `AppBar` (zero
  elevation, black icons, condensed-uppercase title, 1px hairline underline) with
  the platform back button. All ~25 pushed screens + the 4 non-home tabs were
  converted: in-body `ScreenHeader`/`BackChip`/stacked back rows deleted, header
  actions (Share, +, Edit, Save, Mark-all-read, Manage, drawer hamburger) moved
  into `appBarActions`, `SafeArea(top:false)`, body top padding ~12. Bottom-bar
  tabs (play/stats/community/profile) use `showBackButton:false`; live_match /
  match_outcome / post_match use `showBackButton:false` (self-controlled nav);
  wizards (signup, team_create, football_profile) use `PopScope` so the native
  back rewinds a step. **Untouched:** home (rich custom dashboard bar), splash,
  welcome. `flutter analyze` clean project-wide, `flutter test` 8/8.
- **UI polish sweep (top padding + back buttons).** Across all ~30 screens
  (5 parallel agents): reduced the outer scroll/column TOP padding to 4 and
  trimmed oversized (≥20) header spacers to 12 — screens were sitting too low.
  Back-button rule by nav type: the **5 bottom-bar tabs** (home, play, stats,
  community, profile) had their back arrow **removed** (they're top-level
  destinations — play/stats used `ScreenHeader(showBack:false)`, profile dropped
  its `BackChip`; home/community already had none). Every **non-bottom-bar**
  screen now has a top-left back control (added `BackChip(maybePop)` to
  teams_screen, guest_join, live_scoreboard which were missing one; settings
  BackChip now `maybePop()` instead of routing to home). Entry screens (splash,
  welcome) intentionally have no back; live_match / match_outcome keep their
  self-controlled End/Home navigation (no back mid-flow). `flutter analyze`
  clean project-wide.
- **Deactivated accounts hidden across discovery.** In addition to the global
  leaderboard: `UserRepository.search` and `findByPhones` now filter out
  `deactivated` users, and `public_profile_screen` shows a "Profile unavailable —
  this account is currently deactivated" state instead of the profile (own view
  still shows). (Friends leaderboard still lists deactivated friends — minor.)
- **Community → Contacts tab (contact-based friend discovery).** New third tab
  in `community_screen.dart`. "Find friends from contacts" requests
  `FlutterContacts.requestPermission(readonly:true)`, reads device contacts,
  normalises each number (`_normalise`: strip spaces/dashes, digits, +digits,
  UAE 0→+971), matches against registered players via
  `UserRepository.findByPhones` (contacts never stored — lookup only), drops self
  + existing friends, and lists matches with an **Add** button
  (`FriendRepository.sendRequest`). Added `flutter_contacts` dependency +
  `READ_CONTACTS` (AndroidManifest) + `NSContactsUsageDescription` (iOS plist).
  Caveat: matching is best-effort on the stored `phone` string format (no E.164
  normalisation at sign-up yet). This **replaces** the friends_screen mocked
  empty-list contact sync for real discovery.
- **Friend match invites already work (confirmed).** Lobby admin "Invite a
  friend" lists the admin's friends (`FriendRepository.friendUids`) and sends an
  in-app `matchInvite` notification (`emit`, route `Routes.lobby`, arg matchId) →
  friend gets the bell + push and taps to open the lobby. So the flow "make
  someone a friend (via search/contacts) → invite them to a match → they get an
  in-app notification" is fully in place. (Invite stays admin-only per spec:
  friends-only in-app invites; non-friends join by code.)
- **Settings — Deactivate account (temporary, ≤ 1 month).** `AppUser` gained
  `deactivated` + `reactivateAt`. `UserRepository.deactivate(uid, days:)` (days
  clamped 1–30) sets the flags + `deactivatedAt`; `reactivate(uid)` clears them.
  Settings → Account → "Deactivate account" opens a duration sheet (7 / 15 /
  1 month) → deactivates + signs out → welcome. **Login reactivation:**
  `login_screen._proceedAfterLogin()` (both email + Google paths) auto-reactivates
  once `reactivateAt` passes, otherwise shows an "Account deactivated until <date>
  — Reactivate now?" dialog (Reactivate → home; Not yet → sign out). Deactivated
  accounts are filtered out of the global leaderboard (`watchTopUsers`,
  client-side). NOTE: broader hiding (search / friends leaderboard / public
  profiles) is a follow-up; only the global board is filtered so far.
- **Settings — "Delete all my data" (Danger Zone).** New destructive action:
  `AuthRepository.deleteAllData()` wipes the user's profile doc + subcollections
  (notifications, playedWith), friendship edges (`friendships` where users
  arrayContains uid), removes the user from everyone who follows them, deletes
  teams they **own** / removes them from teams they're only a member of, then
  deletes the Firebase Auth account (falls back to sign-out if it needs a recent
  login). Best-effort per section; user ends signed out → routed to welcome.
  UI: `settings_screen.dart` Danger-Zone row → `_DeleteDataDialog`, whose Delete
  button is **locked for a 10-second backward countdown** ("Delete (10)"→"Delete")
  before it can be confirmed. Allowed by existing rules (all writes are
  signed-in). Note: match records the user played in are shared history and are
  left intact (their profile is gone, so stats no longer resolve to a live user).
- **OVR confirmed as spec-required, not removed.** OVR (0–99) is explicitly in the
  doc — Section 2 (Home → Centre Stage) and Section 8/12 as a headline profile
  stat. Computed in `AppUser.ovr` (`models.dart`): base **40** for new players,
  then `+ goalsPerMatch×12 (≤30) + winRate×0.25 (≤25) + totalMotm×3 (≤20) +
  matchesPlayed×0.5 (≤14)`, clamped 0–99. Maps to the doc's factors (goals/match,
  win rate, MOTM, consistency/activity, base). **Deviation:** the doc lists
  "average rating" as a factor, but the final spec replaced the old 1–5 star
  ratings with the **Community Award vote** (Section 7), so no average-rating
  number exists — that factor is folded into **Recognition** (`totalMotm` =
  algorithm-MOTM + community-award counts).

## 9. App restructure — nav / Matches / Profile (2026-07-09)

Reworked the primary navigation and screen structure per product decisions
(user-confirmed this session).

- **Bottom nav → 4 tabs + centre Create button.** `bottom_nav.dart` rewritten.
  `enum NavTab { home, matches, community, profile }` (dropped `play`/`stats`).
  Layout: **Home · Matches · [＋ CREATE] · Community · Profile**. The raised
  centre `_CreateButton` (flat outlined square) calls `openCreateMatch()` — it
  is an action, not a tab (no selected state).
- **Sport selector removed entirely.** Football is the only live sport, so the
  ESPN-style sport grid is gone: **deleted `play_screen.dart`**, dropped
  `Routes.play` + `NavTab.play`. The create-match flow now goes straight to
  football match creation (still gated on the one-time football profile).
- **New `lib/widgets/match_actions.dart`** — single source of truth for two
  flows, shared by Home, the Matches page, the nav centre button and the drawer:
  `openCreateMatch(ctx)` (football-profile gate → `matchCreate`) and
  `showJoinByCodeSheet(ctx)` (the join-by-code bottom sheet, lifted verbatim out
  of `home_screen`). NOTE: `showYnoToast` lives in `widgets/header.dart`, not
  `common.dart`.
- **New `lib/screens/matches_screen.dart`** (`Routes.matches`, bottom-nav tab).
  Lists the signed-in player's matches from `watchUserMatches(uid)`, split into
  **Ongoing** (live/lobby) and **Played** (ended/abandoned). Top row: a live
  search field (`YnoTextField` + controller listener; filters team names /
  location / format / surface) plus two 50×50 outlined action squares —
  **＋ create** (`openCreateMatch`) and **🔑 join-by-code** (`showJoinByCodeSheet`).
  Tapping a card routes by status (live→live, lobby→lobby, ended/abandoned→
  post-match).
- **Stats page removed; folded into Profile.** **Deleted `stats_screen.dart`**,
  dropped `Routes.stats`. `profile_screen.dart` rewritten as a **StatefulWidget**
  that now carries the *entire* Section-8 breakdown (ported `_WindowStats` +
  `_computeWindow` + time-window logic). Layout is compact + collapsible:
  header (smaller avatar) → Points/OVR → **stats block** (All/Month/Week
  `SegmentedTabs`; always-visible match-record grid + form row; **collapsible**
  Scoring / Assists / Recognition sections incl. goals-by-surface/format +
  streaks) → collapsible Match history (expanded by default) / Teams /
  Played-with / About. New private `_Expandable` widget = wireframe
  `SectionLabel` header + chevron; deep sections start collapsed to keep it tight.
- **Home unchanged in layout**, two behaviour tweaks: the big "يلا نلعب" button
  and the "Join with code" button now call `openCreateMatch` / `showJoinByCodeSheet`
  (was `Routes.play` + a local `_joinByCode` that is now deleted). **Side drawer**
  "Create a Match" item → action calling `openCreateMatch` (was `Routes.play`).
- **Community unchanged** — the Contacts tab already does exactly the requested
  flow (permission → read contacts → normalise → `findByPhones` → drop self +
  accepted friends → list matches WITH phone numbers + Add button). Verified
  `READ_CONTACTS` (AndroidManifest) + `NSContactsUsageDescription` (iOS) are
  declared. Left as-is. Caveat unchanged: matching is best-effort on the stored
  `phone` string (no E.164 normalisation at sign-up).
- l10n: added `nav.matches`, `nav.create`, and a `matches.*` cluster to
  `tr_common.dart` (EN + AR). Kept `nav.play`/`nav.stats` keys (still referenced
  as the Stats section label + Community label inside profile).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` → **8/8**.

## 10. Signup simplification + OVR removal (2026-07-09)

Cut onboarding from a 14-step wizard to a single page, moved position-setup to
Home, and removed OVR entirely (user-confirmed decisions this session).

- **Single-page sign up** (`signup_screen.dart` fully rewritten). One form:
  **full name · email · password (≥8) · optional referral code**, plus a
  one-tap **Continue with Google** and an implicit "By creating an account you
  agree…" consent line (the separate T&C/privacy steps are gone). On success →
  `pushNamedAndRemoveUntil(Routes.home)`; the celebration "done" screen is gone.
  Dropped from onboarding: username, DOB, gender, language step, photo, T&C step
  (language now inferred from the active locale at signup; photo/DOB/gender
  editable later in Edit Profile).
- **Referral is validated inline.** Debounced lookup via
  `UserRepository.findByReferralCode` → shows Checking / ✓ Valid / ✗ Not found;
  a non-empty code must resolve to a real user before Create/Google proceed
  (`_referralBlocks`). Only a validated code is passed on. Both-parties +10 award
  is unchanged (`AuthRepository._applyReferral`).
- **@username is auto-generated** (per user decision). New
  `AuthRepository._generateUniqueUsername(first,last,email)` — lowercase alnum of
  the name (fallback: email local-part → 'player'), appends a short `randomCode`
  suffix until `usernameLower` is free. `signUp`'s `username` param is now
  optional (auto-gen when omitted); `signInWithGoogle({referralCode})` now also
  auto-gens the handle, applies referral, sets foot=Right + tcAcceptedAt for new
  Google users (closes the old "new Google user has no username/referral" gap).
  Editable anytime in Edit Profile (already had username availability + cooldown).
- **Preferred foot defaults to `Right`; skill dropped from onboarding.** Both
  `signUp` and `signInWithGoogle` seed `preferredFoot: 'Right'`.
  `UserRepository.completeSportProfile` relaxed: `{required position, foot='Right',
  String? skill}` (skill only written if provided). Foot & skill stay editable in
  Edit Profile (chip pickers already there).
- **Position asked on Home after signup.** `football_profile_screen.dart` reduced
  to a **position-only** picker (foot/skill steps + progress bar removed) → calls
  `completeSportProfile(position:)`. `home_screen.dart` converted to a
  **StatefulWidget**: when the loaded user has no position and
  `!sportProfileDone`, it post-frame-pushes `Routes.footballProfile` once per
  mount (`_maybePromptPosition`). The existing create-match gate
  (`openCreateMatch` → footballProfile when `!sportProfileDone`) still works as a
  backstop.
- **OVR removed everywhere** (no calc, no display): deleted `AppUser.ovr`
  (`models.dart`); Home centre-stage OVR badge → replaced with the player's
  **position** chip (shown when set); Profile Points/OVR row → **Points only**
  (full-width); `public_profile` grid OVR tile → **Goals**; `friend_compare`
  dropped the avg-rating/OVR row; `help` dropped the "What is OVR?" FAQ. Removed
  keys `profile.ovr`/`profile.ovrRating`/`home.faqOvrQ`/`home.faqOvrA`
  (`social.avgRating` left unused, harmless). Tests updated (dropped the two
  `u.ovr` expectations).
- New l10n (`tr_auth`): `auth.signupSub`, `auth.fullNameLabel/Hint`,
  `auth.pwMin8`, `auth.referralChecking/Valid/Invalid`, `auth.consent`
  (reused `auth.or`, existing email/password/referral/position keys).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` → **8/8**.

## 11. Real UI design — wireframe → YNO brand (2026-07-09)

Removed the lo-fi wireframe skin and restored the **actual brand design** from
`.claude/design/YNO App.html`: a modern **dark** theme with a **volt-green**
accent and **Barlow / Barlow Condensed** type. Done centrally through the theme
layer + shared widgets, so all ~35 screens re-skinned at once (many screens —
e.g. welcome — were originally authored for this design and just looked
monochrome under the wireframe palette).

**Palette (`theme/app_colors.dart`), extracted from the design bundle:**
- bg `#0A0D0B`, bgDeep `#060807`; surfaces `#13181A` / `#1B2225` / `#252D30`
  (stepped for depth); borders `#232B2E` / `#35403F`.
- text `#F1F4F2` / `#8B948F` / `#5B635E`.
- **accent volt-green `#C6FF3A`** (+ `#A6E800` deep); `ink` = `#0A0D0B`
  (text/icons ON the accent fill).
- semantic win `#3DE27A` / loss `#FF4D5E` / gold `#FFC53D` / cyan `#38E0E0`.
- `*Glow(o)` helpers now return real translucent accent washes (were transparent).

**Type (`theme/app_text.dart`):** `barlow()` → Barlow, `condensed()` → Barlow
Condensed, `semiCondensed()` → Barlow SemiCondensed, `label()` → Barlow w700
tracked-out. Removed the wireframe weight-clamp (heavy display weights restored).
Cairo Arabic fallback kept.

**Theme (`theme/app_theme.dart`):** `ThemeData.dark`, volt-green ColorScheme,
Barlow text theme, real accent-tinted ripples (splash/highlight restored),
rounded cards (16) / dialogs (18), progress indicator = accent, light status-bar
icons.

**Widgets un-flattened:**
- `buttons.dart` — PrimaryButton = **filled volt-green, rounded 14, accent glow**
  (`glow` default now true), disabled → muted; Secondary = surface2 + border,
  rounded; Back/IconChip rounded, IconChip badge → red dot; real InkWell ripples.
- `common.dart` — InitialsAvatar **circular** (+ optional gradient ring
  primary→cyan); TagChip = pill (rounded-100); SurfaceCard honours `radius` +
  `gradient` again, InkWell ripple on tap; SegmentedTabs selected segment =
  **filled volt-green pill** (animated); StatTile rounded.
- `inputs.dart` — fields rounded 14 on surface2, focus border = accent;
  SelectableRow selected = accent border + faint accent tint + accent check dot.
- `yno_scaffold.dart` — **radial accent glows re-enabled** (paints the caller's
  `glow` list + a faint ambient top volt wash); AppBar dark with hairline.
- `bottom_nav.dart` — centre create button = **filled volt-green rounded square
  with glow** + accent CREATE label; active tab already accent via palette.
- `header.dart` — toast → rounded pill on surface2 with elevation.
- Inline: home points-earn flash `#178A2B` → `AppColors.win`; referral keeps the
  WhatsApp brand green `#25D366` (intentional).

Only screen-level colour that stays hardcoded: WhatsApp green (brand) + the green
"O" / accent already reference `AppColors.primary`.

**Verified:** `flutter analyze` → **No issues found!**; `flutter test` → **8/8**.

## 12. Home polish + softer corners + motion (2026-07-09)

Visual/interaction polish, focused on Home plus app-wide softening & animation.

- **New `widgets/motion.dart`** — two reusable primitives:
  - `Pressable` — springs a child to 0.96 scale while pressed (tactile feel).
  - `FadeSlideIn` — one-shot fade + slide-up entrance with an optional `delay`
    (for staggered cascades). AnimationController-based.
- **Home (`home_screen.dart`)**:
  - **Header lifted / more breathing room**: content top padding 12, header→centre
    gap 2→22, header row top pad 8→12. Avatar 42→44; unread dot recoloured to the
    **volt accent** (was near-white).
  - Centre profile avatar now uses the **gradient ring** (volt→cyan); @handle 28→30;
    position chip → rounded **pill** on surface2.
  - "يلا نلعب" CTA → rounded-24 gradient card with a faint accent glow, wrapped in
    `Pressable`; the Arabic wordmark now renders in the **volt accent**.
  - Points badge → rounded pill (was sharp).
  - Sections wrapped in staggered `FadeSlideIn` (0 / 90 / 180 ms) for an entrance
    cascade.
- **App-wide softening** (shared widgets): PrimaryButton/SecondaryButton radius
  14→**18** and both now spring on press (`AnimatedScale` via `onHighlightChanged`,
  keeping ripple); SurfaceCard default radius 16→**20**; StatTile 14→**18**;
  Back/IconChip 13→**15**; inputs (FieldBox/YnoTextField/SelectableRow) 14→**16**.
- **Verified:** `flutter analyze` → **No issues found!** (tests unchanged, still 8/8).

## 13. Device-screenshot fixes: soft corners, spacing, motion (2026-07-09)

Acting on real device screenshots the user pasted. Three systemic issues fixed
across the whole app.

- **ROOT-CAUSE FIX — the "big empty gap under the header".** `YnoScaffold`
  wrapped body content in `Center`, which **vertically centres** any short
  scrollable screen (a `SingleChildScrollView` shrink-wraps under loose
  constraints), so My Teams / Create Team / Community floated in the middle.
  Changed `Center` → `Align(alignment: Alignment.topCenter)` — content now
  top-aligns under the AppBar everywhere; tall/`Expanded` screens are unaffected.
- **Sharp corners eliminated app-wide.** The wireframe era left ~140 inline
  `BoxDecoration(border: Border.all(...))` boxes with no radius across 30 screens.
  Swept them all: **16** for cards/rows/inputs/empty-states, **12** for
  badges/small icon buttons, **100** for text pills, **4** for thin progress
  segments. Left `shape: BoxShape.circle` and directional `Border(top/bottom:)`
  dividers alone. Method: home/matches/community + the small auth/help/about/
  splash/football-profile/signup screens done by hand; the other ~24 screens by
  **5 parallel general-purpose agents** (distinct file sets, identical ruleset),
  then verified centrally.
- **Shared-widget softening bumped** (from §12): buttons 18, cards 20, tiles 18,
  chips 15, inputs 16.
- **Motion everywhere** via `widgets/motion.dart` (`FadeSlideIn`, `Pressable`):
  staggered fade-slide entrances on section groups and list rows across all
  screens; buttons/CTAs spring on press. Agents correctly kept animations OFF
  frequently-rebuilding widgets (live-match ticker, post-match vote streams,
  lobby pending area) so they don't re-trigger every tick.
- **Filler text trimmed** (conservative): removed Community's "frame view note"
  line. Agents kept functional hints/CTAs.
- **Misc brand touches:** team-create step progress bar recoloured to the volt
  accent (was near-invisible dark-on-dark); match-create selected chips/tiles get
  a faint `primaryGlow` fill; settings + friends toggles restyled as proper
  volt-green pill switches; live/lobby status badges use accent when live.
- **Verified:** `flutter analyze` → **No issues found!** across the project;
  `flutter test` → **8/8**.

## 14. Saved-team identity + challenge-by-code (2026-07-14)

Two product asks: (a) a pre-existing team always plays under its own name and is
editable only on the Teams page; (b) a user can challenge a friend's team on the
match-creation screen using that team's code.

Half of this already existed (saved-team chips per side, `createMatch` already
took `teamAId`/`teamBId`, `TeamModel.inviteCode` + `findByInviteCode` were live).
What was added:

- **BUG FIXED — team id/name could diverge.** The side name field was a plain
  editable `YnoTextField`, and nothing cleared `_teamAId`/`_teamBId` when it was
  retyped — so a match could persist name "Rovers" while crediting stats to team
  "Wanderers" via `applyMatchStats`. Now picking a saved team **locks** the name.
- **Team names are locked in match creation.** `YnoTextField` gained a
  `readOnly` param (dims text, uses `surface` fill, no cursor). In
  `match_create_screen._teamSide`, `readOnly: selId != null` + a lock icon
  trailing + a "Saved team — name locked" hint. Tapping the lock or the selected
  chip calls the new `_unlinkTeam(side)` → back to free text.
- **Teams are now editable** (they never were — `TeamRepository` had no rename at
  all; name/badge were write-once at creation). Added
  `TeamRepository.updateTeam(teamId, {name, presetBadge, badgeUrl, badgePublicId})`
  (only writes the fields passed; keeps `nameLower` in sync) and
  `isNameAvailable(name, {exceptTeamId})` so a team doesn't collide with its own
  name on rename. `teams_screen.dart` team cards gained an **edit pencil**
  (`t.canManage(uid)` only) → bottom sheet (name + preset badge, mirroring the
  create wizard). Choosing a preset badge clears an uploaded `badgeUrl`.
- **Challenge a team by code** (side B only, `_challengeBlock` in
  match_create). Code → `findByInviteCode` → locks side B to that team
  (`_teamBId` + name) and shows a volt-accent card. Guards: unknown/disbanded
  code, your own team (you're a member — use the chips), team already on side A.
  Picking a saved team or quick-creating one for side B clears the challenge.
- **Captain is notified.** On create, `NotificationRepository.emit` fires to
  `challenged.captainUid ?? challenged.ownerUid`, category `matchInvite` (a
  `kPhoneNotifCategories` member, so it pushes when the target opted into match
  alerts), route `Routes.lobby` + matchId → they tap through and bring players in.
  `emit` swallows its own errors, so a notify failure can't strand the match.
- **Team code is now shareable.** `team_profile_screen` invite-code card gained a
  `share_plus` share icon next to copy (was clipboard-only, so "friend sends me
  his code" meant a manual paste). Fixed the misleading
  `teams.inviteCodePermanent` label — it said "Permanent" right next to a
  Regenerate button; now "Share to invite players or get challenged".
- **Decisions taken:** reuse `inviteCode` for challenges (no schema change; a
  challenge is a read-only lookup and grants no membership) — caveat:
  **Regenerate on team-manage invalidates any challenge code a friend holds**.
  Challenge = label + notify captain; it does NOT auto-add the opponent roster
  (nobody is put in a match they didn't opt into — they join via the lobby).
- l10n: +11 `teams.*` and +14 `match.*` keys (EN + AR).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` → **8/8**.
  NOT yet exercised against live Firebase (no emulator here) — the challenge
  lookup + captain push need a real device run.

## 15. Challenge handshake — accept/decline + captain gating (2026-07-14)

Turned §14's fire-and-forget challenge into a real two-sided handshake. Product
decisions this pass: **captain, owner as fallback** (a team with no captain
assigned is still reachable); **decline unlinks side B but keeps the match**;
**popup once per app open, banner persists until answered**.

- **Match doc gained a challenge block** (`models.dart` `MatchModel`):
  `challengedTeamId`, `challengedTeamName`, `challengeCaptainUid`,
  `challengeStatus` ('pending' | 'accepted' | 'declined'; null = no challenge)
  + getters `challengePending` / `challengeAccepted`. Parsed in `fromDoc`.
  `createMatch` takes the three new params and stamps `challengeStatus: 'pending'`.
- **`MatchRepository`**: `watchPendingChallenges(uid)` (`challengeCaptainUid` ==
  uid AND `challengeStatus` == 'pending', sorted client-side like
  `watchUserMatches`); `acceptChallenge(matchId, {uid, name, position})` →
  `joinMatch` on side B (`joinedVia: 'challenge'`) + sets `captainBUid` (so the
  §8 captain powers in the lobby compose) + status accepted + notifies the admin;
  `declineChallenge(matchId, {uid})` → status declined, clears `teamBId`, resets
  `teamBName` to 'Team B', notifies the admin. Both re-check
  `challengeCaptainUid == uid` server-read-side so only the captain can answer.
- **`firestore.indexes.json`** +1 composite on `matches`
  (`challengeCaptainUid` + `challengeStatus`) — **must be deployed** or the home
  stream throws. `firestore.rules` needed NO change (`matches` writes only
  require auth, and the captain is signed in).
- **Home popup + banner** (`home_screen.dart`): a `StreamBuilder` on
  `watchPendingChallenges` wraps the existing user-stream column.
  `_maybePopChallenge` auto-opens the newest unanswered challenge once per mount
  (`_poppedChallenges` Set + `_challengeDialogOpen` guard, post-frame like
  `_maybePromptPosition`; the position prompt wins if both are due).
  `_showChallengeDialog` = first `showDialog` on home — volt-accent, shows
  "{teamA} want to play \"{their team}\"" + format/surface/location, with
  **Accept** (→ joins + routes to lobby) / **Decline** / **Decide later**.
  `_challengeBanner` = persistent volt-outlined "⚡ … challenged your team ›" row
  under the top bar; tapping it reopens the dialog. Both vanish reactively once
  answered (the stream drops the match).
- **The challenge notification** now routes to `Routes.home` (not lobby) so the
  tap lands where Accept/Decline lives, and goes only to
  `captainUid ?? ownerUid`. Category stays `matchInvite` (pushes when the target
  opted into match alerts).
- **Invite code is now captain-only.** It was previously rendered to **every**
  viewer of team profile — including non-members of a *private* team
  (`_header` had no conditional). Now `_header(team, canManage)` gates the whole
  code card behind `canManage` (owner|captain) + a "Only you (captain) can see
  this code" hint. team_manage was already manager-gated.
- l10n: +9 `match.*` (dialog/banner/toasts) and +1 `teams.*` key (EN + AR).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **11/11** (+3 new Firebase-free tests covering the challenge state machine).

### Caveats / follow-ups
- **Deploy `firestore.indexes.json` before the next run** — the new composite
  index is required by the home pending-challenge stream.
- **Code gating is client-side only.** `firestore.rules` still allows
  `allow read: if true` on `teams`, so `inviteCode` is readable by anyone
  querying Firestore directly. The UI no longer leaks it; the rules still do.
  Real fix = move the code to a subcollection or gate reads by membership.
- Regenerating a team's invite code still invalidates any challenge code a
  friend holds (accepted trade-off of reusing one code — see §14).
- An admin whose challenge is declined can't re-challenge from the lobby (side B
  just returns to free text); they'd share code B or create a new match.
- Not yet exercised against live Firebase — no emulator here.

## 16. Invite code made a real secret — rules + schema (2026-07-14)

Closed the §15 caveat properly. **Firestore rules gate documents, not fields** —
so as long as `inviteCode` sat on a world-readable `teams/{id}` doc, no rule
could hide it. The client gate added in §15 stopped the *app* showing it; anyone
querying Firestore directly still got it. The code had to physically move.

**New shape:**
- `teams/{id}` — **`inviteCode` field removed entirely** (also dropped from
  `TeamModel`, so the leak is structurally impossible, not just rule-guarded).
  Still world-readable for profiles/discovery/scorecards.
- `teams/{id}/private/meta` → `{inviteCode}` — **read+write: owner|captain only**
  (`teamManager(tid)` rule fn mirrors `TeamModel.canManage`). This is where the
  captain's UI reads its own code from.
- `teamCodes/{CODE}` → `{teamId}` — doc id **IS** the code. `allow get: if
  signedIn()` + **`allow list: if false`**. That split is the whole design:
  possessing a code resolves it, but the collection cannot be enumerated or
  reverse-queried. Writes are manager-gated so nobody can repoint a code.

**Code changes:**
- `TeamRepository`: `_private(id)` + `_code(code)` refs; `_writeInviteCode`
  (writes both docs); `watchInviteCode(teamId)` (stream for captain UI);
  `ensureInviteCode(teamId)` (self-heals teams created before the move — no-op
  otherwise); `findByInviteCode` is now a single doc **get** keyed by the code
  (was a `where('inviteCode', ...)` query — that query is now impossible by rule);
  `regenerateInviteCode` publishes the new code doc then deletes the old one.
  `createTeam` writes the team doc FIRST (the rules `get()` it to resolve manage
  rights), then the code docs.
- `team_profile_screen._inviteCode` + `team_manage_screen._inviteCodeCard` are
  now `StreamBuilder<String?>` on `watchInviteCode`; manage self-heals via
  `ensureInviteCode`.
- **`firebase.json` gained the missing `firestore` block** (`rules` + `indexes`)
  — `firebase deploy --only firestore:rules` would NOT have worked before, it
  had only the flutterfire `flutter` block. Also added an `emulators` block.

**Verified for real — `test/firestore_rules/invite_code_rules.test.mjs`:**
18/18 adversarial assertions pass against the **Firestore emulator**, incl.
member/stranger/anon cannot read the code, team doc carries no `inviteCode`,
stranger-with-code CAN resolve it, **nobody can list or reverse-query
`teamCodes`**, stranger cannot repoint/delete a code or overwrite the private
doc, captain can rotate. Run it with:
  `cd test/firestore_rules && npm install`
  `cd ../.. && npx firebase-tools@13.35.1 emulators:exec --only firestore \`
  `  --project yno-rules-test "node test/firestore_rules/invite_code_rules.test.mjs"`
(Local JDK is 17; current firebase-tools needs Java 21+, hence the `@13.35.1`
pin. Drop the pin once a JDK 21+ is installed.)
`flutter analyze` → No issues found!; `flutter test` → 11/11.

### Follow-ups
- **Deploy both `firestore.rules` AND `firestore.indexes.json`** before the next
  device run (rules for the new collections; the index for §15's home stream).
- **Teams created before this pass** have a dead `inviteCode` field on the team
  doc and no `private/meta` or `teamCodes` entry. `ensureInviteCode` mints a
  fresh one when a manager opens team-manage, so they self-heal — but the OLD
  code stops working. The app has never run against live Firebase, so there is
  probably nothing real to migrate.
- Regenerating a code still invalidates any code a friend holds (unchanged, and
  now the retired `teamCodes` doc is actively deleted).

## 17. Rules + indexes DEPLOYED to live Firebase (2026-07-14)

`firebase deploy --only firestore:rules,firestore:indexes --project yno-app-e96f5`
→ **Deploy complete.** Rules compiled and **released to cloud.firestore**;
indexes deployed to the (default) database.

Verified after the fact with `firebase firestore:indexes --project yno-app-e96f5`:
**7 composite indexes live** (teams ×2, friendships ×1, guests ×2, matches ×2),
including the new `challengeCaptainUid` + `challengeStatus` index that §15's
home pending-challenge stream requires. Index builds are async but the DB is
effectively empty, so no backfill wait.

This clears the "deploy before first run" blocker that had been open since §6.
Deploying account: huzm651@gmail.com. Rules are versioned — previous rulesets
are rollback-able from the Firebase console if needed.

**Still open:** the app itself has never been exercised against live Firebase
(no emulator/device here) — the challenge lookup, captain push and home popup
are verified only by `flutter analyze`, the 11 unit tests, and the 18 emulator
rules assertions. A real `flutter run` remains the highest-value next step.

## 18. One "Edit team" screen; owner-only identity (2026-07-14)

Consolidated team editing. **Most of what was asked already existed but was
fragmented** across three surfaces; this pass unifies it. Decisions: **one Edit
Team screen**, **identity is owner-only**, **adding stays invite-only**.

Already true before this pass (no change needed): the **owner could always see
and share the code** (`canManage` = owner|captain, and the deployed
`teamManager()` rule matches); **delete existed** (owner-only disband, type-the-
name confirm, 6-month restore); **add/remove players existed** (invite + guest +
remove).

- **`team_manage_screen` is now the single Edit Team screen** (`appBarTitle` →
  `teams.editTeam`). Gained an owner-only **identity card** at the top: name
  field + preset badge grid + **PNG upload** (mirrors the create wizard's
  `ImagePicker` → `StorageService.uploadImage(folder:'team_badges', pngOnly)`),
  a **live badge preview** (shows the pending choice, not the saved one), and a
  Save button enabled only when dirty. Name uniqueness re-checked via
  `isNameAvailable(name, exceptTeamId:)`. Preset and upload are mutually
  exclusive — saving clears the loser to `''` so the badge builders fall through.
  Non-owner managers (captains) still see the read-only name header + roster.
- **Controllers live in State, not the builder.** The screen sits under a
  `StreamBuilder`, so a locally-built `TextEditingController` would wipe the
  owner's typing on every roster/invite snapshot. `_seedIdentity(team)` seeds
  once (`_identitySeeded` guard).
- **`teams_screen` pencil now routes to `Routes.teamManage`** (was a local
  rename/re-badge sheet). **Deleted** `_editTeam` (~5.2k chars), the duplicate
  `_presetBadges` list, and the buttons/header/inputs imports it needed. The
  §14 quick sheet is gone — one place to edit, as decided.
- **Permissions tightened per decision:** name/icon are now **owner-only**
  (the deleted pencil sheet let captains rename). Captains keep roster, invites,
  guests and the code; roles/privacy/delete were already owner-only.
- **`YnoTextField` gained `onChanged`** (needed to re-evaluate the Save button's
  dirty state as the owner types).
- **Copy fixes:**
  - `teams.inviteCodeCaptainOnly` said *"Only you (captain) can see this code"* —
    **wrong for an owner who isn't captain**. Now "Only the owner and captain…".
  - The delete action said **"Disband"** while disbanded teams live under a
    screen called **"Deleted Teams"**. Aligned the user-facing copy to
    delete/DELETED (EN + AR) — `disbandTeam`, `disband`, `disbanded`,
    `disbandedWord`, `disbandedTeamsLabel`, `noDisbanded`. **Keys and repo
    method names (`disband`/`restore`) unchanged** — copy only.
  - team_profile's manage IconButton → edit icon + `teams.editTeam` tooltip.
  - Removed 4 now-orphaned keys (`teams.manage`, `teams.manageTeam`,
    `teams.editTeamHint`, `teams.badgeReplacesUpload`).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **11/11**; Firestore rules suite → **18/18** (re-run after the repo edits).

### Known gaps
- `TeamRepository.addMember` is still **dead code** (zero call sites) — adding is
  invite-only by decision. Left in place rather than deleted.
- `_sheetOption`'s `danger` flag is inert (`color: danger ? AppColors.txt :
  AppColors.txt` — both branches identical), so "Remove from Team" has no
  destructive styling. Pre-existing; not touched.
- Remove-member and Leave still have **no confirmation** (unlike delete).
  Pre-existing.

## 19. Destructive-action safety in Edit Team (2026-07-14)

Fixed the two rough edges flagged at the end of §18.

- **`_sheetOption`'s `danger` flag was inert** — `color: danger ? AppColors.txt :
  AppColors.txt`, both branches identical, so "Remove from Team" rendered
  identically to "Make Captain" despite already passing `danger: true`. Now
  `danger ? AppColors.loss : AppColors.txt`.
- **Remove-member and Leave had no confirmation** (they fired immediately on
  tap; only delete-team was guarded). Added a shared `_confirm({title, message,
  confirmLabel})` → `Future<bool>` dialog on `team_manage_screen`, modelled on
  `live_match_screen._confirm`. Remove now names the player and the team;
  Leave names the team. Both no-op on cancel.
- **Destructive confirms are now red across the teams surface.** The app had no
  destructive-button convention — the existing delete-team confirm used the
  default volt-green, the same colour as "Save changes", so it gave no warning.
  The new dialogs use `PrimaryButton(color: AppColors.loss)` and the delete-team
  confirm was switched to match (1 line), so all three agree. Contrast checks out:
  `ink` #0A0D0B on `loss` #FF4D5E ≈ 7.6:1.
  **Deliberately NOT touched:** settings' "Delete all my data" dialog uses a
  different pattern (neutral `OutlinedButton` + 10s countdown) — app-wide
  destructive-red is a bigger call and wasn't asked for.
- Delete-team keeps its stronger type-the-team-name gate on top of the colour.
- l10n: +7 `teams.*` keys (EN + AR) — `remove`, `removePlayerTitle/Body`,
  `leave`, `leaveTeamTitle/Body` (reused `common.cancel`).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` → 11/11.
  Styling/contrast reasoned about, not seen on a device — still no emulator here.

## 20. Destructive-action convention made universal (2026-07-14)

§19's red confirms were extended app-wide. An audit of all ~23 destructive
actions found `team_manage_screen` was **the only file in the app that coloured
destruction at all** — deleting your entire account and discarding a live match
were both styled neutral or volt-green (the same green as "Save changes").

**The convention now has one home** — `kDangerColor` in `widgets/buttons.dart`,
documented there with the rule:

> Red = **loses data**: deletes, removes a person, irreversibly discards.
> NOT merely "negative" — declining an invite, rejecting a join request, signing
> out and booking a red card are normal-flow. Reversible-by-design actions
> (deactivate account, unfollow) stay neutral too.

- `PrimaryButton` + `SecondaryButton` gained `danger: true` (overrides `color`;
  Primary fills + glows red, Secondary tints label + border). Disabled danger
  buttons still read as disabled (`surface3`), not red.
- **Applied** (7 sites): settings delete-all-data (row label **and** the confirm
  button — the "Danger Zone" had zero red in it); team_manage remove-member
  (option + confirm), leave, delete-team; live_match **discard everything** and
  **restart** confirms; lobby **remove from lobby**; post_match **delete goal**
  (was visually identical to REASSIGN next to it).
- `live_match._confirm` gained a `danger` param rather than a blanket change —
  it also backs **end match** and **save-abandoned**, which preserve the match
  and stay green. Same for team_manage's `_confirm`.
- **Deliberately NOT red** (per the rule, each considered): sign out (settings +
  drawer), deactivate account (reversible by design), cancel/decline invites and
  friend requests, decline pending join, unfollow, decline challenge, red card
  (a match event, already has 🟥), both code regenerations, quit-abandon (saves),
  end match.
- team_manage migrated off `color: AppColors.loss` to `danger: true`; its
  `_sheetOption` uses `kDangerColor`. **No destructive action uses a bare
  `AppColors.loss` any more** — the only remaining bare uses are legitimately
  non-destructive: LIVE status dots, the scoreline loss colour, and the IconChip
  unread badge.
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **18/18** — including a NEW `test/danger_button_test.dart` that pumps the real
  widgets and asserts the actual rendered fill/label colour (danger → red,
  default → volt, danger overrides `color:`, disabled → `surface3`, and
  `kDangerColor != primary`). The convention is machine-checked, not just prose.

### Known gaps (flagged, not fixed — colour was the ask, not confirmations)
Several destructive actions are still **one-tap with no confirmation**: remove
from lobby, delete a goal, revoke a pending team invite, both code
regenerations. They are now at least red. Adding confirms is a separate call.

## 21. Confirmations on the remaining one-tap destructive actions (2026-07-14)

Closed the §20 gap. Also **de-duplicated the dialog**: `live_match` and
`team_manage` each had their own near-identical `_confirm`, which is exactly how
they drifted apart (live-match's confirm button stayed green while
team-manage's went red).

- **New `lib/widgets/confirm.dart` → `showConfirm(context, {title, message,
  confirmLabel, danger})`** — the app's one yes/no dialog. Both local `_confirm`
  helpers are now thin shims delegating to it (live_match keeps its uppercase
  title styling). Documented there: **`danger` is a SEPARATE axis from
  confirming** — an action can deserve a confirmation without losing data
  (regenerating a code), and those keep the default volt button.
- **Confirmations added** (5 previously one-tap actions):
  | Action | file | danger? |
  |---|---|---|
  | Remove player from lobby | `lobby_screen` | **yes** (red) |
  | Regenerate match code | `lobby_screen` | no (volt) |
  | Delete a goal | `post_match_screen` | **yes** (red) |
  | Revoke a pending team invite | `team_manage_screen` | no (volt) |
  | Regenerate team invite code | `team_manage_screen` | no (volt) |
  Each names the specific target ("Sam will be removed from the lobby", the
  scorer's name on a goal). The code-regen copy spells out the real consequence:
  every code already shared — to join OR to challenge — stops working.
- Still deliberately unconfirmed (normal-flow, per the §20 rule): declining a
  join request / friend request, unfollow, red card, end match.
- l10n: +8 `teams.*`, +5 `match.*`, +2 `live.*` keys (EN + AR).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **24/24**. New `test/confirm_dialog_test.dart` drives the real dialog: it
  renders title/message/label, confirm→true, cancel→false, and — the one that
  matters — **barrier-dismiss returns false, not null**, so an accidental tap
  outside can never read as consent.

### Still not verified on a device
Everything this session is analyzer-, unit- and widget-test-verified plus 18
emulator rules assertions. The app itself has still never run against live
Firebase (no emulator/device here). That remains the highest-value next step.

## 22. Team captaincy, guest accounts, join-by-code team-or-match (2026-07-17)

Four connected membership asks. **Much of the plumbing already existed**
(`assignCaptain`, `createPlayerAccount`, `addMember`, `findByInviteCode`); this
pass wires it into the product flows. User decisions this session: team guests
become **full roster members** with real accounts; the **match** add-guest flow
is **aligned** to also create real accounts (email now required).

- **Owner is captain at creation.** `TeamRepository.createTeam` now sets
  `captainUid: ownerUid` (was `null`). Safe because `TeamModel.roleOf` checks
  `ownerUid` first, so the owner still renders as OWNER and later transferring
  captaincy (`assignCaptain` demoting `roles[owner]`) can't corrupt the display.
- **Make-captain chip.** `team_manage_screen._memberRow` gained a volt-outlined
  "Make Captain" chip on each non-owner, non-current-captain row (owner-only
  viewer) → `_promoteCaptain` → `showConfirm` (non-danger, promoting doesn't
  lose data) → `assignCaptain`. The existing member-sheet option is kept as a
  duplicate shortcut.
- **Team guest → real member.** `team_manage_screen._addGuestSheet` now takes
  **name + required email**, calls `AuthRepository.createPlayerAccount`
  (pw `123456`, secondary FirebaseApp — already existed) then
  `TeamRepository.addMember`, so the guest is a claimable roster member. The old
  name-only `TeamRepository.addGuest` / `watchGuests` / team_profile guest list
  are now **vestigial** (nothing writes them) — left in place, harmless.
- **Match add-guest aligned.** `lobby_screen._addPlayer` Guest tab now requires
  an **email** and calls `MatchRepository.addNewPlayer` (createPlayerAccount +
  joinMatch) instead of the accountless `addGuestPlayer`. `guest_join_screen`
  (a person self-joining by code, no auth) is untouched — different flow.
- **"We already have your data" popup.** New `UserRepository.findByEmail`
  (`users` is world-readable, so it resolves pre-sign-in). `signup_screen`
  checks it before `signUp`: an existing **auto-created** account →
  `showAccountExistsDialog` reveals the default password `123456` and offers
  **Log in** (→ `Routes.login` with `{email, password}` args) / **Use another
  email**; a **real** account shows the same dialog but **never** reveals the
  password. `login_screen.didChangeDependencies` reads the `{email, password}`
  route args and prefills. `showAccountExistsDialog` is a **top-level** function
  (extracted from the State) precisely so the "reveal password only when
  auto-created" contract is unit-testable.
- **Home join-by-code asks team or match.** `showJoinByCodeSheet(context,
  {allowTeam = true})` gained a `SegmentedTabs(Match | Team)` header. Match =
  unchanged (`findByCode` → `joinMatch`). Team = `findByInviteCode` (single
  keyed `get`) → guards (unknown/disbanded → toast, already a member → toast) →
  `addMember` → toast + open team profile. Home / drawer / nav use the default;
  `matches_screen` passes `allowTeam: false` to stay match-only.
- No Firestore **rules or index** changes: `users` read is `allow read: if
  true`, `teams` write needs only `signedIn()`, `teamCodes` `get` needs
  `signedIn()`. No new dependencies.
- l10n: +`teams.*` (makeCaptainConfirm, guest email/account/error, alreadyMember,
  joinedTeam), +`match.*` (email/guestEmailHint/guestAccountHint/
  guestEmailRequired), +`auth.*` (accountExists title/auto/real bodies, logIn,
  useAnotherEmail), +`home.*` (joinByCode/joinTeam prompt/hint/noTeamFound),
  +`common.match`/`common.team` (all EN + AR).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **27/27** (+3 in new `test/account_exists_dialog_test.dart`: auto-created
  reveals the default password, a real account never does, Log in navigates).

### Still not verified on a device
Same standing caveat — no emulator/device here, so the new challenge/guest/join
flows are analyzer- + test-verified only. A real `flutter run` (creating a team,
adding a guest, claiming the account, joining a team by code) is the next step.

## 23. Super-admin web dashboard (2026-07-17)

**The web build is now a super-admin control panel, not the player app.**
`main.dart` runs `AdminApp` when `kIsWeb` (mobile/desktop still run `YnoApp`).
The panel lists every user and team from live Firebase and can delete a single
user, a single team, all users, all teams, or the entire database. Internal
owner tool — English-only, not localised.

**Access model (user-decided this session):** *no login screen.* `AdminApp` →
`_AdminGate` **silently signs into a dedicated super-admin account**
(`huzm651@gmail.com`) using credentials baked into the build, **creating the
account on first run** if it's missing (`createUserWithEmailAndPassword`). That
auth session is what makes Firestore deletes work and satisfies the new
`isSuperAdmin()` rule. ⚠️ **The web build must be kept private / never hosted at
a public URL** — anyone with the built files can extract the credentials. Creds
live in `lib/admin/admin_config.dart` (`kSuperAdminEmail` /
`kSuperAdminPassword` — **change the password before first run**).

**New files under `lib/admin/`:**
- `admin_config.dart` — super-admin email/password constants + the security
  warning. `kSuperAdmins` list kept in sync with the rules allowlist.
- `admin_app.dart` — `AdminApp` (own `MaterialApp`, `AppTheme.dark`) +
  `_AdminGate` (silent auto-login, loading spinner, and a clear error screen
  with Retry if email/password auth is disabled or the baked password no longer
  matches an existing account).
- `admin_repository.dart` — `watchUsers`/`watchTeams` (reuse `AppUser.fromDoc`/
  `TeamModel.fromDoc`), `counts()` (aggregation `.count()` with a full-read
  fallback), and deletes: `deleteUser` (doc + notifications/playedWith),
  `deleteTeam` (doc + private/invites/guests + its `teamCodes` entry),
  `deleteAllUsers`, `deleteAllTeams` (+ sweep all `teamCodes`),
  `deleteAllMatches` (each match + subs players/pending/goals/cards/subs/votes/
  ratings), and `deleteAllData` (users, teams, teamCodes, matches, guests,
  friendships, rivalries — best-effort per section).
- `admin_dashboard.dart` — summary count chips + **Users / Teams / Danger Zone**
  tabs. Users: search (name/@username/email) + cards (avatar, email, phone,
  points, matches, auto-created/deactivated badges) + red delete via
  `showConfirm(danger:true)`. Teams: cards (members, owner, public/private,
  disbanded) + red delete. Danger Zone: three nuclear buttons, each gated by a
  **type-`DELETE ALL`-to-confirm** dialog.

**Rules (`firestore.rules`) — added `isSuperAdmin()`** (email allowlist
`huzm651@gmail.com`) and OR'd it into the only two paths the admin couldn't
already touch as a signed-in user: `teams/{tid}/private/{doc}` (read+write) and
`teamCodes/{code}` (**list** — was `if false`; the panel needs enumeration to
sweep codes — plus create/update/delete). Everything else only needs
`signedIn()`, which the admin is. **Keep the rules allowlist in sync with
`kSuperAdmins`.**

**Client-SDK limitations surfaced in the UI copy:** deleting a user removes
their Firestore data but **not** their Firebase Auth login (only the Admin SDK
can); the super-admin account has no `users/{uid}` doc so it never appears in the
list and survives a full wipe (panel stays usable).

**Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
**27/27**; **`flutter build web` → √ Built build\web** (the whole admin path
compiles for web). Not yet run live.

## 24. Team profile/permissions + dual challenge notify (2026-07-17)

Refines the team detail experience and the challenge handshake.

**Team profile (view — `team_profile_screen.dart`):**
- **Guests show inline in the roster with a GUEST badge** (per user choice: one
  list, not a separate section). Guests are auto-created members, so
  `_memberRow` now shows `badge.guest` when `user.autoCreated`. The old
  name-only `_guests` section (fed by the vestigial `watchGuests`) was
  **removed**.
- **Invite code stays in VIEW mode** (was already shown to managers). Captains
  see/copy/share it (they're `canManage`); **owners additionally get a
  regenerate ↻** control here (`_regenerateCode`, `showConfirm`, owner-only) —
  regenerate moved out of the edit screen.

**Edit team (`team_manage_screen.dart`) — permissions per user:**
- **Captains can now edit name/icon** (identity card gated on `canManage`, not
  `amOwner`; reverses the §18 owner-only decision). Both owner and captain still
  add members (invite/guest).
- **Removing members is owner-only.** The per-member `⋯` actions button and the
  Remove option are gated to `amOwner` (captains manage identity + roster
  additions, not removals).
- **Invite code card removed from the edit screen** (it's in view mode now);
  `_inviteCodeCard`/`_codeCardBody` deleted, `flutter/services` import dropped.

**Challenge → notify BOTH owner and captain, first answer clears the rest:**
- `MatchModel` gained `challengeRecipientUids` (owner + captain, deduped);
  `createMatch` stores it; `match_create_screen` computes the recipient set and
  **emits a bell/push to each** (was only `captainUid ?? ownerUid`).
- `watchPendingChallenges(uid)` now queries `challengeRecipientUids
  arrayContains uid` + `challengeStatus == pending`, so BOTH see the home
  popup/banner. Because it keys off `challengeStatus`, the first accept/decline
  flips the status and the challenge **drops out of everyone's stream at once**.
- `acceptChallenge`/`declineChallenge` accept any recipient
  (`_canAnswerChallenge`, with a legacy `challengeCaptainUid` fallback) and call
  `_clearChallengeNotifs` → new `NotificationRepository.clearByArg(uid, matchId,
  category)` deletes the lingering bell notification for the OTHER recipients.
- `firestore.indexes.json` +1 composite (`challengeRecipientUids` CONTAINS +
  `challengeStatus`) — **must be deployed**. Rules unchanged.
- l10n: `match.challengeWillNotify` copy → "owner & captain get notified".

**Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
**27/27**. Not yet run against live Firebase.

### ⚠️ Deploy the new index before the next run
`firebase deploy --only firestore:indexes --project yno-app-e96f5` — the home
pending-challenge stream throws without the `challengeRecipientUids` composite.

## 25. Team roster auto-fills the match line-up + minus button (2026-07-17)

Picking a saved team for a side — or a challenged team accepting — now brings
that team's **whole roster into the match** instead of showing an empty "Add
player" list.

- **New `MatchRepository.addTeamRoster(matchId, teamId, side)`** — batch-adds
  every team member as a `MatchPlayer` on `side`, skipping anyone already in the
  match (checked via `getPlayers`). `joinedVia: 'team'`; auto-created members
  keep `isGuest: true` (so they still get the GUEST badge). Reuses
  `TeamRepository.getTeam` + `UserRepository.getUsers`.
- **Wired in:**
  - `createMatch` — side A roster added when `teamAId` is set; side B roster
    added when `teamBId` is set AND it's **not** a pending challenge
    (`challengedTeamId == null`). A pending challenge waits for accept.
  - `acceptChallenge` — after the captain joins, the challenged team's whole
    roster is added to side B (the captain is skipped as already-in).
- **Lobby minus (−) button** (`lobby_screen._playerRow`): each player row now has
  a leading red − for managers (admin any side; captain their own side), hidden
  for the admin row and for a captain's own row. Tapping it confirms
  (`showConfirm`, danger) then `removePlayer` — **removes from THIS match only**,
  never the saved team. The `＋ Add player` button (guest/registered) stays for
  adding extras. Reused existing `match.removePlayerQ/Body/remove/removed` keys +
  `kDangerColor`.
- No schema/rules/index changes. `flutter analyze` → **No issues found!**;
  `flutter test` → **27/27**. Not yet run live.

## 26. Profile privacy + actionable team invites + add-friend from community (2026-07-17)

Filled the real gaps in the friends/community/invite flow. Much already existed
(friend request send/accept/decline in `friends_screen` + public profile;
`TeamRepository.acceptInvite/declineInvite`); the missing pieces:

- **Profile privacy (public/private).** New `AppUser.profilePublic` (default
  **true** — user-chosen). `UserRepository.updatePrefs` persists it; **Edit
  Profile** gained a Privacy toggle (`_privacyToggle`). `public_profile_screen`
  now **gates stats + match history** via `_gatedContent`: shown to self, to
  everyone when public, and to accepted friends when private (via
  `watchFriendship`); otherwise a "🔒 This profile is private — send a friend
  request" card (the Add Friend button already sits above in `_actions`).
  ⚠️ **Client-side gate only** — `users` docs are still world-readable by rule,
  so the stats aren't hidden from a direct Firestore query (same class of
  caveat as the old invite-code; a true fix needs rules/data changes).
- **Team invites are now answerable.** `acceptInvite` had **zero UI call sites**
  before. `notifications_screen` now renders **Accept / Reject** on a
  `teamInvite` notification (arg = teamId): Accept → `acceptInvite` (joins +
  notifies owner), Reject → `declineInvite` (notifies owner), both then
  `NotificationRepository.remove` the notification. New `remove(uid, id)`.
- **Add a friend from Community.** The **Global** leaderboard rows gained an
  Add / Pending / ✓ pill (`_friendPill`) driven by a `watchMyEdges` stream —
  send a request without leaving the list. (Contacts tab + profile add-friend
  already existed.)
- **Invite friends to a team.** `team_manage` invite sheet now shows a **friends
  quick-list** (`_friendsInviteList`, minus current members) before you search,
  so inviting people you know is one tap → `inviteMember`.
- l10n: +`profile.*` (privacy toggle + private-card copy), +`teams.reject/
  inviteAccepted/inviteRejected/inviteFriends` (EN + AR).
- No rules/index changes (all writes are signed-in; friendships/notifications
  already allowed). `flutter analyze` → **No issues found!**; `flutter test` →
  **27/27**. Not yet run live.

## 27. Match-create simplified: collapsible options + floating Create (2026-07-17)

The create-match screen was one long scroll of ~10 sections. Trimmed to the
essentials up front, everything else behind a toggle, and the CTA is now
floating.

- **Only the essentials show by default:** match name, **Team setup** (A/B +
  saved teams + challenge), and **Format**. A match can be created with just
  these — everything else has a sensible default.
- **"More options" collapsible** (`_moreOptionsToggle`, `bool _showMore` — false
  by default): Surface, Location, Date/Time, Visibility, Joining method, Timing,
  and Admin mode now live inside `if (_showMore) ...[ … ]` with an animated
  chevron header. Nothing about creation logic changed — the same state fields
  keep their defaults whether or not the panel is opened.
- **Create is a floating button now.** The inline bottom `PrimaryButton` was
  replaced by a volt-green `FloatingActionButton.extended` (check icon +
  "Create Match", spinner while busy) so it's always reachable. Added ~90px
  bottom padding so it never covers the last field.
- **`YnoScaffold` gained `floatingActionButton` + `floatingActionButtonLocation`
  passthrough params** (optional; null for every other screen).
- l10n: +`match.moreOptions` / `match.moreOptionsSub` (EN + AR). The old
  `match.createOpenLobby` key is now unused (harmless). FAB reuses
  `match.createMatchTitle`.
- UI-only — no schema/rules/index changes. `flutter analyze` → **No issues
  found!**; `flutter test` → **27/27**. Not yet run live.

## 28. Post-refactor UI tweaks + l10n bug fix (2026-07-18)

A batch of smaller polish items and one real localisation bug.

- **Match-create Create button → full-width docked button.** Replaced the
  `FloatingActionButton.extended` (§27) with a full-device-width `PrimaryButton`
  in `YnoScaffold.bottomNav` (safe-area padded, `bg` background), and swapped the
  **✓ tick for a ＋** icon. Still always reachable while scrolling.
- **Edit Team: name + icon are locked for everyone.** Removed the entire
  identity-editing card (name field, preset badges, PNG upload, Save) from
  `team_manage_screen` — it now shows the team name as a **read-only header**.
  Deleted `_identityCard`/`_livePreviewBadge`/`_pickBadge`/`_saveIdentity` +
  identity state + the `dart:io`/`image_picker`/`storage_service` imports +
  `_presetBadges`. (`TeamRepository.updateTeam`/`isNameAvailable` are now dead
  code — left in place, harmless.) **Create Team** gained a 🔒 note on the name
  step: "name & icon can't be changed after creation" (`teams.identityLockedNote`,
  EN + AR).
- **Home coins/points badge → Refer & Earn.** The 🪙 points pill now routes to
  `Routes.referral` (was `Routes.profile`). The top-left avatar still opens the
  profile.
- **Community → Global hides the current user.** `_globalSection` filters out
  `_uid`, so the board only shows other players (ranks stay sequential). The
  Friends leaderboard still includes you (by design).
- **Profile page trimmed:** removed the **points box** (`_pointsOvr`), the
  **skill-level chip** (header now shows only position ⚡ + preferred foot 🦶),
  and the **team-badge row** in the header (the "MF" circle). Teams still appear
  in the profile's dedicated Teams section.
- **🐛 l10n fix — bottom bar & side drawer didn't switch to Arabic.** Root cause:
  `tr()` reads the locale imperatively (re-resolves only when a widget rebuilds),
  and both `YnoBottomNav` and `YnoDrawer` were instantiated as **`const`** — a
  const widget is the same canonical instance every rebuild, so Flutter skipped
  re-running its `build()` on locale change and the labels stayed frozen. Removed
  `const` from `YnoBottomNav(...)` (home/matches/community/profile) and
  `YnoDrawer()` (home/profile). Other selectors (position/foot/skill chips,
  match surface/format, language sheet) were already fine.
- `YnoScaffold` gained `floatingActionButton` + `floatingActionButtonLocation`
  passthrough (§27) — still present but the match-create screen now uses
  `bottomNav` instead.
- Every step verified: `flutter analyze` → **No issues found!**; `flutter test`
  → **27/27**. All UI-only — no schema/rules/index changes, nothing to deploy.

### Deploy state confirmed in sync (2026-07-18)
Audited before this batch: local `firestore.indexes.json` (8 composite indexes)
== deployed (verified via `firebase firestore:indexes`); `firestore.rules`
(with `isSuperAdmin()`) deployed; every multi-field query in the repos maps to a
deployed index. **Nothing pending.** Only standing gaps (not deploys): private
profiles are a client-side gate (users docs are world-readable by rule), and the
rules remain prototype-permissive overall.

## 23b. Admin follow-ups (unchanged)

### ⚠️ Follow-ups before using it
- **Change `kSuperAdminPassword`** in `lib/admin/admin_config.dart` before the
  first web run.
- **Deploy the rules:** `firebase deploy --only firestore:rules --project
  yno-app-e96f5` (deletes on team codes/private will be denied until then).
- Ensure **Email/Password** sign-in is enabled in the Firebase console (it is —
  the app uses it) or the silent login errors out.
- Run it: `flutter run -d chrome`. Not yet exercised against live Firebase.

### 23a. Deletes now report the truth (2026-07-17)
First live use: user ran "delete all data", saw "Done", but the app + their
account were untouched. Root cause: **every delete helper swallowed errors**
(`catch (_)`), so a permission-denied wipe looked successful. Also confirmed
`AuthRepository.ensureProfile` is **never called**, so a deleted user doc does
NOT get re-created on login — i.e. surviving data means the delete never
executed server-side. Fixes:
- `admin_repository.dart` deletes now return a **`DeleteResult`** (`deleted` /
  `failed` / `firstError`) instead of swallowing; `_wipe` records per-doc
  outcomes and reads with `Source.server`; `counts()` uses
  `AggregateSource.server` — so the summary reflects the real server state, not
  a cache.
- `admin_dashboard.dart` shows **"signed in as <email>"** (or a red "NOT SIGNED
  IN") under the title, and bulk deletes pop a **result dialog** ("Deleted X /
  Failed Y" + the first error + the rules-deploy hint) so a permission failure
  is impossible to miss.
- Same-project confirmed (web/android/ios all `yno-app-e96f5`) — not a
  wrong-project issue. Likely real cause is un-deployed `isSuperAdmin()` rules
  and/or the admin session — the surfaced error will now say which.
- **Reminder:** deleting data never removes Firebase **Auth logins** (client SDK
  can't); those are removed in the console (Authentication) or via Admin SDK.
- Verified: `flutter analyze` clean, `flutter test` 27/27, `flutter build web`
  √ Built.

## 29. Sticky live match + own-team-only rosters + 6h vote (2026-07-18)

Turned the match flow into a real shared, sticky live session and locked
per-team control to each team's owner/captain. User scenario: A creates a
match, adds their club as Team A, challenges B's club (Team B). Decisions this
session: **own-team-only roster control everywhere** (not just challenges);
**creator + BOTH captains can log live events for either team**.

- **Lobby — own-team-only roster management.** New pure rule
  `MatchModel.canManageSide(uid, side)` (models.dart, unit-tested): Team A is run
  by the creator (admin) or captain A; Team B by captain B, OR by the creator
  ONLY while Team B has no captain yet (a plain pickup match). So once B's captain
  is set — e.g. a challenge is accepted (`captainBUid = userB`) — **the creator
  can no longer add/remove Team B players**, and B's captain can't touch Team A.
  `lobby_screen`: `_teamCard`/`_playerRow`/`_playerActions` now key off
  `_canManage(match, side)` (delegates to the model). Make-captain is offered only
  to the creator on a side they still control; **move-between-teams** only while
  the creator controls BOTH sides (no opposing captain has claimed one) — moving
  touches both rosters. Previously the admin could manage BOTH teams outright.
- **Start button is creator-only.** `_startBar`: non-creators now see just a
  "waiting for the host" line — the Start control (and the old "only admin can
  start" toast on a visible button) is gone for everyone but `adminUid`.
- **Live match is shared + sticky.** New global `ActiveMatchGate` (app.dart,
  wraps every route via `MaterialApp.builder`) + a `_RouteTracker`
  `NavigatorObserver`. It watches `MatchRepository.watchMyLiveMatch(uid)` (a match
  in `playerUids` with `status == live`, filtered client-side off the existing
  arrayContains query — **no new index**) and, from ANY screen, pushes
  `Routes.live` when the creator starts and **again after an app
  kill/relaunch** — until the match stops being live. It stands aside on
  auth/splash routes and while the match flow (live/outcome/post-match) is already
  on top, so it never double-navigates or fights the screens that own that flow.
- **Live screen — captains can log, creator ends.** ⚠️ **The "captains can log"
  half was REVERSED in §34 — logging is now creator-only.** The rest of this
  bullet (creator-only End/settings/approvals/half-time) still holds.
  `live_match_screen`:
  `MatchModel.canLogLive(uid)` (creator + captain A + captain B) gates the
  goal/card/sub action area (was admin-only; others saw a read-only note). The
  **End Match** button, the settings gear (restart/quit/extend), mid-game pending
  approvals and the "start second half" control stay **creator-only** (captains
  see a half-time "waiting for the host" panel). `PopScope(canPop:false)` blocks
  the system back button while live. When the match goes ended/abandoned the
  screen **auto-moves every non-creator to the post-match scorecard** (the creator
  drives their own End/quit nav); if the creator discards the match the doc
  vanishes and everyone still on the screen is sent home. Both via a one-shot
  `_left` guard.
- **Community vote window → 6 hours** (was 24h). `finalizeMatch` sets
  `voteCloseAt` to now+6h; the vote-invite notification copy now says 6 hours. The
  admin scorecard **edit** window is a separate concern and stays 24h
  (`editableUntil`). The post-match card already renders the countdown dynamically,
  so it just shows ~6h now.
- **l10n:** `live.viewerNote` reworded (host + captains), new `live.halfWaitingHost`
  (EN + AR). `match.onlyAdminStart` is now unused (harmless).
- **No schema / rules / index / deploy changes.** All new reads/writes are by a
  signed-in user (rules already allow `matches` writes to any signed-in user, so
  captains logging goals is permitted), and the live-match query reuses the
  existing single-field arrayContains index.
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **35/35** (+8 in new `test/match_permissions_test.dart` covering canManageSide
  own-team-only + canLogLive). Not yet exercised against live Firebase (standing
  caveat — the auto-navigate/sticky/redirect behaviour wants a real two-device run).

### Known follow-ups
- **Admin-only-mode creator** (a match where the creator doesn't play) isn't in
  `playerUids`, so the sticky gate won't re-grab them after a restart. The common
  path (creator adds their club → they're a player) is covered; admin-only mode is
  an edge and the `_start` push still navigates them at kickoff.
- Accountless link-guests (`g_…`) aren't signed-in auth users, so the gate doesn't
  apply to them — they use the existing read-only scoreboard/guest flow.

## 30. Web admin: real email/password login (2026-07-18)

Replaced the silent auto-login on the web super-admin build (§23) with an actual
**email + password login screen**. Credentials: **huzaifa@admin.com / 123456**.

- **`admin_config.dart`**: `kSuperAdminEmail` → `huzaifa@admin.com`,
  `kSuperAdminPassword` → `123456` (bootstrap password). Security comment updated
  (there's a login now; `123456` is a placeholder to change before real use).
- **`admin_app.dart` rewritten**: `_AdminGate` is now a `StreamBuilder` on
  `authStateChanges()` — dashboard when a `kSuperAdmins` account is signed in,
  otherwise the new `_AdminLogin` (styled email + password fields, show/hide
  password, inline errors, spinner). On submit it signs in; on the first run it
  **bootstraps (creates) the account ONLY when the entered email+password exactly
  match the configured super-admin** (so the account can't be created with a
  typo'd password); any non-allowlisted account is signed straight back out with
  "not authorised". The old silent `_ensureSuperAdmin` gate is gone.
- **`admin_dashboard.dart`**: added a **Sign out** button to the AppBar
  (`FirebaseAuth.signOut()`) — without it, persistent auth would trap you in the
  dashboard and the login would never reappear.
- **`firestore.rules`**: `isSuperAdmin()` allowlist `huzm651@gmail.com` →
  `huzaifa@admin.com` (kept in sync with `kSuperAdmins`).
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **35/35**; `flutter build web` → **√ Built build\web**.

### ⚠️ Deploy + first-run notes
- **Deploy the rules** before using the panel:
  `firebase deploy --only firestore:rules --project yno-app-e96f5` — until then
  the super-admin's privileged deletes (team private docs / teamCodes) are denied
  under the OLD email.
- First login with `huzaifa@admin.com` / `123456` creates the Auth account. The
  **old** `huzm651@gmail.com` super-admin account still exists in Firebase Auth
  but is no longer allowlisted (rules or panel) — remove it in the console if
  desired.
- Email/Password sign-in must be enabled in the Firebase console (it is).

## 31. Registered players are INVITED (popup), not added (2026-07-18)

"Add player → Registered" no longer force-adds someone to a match. It now sends
them an **invite** they must accept — mirroring the team-challenge popup. Flow:
A creates a match (no challenge), Add player → Registered → picks B → B gets a
home popup "A invited you to join {match}" → Accept → B joins the side A chose
and lands in the lobby → if A makes B captain of Team B, B can then add/invite
others (existing own-team-only rule). Decline just clears the invite.

- **Match doc gained invite fields** (`models.dart` `MatchModel`): `invitedUids`
  (array, the field the invitee queries by) + `invites` (map uid → {team, name,
  byName}). Getters `invitedTeam(uid)`, `inviterName(uid)`, `inviteeName(uid)`,
  `invitedForSide(side)`. Parsed in `fromDoc`.
- **`MatchRepository`**: `invitePlayer(matchId, {uid,name,team,byName})` writes the
  arrays + emits a `matchInvite` bell/push (route `/home`, so the tap lands where
  Accept/Decline lives). `watchPendingMatchInvites(uid)` =
  `invitedUids arrayContains uid` filtered client-side to lobby/live (no composite
  index). `acceptMatchInvite(...)` → `joinMatch` on the invited side
  (`joinedVia:'invite'`) + clears the invite. `declineMatchInvite(matchId, uid)`
  clears it (also used by the creator to cancel).
- **Lobby** (`lobby_screen`): the Registered tab tap now calls `invitePlayer`
  (was `joinMatch`) + toasts "Invite sent to X"; the row action reads "Invite".
  Invited players render as muted **INVITED** rows under their side, with a − for
  managers to cancel the invite. (The Guest tab is unchanged — it still creates a
  real account and adds immediately.)
- **Home** (`home_screen`): a second `StreamBuilder` on
  `watchPendingMatchInvites` drives a 📩 popup (`_showInviteDialog`, Accept & Join
  / Decline / Later) + a persistent 📩 banner, same once-per-mount +
  banner-persists behaviour as challenges. Accept routes to the lobby (or live if
  the match already started); the challenge and invite popups defer to each other
  so only one shows at a time.
- l10n: +`match.invitedTag/inviteCancelled/inviteDialogTitle/inviteNotifBody/
  joiningSide/inviteAcceptJoin/inviteDeclined/inviteBannerOne/inviteBannerMany`
  (EN + AR); reused `inviteSentTo`/`inviteBtn`/`challengeDecline`/`challengeLater`.
- **No rules / index / deploy changes**: `matches` write is `signedIn()` (so both
  A's invite write and B's accept write are allowed) and the invite query is a
  single-field arrayContains.
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **39/39** (+4 in `test/match_permissions_test.dart` covering invitedTeam /
  inviter+invitee names / invitedForSide). Not yet run against live Firebase.

### Note
- The separate admin **"Invite a friend"** flow (`_inviteFriend`) still just emits
  a notification routed to the lobby (unchanged) rather than using this new
  invite/accept popup — a candidate to unify later.

## 32. Draft matches (2-day TTL) + old profile pic deleted from Cloudinary (2026-07-18)

Two asks. (a) A created-but-never-started match is a **DRAFT**, shown separately
on the Matches page with a deletion warning and auto-removed after 2 days.
(b) Uploading a new profile picture **deletes the previous one from Cloudinary**.

### Draft matches
- A match sits in `lobby` status from creation until the creator starts it — so
  "draft" needs no new field, it's just `status == lobby`. Backing out of the
  lobby already leaves the doc as a draft (nothing to save).
- **`matches_screen`** now buckets the user's matches into **Ongoing** (`live`
  only — was `live`+`lobby`), **Drafts** (`lobby`), **Played** (ended/abandoned).
  The Drafts section shows a gold ⚠️ warning box ("A draft is deleted 2 days
  after it's created if the match still hasn't started — its data will be
  lost.") and each draft card shows a **DRAFT** badge + a live "⚠️ Deletes in
  Xd/Xh" countdown (from `createdAt + kDraftTtl`) and hides the 0–0 score.
  Tapping a draft still opens the lobby to resume/start it.
- **Auto-delete:** `MatchRepository.sweepStaleDrafts(uid)` (new) deletes the
  user's own `lobby` matches (`adminUid == uid`) created > `kDraftTtl`
  (`Duration(days: 2)`) ago, via `quitDiscard` (removes the doc + subcollections).
  Single-field `adminUid` query + client-side status/age filter → **no composite
  index**. Called from `matches_screen.initState` — there are no Cloud
  Functions, so cleanup is lazy on open (same pattern as `resolveCommunityAward`).
- l10n: +`matches.drafts/draftBadge/draftWarning/draftDeletesIn/draftDeletesSoon`
  (EN + AR). `match.lobbyBadge` is now unused (harmless).

### Old profile picture deletion
- **`StorageService.deleteImage(publicId)`** (new): calls Cloudinary's
  `image/destroy` endpoint, **signed** (SHA1 of `public_id=…&timestamp=…` +
  `apiSecret`) — destroy has no unsigned mode. Added **`crypto: ^3.0.3`** to
  pubspec (was transitive). Best-effort: returns true on `ok`/`not found`, never
  throws.
- **`edit_profile_screen`** tracks `_originalPhotoPublicId` (the picture present
  when the screen opened). On **save**, once the new photo is persisted, the old
  original is deleted from Cloudinary ("save new in that place"). On **re-pick**
  within a session, the just-replaced *unsaved* intermediate upload is deleted
  immediately so it doesn't orphan — the saved original is only removed on save.
- ⚠️ The Cloudinary `apiSecret` is bundled in the client (like the app's other
  keys). Fine for the prototype; destroy should move server-side before launch.

### Verified / notes
- `flutter analyze` → **No issues found!**; `flutter test` → **39/39**;
  `flutter pub get` OK (crypto added).
- Not run against live Firebase/Cloudinary — the draft sweep and the Cloudinary
  destroy call are logic-verified only (destroy is best-effort regardless).
- **Draft cleanup is lazy** (runs when the Matches page opens). If a user never
  reopens Matches, their own stale drafts linger until they do — acceptable given
  the no-Cloud-Functions constraint. A true scheduled purge would need a backend.
- **No Firestore rules/index changes**; nothing to deploy.

## 33. Admin panel: Matches tab (view + delete ongoing/draft) (2026-07-18)

The web super-admin dashboard gained a **MATCHES** tab so the admin can see and
delete matches — including ongoing (live) and draft (lobby) ones.

- **`admin_repository.dart`**: `watchMatches()` (streams all `matches` as
  `MatchModel`) + `deleteMatch(matchId)` → `DeleteResult` (public wrapper over
  the existing `_deleteMatch`, which removes the doc + players/pending/goals/
  cards/subs/votes/ratings).
- **`admin_dashboard.dart`**: tab count 3 → 4 (TabBar now `isScrollable`), new
  `MATCHES` tab. It has the shared search (team/location/format) + **status
  filter chips** (All / Ongoing / Drafts / Played), lists matches newest-first,
  each card showing a coloured status chip (LIVE=volt, DRAFT=gold, FT=dim,
  ABD=red), teams, meta, score/code, created date, and a red delete button
  gated by `showConfirm(danger:true)`. Deleting refreshes the summary counts.
- Reuses the existing `_card`, `_searchField`, `showConfirm`, `DeleteResult`
  and toast plumbing — no new patterns.
- **No rules/index/deploy changes**: admin already had full `matches` read (`if
  true`) and delete (subcollection writes are `if true`, match doc write is
  `signedIn()`), so no `isSuperAdmin()` addition was needed.
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **39/39**; `flutter build web` → **√ Built build\web**. Not yet run live.

## 34. Creator-only live logging · team setup tightened · captain auto-adopt (2026-07-20)

Three connected asks about who controls a match. All user-decided this session.

### (a) Live logging is the creator's alone (reverses half of §29)
`MatchModel.canLogLive` was `admin || captainA || captainB`; it is now
**`adminUid == uid`**. Captains keep their lobby roster powers
(`canManageSide`, unchanged) but no longer log the match.
- `live_match_screen`: `_canLog` deleted — `_isAdmin` now *delegates to
  `canLogLive`* so the screen can't drift from the model. `_actionArea` lost its
  `admin` param and both internal `if (admin)` branches (dead once the whole
  area is creator-gated).
- Non-creators at half-time now see `_halfTimeWaiting()` ("waiting for the host
  to start the second half") instead of the generic viewer note — that panel
  existed for captains in §29 and would otherwise have been orphaned.
- l10n `live.viewerNote` said "Only the match host **and team captains** can log
  events" — now "Only the match host can log goals, cards and subs" (EN + AR).
- **Unchanged, and worth restating:** End Match, the settings gear
  (restart/quit/extend), mid-game join approvals, resuming from half-time and
  Start were already creator-only.

### (b) Match-create team setup: saved teams on side A only, no quick-create
Two problems: your own teams were listed under **both** sides (so you could
field your team against itself), and `＋ New team` minted a **half-configured**
team (name + badge only, bypassing the 4-step wizard's privacy/upload/roles).
- Saved-team chips now render only when `side == TeamSide.a`, and that list
  **excludes `_teamBId`** so a challenged team can't also be picked for A.
- **`＋ New team` removed from BOTH sides**; `_quickCreateTeam` (~120 lines of
  bottom sheet) and the `_badges` emoji list are **deleted**. `team_create_screen`
  is now the single way to create a team — it still uses `createTeam` +
  `isNameAvailable`, so no repo code went dead.
- `_pickTeam(TeamSide, TeamModel)` → `_pickTeam(TeamModel)` (side-B branch was
  unreachable); it also clears a stale challenge to the team being picked.
- Side B is now free text **or** a challenge code. The "opponent has no account
  and no team" case is served by typing a name and building their line-up in the
  lobby — no throwaway team lands in your Teams list.
- Orphaned l10n keys (harmless, left in place): `match.newTeamChip`,
  `match.newTeam`, `match.quickTeamHint`, `match.createTeam`,
  `match.teamNameTaken`, `match.couldNotCreateTeam`.
- ⚠️ **Known gap, deliberately not closed:** a user with **zero saved teams**
  now sees nothing under Team A — no chips, no hint teams exist (`＋ New team`
  used to be the discovery path). They'll type free text, and their own side
  then accrues no team stats. Suggested fix (declined for now): an empty-state
  line under Team A routing to `Routes.teamCreate`.

### (c) A team's captain auto-takes the match armband
`_start` blocks until BOTH sides have a match captain, but nothing bridged
**team** captaincy → **match** captaincy: `createMatch` never set `captainAUid`
and `addTeamRoster` never read `team.captainUid`. So picking your own club still
made you nominate yourself. (Side B was already automatic — `acceptChallenge`
sets `captainBUid` to whoever answered.)
- New **`MatchRepository._adoptTeamCaptain(matchId, team, side)`**, called at the
  end of `addTeamRoster`: if the side has **no** captain yet and the team's
  `captainUid` (**falling back to `ownerUid`**) is a player **on that side**, it
  calls `assignMatchCaptain` (which also sets `MatchPlayer.isCaptain`, so the ★
  badge renders).
- **`addTeamRoster`'s `if (toAdd.isEmpty) return;` was the trap** — the creator
  is already a player from `createMatch`, so a saved Team A often adds *nobody*
  and the method exited before ever looking at the captain. The batch-add is now
  wrapped in `if (toAdd.isNotEmpty)` and the captain step runs unconditionally.
- The `match.captainUid(side) != null` guard is load-bearing: it preserves
  `acceptChallenge`'s "whoever answered runs side B" (it sets `captainBUid`
  *before* calling `addTeamRoster`) and never silently replaces a hand-assigned
  captain.
- Ordering verified: `createMatch` writes the admin's player doc (awaited) before
  `addTeamRoster`, and re-reads the doc after — so the returned model already
  carries `captainAUid`.
- **Still asks for a captain** when: side B is free text (no team), the team's
  captain isn't playing, `adminOnlyMode` (creator isn't a player), or the team
  has neither captain nor owner on that side.

### Verified
`flutter analyze` → **No issues found!**; `flutter test` → **41/41** (+2:
`match_permissions_test.dart` now asserts an opposing captain CAN manage their
side but CANNOT log, and that a captain-who-is-also-creator can). No schema,
rules, index or repo-contract changes — **nothing to deploy**.

### Note on the owner fallback (corrects an in-session claim)
`_adoptTeamCaptain` falls back to `ownerUid` when `captainUid` is null. I said
that only matters for teams created before §22 — **that was wrong**.
`TeamRepository.removeMember` sets `'captainUid': null` when the removed member
was the captain, so a *live* team can lose its captain at any time. The fallback
is load-bearing, not legacy compatibility.

### Not covered by tests
`_adoptTeamCaptain` is Firestore-dependent, so it can't join the Firebase-free
unit suite — logic-verified only, like the rest of the repo layer. **Add to the
first device run:** create a match with a saved team and confirm Start does not
ask for a Team A captain.

## 35. Match creation trimmed: fewer formats, no surface/location/schedule, private-only, 45-min cap (2026-07-27)

Six user-decided cuts to the create-match screen. It's now **name → teams →
format**, with only joining method / timing / admin mode behind "More options".
962 → 781 lines.

- **Formats start at 4v4.** `1v1`/`2v2`/`3v3` dropped; **`Custom` removed** so
  `Unlimited` is the only non-numeric option. List is now
  `4v4·5v5·6v6·7v7·8v8·9v9·11v11·Unlimited`, default `5v5` (unchanged).
  `_formatLabel` collapsed to a one-liner; `match.customPoints` +
  `match.formatCustom` are now orphaned keys (harmless).
- **Surface, location and date/time removed** — picker UI, state and the
  `_surfaceTile`/`_surfaceLabel`/`_durTile` helpers are gone, as is the `intl`
  import (`DateFormat` was only used by the schedule tile).
  ⚠️ **`createMatch`'s `surface` default changed `'Grass'` → `''`** — otherwise
  dropping the picker would have silently stamped every match as Grass.
  The params stay on the repo signature so old matches read back and the
  fields can return without a schema change.
- **Empty surface is now handled at every display site** (they used to hard-code
  `'$format · $surface'` and would have shown a dangling separator): `home_screen`
  ×2, `guest_join_screen`, `post_match_screen._detailLine`. `admin_dashboard` and
  every `location` site were already `isNotEmpty`-guarded. `matches_screen`'s
  search haystack is unaffected.
- **Visibility removed — every match is private** (`isPublic: false`, passed
  explicitly with a comment). You get in by invite or by code.
  **Consequence, handled:** `watchOpenMatches` could only ever return nothing, so
  **`find_match_screen.dart` was deleted** along with `Routes.findMatch`, its
  `app.dart` route + import, the 🔍 drawer item, and the repo query (a comment
  marks the spot). The deployed `status + isPublic` composite index is now
  **unused but left in place** — nothing to deploy, and restoring public matches
  means restoring query + screen together. `drawer.findMatch` is an orphaned key.
- **Duration is a ± stepper, max 45 min** (was 30/60/90 tiles). Default **45**
  (was 60 — out of range now). Tap = 1 minute; **press-and-hold repeats** after
  400 ms at 70 ms/tick, so 45→10 isn't 35 taps. `_stepTimer` is cancelled in
  `dispose` and stops itself at either end. Applies per half in halves mode.
  New key `match.durationMaxHint` (EN + AR); `match.extendClockHint` kept below it.
- **Profile's "Goals by surface" breakdown removed** — no new match can feed it.
  Goals-by-format stays. `UserRepository.applyMatchStats` already guarded on
  `surfaceKey.isNotEmpty`, so an empty surface never pollutes the map.
- `match.moreOptionsSub` reworded ("Surface, timing, visibility & more" →
  "Joining, timing & admin mode").
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **41/41**. No schema, rules or index changes — **nothing to deploy**. Not run
  against live Firebase (standing caveat).

## 36. Orphaned l10n keys pruned — 1041 → 879 (2026-07-27)

Swept every `tr_*.dart` cluster for keys with **zero call sites** and removed
them. 162 keys deleted across 7 files; `tr_live.dart` and `tr_misc.dart` were
already clean.

**Method** (repeatable — rerun it after any screen deletion):
```
# defined
grep -ho "^  '[a-zA-Z0-9_]*\.[a-zA-Z0-9_]*'" lib/l10n/tr_*.dart | tr -d " '" | sort -u
# referenced (any quoted key-shaped literal, not just tr('…') — this is what
# makes it safe for the _trAttr value→key maps in profile/public_profile/edit_profile)
find lib test -name "*.dart" -not -path "lib/l10n/*" -exec cat {} + \
  | grep -o "'[a-zA-Z0-9_]*\.[a-zA-Z0-9_]*'" | tr -d "'" | sort -u
# orphans = comm -23 defined used
```

**Two keys were deliberately kept despite reading as orphans:** `result.win`
and `result.loss` are built at runtime by ``tr('result.$result')``
(`post_match_screen.dart:300` and `:646`) so the literal never appears in the
source. **`result.draw` is only used the same way** — it survived the sweep by
coincidence (it appears as a literal elsewhere). ⚠️ **Any future sweep must
re-check `tr('…$…')` interpolation before deleting** — a plain grep will
happily delete a live string. The only interpolated keys in the app today are
these three.

**What went:** 93 `auth.*` (the entire 16-step signup wizard retired in §10 —
DOB, gender, username, photo, language, terms, privacy, skill, password-strength
meter), 36 `match.*` (surface/location/date-time/visibility from §35, plus the
§34b quick-create-team and `findMatchTitle`/`noOpenMatches` from the deleted Find
Match screen), 14 `teams.*` (the §28 identity-editing card), 11 `common.*`,
5 `profile.*` (incl. `goalsBySurface`), 2 `social.*`, 1 `home.*`. Also deleted 12
section-header comments left pointing at nothing.

**Archived, not lost.** This project has **no git history**, so every removed
entry — both languages, verbatim — was written to
**`.claude/l10n_removed_keys.md`** grouped by file. Restoring a string is a
copy-paste back into its map.

**Verified:** the sweep re-run reports only the two intentional `result.*`
survivors; no key referenced in code is undefined; Arabic text intact (byte-level
edit, no re-encoding). `flutter analyze` → **No issues found!**;
`flutter test` → **41/41**. Nothing to deploy.

## 37. Admin mode as two choices · edit a match from the lobby (2026-07-27)

### (a) Admin mode is now two explicit options
It was **one** `SelectableRow` whose own title/subtitle flipped when tapped — so
the alternative was invisible until you'd already picked it, and "selected" meant
admin-only. Now two rows, exactly like Joining method:
**Playing admin** (`playingAdmin` / `playingAdminSub`) and **Not playing
(referee)** (`adminOnly` / `adminOnlySub`). Default is **Playing admin**
(`_adminOnly = false`, unchanged). Reuses all four existing keys; only
`match.adminOnly`'s copy changed ("Admin-only (referee)" → "Not playing
(referee)", EN + AR) to match the two-way wording.

### (b) The lobby can step back to creation ("page 2 → page 1")
Creation is now a two-step flow **in the backend only — the screens are
untouched**: the same `match_create_screen` runs in a second mode.

- **`MatchCreateScreen` takes an optional `matchId` route argument.** No
  argument = create (every existing entry point — `openCreateMatch`, home,
  nav ＋, drawer — is unaffected). An argument = **edit**: `didChangeDependencies`
  reads it once (`_argsRead` guard), `_loadMatch` prefills every field, the title
  becomes "Edit Match", the docked button becomes ✓ **Save changes**, and
  "More options" starts **open** (they came back for a specific setting).
- **Lobby gained an "✎ Edit match details" button**, creator-only, under
  Invite a friend → `pushNamed(matchCreate, arguments: match.id)`. Saving pops
  back; the lobby streams the doc, so it repaints itself.
- **New `MatchRepository.updateMatchSettings(matchId, …)`** — editable: name,
  free-text team names, format, joining method, timing, duration, admin mode.
  It **refuses unless `status == lobby` and the caller is `adminUid`**
  (`StateError('match-started'` / `'not-admin'`)), since the live screen reads
  these every tick.
  Two settings have side effects, handled in the repo so the screen can't drift:
  - **Joining method** → separate teams mints `codeB` if missing (keeping any
    code already shared); open lobby nulls `codeA`/`codeB` so `codeFor(side)`
    falls back to the master code.
  - **Admin mode** → switching to not-playing deletes the creator's player doc,
    pulls them from `playerUids` **and clears their armband** (a captain who
    isn't playing would block `_start` forever); switching to playing re-adds
    them to side A as `isAdmin`.

### Deliberately NOT editable when editing
- **Saved-team chips and the challenge block are hidden**, and a linked side's
  🔒 is **not tappable** (`canUnlink = !_editing`). Unlinking would let the name
  and `teamAId` diverge again — the exact §14 bug — while the roster is already
  in the match and stats will fold into that team. A note under side B says so
  and points at the lobby. Changing the opponent = manage the line-up there, or
  create a new match.
- **A legacy format keeps its own chip while editing** (`if
  (!_formats.contains(_format)) _format` prepended), so opening this screen on a
  pre-§35 `1v1`/`Custom` match can't silently re-format it. Duration is clamped
  into 1…45 on load for the same reason (old matches were 60/90).

### Verified
`flutter analyze` → **No issues found!**; `flutter test` → **41/41**.
No schema, rules or index changes — **nothing to deploy** (`matches` writes only
require a signed-in user, and the admin check is enforced in the repo).
**Not covered by tests:** `updateMatchSettings` is Firestore-dependent, like the
rest of the repo layer. **Add to the first device run:** edit a match from the
lobby and confirm (1) the code cards change with the joining method, (2)
switching to Not playing removes you from Team A, and (3) switching back puts
you in it.

## 38. Cards & subs removed · pause/resume · restart fixed (2026-07-27)

The live match now logs **goals only**, and the host can stop the clock.

### (a) Substitutions removed
`SubEvent` (models), `_subs`/`watchSubs`/`recordSub` (repo), the 🔁 button and
both `_subOffSheet`/`_subOnSheet` picker sheets, and `_FeedItem.sub` are gone.

### (b) Yellow/red cards removed
`CardEvent`, `CardType`, `cardTypeFrom`, `CardTypeX` (models),
`MatchPlayer.yellows`/`reds` (field, `fromDoc`, `toMap`), `_cards`/`watchCards`/
`recordCard` (repo), the 🟨/🟥 buttons + `_cardSheet` + `_FeedItem.card`
(live screen), the whole **CARDS section** and `_cardRow` on the public
scoreboard, and post-match's **Cards stat tile** + the 🟨n/🟥n line on each
scorecard row. The personal stat block is now Goals · Assists · Points.
- The `cards`/`subs` **subcollections are still swept** by `quitDiscard`,
  `restartMatch` and the admin wipe, so documents written by an older build get
  cleaned up rather than orphaned. Nothing writes them any more.
- 16 orphaned `live.*` keys pruned (archived to `.claude/l10n_removed_keys.md`),
  and two live strings that *named* the removed features were reworded:
  `live.noEvents` ("log a goal, card or sub" → "tap a team to log one") and
  `live.viewerNote` ("goals, cards and subs" → "goals").

### (c) Pause / resume (new)
- **`MatchModel.pausedAt`** (+ `bool get paused`). While set, **every clock is
  read against it instead of "now"** — a new `_clockNow(m)` in both
  `live_match_screen` and `live_scoreboard_screen`. That one change freezes the
  readout, and also stops a paused first half from tripping the auto-half-time
  branch.
- **`MatchRepository.pauseMatch`** stamps `pausedAt` (no-op if already paused, so
  a double tap can't lose the timestamp). **`resumeMatch`** measures the break
  and pushes **both `startedAt` and `endsAt` forward by it**, so a pause costs no
  match time — `startedAt` moves too because it drives the count-up readout *and*
  `actualDurationSec`, which should measure football played.
- **UI:** host gets a **⏸ PAUSE** button under the two goal buttons. While
  paused the goal buttons are replaced by a gold `_pausedPanel` (**Resume
  Match** + **Restart Match**), and everyone else sees `_pausedNote` instead of
  the viewer note. The header LIVE dot stops pulsing and turns **gold + PAUSED**
  on both the live screen and the public scoreboard. End Match stays available.

### (d) 🐛 Restart was broken — fixed
`restartMatch` set `startedAt: null, endsAt: null` while leaving `status: live`,
so a restarted match read **`--:--` forever with no way to start it** (the Start
button lives in the lobby, and a live match never goes back there). It now
**re-arms the clock**: `startedAt = now`, `endsAt = now + durationMin` (timed
modes), `currentHalf 1`, `halfTime false`, `pausedAt null` — i.e. restart means
kick off again from 0:00 with the same players. Restart is reachable from the
settings gear **and** the paused panel (shared `_restartMatch`, red/danger,
confirmed). Copy updated to match (`live.restartSub`, `live.restartMsg`).

### Verified
`flutter analyze` → **No issues found!**; `flutter test` → **44/44** (+3 in
`match_permissions_test.dart`: a running match isn't paused, `pausedAt` marks it
paused, and the remaining-time arithmetic stays frozen at the pause).
No schema, rules or index changes — `pausedAt` is a new field on an existing doc
and `matches` writes only need a signed-in user. **Nothing to deploy.**
**Add to the first device run:** pause mid-half on one device and confirm a
second device's clock freezes too, then resume and confirm no minutes were lost.

## 39. New Home · bottom bar removed · Matches page → single Draft page (2026-08-03)

The app's primary navigation was rebuilt from a new design bundle,
**`.claude/design/design.html`**. Three user decisions this session: adopt the
new palette **globally**, drop the Matches page entirely in favour of a
**one-draft-only** Draft page, and present "يلا نلعب" as a **bottom sheet**.

### (a) Palette adopted app-wide
`app_colors.dart` now carries the design bundle's four named values —
accent **`#D4FF00`** (was `#C6FF3A`), bg **`#0C0F0A`**, surface **`#161A14`**,
border **`#252B21`** — and `bgDeep`/`surface2`/`surface3`/`line2`/`primaryDeep`
are re-stepped along the same olive hue. One file re-skins ~35 screens. The
three places that hard-coded the old accent instead of referencing `AppColors`
were also fixed: the ambient wash in `yno_scaffold.dart`, the splash/highlight
ripples in `app_theme.dart`, and welcome's `ScreenGlow`. **No bare `C6FF3A`
remains in the project.**

### (b) The bottom navigation bar is gone
`widgets/bottom_nav.dart` **deleted** (`YnoBottomNav`, `NavTab`, the raised
centre create button). `community_screen` and `profile_screen` dropped their
`bottomNav` **and their `showBackButton: false`** — they are pushed routes now,
so without that they would have been dead ends.

### (c) Home rebuilt (`home_screen.dart`)
- **Ambient background:** `_PitchLines` (a `CustomPainter` drawing halfway lines
  every 90px + a centre circle at 5% accent opacity) and `_FloatingIcons`
  (⚽⚽⚽🥅👟 bobbing on five different durations so they never sync).
- **Top bar:** `_ProfileSquare` (rounded-18 square, volt border — *not* the
  app's usual circular `InitialsAvatar*)* → Profile · `_PointsBadge` (radius 16,
  volt text, still flashes **green** on a real increase) → Refer & Earn ·
  `_IconSquare` bell (volt dot on unread) → Notifications · `_IconSquare`
  hamburger → drawer.
- **Centre stage:** the YN**O** wordmark + "YALLA NEL'AB", the volt
  `يلا نلعب / LET'S PLAY` button under a breathing `_PulseGlow`, and two
  shortcuts: **👥 Friends → `Routes.community`** and **🛡️ My Teams →
  `Routes.teams`**. It is centred in the space left over and **scrolls only when
  the phone is too short** (`LayoutBuilder` + `ConstrainedBox(minHeight)`).
- **The centre circle is painted with the wordmark, not with the background.**
  It was originally part of the full-screen `_PitchLines` painter at a fixed
  `height * 0.42`, while the content was centred independently — so the logo did
  not sit in the circle. `_CentreCirclePainter` now inscribes the ring in the
  wordmark's own box (`size.shortestSide / 2`), which makes the logo centred in
  it by construction and puts everything later in the column below the circle.
  The box is `width - padding`, clamped 180–238 (the design's 119px radius).
- Subtitle is **"YALLA NELLAB"** (per the user) — the design bundle's
  "Yalla Nel'ab" spelling was wrong.
- **The gaps between the three blocks scale with the available height**
  (10% / 7.5%, clamped 26–92 and 18–72). A first device screenshot showed the
  compact block centring fine but leaving a dead zone under the shortcuts —
  fixed spacers can't fill a tall phone. The stage also pads past the system
  navigation bar (`MediaQuery.paddingOf(context).bottom`), since it lays out
  into the full height so the background can bleed behind it.
- **Kept verbatim:** the position prompt, and both the challenge and match-invite
  popup/banner state machines (§15, §31). The two banners now share one
  `_banner()` helper instead of two near-identical copies.
- Sizes step down below a 420px width, matching the design's media query.

### (d) Matches page deleted; Draft page added
`matches_screen.dart` **deleted** along with `Routes.matches`. Nothing was
orphaned by that: live matches are owned by the `ActiveMatchGate` (§29) and
played history already lives on the profile (`profile_screen._matchHistory`).

New **`draft_screen.dart`** at `Routes.draft`, reachable **only from the side
drawer**. It shows the user's single draft — the gold 2-day warning, a live
"Deletes in Xd/Xh" countdown, **Open & Continue** (→ lobby) and a red
**Delete Draft** (confirmed). Empty state explains the one-at-a-time rule and
offers to create one. `sweepStaleDrafts` moved here from the Matches page.

### (e) One draft at a time — enforced
- **`MatchRepository.watchMyDraft(uid)` / `getMyDraft(uid)`**, both over
  `_pickDraft`: an `adminUid == uid` query filtered client-side to `lobby`
  status, newest first. Single-field query → **no composite index**.
- `_pickDraft` **also discards drafts past `kDraftTtl`**, so an expired draft
  can never keep showing its red dot or keep blocking a new one even though
  cleanup is lazy (no Cloud Functions).
- **`openCreateMatch` is the gate.** With a draft already open it shows a sheet
  offering **Open & Continue** or **Delete it & start new** (confirmed, danger)
  instead of creating a second one. The stale-draft sweep is fired
  **`unawaited`** — the TTL filter above already makes the gate correct, so the
  user never waits on a delete just to open the create screen.

### (f) The draft indicator
A **red dot** appears on the home hamburger and on the drawer's **Draft Match**
row whenever a draft is waiting — both driven by `watchMyDraft`, so both clear
the moment the draft is started or deleted. `_action` in `side_drawer.dart`
gained an optional `dot` colour; the drawer is otherwise unchanged.

### l10n
New **`draft.*`** cluster (17 keys, EN + AR) + `drawer.draftMatch`,
`home.createMatchSub`, `home.joinWithCodeSub`. Removed the whole `matches.*`
cluster and four dead `nav.*` bottom-bar labels — **archived verbatim to
`.claude/l10n_removed_keys.md`** (this project has no git history). The four
draft strings that were still needed were carried across rather than re-written.
`nav.community` survives (Community's title + a profile stat label).

### Verified
`flutter analyze` → **No issues found!**; `flutter test` → **44/44**.
The §36 key sweep re-run: **no key used in code is undefined**, and the only
orphans are the two intentional `result.win`/`result.loss` runtime-interpolated
survivors. No schema, rules or index changes — **nothing to deploy**.

**Add to the first device run:** create a match, back out of the lobby, then tap
يلا نلعب again and confirm the draft sheet blocks a second draft; check the red
dot appears on the hamburger and clears when the draft is started or deleted.

## 40. Settings audit — logout confirm, dead rows, one shared dialog (2026-08-03)

Asked to confirm the delete-all-data countdown still guards that action, to put
a confirmation on sign out, and to say which settings rows were fake.

### Already correct — no change
- **"Delete all my data" DOES show the 10-second countdown** (`_DeleteDataDialog`,
  §8): `barrierDismissible: false`, Delete disabled and labelled "Delete (10)…"
  until the timer reaches 0, then red (`kDangerColor`). Verified, not rewritten.
- Match alerts / friend activity toggles are real — `NotificationRepository`
  reads both before pushing (`notification_repository.dart:75,80`).
- Contact sync is real — `friends_screen` auto-runs a sync when the flag is set.

### Fixed
- 🐛 **Sign out fired instantly from Settings** — a single mis-tap dumped you at
  the welcome screen. It now goes through `showConfirm`. **Not danger-red**: per
  the §20 rule signing out loses nothing, so `danger` stays false; confirming is
  the separate axis (§21).
- **The drawer's logout dialog was a bespoke copy** and had drifted into the old
  wireframe styling (square corners, its own `_DialogButton`). Both logouts now
  call the same `showConfirm`; `_DialogButton` deleted. This is exactly the
  drift §21 called out when it de-duplicated `_confirm`.
- 🐛 **The "Privacy" row was dead** — it called
  `showYnoToast(tr('home.privacySettings'))`, i.e. tapping it popped a toast
  reading "Privacy settings" and changed nothing. Meanwhile the app's one real
  privacy setting (`profilePublic`, §26) was reachable only from Edit Profile.
  The row is now a genuine **public ↔ private profile toggle** writing the same
  field via `updatePrefs`, reusing the `profile.publicProfile*` copy.
- 🐛 **Contact sync's subtitle always read "Off · contacts never leave your
  phone"**, even when switched on — `tr('home.contactSyncOff')` was passed
  unconditionally. Replaced with the state-neutral `home.contactSyncSub`
  ("Contacts never leave your phone", true either way); the switch already shows
  the state.
- **Settings went stale after Edit Profile.** `_loadPrefs` is a one-shot read in
  `initState`, but Edit Profile writes the same `profilePublic` and `language`.
  New `_pushAndRefresh` re-reads prefs on the way back.

### Known, left alone (reported to the user)
- **The About row's `v1.0.0` is hard-coded** in `settings_screen`, not read from
  the build. It will silently lie after the first version bump. A real fix means
  adding `package_info_plus`; not done unasked.
- Contact sync is now togglable in **two** places (Settings and the Friends
  screen). Both write the same field so they can't disagree, but it is
  duplicated UI.

### Verified
`flutter analyze` → **No issues found!**; `flutter test` → **44/44**. The l10n
sweep reports no undefined key and only the two intentional `result.*` orphans.
Three keys removed → archived to `.claude/l10n_removed_keys.md`. Nothing to deploy.

## 41. Contact sync has one home · real version number (2026-08-03)

Follow-up to §40's audit. Two asks: contact sync should be switchable **only**
in Settings (the Friends page points there instead), and `package_info_plus` was
left to my discretion.

### 🐛 The Friends page's contact sync never worked
Removing the duplicate toggle surfaced a bigger problem: `_runContactSync` there
matched against a **hard-coded empty list** —
`const mockedPhoneNumbers = <String>[]` — a §7-era stub that predates the real
implementation. It could only ever report "no contacts matched", and the copy
(`social.noContactsMatchedGated`) even said device access "ships later". It
already shipped in §8 — but only inside `community_screen`, as a private method.
So sending users to Settings to switch on a feature that did nothing would just
have moved the lie.

- **New `services/contact_matcher.dart`** — `findRegisteredContacts(uid)`
  returning a `ContactLookup` (`ok` / `permissionDenied` / `failed` + matches),
  plus `normalisePhone`. It is the §8 implementation lifted verbatim out of
  `community_screen`: permission → read book → normalise → `findByPhones` →
  drop self and existing friends. **Contacts are still never stored** — the
  numbers are used for one lookup and dropped.
- **Both screens now call it.** `community_screen._findFromContacts` is a
  `switch` over the status onto its existing state fields, and its private
  `_normalise` is deleted. The Friends page runs the same real lookup.

### Contact sync switches in Settings only
- The Friends page's bespoke ON/OFF pill is **gone**. When sync is off the card
  explains what it does and offers a volt **Settings** button
  (`social.contactSyncEnableInSettings`); when on it offers **Refresh**.
- `_openSettings` re-reads the flag on the way back, so flipping it in Settings
  takes effect on return without a restart, and kicks off the first sync.
- The section now distinguishes **permission denied** and **read failed** from
  "nobody matched", which the stub could not do (it had one dead-end message).
- ⚠️ Note the two-step: the Settings toggle is a *preference* and does not
  prompt for the OS contacts permission — the Friends page asks when it actually
  reads the address book. `READ_CONTACTS` / `NSContactsUsageDescription` were
  already declared (§8), so nothing to add.

### Real version number (`package_info_plus`)
Settings hard-coded `v1.0.0` and `about_screen` hard-coded `static const
_version = '1.0.0'` — two literals to remember at every bump. Added
**`package_info_plus`**; new `services/app_version.dart` reads it once in
`main()` (before `runApp`) into `AppVersion.current`, so both screens read it
synchronously with no `FutureBuilder`. If the platform channel fails the string
stays **empty and the version is hidden** rather than printing a guess.

### Verified
`flutter analyze` → **No issues found!**; `flutter test` → **44/44**; l10n sweep
clean (no undefined keys, only the two intentional `result.*` orphans).
**Add to the first device run:** the contacts permission prompt now fires from
the Friends page — confirm the denied / failed / no-match states all render.

## 42. Side drawer trimmed (2026-08-03)

- **Points card removed.** The 🪙 balance box (points + "Redeem in V2") is gone
  from the drawer. Points still have two homes — the Home top-bar pill, which
  opens Refer & Earn, and the profile. The `StreamBuilder<AppUser?>` stays: the
  drawer header still needs name / @handle / photo.
- **Footer is now just brand + version**: `YNO v1.0.0`, built from
  `AppVersion.current` (§41) instead of the `home.drawerFooter` key, which had
  **hard-coded `v1.0.0` in both languages** and would have gone stale at the
  first bump. Deliberately untranslated — a brand name and a number read the
  same in EN and AR. Falls back to plain `YNO` if package info is unavailable.
- "Made in Dubai" was then removed from the **About** screen too. Its whole
  footer line went, because the string was `Made in Dubai · © 2026 YNO` — so the
  **copyright notice went with it**. Add a plain `© 2026 YNO` back if that
  matters for release. About keeps its version pill (top of the page) and the
  terms/privacy text.
- 4 keys removed → archived to `.claude/l10n_removed_keys.md`.
- **Verified:** `flutter analyze` → **No issues found!**; `flutter test` →
  **44/44**; l10n sweep clean. Nothing to deploy.
- **My Teams removed from the drawer** — Home already has a My Teams button.
  The `drawer.myTeams` key stays (Home's button uses it), so nothing to archive.
  Friends was kept at this point — Home's Friends button opens **Community**
  (`Routes.community`), a different page from the drawer's Friends
  (`Routes.friends`, requests + search), so they were not duplicates.
  **Superseded immediately by §43**, which removed Friends too (and had to
  rehome accept-friend-request first).

## 43. Friends removed from the drawer — requests answerable on the bell (2026-08-03)

Asked to drop Friends from the drawer since friends are visible on Community.
**Straight removal would have broken friend requests**, so the answer path moved
first.

### The problem
`FriendRepository.acceptRequest` had exactly **one** call site —
`friends_screen.dart` — and the drawer row was the only deliberate way in.
Community can *send* requests (Global + Contacts tabs) and *show* accepted
friends (Friends leaderboard), but nothing anywhere could **accept** one.
`public_profile` only sends (it renders "Pending" for an incoming request), and
the bell rendered `NotifCategory.friend` as an icon with no actions. Left as-is,
requests would have piled up unanswerable — which also stalls the private-profile
gate (§26 opens stats to *accepted* friends) and the friends leaderboard.

### Fix — answer requests from the notification, like team invites (§26)
- `sendRequest`'s notification now carries **`arg: me`** (the requester's uid).
  It previously had only a route, so there was no way to know who was asking.
- `notifications_screen._friendRequestActions` renders **Accept / Decline** on a
  friend notification. It keys off a live `watchFriendship` edge, **not** the
  notification text — `NotifCategory.friend` covers both "X sent you a request"
  and "X accepted yours", and only a still-pending edge whose `requester` is the
  *other* party is answerable. Buttons vanish on their own if it's answered
  elsewhere. Accept → `acceptRequest` + clear the notification; Decline →
  `removeOrDecline` + clear.
- l10n: +`social.decline` (EN + AR); reused `social.accept`, `social.friendAdded`,
  `social.requestDeclined`, `social.aPlayer`.

### Drawer
`My Teams` (§42 follow-up) and `Friends` rows removed. `Routes.friends` and
`friends_screen.dart` are **kept and still routed** — tapping a friend-request
notification opens it (its `route` is `/friends`), so its search / sent-requests
/ contact-match sections stay reachable; nothing now *depends* on finding it.

### Still only on the Friends page (flagged, not moved)
- **Search for a player by username/name** — Community has no search field, so
  adding a specific person who is neither in your contacts nor on the global
  leaderboard now means arriving via a notification. Worth adding search to
  Community's Friends tab if that path matters.
- The **requests sent** list.

### Verified
`flutter analyze` → **No issues found!**; `flutter test` → **44/44**; l10n sweep
clean. No schema/rules/index changes — `arg` is an existing field on the
notification doc. **Add to the first device run:** send a request between two
accounts and accept it from the bell.

## 44. Global leaderboard disabled behind a flag (2026-08-03)

Product decision: the global points board stays hidden until the app has
**~500 users** — a global ranking over a handful of accounts is noise.

- **`kGlobalLeaderboardEnabled = false`** (+ `kGlobalLeaderboardMinUsers = 500`
  recording the threshold) at the top of `community_screen.dart`. **Disabled,
  not deleted** — `_globalSection()`, `watchTopUsers`, the add-friend pill and
  the copy are all still compiled and referenced from the tab switch, so
  flipping one `bool` brings it back with nothing to rebuild.
- Community's tabs are now driven by a **`_CommunityTab` enum** rather than
  fixed `0/1/2` indices (`_tabs` filters Global out, `switch` dispatches on the
  identity). Index arithmetic would have quietly pointed the Contacts tab at the
  global section the moment one was removed.
- `social.global` stays referenced (via `_tabLabel`), so no l10n churn.

### ⚠️ Consequence — finding new people is getting thin
The Global tab carried the **add-a-friend pill** (§26). With it off, and after
§43 removed Friends from the drawer, the ways to add someone you are not already
playing with are: the **Contacts** tab, a **public profile** reached from a match
or team, and answering a request on the bell. **There is still no username
search anywhere** (§43 flagged this; Community has no search field). If players
are expected to add friends by handle, Community's Friends tab needs a search
box — this is the second change in a row to narrow that path.

### Verified
`flutter analyze` → **No issues found!**; `flutter test` → **44/44**. UI-only —
nothing to deploy.

## 45. Release keystore created · both SHA fingerprints (2026-08-03)

Asked for the debug **and** release SHA keys so Google sign-in can be enabled in
Firebase. Debug already existed; **there was no release keystore at all** —
`build.gradle.kts` signed release builds with the debug key (the Flutter
template's `// TODO: Add your own signing config`), so there was no release
fingerprint to read.

### The two fingerprints
| Build | SHA-1 |
|---|---|
| **debug** (`~/.android/debug.keystore`, alias `androiddebugkey`) | `11:01:FD:E9:23:79:18:E6:C5:86:16:C8:80:95:BA:07:0B:B6:A6:3D` |
| **release** (`android/app/yno-release.jks`, alias `yno`) | `19:6A:E2:4A:FB:57:C6:B3:51:91:42:65:2B:94:02:5E:FF:EF:50:CF` |

SHA-256, release: `7D:3A:5A:21:25:D1:03:48:04:F8:E9:8E:0A:9E:80:F7:86:A7:1D:90:DD:A9:0E:A3:AA:C6:80:85:0D:30:FE:58`
SHA-256, debug: `18:14:8A:A8:77:CB:94:46:59:FA:7A:E6:AF:B3:93:D1:97:33:27:CE:72:5B:8C:D2:6E:FE:36:FD:B1:AC:FF:99`

### The release keystore
- **`android/app/yno-release.jks`** — PKCS12 (not JKS: keytool warns that JKS is
  a proprietary deprecated format on every read), RSA 2048, 10000 days, alias
  `yno`, `CN=YNO … L=Dubai, C=AE`.
- **Credentials are in `android/key.properties` and NOWHERE ELSE** — deliberately
  not written into this file. `android/.gitignore` already excluded
  `key.properties`, `**/*.jks` and `**/*.keystore`, so nothing had to be added.
  ⚠️ **This project has no git history and the keystore is gitignored — if that
  file is lost the app can never be updated on Play under this identity.**
  Back both files up outside the repo.
- `build.gradle.kts` loads `key.properties` via `rootProject.file(...)` and
  builds a `signingConfigs.release` from it. It is **guarded on the file
  existing** (`hasReleaseKeystore`) and falls back to the debug config when it
  doesn't — a fresh clone without the keystore still builds instead of dying on a
  null property.

### Verified
`flutter build apk --release` → **√ Built app-release.apk (55.2MB)**, which also
closes §2a's "`package_info_plus` was never built" gap — all native plugins link.
`apksigner verify --print-certs` on the output reports **`CN=YNO`, SHA-1
`196ae24afb57c6b3519142652b94025effef50cf`** — i.e. the APK really is signed with
the release key, not the debug key. (The build logs a suppressed Kotlin
incremental-compile stack trace about "different roots" — the pub cache is on
`C:` and the project on `D:`; it is a warning, the build succeeds.)

### Still to do — ⚠️ items 1–2 were DONE later the same day, see §46–§47
1. ~~Paste both SHA-1s into the Firebase console and re-download
   `google-services.json`~~ — **done in §46** (via the CLI, not the console).
2. ~~Enable **Google** as a sign-in provider~~ — **done in §47** by the user.
3. ⚠️ **Still open. If you ship through Play with Play App Signing, Google
   re-signs with its own key** — the fingerprint that matters for production
   Google sign-in is the *App signing key certificate* in Play Console → Setup →
   App signing, not the upload keystore above. Register that one too.
4. ⚠️ **Still open.** The placeholder `applicationId` (§2a) — deferred by the user.

## 46. SHA fingerprints registered · google-services.json refreshed (2026-08-03)

Follow-up to §45, done against the **live Firebase project** with the already
authenticated `firebase` CLI (v15.14.0, logged in as huzm651@gmail.com).
Android app id `1:1082478194715:android:7946933b7c0efc91a2c8be`.

### Registered — was completely empty before
`firebase apps:android:sha:list` reported **"No SHA certificate hashes found."**
All four were added via `firebase apps:android:sha:create`:

| Cert | Type | Hash |
|---|---|---|
| debug | SHA_1 | `1101fde9237918e6c58616c88095ba070bb6a63d` |
| release | SHA_1 | `196ae24afb57c6b3519142652b94025effef50cf` |
| debug | SHA_256 | `18148aa877cb944659fa7ae6afb393d1973327ce725b8cd26efe36fdb1acff99` |
| release | SHA_256 | `7d3a5a2125d1034804f8e98e0a9e80f786a71d90dda90ea3aac680850d30fe58` |

SHA-1 is what Google sign-in needs; the SHA-256s were added too because App
Check / Play Integrity / App Links will want them and they cost nothing now.

### `android/app/google-services.json` replaced
Downloaded fresh with `firebase apps:sdkconfig ANDROID <appId>`. The previous
file is kept as **`google-services.json.bak-pre-sha`**. It went from
`"oauth_client": []` + `"other_platform_oauth_client": []` (i.e. **nothing
registered at all**) to two `client_type: 1` Android clients — one per SHA-1 —
plus a `client_type: 3` web client. Project/app id unchanged.
**Verified:** `flutter build apk --debug` → **√ Built app-debug.apk** with the
new file, so the google-services Gradle plugin parses it.

### The Dart side needs no change
`auth_repository.signInWithGoogle` uses the **google_sign_in v6** API
(`GoogleSignIn().signIn()` → `authentication` → `accessToken`/`idToken` →
`GoogleAuthProvider.credential`), pinned `^6.2.1`. On Android v6 reads the client
id out of `google-services.json`, so **no `serverClientId` is required**. (If
this is ever bumped to **v7**, the API is a hard break — `GoogleSignIn.instance`
+ `authenticate()` — and v7 *does* require an explicit `serverClientId`.)

### ⛔ NOT done — enabling the Google provider
`firebase` has **no CLI command** for auth providers; it is the Identity Toolkit
Admin API (`admin/v2/projects/{p}/defaultSupportedIdpConfigs?idpId=google.com`).
Doing that from here meant reading the refresh token out of the CLI's
configstore to mint an access token, which **the sandbox classifier blocked** —
correctly, it looks like credential exfiltration. Not worked around.

So the provider's state is **unverified**: a `client_type: 3` web client does
appear in the new config, which is suggestive but is **not proof** that Google
sign-in is switched on. Enable it in the console — Authentication → Sign-in
method → Google → Enable → pick a **project support email** (a required field
the API path skips) → Save. If enabling mints a *new* web client, re-run the
`apps:sdkconfig` download above.

**Add to the first device run:** actually sign in with Google on a debug build —
that is the only real proof the fingerprint round-trip worked.

## 47. Google provider enabled · config confirmed stable (2026-08-03)

The user enabled **Google** in Firebase console → Authentication → Sign-in
method (§46's one open item).

- **Re-downloaded `google-services.json` and diffed it against the installed
  file: byte-for-byte identical.** So enabling the provider reused the existing
  `client_type: 3` web client rather than minting a new one, and the file
  installed in §46 is already correct. **Nothing to re-install.**
- **The provider state could not be verified from here.** The public
  `identitytoolkit/v1/projects?key=<apiKey>` endpoint returns only `projectId`
  and `authorizedDomains` — Google does **not** expose an `idpConfig` list to an
  unauthenticated caller, so a project's enabled providers can't be probed
  client-side. Taken on the user's word; the only real proof is a live sign-in.
- **Correction to §2:** there **is** an Android emulator on this machine —
  `Medium_Phone_API_36.1`. Every "no Android emulator" claim before this section
  is wrong. `adb devices` is currently empty (the AVD is not running).

### Setup for Google sign-in is now complete
Fingerprints registered (§46) · `google-services.json` carries both Android
OAuth clients (§46) · provider enabled (this section) · the Dart side already
uses the google_sign_in v6 API that needs no `serverClientId` (§46).
**What remains is verification, not configuration.**

### 🔴 Still never run against live Firebase
Unchanged from §2a and still the highest-value next step. Google sign-in
specifically **cannot** be tested on Chrome/Edge — `main.dart` runs `AdminApp`
when `kIsWeb`, so the web build is the super-admin dashboard, not the player app.
It needs the AVD (with Play services) or a physical device.

## 48. Client feedback pass — 11 of 21 points implemented (2026-08-18)

The client sent 21 change requests; they are analysed point-by-point in
**`.claude/CLIENT_FEEDBACK_PLAN.md`** (numbered C1–C21, with sizing, and the
nine decisions still open). This section is what was **built**.

**Deliberately not done this pass:** C7 (email OTP / claim account — deferred by
the user; needs the backend decision in the plan's D5), C1 (spelling — needs the
exact target string), C3 (removing Community — ambiguous "as it currently is",
and it would orphan contact-based friend discovery), C12 (website join page —
needs a domain), C17 (keyboard-back lag — needs a device).

### 🐛 C5 — match-invite and challenge popups could go permanently silent
The real defect behind "popups don't appear on my phone". `home_screen`'s
`_maybePopChallenge`/`_maybePopInvite` both opened with

```dart
if (_promptedPosition && user != null && !user.sportProfileDone) return;
```

`sportProfileDone` only ever flips true in `UserRepository.completeSportProfile`,
and `_promptedPosition` is set true again on **every mount of Home** — so any
account that saw the position prompt and backed out without choosing never saw
another popup, on any device, ever. The banner still rendered, which is why it
looked device-specific rather than broken. Replaced with `_positionRouteOpen`,
set when the picker is pushed and cleared when it pops (with a `setState`, so a
popup waiting behind it fires on the way back). **Rule this cost us: never gate
UI on a flag with no path back to false.**

### C4 · C20 — invites must be answered, draws must be confirmed
- The match-invite dialog lost **"Decide later"** and is now
  `barrierDismissible: false`: Accept or Decline, no silent dismissal. The
  **challenge** dialog keeps its Later (not what the client asked to change).
- `match_outcome_screen`'s **Ends as a Draw** and **Extra Time Played** now go
  through `showConfirm` — one tap used to finalise a match for everyone.
  Neither is danger-red: per the §20 rule they lose no data.

### C19 — penalty shootout is a first-class outcome, with a score
Penalties previously existed **only** behind "extra time played" and recorded
just a winner. Now:
- **Penalty Shootout** is a third top-level option next to draw and extra time,
  and the extra-time branch routes to the same sheet — one entry point, so a
  shootout always captures its score.
- New `MatchModel.penaltyA`/`penaltyB` (+ `hasShootoutScore`) and
  `setOutcome(..., penaltyA:, penaltyB:)`, which writes them **only when
  supplied**, so a legacy penalties result is not damaged.
- The sheet is ± steppers per team; **Confirm stays disabled while the scores
  are equal**, which is what makes deriving `winnerSide` from the score safe.
- Rendered on the post-match scorecard as `(5 – 4)` under the scoreline and in
  the share text. Every display site is gated on `hasShootoutScore`.

### C9 — non-admins are held while the host settles a level match
`live_match_screen._redirectToResults` sent every non-creator straight to the
scorecard the moment the match ended — so on a draw they saw "DRAW" and could
walk away while the host was still choosing extra time or penalties. New
`_awaitingHostDecision(m)` (`ended` **and** `isLevel` **and** no
`outcomeMethod`) holds them on a `_hostDecidingPanel` instead; the screen is
already `PopScope(canPop: false)`, so it really holds. When the host writes the
outcome the stream rebuilds and they move on. **`abandoned` is excluded** — an
abandoned match has no outcome to wait for and must not trap anyone.

### C11 — players can leave a lobby
New **`MatchRepository.leaveMatch(matchId, uid)`**: refuses once the match is
live (`StateError('match-started')`) and refuses the creator
(`'admin-cannot-leave'` — they delete the draft or end the match). It clears the
player doc, `playerUids`, **any pending invite** (or the invite they just walked
out of would pop straight back up) and **their armband** (`_start` blocks until
both sides have a captain, so a departing captain would freeze the match). Red
confirmed button in the non-admin start bar.

### C21 — the match code never changes
The lobby's "↻ Regenerate" is gone: one code, valid for the life of the match.
`MatchRepository.regenerateCode` is left in place, uncalled, so restoring it is
one widget. **Team invite-code regeneration is untouched** — different surface,
and the client's note said "Matchmaking page". Flagged as decision D8.

### C16 — "Unlimited" is now **Custom**, and it leads the list
Renamed in l10n only — **the stored value stays `'Unlimited'`**, so matches
created before the rename still read back and `_teamSize`'s `^(\d+)v` parse
still returns null for it. Moved to the front of `_formats` and given a
description that is **always visible**, not only once selected (it is the first
chip now, so it has to be readable before you commit to it).
⚠️ **1v1/2v2/3v3 were NOT re-added** — the client's phrasing implies 3v3 exists,
but §35 removed it. That is decision D4.

### C6 · C13 · C14 · C15 — you can tell you own a team now
The §34 known gap, independently reported by the client three times.
- **Side A** gained `_ownTeamBlock`: a labelled "Or use one of your teams" with
  a sentence explaining what picking one does (roster copied in, captain takes
  the armband, result counts for the club) — and, when the user owns **no**
  teams, a tappable empty state routing to team creation. Previously this was a
  row of unlabelled chips that rendered as **nothing at all** with zero teams.
- **Challenge by code** is now a bordered block with a ⚡ heading and a
  plain-English explanation, presented as the other way to pick an opponent
  rather than a 12px dim label under a field.

### C2 — the Draft page is now **My Matches**
`draft_screen.dart` → **`matches_screen.dart`** (`Routes.draft` →
`Routes.matches`), drawer row "Draft Match" → **"My Matches"**. Sections:
**Playing now** (live), **Draft** (the existing card, warning and countdown
carried over verbatim), and **Played**. The draft is still read through
`watchMyDraft` rather than filtered out of the list, because that is the query
that also discards an expired draft. **The indicator stays a red dot, not a
count** (client's clarification), so the one-draft-at-a-time rule is unchanged.
`sweepStaleDrafts` moved with the screen.

### C8 — you can ask to join a team
Joining was invite-only or by code; you could view a team and have no way in.
New `teams/{id}/joinRequests/{uid}` subcollection mirroring `invites`, with
`requestToJoin` / `approveJoinRequest` / `declineJoinRequest` /
`watchJoinRequests` / `watchMyJoinRequest`. A **public** team shows Request to
Join on its profile (then "Request sent · tap to withdraw"); a **private** team
says plainly that it needs a code instead of silently offering nothing. Owner
**and** captain are notified; managers answer in `team_manage_screen`, where the
section collapses to nothing when the queue is empty.

### ✅ `firestore.rules` DEPLOYED (2026-08-18)
`joinRequests` was a **new subcollection with no rule**, and Firestore denies
unmatched paths, so C8 would have failed silently. Deployed with
`firebase deploy --only firestore:rules --project yno-app-e96f5` →
*"rules file firestore.rules compiled successfully / released rules to
cloud.firestore / Deploy complete!"*

Its rule mirrors `invites` (`read: if true`, `write: if signedIn()`). No index
changes — every new query is a single-collection read.

### Verified
`flutter analyze` → **No issues found!** · `flutter test` → **48/48** (+4 new
shootout cases in `match_permissions_test.dart`: score exposed, legacy result
without a score ignored, score on a non-penalties outcome ignored, and the
shootout winner taking a real win off a level scoreline) · l10n sweep clean —
no undefined keys, only the two intentional `result.win`/`result.loss`
runtime-interpolated survivors. 7 removed keys archived to
`.claude/l10n_removed_keys.md`.

**Add to the first device run:** leave a lobby as a player and confirm the host
sees you go; end a level match and confirm a second device is held on "the host
is deciding" until the shootout score is entered; request to join a public team
from a second account (**after deploying the rules**).

### 48a. Client answers — C1, C3, C16 closed (2026-08-18)

- **C1 — no change.** `YALLA NELLAB` is correct as it stands; the client
  confirmed the spelling. Do not "fix" it again — it has now been questioned
  twice (§39 and here) and kept both times.
- **C3 — Community is NOT removed, only renamed.** The page title is now
  **"Your Friends"** (`nav.yourFriends`). Everything on it — the friends
  leaderboard, the disabled Global tab, Contacts — is untouched, so nothing was
  orphaned. ⚠️ The title needed a **new key**: `nav.community` is also the
  profile's Community-award stat label (`profile_screen.dart:331`), so editing
  that key's value in place would have relabelled an award count "Your Friends".
  The file and class stay `community_screen.dart` / `CommunityScreen` —
  `friends_screen.dart` already exists and is a different page (requests +
  search), so renaming this one would be actively confusing.
- **C16 — small formats stay out.** The client confirmed: do **not** re-add
  1v1/2v2/3v3. Formats remain Custom · 4v4 … 11v11. Decision D4 is closed.

`flutter analyze` clean · `flutter test` 48/48 · l10n sweep clean.

### 48b. Team invite-code regeneration removed too (2026-08-18)

Completes C21 / decision D8. **No code in the app rotates any more** — a match
code and a team code are each issued once and live for the lifetime of the thing
they belong to.

- `team_profile_screen`: the owner-only ↻ control and `_regenerateCode` are
  gone. With them went the last owner-gated element on this page, so
  `_inviteCode(team, amOwner)` → `_inviteCode(team)`, `_header`'s `amOwner`
  parameter and the `amOwner` local in `build` were all removed as dead.
  Copy/share remain.
- `TeamRepository.regenerateInviteCode` is **left in place, uncalled**, like
  `MatchRepository.regenerateCode` — restoring either is one widget.
- `teams.inviteCodeCaptainOnly` now says the code **never changes — share it
  carefully**, since that is the whole trade being made.
- 4 keys removed → archived to `.claude/l10n_removed_keys.md`.

⚠️ **The consequence, stated plainly:** a team invite code is also its
**challenge** code, it is permanent, and there is now **no way to revoke it**.
Anyone who ever holds it — a former member, anyone they forwarded it to — can
join the team or challenge it forever. The only remedy left is removing the
person from the roster after the fact. This was the client's explicit call; the
repo method survives so it can be undone cheaply.

`flutter analyze` clean · `flutter test` 48/48 · l10n sweep clean.

## 49. 👉 START HERE NEXT SESSION — what is open and what is waiting (2026-08-18)

State at the end of the client-feedback session. **18 of the client's 21 points
are closed** (§48, §48a, §48b). Full per-point analysis, sizing and the original
decision list live in **`.claude/CLIENT_FEEDBACK_PLAN.md`** — note that D1
(spelling), D2 (draft count), D3 (Community), D4 (small formats) and D8 (team
codes) are now **answered and closed**; read this section for the current truth
rather than the plan's decision list.

Green across the board: `flutter analyze` → **No issues found!** ·
`flutter test` → **48/48** · l10n sweep clean (only the two intentional
`result.win`/`result.loss` runtime-interpolated survivors) · Firestore rules
deployed and in sync.

### The three client points still open

| # | Point | Why it is not done | Blocked on |
|---|---|---|---|
| **C7** | Email OTP · set password · claim account | Deferred by the user, then re-opened with an agreed design (below). Needs a server — Firebase Auth **cannot send a 6-digit code**, only links | Domain · email provider · host account |
| **C12** | Website join link | **Not a code problem.** `guest_join_screen` already does exactly what the client described, and `lobby_screen.dart:41` already shares `https://yno.app/join?code=…` — **the domain does not exist**, so every shared link is dead today | The same domain as C7 |
| **C17** | Back-navigation slow with the keyboard open | Cannot be diagnosed statically — an OEM keyboard's dismiss animation and our own rebuild cost look identical in a code read | A device profile run |

### C7 — the agreed design (user's idea, refined; supersedes plan D5)

A **standalone Node service** the app calls, instead of Cloud Functions (avoids
Blaze billing) or a bundled email key (bypassable). Two endpoints:

- `POST /request-otp` — look up the email, generate a 6-digit code, store its
  **hash** (never plaintext) in Firestore with a ~10-minute expiry and an
  attempt counter, send the mail.
- `POST /verify-otp` — compare, burn the code, **mint a Firebase custom token**
  with the Admin SDK and return it.

**The load-bearing decision: verify must return a custom token, not `{ok:true}`.**
A boolean leaves the *app* deciding who gets in, so a repackaged APK skips the
call entirely. Returning a token means possession of the OTP is what produces
the credential — the app then calls `signInWithCustomToken`.

- **State** in Firestore `emailOtps/{email}`, rules `allow read, write: if false`
  — the Admin SDK bypasses rules, so only the server ever sees it.
- **Non-negotiable on the endpoint:** rate-limit per email AND per IP (or it is
  an open spam relay that will burn the sending quota), short expiry, ~5 attempt
  cap, single use.
- **Claim flow:** email → server confirms a `users` doc with `autoCreated: true`
  → OTP → verify → custom token → app forces *set your password* →
  `updatePassword` → clear `autoCreated`. **This is what removes the `123456`
  reveal from `showAccountExistsDialog`.**
- **Host:** recommended **Cloudflare Workers** over Vercel — Vercel's Hobby plan
  is non-commercial-only and this is a client product, so it would need Pro
  ($20/mo). Confirm current terms before committing. **User has not chosen yet.**
- **Email:** Resend (simplest) or Brevo. Both offer a **test sender that works
  without a domain**, so the service and the app flow can be built and tested
  before DNS is verified, then the real sender swapped in. *Nobody is blocked.*
- **Bonus worth taking in the same pass:** move FCM sending to this server and
  **delete the bundled admin key from the APK** (~half a day). That ends the
  worst security exposure in the project.
- **Effort:** ~2–3 days. The API is small; the app-side flow (signup + claim +
  set-password) is the larger half. **No new Flutter dependencies** — `http` and
  `firebase_auth` are already in `pubspec.yaml` and `signInWithCustomToken` is
  built in.

### Waiting on the user (told to them 2026-08-18, not yet supplied)

1. **A domain** (~$12/yr) — gates C7's sender identity AND C12's join page. One
   purchase unblocks both. DNS propagation takes hours, so start early.
2. **Email provider account** → API key + sender address.
3. **Host account** → and the Cloudflare-vs-Vercel choice.
4. **A second Firebase service account key** — generate a *fresh* one for the
   server rather than reusing the app's, so the two revoke independently.

Total running cost ≈ **$12/year** on Cloudflare + a free email tier.

### Also still open (not client points)

- 🔴 **The device run** — see §2a. It is now the gate on C17, on confirming C5
  on the client's own handset, and on proving six flows built in §48 that no
  human has seen work.
- ⚠️ **`applicationId` is still `com.example.ynoapp`** — Play rejects it; costs
  a new Firebase Android app + `google-services.json` + re-registering all four
  SHAs. Deferred by the user, but it lands before release.
- The username-search gap (§2a) — flagged three times, still undecided.


## 50. C7 — email-OTP claim flow, built and green (2026-08-18)

Closes the design agreed in §49, **as amended by the client mid-session**.
Written and verified; **not deployed** — the Worker needs a Cloudflare account
and a service-account key (below).

Infra answers this session: domain **nellab.org** (which already serves other
pages), email **Resend**, host **Cloudflare Workers**.

### ⚠️ The client changed the design mid-build. Read this before "fixing" anything

The §49 plan was: OTP → server returns a custom token → app calls
`signInWithCustomToken` → **force** a new password. Two of those were overruled:

1. **The password stays `123456`.** `kAutoAccountPassword` is back, and
   `createPlayerAccount` uses it again. A `randomPassword()` helper was written
   and then **removed** — do not resurrect it without re-reading point 3.
2. **After a correct OTP the app signs in silently with `email + 123456`,** not
   with the custom token. The server still returns the token; the app ignores it.
3. **Setting a password is offered, not forced** — "Skip for now" goes Home.

🔴 **The consequence, stated plainly: `email + 123456` still works on the normal
login screen.** Anyone who knows a host-created player's address can sign in as
them without touching the OTP, exactly as before — the claim flow is a
convenience path, not a security boundary. The client was told this twice and
chose it anyway; it is **their decision, not an oversight**. Closing it later is
cheap and deliberately left cheap: one line in
`OtpService.verifyAndSignIn` (use the token it already receives) plus
randomising `kAutoAccountPassword`. Nothing server-side has to move.

A `server/scripts/rotate-auto-passwords.mjs` was written earlier in the session
and **deleted** — under this design it would rotate away the very password the
claim flow signs in with, locking every unclaimed player out. Do not re-add it
unless point 2 is reversed first.

### The server — `server/`

Cloudflare Worker. `POST /request-otp` · `POST /verify-otp` · `GET /health`.

⚠️ **There is no `firebase-admin` and there cannot be** — it needs gRPC and Node
internals and does not run on Workers. All it was needed for is two signed JWTs,
so `src/google.js` signs them with **WebCrypto RS256** and `src/firestore.js`
uses the Firestore **REST** API. No `nodejs_compat`, no polyfills. Adding the
SDK back breaks the deploy, not just the tests.

| File | Role |
|---|---|
| `src/index.js` | Router, rate limits, both endpoints |
| `src/google.js` | PKCS#8 import, RS256 signing, per-scope OAuth token, custom token |
| `src/firestore.js` | REST get/set/delete + case-insensitive user lookup |
| `src/otp.js` | Code generation, peppered hashing, constant-time compare |
| `src/email.js` | Resend send + dark/volt HTML template |

State is `emailOtps/{email-lowercased}`: the code **hash** (never the code),
`uid`, `expiresAt`, `attempts`, send-throttle counters.

**Limits** — 10-min code · 60 s resend cooldown per address · 3 sends per 15 min
· 5 wrong guesses then burned · 20 req/60 s per IP via the Workers rate-limit
binding. The per-address limits live in Firestore and are authoritative, so a
missing IP binding degrades the service rather than opening it.

`/request-otp` returns **`not_claimable`** (404) when no host-created account
exists, so the screen can say so rather than asking for a code that will never
come. This does confirm whether an address has a host-created account —
deliberate, and not new: `users` is world-readable and `findByEmail` already
does the same lookup client-side.

Gotchas already paid for: the rate-limit binding wants `name =` in
`[[ratelimits]]`, **not** `binding =` (wrangler 4 errors on the latter);
`createPlayerAccount` stores email **trimmed but not lowercased**, so the server
matches both casings in one `IN` query.

### The app side

- **`services/otp_service.dart`** — `requestOtp` / `verifyAndSignIn`.
  `OtpException` carries a stable machine code the screen dispatches on. **No new
  pubspec dependencies.**
  ⚠️ **`kOtpServiceUrl` is still the placeholder `https://yno-otp.workers.dev`**
  and must be set after the first deploy.
- **`screens/claim_account_screen.dart`** — three steps in **one route**
  (email → code → password). One route on purpose: the sign-in happens between
  steps 2 and 3. The password step is `PopScope(canPop: false)` with no back
  button — backing out would drop a signed-in user behind the login screen —
  and offers **"Skip for now"** instead.
  A burned code (`too_many_attempts` / `code_expired`) drops back to the email
  step; `rate_limited` on send moves *forward* to the code step, since a code is
  already in flight.
- **`autoCreated` is cleared only when a password is actually set**, not after
  the OTP. Someone who skips still has the shared password, so they must be able
  to claim again.
- **`widgets/common.dart` → `ClaimAccountLink`** — the entry point, on **both**
  login and sign-up (the client asked for both). Carries whatever email is
  already typed; passes `null`, not `''`, when empty.
- **`showAccountExistsDialog`** no longer prints a password; an auto-created
  account gets **"Claim my account"** → `Routes.claim`.
- **Login's `'password'` route argument was removed** — it used to arrive
  pre-filled with the shared default. Not read back on purpose.
- **`Routes.claim` is in `ActiveMatchGate._skip`** — without it the gate can
  yank a user into a live match mid-claim.
- 32 new `auth.*` keys, EN + AR. `auth.accountExistsAutoBody` was **reworded,
  not removed**; old value archived to `.claude/l10n_removed_keys.md`.

### C12 — the join link now points at a domain we own

`lobby_screen._linkFor` was `https://yno.app/join?code=…` — **a domain that is
not ours.** Now `https://join.nellab.org/?code=…`.

A **subdomain** by the client's instruction: nellab.org already serves other
pages, and a subdomain takes its own DNS record and its own deploy without
touching them. ⚠️ **The page does not exist yet, so the link still does not
resolve** — that is the rest of C12.

The **referral share links now point there too** (client's call) —
`misc.shareMsgB`, EN and AR, was `https://yno.app`. Old value archived to
`.claude/l10n_removed_keys.md`.

**The domain lives in exactly one place: `lib/links.dart`.** `kJoinBaseUrl` +
`joinLink(code)`. `lobby_screen._linkFor` delegates to it, and `misc.shareMsgB`
**interpolates it in both languages** — it is a compile-time const, so `trMisc`
stays a `const` map. This replaced three hard-coded copies, where a domain
change could update English and miss Arabic. `test/links_test.dart` guards it:
the link is present in both languages, and no `misc.*` string mentions
`yno.app`.

The **support address** moved too: `help_screen.dart` now renders
`kSupportEmail` = **`support@nellab.org`** (was `support@yno.app`). ⚠️ **That
mailbox has to actually exist and be read** — it is the app's only email contact
route.

⚠️ **One `yno.app` reference remains:** `live_scoreboard_screen.dart:109` —
`BrowserChrome(url: 'yno.app/live')`, decorative fake browser chrome. Cosmetic,
but it still shows users a domain that isn't ours.

### ✅ Verified

`flutter analyze` → **No issues found!** · `flutter test` → **56/56**
(`account_exists_dialog_test.dart` rewritten to the claim-vs-login contract;
new `claim_account_link_test.dart` covers the entry point that is now the only
way in for a host-created player — note `find.textContaining` needs
`findRichText: true` for that label) · l10n sweep clean, only the two
intentional `result.*` survivors · server `npm test` → **10/10** ·
`wrangler deploy --dry-run` builds with the rate-limit binding bound ·
**`firestore.rules` DEPLOYED** — `emailOtps` is `allow read, write: if false`.

### 50a. 👉 DEPLOYMENT RUNBOOK — pick this up here next session

Nothing below has been done. The code is finished and green; this is purely
credentials and DNS. **Steps 1–2 are the only blockers** for a working,
testable OTP flow.

#### The two blockers

**1. A fresh Firebase service-account key.**
Console → Project Settings → Service Accounts → *Generate new private key*.
Must be **separate** from `assets/firebase_admin_key/service_account.json` so
the two revoke independently. Not yet supplied by the user (asked twice).
Without it the Worker cannot mint an OAuth token and every endpoint 500s (which
is exactly what the local smoke test showed — it fails closed, no leak).

**2. Cloudflare auth.** `wrangler login` is an interactive browser OAuth, so it
cannot be run from a tool call. **Ask the user to run it themselves** in the
Claude Code session with the `!` prefix:

```
! cd server && npx wrangler login
```

Once that lands, the auth is on this machine and the assistant can do the rest
unattended. **The free plan is sufficient** — 100k req/day, and the
rate-limiting binding works on free.

#### Then (assistant can run these once 1 and 2 are done)

```bash
cd server
npx wrangler secret put SERVICE_ACCOUNT_JSON   # the whole JSON, one line
npx wrangler secret put RESEND_API_KEY
npx wrangler secret put OTP_PEPPER             # node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
npx wrangler deploy
```

Deploy prints `https://yno-otp.<subdomain>.workers.dev`. **Set that as
`kOtpServiceUrl`** in `lib/services/otp_service.dart` — it is still the
placeholder `https://yno-otp.workers.dev`, which is NOT a real URL.

🔑 **The Resend API key was pasted in chat and is deliberately NOT written into
this file or memory** — it is a live credential and these files are plain text.
It is `re_T8VY…` (ask the user for the rest, or read it from the Resend
dashboard). **Tell the user to rotate it once the service works.**

#### 3. Resend sender domain — ❓ OPEN QUESTION, ASK FIRST

⚠️ **We do not know where `nellab.org`'s DNS is hosted** — Cloudflare or the
registrar. The user was asked and has not answered. That decides where the
records go. **Ask before giving instructions.**

Resend → Domains → Add `nellab.org` → it shows 3–4 records (DKIM `TXT`, SPF
`TXT`, usually an `MX` for the return path). Add them verbatim. If DNS is on
Cloudflare, leave the proxy (orange cloud) **off** — it only applies to A/CNAME,
but it is a common trip-up. Verification takes minutes to a few hours.

Then swap the commented `MAIL_FROM` line in `server/wrangler.toml` to
`YNO <no-reply@nellab.org>` and redeploy. Nothing else changes.

**Until then the shared test sender works with no DNS at all — but it only
delivers to the address that owns the Resend account.** Enough to prove the
whole flow end to end; useless for a second tester.

⚠️ Existing `nellab.org` pages are unaffected by this step — these are new
TXT/MX records, not edits to A/CNAME.

#### 4. `join.nellab.org` — the rest of C12, later

Needs `nellab.org`'s DNS to be **on Cloudflare**. If it is not, moving the
nameservers **does** affect the existing site and needs care — do not suggest it
casually.

Then: Workers & Pages → the join worker → Settings → Domains & Routes → Add
custom domain → `join.nellab.org`. Cloudflare writes the DNS record itself. The
root domain and its existing pages are untouched — a subdomain is its own
record. The join **page itself is still unbuilt**; the app already links to it
(`kJoinBaseUrl`), so those links resolve to nothing today.

#### 5. `support@nellab.org` must become a real mailbox

`help_screen` renders `kSupportEmail`. It is the app's only email contact route,
so somebody has to receive it. Not verified as existing.

### Still open after this

- **Moving FCM onto this server** and deleting the bundled admin key from the
  APK — ~half a day, and the infrastructure now exists. Every build still ships
  full project-admin credentials.
- The device run, `applicationId`, C17, and the username-search gap (§2a, §49).

### 50b. ✅ The DNS question is answered — it is Hostinger, and the site is Firebase (2026-08-20)

§50a step 3 asked the user where `nellab.org`'s DNS lives. It did not need
asking — it is public. Looked up rather than waited on:

| Fact | Evidence |
|---|---|
| DNS is on **Hostinger**, not Cloudflare | `NS ns1/ns2.dns-parking.com`; SOA contact `dns.hostinger.com` |
| Mail is on **Hostinger** | `MX mx1/mx2.hostinger.com`; `SPF include:_spf.mail.hostinger.com`; `_dmarc p=none` |
| The site is **Firebase Hosting** | `A 199.36.158.100`; `Vary: x-fh-requested-host`; TXT `hosting-site=yalla-nellab-12650` |
| In project **`yalla-nellab-12650`** ("Yalla Nellab") | `firebase projects:list` — and **this machine is already logged in** (`huzm651@gmail.com`) and can see it |

Note it is **not** the app's project (`yno-app-e96f5`, whose `.web.app` 404s and
which has no `.firebaserc`). Root serves a 1.7 KB landing page,
"Yalla Nellab | Community Sports Organization", last modified 2025-11-19.

#### What each pending step actually needs now

- **The OTP Worker: no DNS at all.** `*.workers.dev` is a real hostname. Steps 1
  and 2 of §50a (service-account key, `wrangler login`) remain the only blockers
  — **DNS was never on that path.**
- **Resend (§50a step 3): unaffected, do it at Hostinger's hPanel.** ⚠️ Take
  Resend's **subdomain** option — `send.nellab.org` — so its DKIM/SPF/return-path
  MX land on their own record and the **root MX and SPF that carry the client's
  live mail are never edited**. Adding a second root MX or a second `v=spf1`
  would break their existing email.
- **`join.nellab.org` (§50a step 4): the Cloudflare Workers plan is dead.** A
  Workers custom domain requires the zone to be on Cloudflare, and it is not.
  **Use Firebase Hosting instead** — a second site in `yalla-nellab-12650`,
  `firebase hosting:sites:create`, deploy the page, add the custom domain, paste
  the TXT + A records it prints into hPanel. Free, works with DNS anywhere, same
  account we already hold, and it is where the rest of the domain already lives.
  (Cloudflare **Pages** would also work via CNAME, but there is no reason to add
  a second vendor.) `lib/links.dart` needs no change — the URL is already right.
- **`support@nellab.org` (§50a step 5): cheap.** Hostinger already runs the MX,
  so it is a mailbox add in hPanel, not new infrastructure.

⛔ **Do not suggest moving the nameservers to Cloudflare.** It would mean
re-creating Firebase's A record, the Hostinger MX pair, SPF, DMARC and the
`hosting-site=` verification TXT by hand, with the client's live site and their
email in the blast radius — to buy a subdomain we can already get for free.

#### Now the only thing missing for DNS work

**hPanel access** (or a willing pair of hands there) — the records for both
Resend and `join.` get pasted at Hostinger. That is a *third* thing to ask the
user for, alongside the §50a service-account key and `wrangler login`.

## 51. C12 — the join page is built (2026-08-20)

`join_site/` in the repo. One static file, `public/index.html` — no build step,
no framework, no dependencies. **Written and green; deploy is the user's to run**
(the tool call was blocked as an outward-facing publish).

The Firebase Hosting **site was created**: `nellab-join` in project
**`yalla-nellab-12650`** — the project that already serves `nellab.org` (§50b),
on a **separate site**, so the existing pages cannot be touched. It will be live
at `https://nellab-join.web.app` once deployed.

```bash
cd join_site && npx firebase deploy --only hosting --project yalla-nellab-12650
```

`firebase.json` pins `"site": "nellab-join"`, so a deploy from that folder can
only ever write to that site. ⚠️ **Never run a hosting deploy from the repo
root** — D6 still stands: the Flutter web build is the super-admin dashboard
with credentials baked in (§23) and must never be published.

### What it serves

Two audiences, because the domain is the target of **two** different shares:
`?code=…` from the lobby's share sheet, and the **bare domain** from the
referral text (`misc.shareMsgB`). Bare visits get a landing page and a code
field rather than an empty screen.

With a code it renders the real match — status pill, team names, format,
duration, players joined — then the code, a copy button and the three join
steps. **Live** matches show the score and the app's own "the admin approves
you" warning. **Ended** matches show the final score and **drop the code and the
steps**, because there is nothing left to join.

EN + AR with RTL, following the browser and remembered in `localStorage`.
Strings that already exist in `lib/l10n/` are **copied verbatim**, so the page
and the app say the same thing in both languages.

### How it resolves a code

Firestore **REST**, unauthenticated, straight from the browser — allowed by the
existing `match /matches/{mid} { allow read: if true }`, the same rule that lets
an accountless guest look a code up in the app. Verified against the live
database before the page was written.

It mirrors `MatchRepository.findByCode` exactly: `code`, then `codeA`, then
`codeB`; side B only from `codeB`, so the shared code lands on side A — which is
what `guest_join_screen` does, and that screen has **no side picker**, so the
page's "You will join X" is a promise the app actually keeps.

The Firebase **web API key in the page is a public identifier, not a secret** —
the same key already ships in the Android APK, and reads are governed by rules.

⚠️ **The page never writes.** It hands over a code and stops. Re-implementing
`guestJoin` in vanilla JS would duplicate the guest doc + `joinMatch` +
mid-game-pending logic in a second language with no tests, where drift corrupts
match state. Joining from the web is a deliberate follow-up, not an oversight.

### ✅ Verified

`npm test` → **42/42** (`join_site/test/render_test.mjs`) — a stub DOM seeded
from the real markup, so a `getElementById` with no matching element fails the
run. Covers lobby/live/ended/abandoned, the side-B code, an unknown code, a bare
visit, a code as a path segment, and that every translated string has Arabic
copy. `npm run test:live` resolved **13/13** real codes against the live
database, including correct A/B sides and a null for an unknown code.

**No Dart changed** — `lib/links.dart` has pointed here since §50.

### Left inside the page

- **`STORE_URL` is `null`.** The app is on no store (`applicationId` is still
  `com.example.ynoapp`), so the page says so honestly instead of showing a dead
  button. Set the constant and the download button appears by itself.
- **No `og:image`** — WhatsApp previews show title and description, no picture.
  Needs a 1200×630 PNG, which is a design asset.
- **No deep link.** `AndroidManifest.xml` has **no intent-filter** beyond
  LAUNCHER, so the page cannot open the app directly; it hands over a code to
  paste. Adding an intent-filter for `join.nellab.org` would let the link open
  the app straight into the lobby — a genuine improvement, and a change to the
  app, not the page.

## 52. Spec written for the two website pages + deep-link routing (2026-08-20)

**`.claude/WEBSITE_PAGES_SPEC.md`** — the build spec for a **Join** page and a
**Live match** page, to be built inside the *nellab.org website project* (the
user pastes the spec there, so it is deliberately **self-contained**: palette,
type, Firestore schema, queries, clock maths and EN/AR copy are all written out,
because `lib/` is not visible from that repo).

Nothing built this session beyond the spec. §51's `join_site/` remains the
reference implementation to port from.

### Two decisions in the spec that need the user's yes

1. **The pages move to the existing site: `nellab.org/join` + `/live`.** The user
   asked for one project, one deploy, "no extra setup" — which rules out
   `join.nellab.org`, since that needs a Hostinger DNS record and a Firebase
   custom domain. ⚠️ **This supersedes §50/§51's subdomain** and changes
   `kJoinBaseUrl` in `lib/links.dart` (one line, guarded by `links_test.dart`).
   It also makes the `nellab-join` Hosting site created in §51 redundant.
2. **"Join" on the website means *watch*, not *enter the roster*.** The user
   described the second page as the live match screen, so the site is
   spectate-only and never writes. Real web guest-join would mean
   re-implementing `guestJoin` in JS — flagged, not assumed.

### The link routing it specifies

Verified **Android App Links** are the whole mechanism — a web page cannot detect
an installed app, the OS decides. `?code=` opens the app on Home with the join
sheet pre-filled, or falls through to the web live page; `?ref=` opens Sign-up
with the code pre-filled, or Home plus an "you already have an account" popup if
signed in, or the Play Store if the app is missing.

Three traps recorded because each one silently breaks App Links:

- **Firebase Hosting's default `"ignore": ["**/.*"]` excludes `.well-known/`**,
  so `assetlinks.json` never deploys.
- It must be served as `application/json`, 200, no redirect.
- **Play App Signing re-signs the APK**, so the release fingerprint in
  `assetlinks.json` stops matching unless Play's own app-signing SHA-256 is added
  (the same trap as §45 item 3). Both current SHA-256s are quoted in the spec.

### App-side work it implies (not done)

A **new Flutter dependency** (`app_links` — nothing in `pubspec.yaml` can receive
a deep link today), the `AndroidManifest.xml` intent-filter with
`pathPrefix="/join"` (the app has **no** intent-filter at all today), cold-start
*and* warm-resume handling, `kJoinBaseUrl`, a `referralLink(code)` helper,
`misc.shareMsgB` + `profile_screen._shareReferral` carrying `?ref=`, and two new
l10n keys for the already-have-an-account popup.

🔴 **`applicationId` is now blocking three things at once** — Play rejects
`com.example.ynoapp`, `assetlinks.json` must name the final id, and the Play
Store URL contains it. It has been deferred since §2a; it is now on the critical
path.

### 52a. Decisions confirmed · work split into two phases (2026-08-20)

The user answered every open question in §52 and set the order of work.

| Decision | Answer |
|---|---|
| Where the pages live | **`nellab.org/join` + `nellab.org/live`.** `join.nellab.org` is **dropped** — no DNS work for either page |
| What "Join" means on the web | **Spectate only.** The site never writes; the button leads to the live screen |
| `applicationId` | **`org.nellab.yno`** — the placeholder `com.example.ynoapp` is finally settled |
| Order | **Website pages first.** Deep links are recorded and deferred |

`.claude/WEBSITE_PAGES_SPEC.md` now opens with a **Build order** table:

- **Phase 1 — the two pages** (§1–§4, §6). 👉 Build now. Self-contained: both
  pages work as ordinary web pages whether or not the app exists.
- **Phase 2 — App Links routing** (§5). ⏸ Deferred, banner-marked "do not build
  yet", kept in full so the design is not lost.

### ⚠️ Sequencing rule recorded in the spec

**`kJoinBaseUrl` does not move until the pages are deployed.** Flipping
`lib/links.dart` to `https://nellab.org/join` early would only move the app's
dead links from one dead URL to another — `join.nellab.org` has no DNS, and
`/join` would 404 until Phase 1 ships. It flips the day the pages go live,
together with `test/links_test.dart`.

### ⚠️ `org.nellab.yno` is not a one-line change

Recorded in the spec so it is not under-budgeted when Phase 2 starts: renaming
the package needs a **new Firebase Android app**, a fresh `google-services.json`,
and **all four SHA fingerprints re-registered** (§45–§46). It also has to happen
before any Play submission and before `assetlinks.json` is published, since both
carry the id.

### Next action

**The website project's folder.** It is the one thing that cannot be guessed —
its stack decides Firestore-SDK-vs-REST (§2.3) and how routes are declared. Once
the user pastes the spec there and points at the folder, Phase 1 gets built from
it, porting `join_site/public/index.html` (§51) as the starting point.

## 53. Phase 1 built — /join and /live live in the website project (2026-08-20)

Built in **`D:\Web\yno`** (the nellab.org site: Create React App, React 19,
react-router 7, antd, `firebase` 9.22.2 already a dependency), against
`.claude/WEBSITE_PAGES_SPEC.md`. **Written, tested, built — not deployed.**

### Files

| File | Role |
|---|---|
| `src/lib/ynoMatchDb.js` | Firestore access: code lookup + three live subscriptions |
| `src/lib/matchTime.js` | Pure helpers — timestamp coercion, code normalising, **`isSideB`** |
| `src/pages/match-pages/matchClock.js` | The live clock, ported from `_timerText` |
| `src/pages/match-pages/matchI18n.js` | EN/AR copy + the language hook |
| `src/pages/match-pages/matchTheme.css` | The app's brand, scoped under `.ynoPage` |
| `src/pages/match-pages/matchConfig.js` | `PLAY_STORE_URL` and friends, one place |
| `src/pages/match-pages/MatchShell.js` | Shared frame + `GetAppCard` |
| `src/pages/match-pages/JoinMatchPage.js` | `/join` |
| `src/pages/match-pages/LiveMatchPage.js` | `/live` |
| `src/App.js` | **edited** — routes split (below) |
| `package.json`, `src/setupTests.js` | **edited** — test infra (below) |

### Three decisions worth knowing

**1. The match pages render OUTSIDE the site chrome.** `App.js` wrapped every
route in `<Header/> <main/> <Footer/> <Chatbot/>`. That is now a `SiteLayout`
component sitting on a `path="*"` route, with `/join`, `/join/:code` and `/live`
as siblings above it. Someone opening a shared match link gets the app's dark
brand, not a charity landing page — and the marketing chrome cannot fight the
dark theme.

**2. A SECOND, named Firebase app.** The site is `yalla-nellab-12650`; the
matches are in the app's `yno-app-e96f5`. `ynoMatchDb.js` calls
`initializeApp(config, 'yno-match')` — ⚠️ **it must stay named**, or it clobbers
the site's default app and breaks auth everywhere.

**3. The CSS is scoped under `.ynoPage`.** CRA bundles all CSS globally, so a
bare element selector here would repaint the marketing site. The only unscoped
rule is `body.ynoDark`, added and removed by a mount effect.

### 🐛 Caught by testing against real data: the side is UPPERCASE

Firestore stores `team` as **`'A'` / `'B'`** (`TeamSideX.id`), not lowercase.
The first cut compared against `'b'`, which files **every Team B player and
every Team B goal under Team A** — it renders perfectly and is simply wrong.

Worse, the first fixtures used lowercase too, so **the tests passed while the
code was wrong.** It only surfaced when the subcollections were read from the
live database. Now: `isSideB()` in `matchTime.js`, strict `=== 'B'` to mirror the
app's `fromId`, fixtures corrected to uppercase, and a named regression test —
**verified to fail (3 tests) when the bug is reintroduced.** The spec's schema
section carried the same error and has been corrected.

### Other things the port got right on purpose

- **No `orderBy` on `players`/`goals`.** Both are ordered by server timestamps,
  and an `orderBy` silently drops documents whose write has not resolved — a
  goal scored seconds ago would vanish from the feed. Goals are sorted
  client-side by `minute` then `at`.
- **Enter submits the code field** (a real `<form>`), which is client bug C18.
- **No roster listing.** The app names every player; a public web page has no
  business publishing the turnout. Head counts only, plus goal scorers.
- **Ended matches** drop the "You will join" note and the timer, keep the score.
- The **referral landing** (`/join?ref=`) is built but **dormant** — nothing
  links to it until the app sends such links in Phase 2.

### ✅ Verified

`npm test` → **40/40** across two suites (20 clock, 20 render) ·
`npm run build` → **compiles clean, no warnings from any new file**, +5 kB JS
(Firebase was already bundled) · subcollection reads confirmed **unauthenticated
against the live database** (14/14 checks over 4 real matches, players *and*
goals).

⚠️ **`src/App.test.js` fails** — it is the stale Create React App scaffold
asserting "learn react", it has never passed, and it is untouched. Left alone
deliberately; delete it whenever convenient.

### Test infrastructure that had to be fixed first

Jest could not even load the pages, for two reasons unrelated to this work:

- **`react-router-dom` 7's `main` points at `dist/main.js`, which it does not
  ship.** Webpack resolves via `exports`; CRA's Jest does not. Added a
  `moduleNameMapper` in `package.json` for `react-router-dom` and
  `react-router/dom`.
- **react-router 7 needs `TextEncoder`/`TextDecoder` at import time**, and the
  jsdom bundled with react-scripts 5 predates both. `src/setupTests.js` now
  borrows Node's.

### Still open

1. **Deploy** — `npm run build && firebase deploy --only hosting` from
   `D:\Web\yno` (project `yalla-nellab-12650`). Not run: outward-facing.
2. **Flip `kJoinBaseUrl`** to `https://nellab.org/join` + `test/links_test.dart`,
   **the day the pages are live** (§52a).
3. **`PLAY_STORE_URL` currently 404s** — `org.nellab.yno` has no listing yet, so
   the Download button leads nowhere. The user asked for a placeholder; set
   `matchConfig.js`'s constant to `null` to show the honest "not on the stores"
   text instead.
4. **Arabic review** by a native speaker, and an **`og:image`**.
5. Retire the now-redundant `nellab-join` Hosting site from §51.

## 54. C12 CLOSED — pages deployed, the app now links to them (2026-08-20)

The user deployed `D:\Web\yno` to Firebase Hosting. **`nellab.org/join` and
`nellab.org/live` are live**, and the app has been flipped over to them.

### Deployment verified

Not by the HTTP 200 — the site rewrites `**` to `index.html`, so *every* path
returns 200 with the same 1701-byte CRA shell and the same generic `<title>`.
That looks exactly like a stale deploy. What actually proves it:

- the served `index.html` references **`main.7694458e.js`**, the hash of the
  final local build;
- the bundle contains `Football, organised.`, `yno-match`, `yno-app-e96f5`,
  `No match found for that code.` and `ynoPage`;
- the CSS carries `.ynoPage{--bg:#0c0f0a;…}`;
- **584 escaped Arabic code points** are in the bundle — the Arabic copy shipped,
  the minifier just writes it as `\uXXXX`, which is why a plain grep for the
  Arabic text "finds nothing" and means nothing.

Also checked, because it can only fail in a browser: the Firebase **web API key
has no HTTP-referrer restriction** — a Firestore REST query with
`Origin: https://nellab.org` returns 200, and the CORS preflight returns 200. (A
restricted key would 403. The 400 from a hand-rolled Listen-channel request is
just a malformed handshake, not a permission signal.)

### App side — `lib/links.dart`

```
kJoinBaseUrl:  https://join.nellab.org   ->   https://nellab.org/join
joinLink():    '$kJoinBaseUrl/?code=$c'  ->   '$kJoinBaseUrl?code=$c'
```

The slash went with it: the route is `/join`, and `/join/?code=…` would lean on
the router's trailing-slash leniency for nothing. `misc.shareMsgB` (EN + AR)
interpolates the const, so both languages moved for free — which is the entire
reason that indirection exists.

`test/links_test.dart` gained a test pinning the **exact** URL shape
(`https://nellab.org/join?code=ABC123`) against the route the website actually
serves, not just "contains the base".

**No `join.nellab.org` references remain in `lib/` or `test/`.**

### ✅ Verified

`flutter analyze` → **No issues found!** · `flutter test` → **57/57** (was 56).

### C12 is closed. **20 of the client's 21 points are done** — only **C17**
(back-navigation slow with the keyboard open) remains, and it needs a device
profile, not code.

### Two small follow-ups left on this

1. ⚠️ **`nellab-join` Hosting site (§51) is now redundant** — the standalone
   site in `yalla-nellab-12650`. Deleting it is a destructive action on the
   client's project, so it is left for the user to confirm. `join_site/` in the
   Flutter repo stays useful as the tested reference implementation.
2. **`PLAY_STORE_URL` still 404s** — `org.nellab.yno` has no listing.
   `src/pages/match-pages/matchConfig.js`, one constant; set it to `null` for the
   honest "not on the stores yet" text instead.

### 54a. `nellab-join` is KEPT, deliberately (2026-08-20)

The user's decision: **do not delete it.** The `/join` path on the main site is
the current answer, but moving to `join.nellab.org` later is still on the table,
and the site + its deploy config are the expensive part to recreate. It costs
nothing to leave in place.

So there are now **two** valid targets, and §51's `join_site/` stays meaningful:

| | |
|---|---|
| **Live today** | `nellab.org/join` + `/live` — React pages in `D:\Web\yno` |
| **Held in reserve** | `nellab-join` Hosting site (`yalla-nellab-12650`), currently serving nothing |
| **Reference impl** | `join_site/` in the Flutter repo — the standalone, tested join page |

⚠️ If the subdomain is ever adopted, the switch is: deploy to `nellab-join`, add
the custom domain, add the Hostinger DNS record, then change **`kJoinBaseUrl`**
— one line, still the only place the domain is written.

## 55. OTP deploy — service-account key received, Cloudflare still not authed (2026-08-20)

### ✅ Blocker 1 cleared — the fresh key

`C:\Users\huzaifa\Downloads\yno-app-e96f5-firebase-adminsdk-fbsvc-6de5911286.json`

Verified before use:

| | |
|---|---|
| `type` / `project_id` | `service_account` / `yno-app-e96f5` ✓ |
| `private_key` | present, valid PEM ✓ |
| `private_key_id` | `6de59112…dc39` |
| Bundled key's id | `fade14a1…ca6b` |
| **Distinct?** | **YES** — the two revoke independently, which was the whole requirement |

Same `client_email` as the bundled key, which is fine and expected: Firebase
offers one admin service account, and the isolation that matters here is at the
**key** level, not the account level. Revoking `6de59112…` kills the Worker
without touching the app, and vice versa.

🔑 **Handling:** the file stays OUT of the repo. It goes into the Worker as a
secret and nowhere else. ⚠️ Once the deploy succeeds, delete it from `Downloads`
or move it to wherever the keystore backups live — `Downloads` is not storage,
and this project has **no git history**, so nothing here is recoverable.

### 🔴 Blocker 2 NOT cleared — `wrangler whoami` says not authenticated

`npx wrangler whoami` → *"You are not authenticated. Please run `wrangler
login`."* The login has not landed on this machine. It is interactive browser
OAuth, so it **cannot** be run from a tool call.

Two ways forward, the user's choice:

1. `! cd server && npx wrangler login` in the session — the `!` prefix runs it
   in the user's own shell, and the credential persists to this machine.
2. **A Cloudflare API token** (dashboard → My Profile → API Tokens → *Edit
   Cloudflare Workers* template). With `CLOUDFLARE_API_TOKEN` set, wrangler needs
   no browser at all. Better for repeat/CI deploys.

⚠️ `wrangler deploy --temporary` (which wrangler itself suggests) deploys to a
throwaway preview account. **Not for a client product** — the URL evaporates.

### 🔴 Also still missing — the Resend API key

Deliberately never written to disk (§50a). Starts `re_T8VY…`; the rest has to
come from the user or the Resend dashboard.

### Ready and waiting

`npm test` → **10/10** · `wrangler deploy --dry-run` → builds, **17.35 KiB**,
rate-limit binding bound, `FIREBASE_PROJECT_ID`, `APP_NAME` and `MAIL_FROM` all
resolved.

`MAIL_FROM` is still `YNO <onboarding@resend.dev>` — Resend's shared test sender.
It needs no DNS and is enough to prove the whole flow end to end, but ⚠️ **it
only delivers to the address that owns the Resend account**, so it is useless for
a second tester. Swapping to `no-reply@nellab.org` is the Hostinger DNS step
(§50b), and it is a one-line change plus a redeploy.

### The deploy, once auth lands

```bash
cd server
node -e "console.log(JSON.stringify(require('C:/Users/huzaifa/Downloads/yno-app-e96f5-firebase-adminsdk-fbsvc-6de5911286.json')))" | npx wrangler secret put SERVICE_ACCOUNT_JSON
echo "<the re_… key>" | npx wrangler secret put RESEND_API_KEY
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))" | npx wrangler secret put OTP_PEPPER
npx wrangler deploy
```

Then set the printed `https://yno-otp.<subdomain>.workers.dev` as
**`kOtpServiceUrl`** in `lib/services/otp_service.dart` — still the placeholder
`https://yno-otp.workers.dev`, which is not a real host.

## 56. 🚀 The OTP Worker is DEPLOYED and verified live (2026-08-20)

The user logged in via a normal terminal (`npx wrangler login` in PowerShell —
the `!`-prefix route did not execute; `wrangler whoami` was the thing that
settled it either way). Account **`huzm651@gmail.com`**, id
`b753690b79f479375193717e371bee31`, scope includes `workers (write)`.

### Live

**`https://yno-otp.yno-otp-server.workers.dev`** — version
`0ea4617d-6ac1-4a6c-b078-2054b0e70cb0`, 17.35 KiB (5.56 KiB gzipped).

Note the workers.dev subdomain is **`yno-otp-server`**, so the host is
`yno-otp.yno-otp-server.workers.dev` — *not* the `yno-otp.<something>.workers.dev`
that §50a guessed. Deploy order that worked: **deploy first, then secrets** —
`wrangler secret put` attaches to a Worker that already exists.

⚠️ First request after deploying failed TLS (`SEC_E_ILLEGAL_MESSAGE`). That was
just workers.dev DNS not yet propagated — wrangler warns about it. It resolved
within a minute; not a certificate problem, so do not go chasing one.

### ✅ Verified against the live service

| Check | Result |
|---|---|
| `GET /health` | `{"ok":true,"service":"yno-otp"}` · 200 |
| `POST /request-otp` with an unknown address | `not_claimable` · 404 |

That second one is the important one. Reaching `not_claimable` means the whole
credential chain works end to end: **PKCS#8 import → WebCrypto RS256 signing →
Google OAuth token → Firestore REST query** — all of it, on a runtime with no
`firebase-admin`. Blocker 1 from §50a is closed and *proven*, not assumed.

### Secrets

`wrangler secret list` → **`SERVICE_ACCOUNT_JSON`**, **`OTP_PEPPER`** (32 random
bytes, generated in the pipe so the value was never printed or written to disk).

🔴 **`RESEND_API_KEY` is still missing** — the only remaining gap. Until it is
set, `/request-otp` will reach the send step for a *real* claimable account and
fail there. Everything before it works. It needs **no redeploy**: secrets take
effect immediately.

```bash
cd server && echo "<the re_… key>" | npx wrangler secret put RESEND_API_KEY
```

### App side

`kOtpServiceUrl` in `lib/services/otp_service.dart` is now the real host (was the
placeholder `https://yno-otp.workers.dev`, which never existed).

`flutter analyze` → **No issues found!** · `flutter test` → **57/57**.

### What is left on C7

1. **The Resend key** (above) — then a real end-to-end claim.
2. ⚠️ The sender is still `onboarding@resend.dev`, Resend's shared test address,
   which **only delivers to the address that owns the Resend account**. Fine to
   prove the flow; useless for a second tester. Real sender = the Hostinger DNS
   step (§50b), then uncomment `MAIL_FROM` in `wrangler.toml` and redeploy.
3. **Rotate the Resend key** once it works — it was pasted in chat.
4. ⚠️ **Move the service-account key out of `Downloads`.** It is live
   project-admin credential sitting in a scratch folder, and this repo has no git
   history.

## 57. All three secrets set · email delivery proven (2026-08-20)

`RESEND_API_KEY` is in. `wrangler secret list` → **`OTP_PEPPER`**,
**`RESEND_API_KEY`**, **`SERVICE_ACCOUNT_JSON`**. No redeploy was needed —
secrets take effect immediately.

### Verified, in order

| Link in the chain | How it was proven |
|---|---|
| Worker runs | `GET /health` → 200 |
| SA key → RS256 → OAuth → Firestore REST | `POST /request-otp` (unknown address) → `not_claimable` 404 |
| Resend key is live | `GET /domains` → 200 |
| Sender actually delivers | Test email → Resend id `c65e2d85…`, polled to **`last_event: delivered`** |

The delivery test went **directly to Resend**, not through the Worker, on
purpose: it isolates "does email leave the building" from "does the app flow
work", so a later failure can be attributed to one or the other instead of both.

### Two facts that shape the remaining test

1. **Resend has no domains yet** — `GET /domains` returns `data: []`. So the
   sender is still `onboarding@resend.dev`, and it **only delivers to the address
   that owns the Resend account**.
2. **That owner is `huzm651@gmail.com`** (the user confirmed; same account as
   Firebase and Cloudflare).

### 🔴 The gap that blocks a real end-to-end claim

There are **3 host-created accounts** in `users` (`autoCreated: true`) —
`ni***@`, `ey***@`, `ib***@` — and **none of them is `huzm651@gmail.com`**.

So an OTP for any existing claimable account would be generated correctly and
then **not delivered**, because the test sender refuses every address except the
account owner. Nothing is broken; the two constraints simply do not overlap yet.

**To close it, one of:**

- **(a) Make a claimable account for the owner address.** In the app: create a
  match → add a player by email `huzm651@gmail.com` → that runs
  `createPlayerAccount`, which sets `autoCreated: true`. Then Login → **Claim my
  account** → the code arrives. This also exercises `createPlayerAccount`, so it
  is the more complete test.
- **(b) Verify `nellab.org` in Resend** (§50b: add the DKIM/SPF records at
  Hostinger, on the `send.` subdomain so the root MX/SPF carrying the client's
  live mail is untouched), then swap the commented `MAIL_FROM` in
  `wrangler.toml` to `no-reply@nellab.org` and redeploy. After that **any**
  address receives, and the three existing accounts become testable.

(b) is required for production regardless; (a) is the faster proof.

### Still open on C7

- ⚠️ **Rotate the Resend key** — it was pasted in chat, so it is in plain text in
  the transcript and in this file's history. `re_T8VY…`, Resend dashboard → API
  Keys → revoke and reissue, then
  `echo "<new key>" | npx wrangler secret put RESEND_API_KEY`. No redeploy.
- ⚠️ **Move the service-account key out of `Downloads`.**
- The real claim run, per (a) or (b) above.

## 58. 👉 START HERE NEXT SESSION — verify nellab.org in Resend (production sender)

The user chose the **production** route (option (b) of §57) over the quick local
test. They also **confirmed the §57 test email arrived** — so delivery works; the
only thing missing is a sender identity we own.

**Everything else on C7 is done and live.** Worker deployed, all three secrets
set, credential chain proven, `kOtpServiceUrl` wired into the app. This section
is DNS and one config line.

### Why this is the blocker

`MAIL_FROM` is `YNO <onboarding@resend.dev>`, Resend's shared test sender, which
**only delivers to the address owning the Resend account** (`huzm651@gmail.com`).
None of the 3 existing host-created accounts uses that address, so no real user
can be sent a code today.

### 🔴 The rule that matters more than anything else here

**`nellab.org` carries the client's live email.** Verified 2026-08-20:

```
MX     nellab.org        mx1.hostinger.com (5), mx2.hostinger.com (10)
TXT    nellab.org        "v=spf1 include:_spf.mail.hostinger.com ~all"
TXT    nellab.org        "hosting-site=yalla-nellab-12650"   <- Firebase Hosting ownership
TXT    _dmarc            "v=DMARC1; p=none"
A      nellab.org        199.36.158.100                      <- Firebase Hosting
```

⚠️ **Do not replace or edit the root `MX`, and do not add a second root
`v=spf1` record.** Either one breaks the client's mailboxes. A domain may have
exactly one SPF record; two is a permanent-error condition, and mail starts
failing for everyone.

Confirmed clean today — `resend._domainkey.nellab.org`, `send.nellab.org` (MX,
TXT, A) **do not exist yet**, so nothing collides.

### The steps

1. **Resend → Domains → Add Domain → `nellab.org`** (pick the region closest to
   the users; it only sets the return-path host).

   Add the **root domain**, not `send.nellab.org`. Resend already isolates the
   return path onto a `send.` subdomain of whatever you give it, so adding the
   root gets that isolation *and* lets the from-address be the clean
   `no-reply@nellab.org`. Adding `send.nellab.org` instead would force
   `no-reply@send.nellab.org`.

2. **Read the records Resend shows and add them verbatim** in Hostinger →
   hPanel → Domains → DNS Zone. Expect roughly:

   | Type | Name | Purpose |
   |---|---|---|
   | `TXT` | `resend._domainkey` | DKIM public key |
   | `TXT` | `send` | SPF for the return path (`v=spf1 include:amazonses.com ~all`) |
   | `MX` | `send` | Return path (`feedback-smtp.<region>.amazonses.com`, priority 10) |

   ⚠️ **Take the names from Resend's screen, not from this table** — the region
   and key change. What this table is for is the check: **every record must sit
   on `send` or `resend._domainkey`, never on the bare root.** If Resend asks for
   a record at the root `@` that is an `MX` or a second `v=spf1`, stop and
   re-read — that is the one thing that must not be done here.

   Hostinger's DNS editor writes the name relative to the zone, so enter `send`
   and `resend._domainkey`, **not** the fully-qualified form.

3. **Wait for Verified.** Minutes to a few hours. Check with:
   `nslookup -type=TXT resend._domainkey.nellab.org 8.8.8.8`

4. **Swap the sender.** In `server/wrangler.toml` the line is already there,
   commented:
   ```toml
   MAIL_FROM = "YNO <no-reply@nellab.org>"
   ```
   Uncomment it, delete the `onboarding@resend.dev` line, then
   `cd server && npx wrangler deploy`. Nothing else changes — it is a plain var,
   not a secret.

5. **Then run a real claim end to end.** Any of the 3 existing host-created
   accounts now works, or make a fresh one (host a match → add a player by
   email). Login → **Claim my account** → code → set password or Skip.
   If the code does not arrive: `cd server && npx wrangler tail` streams the live
   Worker logs and will show exactly which step failed.

### Do these in the same session

- ⚠️ **Rotate the Resend key.** It was pasted in chat, so it is plain text in the
  transcript. Resend → API Keys → revoke `re_T8VY…` → new key →
  `echo "<new>" | npx wrangler secret put RESEND_API_KEY`. No redeploy.
- ⚠️ **Move the service-account key out of `Downloads`** to wherever the keystore
  backups live. Live project-admin credential, and this repo has **no git
  history**.
- Consider tightening `_dmarc` from `p=none` to `p=quarantine` **only after**
  the domain shows Verified and a real send has been observed — never before, or
  legitimate mail starts landing in spam.

### State to hand over

| | |
|---|---|
| Worker | `https://yno-otp.yno-otp-server.workers.dev` — live, healthy |
| Secrets | `SERVICE_ACCOUNT_JSON`, `OTP_PEPPER`, `RESEND_API_KEY` — all set |
| App | `kOtpServiceUrl` wired · `flutter analyze` clean · `flutter test` 57/57 |
| Website | `nellab.org/join` + `/live` live · C12 closed |
| Client points | **20 of 21** — only C17 (device profiling) left |

### 57a. ✅ Resend key rotated — and downgraded to least privilege (2026-08-20)

The key pasted in chat is **revoked and proven dead.** Done entirely through
Resend's API — the old key had full access, so no dashboard visit was needed.

| | Old | New |
|---|---|---|
| Name | `yalla nellab` | **`yno-otp-worker`** |
| Id | `364800f4…` | **`84d43ece…`** |
| Permission | **full access** | **`sending_access`** |
| Status | **revoked** | live, in the Worker |

**The downgrade is the part worth keeping.** The Worker only ever sends mail; it
has no business being able to create keys, delete domains or read the account.
The old key could do all of that, and it was sitting in a chat transcript.

Order was deliberate — **create → store → prove it sends → only then revoke.**
Revoking first would have meant an outage if any later step failed, and each
failure path in the script exits *before* touching the old key.

The new token was never printed, never written to disk and never passed as a
command-line argument (argv is readable by other processes on the machine). It
went from the HTTPS response straight into `wrangler`'s stdin.

### Verified after rotating

| Check | Result |
|---|---|
| New key really sends | test email → **`delivered`** |
| Old key → `GET /domains` | `400 API key is invalid` |
| Old key → `GET /api-keys` | `400 API key is invalid` |
| Old key → **`POST /emails`** | **`401 API key is invalid`** — the capability that actually mattered |
| Worker `/health` | 200 |
| Worker `/request-otp` | `not_claimable` 404 — credential chain intact |
| `wrangler secret list` | all three still set |

⚠️ **Do not read Resend's status codes as a pass/fail signal.** A revoked key
gets **400** from `/domains` and `/api-keys` but **401** from `/emails`. A check
that only treats 401/403 as "revoked" reports a dead key as alive — which is
exactly what happened here on the first pass, and cost a second look to
disprove.

### One consequence to remember

**There is no full-access Resend key any more.** That is intended, but it means:

- **§58's domain verification is a dashboard job** — which it was anyway.
- A future key rotation cannot be done over the API. Create a new key in the
  Resend dashboard, or temporarily issue a full-access one.
- ✅ **The "rotate the Resend key" item from §57 is closed.** Still open from that
  list: **move the service-account key out of `Downloads`**.

### 57b. ✅ Service-account key removed from `Downloads` (2026-08-20)

Deleted `C:\Users\huzaifa\Downloads\yno-app-e96f5-firebase-adminsdk-fbsvc-6de5911286.json`
(key id `6de59112…dc39` — the one the Worker uses) at the user's instruction.
They keep a copy elsewhere.

Worth recording: the user first said it was moved, but the original was **still
there** — copied, not moved, so both copies existed. Verifying beat taking it on
trust, and it is the second time a "done" turned out to be a copy or a
no-op this session (the other was `wrangler login`). ⚠️ **Check credential and
auth claims rather than assuming them.**

Verified after deleting: no `*adminsdk*.json` / `service_account*.json` remains
in `Downloads`, and the Worker is untouched — `/health` 200, `/request-otp`
`not_claimable` 404. The credential lives in the `SERVICE_ACCOUNT_JSON` **secret**,
not in any file, so deleting the file changes nothing operationally.

⚠️ **The runbook path in §55/§56 is now dead.** If the secret ever needs
re-setting, either ask the user for their copy or just generate a fresh key in
the Firebase console and revoke `6de59112…` — that is cheap and is the cleaner
move anyway.

### 🔴 One admin key deliberately remains: `assets/firebase_admin_key/service_account.json`

Key id `fade14a1…ca6b`. This is **not** an oversight and must not be deleted: the
app still sends FCM push directly from the device with it, so removing it breaks
notifications. It is also the project's worst security exposure — **every APK
ships full project-admin credentials, recoverable by decompiling.**

The fix has been available since §56: the Worker exists, is deployed and already
holds its own service-account key, so moving FCM sending server-side and deleting
this bundled file is now ~half a day of work rather than a project. Still open.

## 59. Language-switch bug fixed · "Draft Matches" rename · app legal pages (2026-08-20)

### (a) 🐛 The side drawer's language switch did nothing

Reported by the user, and real. `side_drawer.dart` carried its **own copy** of
the language sheet whose row was:

```dart
Widget _langRow(BuildContext context, String label) => InkWell(
      onTap: () => Navigator.of(context).pop(),   // closes the sheet. That is all.
```

It never called `L.setLanguage`. Tapping "العربية" dismissed the sheet and
changed nothing. The identical control in **Settings** was complete — locale +
persistence — which is why this looked like "sometimes it works".

**Fixed by deleting the copy, not by patching it.** `showLanguagePicker` now
lives in `widgets/common.dart` and both callers use it. It:

- switches the locale live (`L.setLanguage` drives the `ValueNotifier` the
  MaterialApp listens to),
- **persists** the choice to the user profile, which `splash_screen` reads back
  on next launch — doing only the first is the other easy half-fix, where the
  language changes and then forgets,
- shows a **check mark** against the active language (from the Settings
  version) under the sheet title (from the drawer's),
- returns whether anything changed, so Settings can rebuild.

The profile write is deliberately **after** the switch and wrapped in a
`try/catch`: the language has already changed on screen, and an offline write
must not turn a working switch into an unhandled async error.

**`test/language_picker_test.dart` — 5 tests**, including the one that would have
caught this: *tapping العربية actually switches the app to Arabic*.

### (b) "My Matches" → "Draft Matches"

Client instruction. `matches.title` and the drawer row are now
**`Draft Matches` / `مسودات المباريات`**. The key `drawer.myMatches` was renamed
to **`drawer.draftMatches`** — a key named `myMatches` holding "Draft Matches" is
exactly the drift the l10n sweep exists to catch. Old values archived to
`.claude/l10n_removed_keys.md`.

⚠️ **Flagged to the user:** the page still has **three** sections — *Playing
now*, *Draft*, *Played* — so the title now names one of the three. Their call,
and it is two values to revert. Note this also partly reverses **C2** (§48),
which renamed the Draft page *to* "My Matches" at the client's request.

⚠️ The Arabic is mine, not a native speaker's.

### (c) App Privacy Policy + Terms & Conditions

New pages in the **website** project, live at:

| | |
|---|---|
| `https://nellab.org/app/privacy` | `AppPrivacyPolicy.js` |
| `https://nellab.org/app/terms` | `AppTermsConditions.js` |

Plus `LegalPageShell.js` (shared frame, effective date and contact in one
place). Styled to match the existing website policy pages; **separate from
them** on purpose — those cover the events business and the website, these cover
the app, and each cross-links to the other.

**Written against the source, not from a template.** Every factual claim was
checked:

- **contacts** — `contact_matcher.dart` normalises numbers in memory, runs one
  `whereIn` lookup and drops them. The policy says exactly that, including that
  contact names and emails are never used.
- **no location** — no location package exists; a match's "location" is free
  text someone typed.
- **no ads, no analytics SDK** — verified against `pubspec.yaml`.
- **match records are world-readable** — `firestore.rules`. The policy says
  plainly that scores and scorer names can be viewed publicly by anyone with the
  link, because that is what makes the web scoreboard work.
- **guests, host-created accounts, OTP claiming, hashed codes, 2-day draft
  expiry, 30-day deactivation** — all described as built.
- Sub-processors named: Google Firebase, Cloudinary, Cloudflare, Resend.

The Terms carry the two clauses that actually matter for a sports app and that a
template would miss: **§11 matches are arranged between users** (we do not
organise, supervise or referee them, and we are not party to any payment) and
**§12 physical risk**. Governing law is the UAE, consistent with the existing
website Terms.

### (d) Linked from inside the app

`lib/links.dart` gained **`kTermsUrl`** and **`kPrivacyUrl`** — same
one-place-only rule as the join link.

- **`welcome_screen`** — "Terms" and "Privacy Policy" in the consent line were
  **grey text that merely looked like links and did nothing**. They are now
  tappable and underlined. App review checks that these are reachable *before*
  sign-up, so this was a submission blocker as well as a bug.
- **`about_screen`** — keeps its plain-language summaries and adds
  "Read the full … →" links. The summaries stay a summary; the hosted document
  is the binding text, and two copies of a legal document would drift.
- Implemented as `WidgetSpan` + `GestureDetector` rather than
  `TapGestureRecognizer`, so there is no recognizer to dispose on a stateless
  screen.

### ✅ Verified

`flutter analyze` → **No issues found!** · `flutter test` → **62/62** (was 57) ·
website `npm run build` → clean, +7.33 kB.

### 🔴 Blocker for store submission, found while writing the policy

**The app has no permanent account deletion** — only temporary deactivation (max
30 days, `user_repository.deactivate`). **Google Play requires** an app with
accounts to offer deletion *in-app* **and** at a publicly reachable URL.

The policy handles the policy half honestly (delete by emailing support), but
two things are still missing and both are real work:

1. An in-app "Delete my account" path.
2. A public account-deletion request page — e.g. `nellab.org/app/delete-account`
   — which is a field in the Play Console listing.

### Still needed from the user

- **Deploy the website** for the two legal URLs to resolve — they 404 until then,
  and the app now links to them.
- **`support@nellab.org` must exist.** Both documents name it as the contact and
  as the deletion route. The MX is already at Hostinger, so it is a mailbox add.
- **Confirm the minimum age is 13** (the documents say 13, with guardian consent
  under 18). Yalla Nellab runs youth events, so this affects the Play "target
  audience" declaration and may pull the app into the Families policy.
- A lawyer's read before submission. These are careful and accurate, but they
  are not legal advice.

## 60. Account deletion — in-app, OTP-confirmed, plus the public page (2026-08-20)

Closes the Play-submission blocker found in §59. **Deployed** (Worker version
`1f587afb-4d55-4658-ae4c-1c313a65dafe`); the website page needs the user's
deploy.

### The two gates, and why both

**1. A 10-second hold** on the warning screen. Not theatre — the confirm button
is *absent as a target* while the warning is on screen, which is what actually
defeats a mis-tap. A countdown that only relabels an already-live button looks
identical and protects nobody, so **the test asserts `onTap` is null**, not that
a number changes.

**2. An emailed one-time code.** Proves whoever holds the phone also holds the
mailbox, so a borrowed or stolen unlocked handset cannot wipe an account.

**Cancel is live from the first frame.** Only deletion is delayed; holding
someone on a frightening screen would be hostile.

### 🔑 The ID token is the real security boundary, not the OTP

`purpose: "delete"` **requires a Firebase ID token** and refuses the request
without one, or if the token belongs to a different account than the address
given. Without that, `/request-otp` would let anyone fire *"confirm deleting your
account"* mail at any address they knew — a phishing-shaped spam vector aimed at
a real person's inbox.

The token is checked **twice**: when the code is requested, and again at the
moment of deletion. The two calls are minutes apart and a token can be revoked in
between.

Verified against `accounts:lookup` with the public web API key rather than
hand-rolling JWT verification — Google checks signature, expiry and issuer, so
there is no JWKS to fetch, cache or get wrong. `FIREBASE_API_KEY` is a new plain
var in `wrangler.toml` (public; already ships in the APK).

### Server (`server/`)

- **`src/identity.js`** — `userFromIdToken()` and `deleteAuthUser()`.
  Deletion is **admin-authenticated**, which is the whole reason it is
  server-side: the client SDK's `user.delete()` fails `requires-recent-login`
  for anyone who has not signed in within minutes — and it would fail at the very
  last step, after the countdown and the code.
- **`src/firestore.js`** — `deleteSubcollection()`. Firestore has **no recursive
  delete over REST**: removing `users/{uid}` would leave `notifications` and
  `playedWith` behind as orphans that are still readable by path. That is exactly
  the data deletion is meant to remove, so it is walked explicitly.
- **`src/index.js`** — one code path, two purposes. Deletion codes are stored
  under a **namespaced id** (`del_{email}`) so a pending claim code and a pending
  delete code cannot overwrite each other, and the stored `purpose` is re-checked
  before acting — belt and braces, so a claim code can never be spent on a
  deletion.
- **`src/email.js`** — per-purpose wording. A deletion code must never read like
  a routine login code; the subject says *"confirm deleting your account"* and
  the body says what will be erased.

**Order of operations: auth first, then data.** Auth deletion is the
irreversible, security-critical step and the one the user actually asked for. If
the data sweep then fails, the account is already unreachable and support can
finish; the other order can leave a working login attached to a profile that no
longer exists, which the app has no state for. A partial sweep returns
`dataCleanupPending: true` rather than claiming success.

**Match records are deliberately kept** — they belong to every other participant
too, and the privacy policy already says so.

### App

- **`screens/delete_account_screen.dart`** — the two steps.
- **`services/otp_service.dart`** — `requestDeletionOtp()` /
  `verifyAndDeleteAccount()`, both sending a **force-refreshed** ID token (a
  cached one can be an hour old). Signs out afterwards: the session is a
  credential for something that no longer exists.
- **Settings, not the drawer**, per the user — sitting directly beneath *Deactivate
  account* so the reversible option is read first, and rendered in danger red.
  `_navRow` gained a colour parameter for it.
- 20 new `auth.delete*` keys, EN + AR.
- `_email` is read during `build`, so it is guarded — the warning must render
  even if the auth layer is not ready.

### Website

**`/app/delete-account`** — Play requires deletion to be reachable at a public
URL, without installing the app or signing in, and a reviewer will open it. An
instruction page, not a form: it documents the in-app route, the email fallback,
what is deleted, what is kept and why, timing, and points at deactivation for
anyone who only wants a break.

### ✅ Verified

`flutter analyze` → **No issues found!** · `flutter test` → **68/68** (was 62;
+6 countdown tests) · server `npm test` → **13/13** (+3 on purpose routing) ·
website `npm run build` → clean.

Against the **deployed** Worker:

| Probe | Result |
|---|---|
| Claim flow, unknown address | `not_claimable` 404 — **unchanged**, no regression |
| `purpose:delete` with no ID token | `unauthorised` **401** |
| `purpose:delete` with a junk token | `unauthorised` **401** |
| `verify-otp` delete with a junk token | `invalid_code` 400 — never reaches deletion |

### Not yet done

- **The website deploy** — `/app/privacy`, `/app/terms` and
  `/app/delete-account` 404 until the user deploys, and the app links to the
  first two.
- **A real end-to-end deletion has not been run.** Every gate is proven; the
  happy path needs a throwaway account on a device. ⚠️ Do not test it on a real
  account — it is irreversible by design.
- The Play Console listing needs the deletion URL pasted into it.

## 61. Web guest join — the website can now put someone in the lobby (2026-08-20)

⚠️ **This reverses §52a's spectate-only decision**, at the client's request. The
Join page now takes **name + email + code** and actually joins the match; the
visitor appears in the host's lobby exactly as an in-app guest does. Watching
without joining survives as *"Just watching? Skip this"*.

The `/app/*` legal pages were also moved out of the site chrome in the same pass
(§61a below).

### 🔑 The join runs on the Worker, not in the browser

This is the decision the rest hangs off, and it was forced by a rule rather than
a preference: the host's "new player joined" bell entry is written under
`users/{adminUid}/notifications`, which `firestore.rules` gates on
**`signedIn()`**. A web guest never is. A browser-side join would therefore add
the player to the lobby and **notify nobody** — the host would only find out by
staring at the roster.

Two further reasons it belongs server-side:

- A join writes **three documents that must land together** — the player, the
  match's `playerUids`, and the guest record. Written one at a time, a failure
  half-way leaves a player nobody's roster array knows about. `POST :commit`
  makes it one transaction.
- It has to match `MatchRepository.guestJoin` **field for field**, forever. Two
  implementations drift; one does not. This was the exact risk flagged when the
  page was first built.

### `server/src/guest.js` — a port, not an approximation

Writes `MatchPlayer.toMap()` in full, **including the fields left at their
defaults** (`position: null`, `goals: 0`, `assists: 0`, `isAdmin`, `isCaptain`),
so a document written by the website is indistinguishable from one written by the
app. `joinedVia: 'link'`, `isGuest: true`, `joinedAt` a real server timestamp.

Also ported: the `g_` + 10-char id from `randomCode`, the same
no-ambiguous-characters alphabet, and **`TeamSideX.id`'s UPPERCASE `'A'`/`'B'`**
— the trap from §53 that files every Team B player under Team A.

Branches exactly as `guestJoin` does:

| Match status | Behaviour |
|---|---|
| `lobby` | Joins the roster outright |
| `live` | Writes a **pending** document instead — the host approves mid-game joiners |
| `ended` / `abandoned` | **Refused**, `match_over` 409 |

### ✅ Verified end to end against live infrastructure — 25/25

Run against a **disposable match** created and then destroyed by the test, not a
real client match: a stray guest in someone's lobby is a support question, not a
test fixture.

- player document created with **every** field the app writes, in the right
  shapes (`team: 'A'`, `joinedVia: 'link'`, real `joinedAt`)
- `playerUids` contains the guest
- guest record carries the email for later claiming, `claimed: false`
- **the host's bell entry was written** — `Web Guest joined "Test Falcons".`,
  routing to `/lobby`
- an **ended** match returns `match_over` 409
- a **live** match returns `pending: true`, writes a pending document, and
  **does not** put the joiner on the roster
- everything the test created was deleted afterwards

Plus `npm test` → **45/45** web (the /join suite was rewritten — the old tests
asserted the spectate-only behaviour, which no longer exists), **13/13** server,
and the site builds clean.

⚠️ One transient `ECONNRESET` against workers.dev during the first run left an
orphaned test match, which was deleted. The harness now retries; a flaky socket
must not read as a failing feature.

### 61a. The `/app/*` legal pages lost the site chrome

At the user's request, `/app/privacy`, `/app/terms` and `/app/delete-account`
now render standalone like `/join` and `/live` — no header, footer or chatbot.

Two things had to move with them: `LegalPageShell`'s **`marginTop: -40`**, which
existed only to cancel the site `<main>`'s padding and without the chrome pulled
the title off the top of the window; and its fixed `60px 80px` padding, now
`clamp()`-based, since these are mostly opened by tapping a link inside the app.
A small YNO wordmark was added so a store reviewer landing cold can see whose
document it is.

### Still to do

- **Deploy the website** — the join form and the chrome-free legal pages are
  built but not live.
- The Worker **is** deployed (`b70115ee-1df2-49e1-b9a7-fe2a5015502a`).
- ⚠️ **The deletion test from §57 is still half-finished** — a throwaway account
  (`JbZoPbthz2UUQgzSd04vQl4owJZ2`, `huzm651@gmail.com`) exists with a profile and
  subcollection documents, waiting on the emailed code. Finish it or delete the
  account.

## 62. 👉 START HERE NEXT SESSION (2026-08-20, end of session)

Supersedes §49 and §58 as the entry point. §58's runbook is still correct and is
still the **top priority**; this section adds everything that happened after it
and the loose ends.

### What is live right now — verified at end of session

| | |
|---|---|
| `nellab.org/join` | **200** — resolves a code, and now really **joins** the match |
| `nellab.org/live` | **200** — the live scoreboard |
| `nellab.org/app/privacy` · `/app/terms` · `/app/delete-account` | **200**, no site chrome |
| Worker | `{"ok":true}` — `/request-otp`, `/verify-otp`, `/guest-join`, version `b70115ee` |
| App | `flutter analyze` clean · `flutter test` **68/68** |
| Web | **45/45** · Server **13/13** |

**Client points: 20 of 21.** Only **C17** is open, and it needs a device.

### 🔴 PRIORITY 1 — Resend domain verification (§58)

Unchanged and unstarted. `MAIL_FROM` is still `onboarding@resend.dev`, which
**only delivers to `huzm651@gmail.com`**. Until `nellab.org` is verified in
Resend, **no real user can receive an OTP** — so both the claim flow (C7) and the
new account-deletion flow are unusable by anyone but the account owner.

Full step-by-step is **§58**. The one rule that matters: Resend's records go on
**`send`** and **`resend._domainkey`** — never the root MX, never a second root
`v=spf1`, or the client's live email breaks.

### 🟠 PRIORITY 2 — a throwaway account is sitting in the client's project

**uid `JbZoPbthz2UUQgzSd04vQl4owJZ2`, email `huzm651@gmail.com`.** Created to
test account deletion (§57, §60); the test never finished because the emailed
code was not entered.

It currently holds a profile document, **3 notifications** and **1 playedWith**
document — a proper fixture for the `deleteSubcollection` walk.

⚠️ **It occupies the user's real email address in Firebase Auth**, so signing up
with `huzm651@gmail.com` in the app will fail with `EMAIL_EXISTS` until it is
gone. Two ways out, both fine:

1. **Finish the test** (the better option — it is the only untested path left in
   §60). Request a fresh code with
   `scratchpad/del_resend.mjs`, read the 6 digits from the inbox, then POST
   `/verify-otp` with `purpose: 'delete'` and the ID token. Then confirm: auth
   account gone, `users/{uid}` 404, both subcollections empty,
   `dataCleanupPending: false`.
2. **Just remove it** — `accounts:delete` with the account's own ID token needs
   no admin credentials.

The refresh token is in `scratchpad/del_state.json`; ID tokens expire hourly, so
refresh before use (`del_resend.mjs` does).

### What was built this session, in order

| § | |
|---|---|
| §51–§54 | The website pages; **C12 closed**; `kJoinBaseUrl` moved to `nellab.org/join` |
| §55–§57 | OTP Worker **deployed**, all three secrets set, delivery proven |
| §57a | Resend key **rotated** and downgraded to sending-only |
| §57b | Service-account key deleted from `Downloads` |
| §58 | The Resend-domain runbook (still open) |
| §59 | 🐛 drawer language switch fixed · "Draft Matches" rename · app legal pages |
| §60 | Account deletion — 10s hold + emailed code, server-side, plus the public page |
| §61 | Web **guest join** (reverses spectate-only) · legal pages lost the site chrome |

### Everything else still open

**Release blockers**
- ⚠️ **`applicationId` is still `com.example.ynoapp`.** Decided value is
  `org.nellab.yno`. Not a rename: new Firebase Android app, fresh
  `google-services.json`, **all four SHA fingerprints re-registered**. Blocks
  Play, `assetlinks.json` and the Play Store URL together.
- 🔴 **FCM still sends from the admin key bundled in the APK** — every build
  ships full project-admin credentials. The Worker now exists and holds its own
  service-account key, so this is ~half a day, and it is the worst remaining
  security exposure.
- **Play Console** needs the deletion URL (`/app/delete-account`) pasted in.

**Product**
- **C17** — back-navigation slow with the keyboard open. §59 found the likely
  cause: **`unfocus()` appears nowhere in `lib/`** and `resizeToAvoidBottomInset`
  is never set, so the keyboard's dismiss animation re-lays-out the whole screen
  while the route pops. The cheap fix (unfocus before pop) was offered and not
  yet taken; a device profile settles it either way.
- 🔴 **The device run has still never happened.** It gates C17 and six §48 flows
  no human has seen work. Deferred five times.
- **Phase 2 deep links** — designed in full (spec §5), banner-marked "do not
  build yet".

**Small and cheap**
- `support@nellab.org` **must become a real mailbox** — both legal documents name
  it, and it is the account-deletion contact route. Hostinger already runs the MX.
- **Arabic review** by a native speaker: the new website copy, the `auth.delete*`
  keys, and `مسودات المباريات`.
- **`og:image`** — a 1200×630 PNG; WhatsApp previews have no picture.
- **`PLAY_STORE_URL` 404s** — `matchConfig.js`, one constant, or set it to `null`
  for the honest "not on the stores yet" text.
- **A lawyer should read** the privacy policy and terms before submission.
- `src/App.test.js` in the website project is the stale CRA scaffold and fails;
  it has never passed. Delete it whenever convenient.
- `nellab-join` Hosting site is **kept deliberately** (§54a) for a possible move
  back to a subdomain.

---

## 63. The website join now resolves the email to an ACCOUNT (2026-08-21)

⚠️ **Supersedes §62 as the entry point.** §62's open list is still accurate;
this section adds what changed and what is left.

§61 made `/join` take name + email + code and really join the match — but the
email was only *stored*, on a `guests/{g_…}` record for later claiming. Every web
visitor became an anonymous guest, so someone who already had a YNO account
appeared in the lobby as a stranger, disconnected from their profile, stats and
points.

The client asked for the branch that was missing. `/guest-join` now resolves the
address before it joins anyone:

| the email | who joins | `isGuest` | credential returned |
|---|---|---|---|
| an account exists | **that account**, keyed by its real uid | `false` | 🔑 **none** |
| no account exists | one is **created** (`autoCreated: true`, pw `123456`) and joins | `false` | custom token |
| no email at all | the old accountless `g_…` guest | `true` | none |

### `isGuest` is FALSE for both account branches, deliberately

The request said "show as guest in lobby … or added by mobile". Those are two
different rows in the app and only the second one works:

| | doc key | `isGuest` | in `playerUids` | stats | claimable |
|---|---|---|---|---|---|
| `addGuestPlayer` | `g_XXXX` | `true` | **no** | none | via `guests` |
| `addNewPlayer` (email + name) | real uid | `false` | yes | yes | via OTP claim |

An `isGuest: true` player is excluded from `playerUids` and earns nothing, so
creating an account and then filing them as a guest would waste the account. The
website join is now the **`addNewPlayer` row** — to the host's lobby it is
indistinguishable from a player they added by email in the app.

### 🔑 A token is minted ONLY for an account the request just created

`/guest-join` is public and accepts any address. Returning a custom token for an
account that **already existed** would let anyone type a stranger's email and be
signed in as them — a real privilege escalation on an endpoint with no auth. For
an account created a millisecond earlier there is nothing to take: it holds one
match, and its password is the well-known `123456` either way.

This is asserted in both suites (`join_identity_e2e` step 3, `matchPages.test.js`
"joins an existing account as itself and does NOT sign anyone in"). If either
starts failing, the protection has been removed.

### Files

**Server (`server/`)**
- `src/codes.js` — **new**. `randomCode` + the no-ambiguous-characters alphabet,
  now shared by the `g_` id and a new account's referral code.
- `src/account.js` — **new**. Port of `AuthRepository.createPlayerAccount`:
  `accounts:signUp` (admin, Identity Toolkit REST — `firebase-admin` still does
  not run on Workers) plus `profileFields()`, the full 50-field
  `AppUser.toMap()`. On `EMAIL_EXISTS` it recovers the uid via admin
  `accounts:lookup`, which is the app's `email-already-in-use` branch.
- `src/guest.js` — identity branch + a port of `MatchRepository.joinMatch`
  beside the existing `guestJoin`.
- `src/firestore.js` — `v.nul` / `v.arr` / `v.map`, needed because a user
  document has real nulls, arrays and maps in it.
- `src/index.js` — the endpoint contract in the header comment.
- `test/join.test.mjs` — **new**, 14 tests. `package.json` now runs both files.

**Website (`D:\Web\yno`)**
- `src/lib/ynoMatchAuth.js` — **new**. The one place the site signs anyone into
  the *app's* project. Everything dynamically imported, and it never throws:
  the join is already written by the time it runs, so a failed sign-in is
  cosmetic. Kept out of `ynoMatchDb.js`, whose header promises it never writes.
- `src/lib/ynoMatchDb.js` — exports `ynoApp` (the **named** `yno-match` app; the
  default app is the website's own project and signing a visitor into that would
  be a different account entirely).
- `src/pages/match-pages/JoinMatchPage.js` — email **required**, silent sign-in,
  three confirmation states (created / existing / already in).
- `src/pages/match-pages/matchI18n.js` — ⚠️ **"No account needed" was deleted.**
  It stopped being true the moment the join started making accounts, and copy
  describing the old behaviour is worse than none.

### The duplicate guard is new, and it is not cosmetic

A `g_` id was always fresh, so the first version could not collide. A real uid
can. Without the guard a second join **rewrites the player document** —
`goals` and `assists` back to zero, possibly mid-match. `/guest-join` now reads
`players/{uid}` (or `pending/{uid}` when live) first and returns
`{ok: true, already: true}`. The e2e test scores 3 goals, re-joins, and checks
they survived.

### ✅ Verified

| | |
|---|---|
| Worker | deployed, version **`04a2e502-e253-4312-b92d-e7fdaf714c6c`** (was `b70115ee`) |
| Live e2e | **57/57** — `scratchpad/join_identity_e2e.mjs`, two disposable matches |
| Server unit | **27/27** (was 13) |
| Website | **51/51** (was 45) · build compiles, bundle `main.1a41904f.js` |

The e2e proves, against live infrastructure: the auth account exists and takes
`123456` · the custom token really signs in as that uid · `users/{uid}` has all
50 `AppUser.toMap` fields with `autoCreated: true` · the player document has all
10 fields with `isGuest: false` and `joinedVia: 'link'` · `playerUids` contains
the uid · **no** `guests/` record · the host's bell entry landed · the second
join preserved 3 goals · a mixed-case address finds the same account · an
existing profile is **not** overwritten · an ended match refuses **and creates no
account** (state is checked before identity) · a live match writes `pending` and
stays off the roster. Both matches, both profiles, all notifications and **all
three auth accounts** were deleted afterwards.

⚠️ One harness trap, cost a red herring: `accounts:signInWithCustomToken`
returns `idToken`/`refreshToken` but **no `localId`** — the uid is a claim inside
the ID token. Reading `body.localId` reports a perfectly good token as broken.

### 🔴 Still to do on this

1. **Deploy `D:\Web\yno`** — `firebase deploy --only hosting`
   (project `yalla-nellab-12650`). The build is compiled and current. Until then
   nellab.org serves the old page: harmless, because it still sends an email so
   the new Worker already resolves accounts, but the copy is stale and the email
   field is still optional. Verify by **bundle hash**, not by page title — the
   `**` rewrite makes every path return the same shell (§54).
2. ⚠️ **The claim half does not work for real users yet.** "Claim it later"
   runs through the OTP flow, and `MAIL_FROM` is still `onboarding@resend.dev`.
   Until `nellab.org` is verified in Resend (**§58, still Priority 1**), an
   auto-created player can sign in with `email + 123456` but cannot receive a
   code to claim the account properly. This feature wants §58 done.
3. **Arabic review** — `emailWhy`, `enterYourEmail`, `accountCreatedNote`,
   `signedInNote`, `alreadyInTitle`, `alreadyInBody`. Joins the queue in §62.

### Stated once, and not a blocker

`/guest-join` is public, so "create a Firebase account for any address, password
`123456`" is now reachable by anyone holding a valid match code. The same is
already true from inside the app (`addNewPlayer`), so it is not a new class of
exposure — but it no longer requires installing anything. The valid-code
requirement and the per-IP rate limiter are the mitigations, and both were
already in place.

### 63a. The join form is now ONE card, not two steps (2026-08-21)

The user's report: *"on website /join page it still asking only match code and i
cannot see email and name etc."*

**Not a deploy problem — the deploy was already live.** `nellab.org` was serving
`main.1a41904f.js`, the exact bundle built above, with the new strings in it.
(Checked properly: bundle **hash**, then `grep` for the new copy inside the
served JS. The `**` rewrite makes every path return the same shell, so a page
title proves nothing — §54.)

The cause was a design decision inherited from §61: name and email were wrapped
in `{match ? … : null}` and only rendered once the code resolved. Someone
opening a share link (`?code=…`) never noticed, because the auto-lookup put them
straight on step 2. Someone opening bare `/join` saw a code box and nothing else.

The comment defending it read *"asking a stranger for their details before they
know what they are joining is how a form gets abandoned"* — a fair argument that
lost to the plainer one: **a form that appears to want one thing and then wants
three is worse than a form that says so up front.** The user chose one card.

**What changed in `JoinMatchPage.js`:**
- One `<div className="card">` holding code + name + email, one **Join the
  Match** button. The separate code-lookup button is gone.
- One `<form onSubmit={join}>` around the lot, so **enter submits from any
  field** — three separate `<form>`s previously wrapped one input each.
- The code is validated **first** on submit (`enterMatchCode`), then name, then
  email. Submit posts straight to the Worker; **it is the only authority on the
  code**, and the page no longer looks it up as a gate.
- `lookup()` is now a **quiet preview**, not a step. It runs on link-load and on
  the code field's **blur**, and swallows its errors — a red "no match" under a
  half-typed code fights the visitor as they type.
- ⚠️ **A stale preview is dropped on edit** (`matchHasCode`). Without that, the
  previous match's "you will join Falcons" note sat under a completely different
  code.
- `goLive` now refuses an empty code instead of navigating to the bare
  "No match selected" screen, which reads as a broken button.

**Tests: 51 → 53**, including the two that stop the regression coming back —
"shows the whole form on a bare visit: code, name and email" and "has no
separate code-lookup button any more" — plus preview-on-blur, no-error-while-
typing, and stale-preview-dropped.

New bundle **`main.47eac6f8.js`** (was `main.1a41904f.js`). 🔴 **Needs a
redeploy** — `firebase deploy --only hosting` in `D:\Web\yno`.

Dead string left behind: **`joinBtn`** ('Join' / 'انضم') in `matchI18n.js` has no
caller now. Harmless, left in place. (`couldNotLookup` is still used — by
`LiveMatchPage`.)

### 63b. "Just watching? Skip this" removed (2026-08-21)

At the user's request. The secondary button on the join form is gone; the
primary **Join the Match** is now the card's only button.

**⚠️ What it orphaned — checked first, per the standing rule.** That button was
`/live`'s **only entrance for someone who does not join.** Confirmed by grep, in
both projects:

- website: the only two `navigate('/live?…')` call sites were this button and
  `watchLive` on the post-join confirmation. Nothing else routes there.
- app: `lib/links.dart` says it outright — *"Its companion is
  `https://nellab.org/live`, which the join page navigates to itself; **the app
  never links there directly**."* The share link the app produces is
  `/join?code=…`, never `/live?code=…`.

So `/live` is now reachable **only after joining**, or by typing the URL. The
spectator path the page was originally built around (§52a) is closed on the web.
That is the user's call and it is recorded, not argued — but it is a real loss,
not a cosmetic one, and the cheap fix if it is ever wanted back is to share
`/live?code=…` links instead of putting the button back.

`goLive` survives — the confirmation screen's **Follow the match live** button
still uses it. A test now guards that specifically: *"still offers the live
scoreboard once you HAVE joined"*, with the comment that if it breaks, `/live`
has no entrance left anywhere.

**Archived l10n string** (this project has no git history):

| key | EN | AR |
|---|---|---|
| `justWatching` | `Just watching? Skip this` | `تشاهد فقط؟ تخطَّ هذا` |

Removed from `matchI18n.js`, with a pointer to this table left in its place.

Still-dead string, left alone and flagged: **`joinBtn`** (`Join` / `انضم`), which
lost its caller in §63a.

**Tests 53 → 54.** New bundle **`main.942035b3.js`**.

Deploy state at the end of this session, checked against the served HTML rather
than assumed: the user deployed **`main.47eac6f8.js`** (§63 + §63a — the identity
join and the one-card form) mid-session, and that is what `nellab.org/join` is
serving. 🔴 **`main.942035b3.js` is built and pending** — it adds only §63b.

### 63c. The explanatory line under the email field removed (2026-08-21)

At the user's request. The email field now stands on its own, label and input.

**⚠️ What it was doing.** That line was the **only place a visitor was told,
before submitting, that an account may be created for their email address.** The
join now silently creates one (`autoCreated: true`, password `123456`) for any
address with no YNO account behind it — §63 — and the page no longer says so up
front. `accountCreatedNote` still says it on the confirmation screen, *after*
the account exists.

Recorded rather than argued; the user asked twice for the form to be plainer and
this is consistent with that. Worth re-raising only if the privacy policy is
revisited, since it describes what the site collects.

**This is the second removal from that same slot.** The original read *"No
account needed. Give an email and your match history syncs automatically when you
sign up."* — deleted in §63 because it had become untrue. Both are archived here:

| key | EN | AR |
|---|---|---|
| `emailWhy` | `We use it to find your YNO account — or create one for you, so your stats are saved.` | `نستخدمه للعثور على حسابك في YNO — أو لإنشاء حساب لك، كي تُحفظ إحصائياتك.` |
| `noAccountSync` *(gone in §63)* | `No account needed. Give an email and your match history syncs automatically when you sign up.` | `لا حاجة لحساب. أدخل بريدًا وستتزامن سجلات مبارياتك تلقائيًا عند التسجيل.` |

A comment in `matchI18n.js` marks the slot and points here.

Tests unchanged at **54/54** — nothing asserted the line, which is itself the
sign that it was pure copy with no behaviour attached.

New bundle **`main.e354082f.js`**. Live is still `main.47eac6f8.js`, so 🔴 **one
redeploy now covers §63a + §63b + §63c**.

### The Arabic review queue for this session

Six strings added and two removed. Still needs a native speaker (§62's standing
item): `enterYourEmail`, `accountCreatedNote`, `signedInNote`, `alreadyInTitle`,
`alreadyInBody` — `emailWhy` left the queue by being deleted.

### 63d. `isGuest` now mirrors `autoCreated` · position and name carried over (2026-08-21)

The user's instruction: *"i want that anyone join from web would b consider as
guest as from app someone who we added is guest until his position etc and other
data not come"* — plus the position fix flagged in §63c's review.

§63 had made every web joiner `isGuest: false`. That was wrong against the app's
own behaviour. `addTeamRoster` (`match_repository.dart:595`) already does
**`isGuest: u?.autoCreated ?? false`** — a person a host created by email has a
real uid but no position, no photo and no history, and the app treats them as a
guest until that data arrives. The web now follows the same rule.

| the account | `isGuest` | in `playerUids` | name + position |
|---|---|---|---|
| auto-created just now | **true** | **yes** | typed name, no position |
| host-created, never claimed (`autoCreated`) | **true** | **yes** | their profile's |
| claimed / real | **false** | yes | their profile's |
| no email at all (`g_…`) | true | **no** | typed name |

It **self-heals**: `autoCreated` is cleared when the owner claims the account and
sets a password, so their next match joins as a real player.

### ⚠️ The trap this exposed — `isGuest` ≠ "has a real uid"

Conflating those two is what the first version got wrong, in the other
direction. They are separate axes:

- **`playerUids`** = has a real uid. `addTeamRoster` puts auto-created members in
  it *while flagging them guests*. Only a `g_…` id stays out — it is not a uid
  and every query reading that array would choke on it.
- **`isGuest`** = the profile is a stub.

So the array gate moved from `!isGuest` to a new **`accountless`** flag, which is
the `g_` path and nothing else. Had it stayed on `isGuest`, this change would
have silently dropped every web joiner out of `playerUids` — and with it every
"matches I played" query.

### Also fixed: identity now comes from the profile, not the form

`resolveJoiner` returns `displayName` and `position`, and both are used for the
player document, the pending document and the host's bell entry.

For an **existing** account they come from `users/{uid}`, which is what the
in-app code join does — `match_actions.dart:257` passes `me?.position` and
`me?.name`, never a typed value. Before this, a returning player joining from the
web appeared under whatever they typed, with **no position at all**. Falls back
to the typed name only when the profile has none.

### 🔴 The consequence to know about

`endMatch` branches on `isGuest` (`match_repository.dart:1083`): a guest gets a
`guests/{uid}` stats document, a non-guest gets `users.applyMatchStats` — career
goals, form, streaks, MOTM points, `playedWith` edges. **So an unclaimed web
joiner earns no career stats for that match**, and claiming afterwards does not
backfill it, because the player document is a snapshot taken at join time.

That is the app's existing behaviour for auto-created players, not something new
here — but web joins produce far more of them, so it will be hit far more often.
Two ways out if it matters, neither built: backfill on claim, or re-read
`isGuest` from the user document at `endMatch` instead of trusting the snapshot.
The second is one line and is probably the right fix.

### ✅ Verified

Worker redeployed, version **`0c35712f-1888-4644-b1e0-40df94e4976e`**.
Live e2e **62/62** (was 57) — `server/test/join_identity_e2e.mjs`, which now
claims the account mid-run (sets a name, a position, and clears `autoCreated`)
to exercise both sides of the rule in one pass. Server unit **31/31** (was 27),
including four on `isGuestProfile` — notably that `null`/absent/`'true'` are all
**not** guests, since `plain()` returns null for a missing field and an older
account predates the flag entirely.

Website untouched and still **54/54**; its pending bundle is unchanged at
`main.e354082f.js`.

### 63e. 🐛 Post-match stats no longer trust the join-time `isGuest` (2026-08-21)

The fix offered at the end of §63d, taken. It turned out to close a **real
pre-existing data-loss bug**, not just the timing case it was proposed for.

**What was wrong.** `finalizeMatch` and `resolveCommunityAward` branched on
`MatchPlayer.isGuest` — a snapshot written when the player joined. Two failures:

1. **The timing case.** Someone who claimed their account between kick-off and
   the final whistle was still filed as a guest for that whole match.
2. **🔴 The data-loss case, which nobody had noticed.** The guest branch writes
   `guests/{uid}`, and `claimGuestStats` finds those records with
   `.where('email', ...).where('claimed', isEqualTo: false)`. That write sets
   **neither field** — it merges only goals/assists/result/surface/format. For a
   player holding a real uid (an `addNewPlayer` account, an `addTeamRoster`
   auto-created member, or now a web joiner) the stats went into a document
   **nothing can ever look up**. Gone for good.

**The fix.** `MatchRepository._playersWithAccounts` resolves, live, which player
uids have a `users/{uid}` document, and the pure predicate
`earnsCareerStats(player, uidsWithAccounts)` in `models.dart` replaces every
`!p.isGuest` in the post-match path — MOTM points, career stats, played-with,
notifications, the MOTM notification, and the community award six hours later.

The question it asks is the one that actually matters: **is there an account to
credit?** An accountless `g_…` guest is the only kind without one, and theirs is
the only case whose stats belong in `guests` — where the record *does* carry the
email that makes it claimable.

⚠️ Every uid is looked up, `g_` ids included. Filtering them by prefix first
would save a little query room but makes the answer depend on guessing an id's
shape, and guessing wrong sends a real player's stats down the guest branch. A
`g_` id simply has no document — the same answer, assuming nothing.

**`isGuest` keeps its real job**: it is the lobby's GUEST badge
(`lobby_screen.dart:567`), the live screen's label, and the post-match
"not on YNO" tap. Display only, which is what the user asked for in §63d.

### Also: `addNewPlayer` was inconsistent with the rest of the app

Adding a player by email in the lobby produced `isGuest: false`, while the
*identical* account reached through `addTeamRoster` produced `isGuest: true`
(`u?.autoCreated ?? false`). The same person looked like a guest one way and a
full player the other. `addNewPlayer` now reads the profile back and uses the
same rule — and its **name and position** too, so adding someone already on YNO
no longer relabels them with whatever the admin typed.

⚠️ **Visible consequence:** a player added by email now shows the GUEST badge
where they did not before, and the post-match **Add Friend** button and profile
tap are suppressed for them until the account is claimed
(`post_match_screen.dart:786` and `:854`). That is consistent with the §63d
rule; it costs them no stats, because of the fix above.

### ✅ Verified

| | |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | **75/75** (was 68) — 7 new on `earnsCareerStats` |
| Server unit | 31/31 |
| Live e2e | 62/62, re-run after all of this |
| Website | 54/54 |

The new tests lock both directions: an `isGuest: true` player WITH an account
earns stats, an `isGuest: false` player WITHOUT one does not, and a loop asserts
the flag never changes the answer either way.

🔴 **Not verified on a device.** `finalizeMatch` has never been run against live
Firestore — that is the device run deferred six times now (§62). The decision
rule is unit-tested and the surrounding I/O is unchanged apart from one added
`getUsers` call, but the end-to-end path is still unwitnessed.

### 63f. Both motives checked against the app, field for field (2026-08-21)

Website deployed by the user (`main.e354082f.js` live, hash-matched against the
local build; new copy present, removed copy absent; every built asset 200).

`server/test/motive_check.mjs` — **23/23 live** — states the two motives in the
user's terms and asserts the website's documents against **expectations derived
from the Dart source**, not from what the server happens to return:

| motive | the app path it must match | result |
|---|---|---|
| no account → "join the way we add a guest in matches" | lobby **Add Player** = `addNewPlayer` → `createPlayerAccount` + `joinMatch` | **10/10 fields identical** |
| has an account → "join like an actual player" | in-app **join by code** = `joinMatch` with `me?.name` + `me?.position` | **10/10 fields identical** |

Also confirmed live for motive 1: real account created, `autoCreated: true`,
email attached so the claim flow can find them, `123456` signs them in, GUEST
badge shows, in `playerUids`, host notified. For motive 2: their own uid, their
own name and position, no account created, no credential returned, profile
untouched, in `playerUids`.

**The only field that differs from an in-app join is `joinedVia`** — `'link'`
where the app writes `'added'` or `'code'`. A provenance label; `grep` confirms
nothing in `lib/` ever reads it back.

### 🔎 Dead code found while establishing the comparison

**`MatchRepository.addGuestPlayer` has no callers.** Nothing in `lib/` invokes
it. The lobby's "Add Player" sheet requires an email and calls `addNewPlayer`, so
the accountless-guest-added-by-a-host path does not exist in the UI at all.

`guestJoin` itself is still reachable — but only from **`guest_join_screen`**
(`Routes.guestJoin`), where an accountless person joins by code from inside the
app and gets a `g_` id plus a `guests/` record. That is the path
`claimGuestStats` was built for and it still works.

So there are two guest concepts, not one, and only the second is what the
website mirrors:

| | id | `playerUids` | claimed via |
|---|---|---|---|
| `guest_join_screen` (accountless, in-app) | `g_…` | no | `guests/` record, by email on sign-up |
| lobby Add Player / **website** | real uid | yes | OTP claim, or `123456` |

`addGuestPlayer` left in place, flagged not deleted — it is the only remaining
caller-free wrapper around `guestJoin` and removing it is a separate decision.

### ⚠️ The middle case, stated so it is a decision and not a surprise

An account that **exists but has never been claimed** (a host added them by email
in the app weeks ago) joins from the web as a **guest**, not as an "actual
player" — because `autoCreated` is still true. That follows the §63d rule the
user asked for ("guest until his position etc and other data not come") rather
than the "has an account → actual player" phrasing. It costs them nothing:
§63e means they still earn full career stats, and the badge clears itself the
moment they claim.

---

## 64. Open items as of the web-join work (2026-08-21) — SUPERSEDED by §66

⚠️ Written mid-session, before the §65 UI pass existed. **§66 is the entry
point** and carries this list forward. Kept for the detail it records — read §66
first, then come back here if you need the reasoning.

### What is live and verified right now

| | |
|---|---|
| `nellab.org/join` | `main.e354082f.js` — one-card form, account-backed join |
| `nellab.org/live` · `/app/privacy` · `/app/terms` · `/app/delete-account` | 200 |
| Worker | `0c35712f-1888-4644-b1e0-40df94e4976e` |
| App | `flutter analyze` clean · `flutter test` **75/75** |
| Server | unit **31/31** · live e2e **62/62** · motive check **23/23** |
| Website | **54/54** |

Client points: **20 of 21**. Only **C17** is open, and it needs a device.

### 🔴 PRIORITY 1 — Resend domain verification (§58). Now worse than it was.

`MAIL_FROM` is still `onboarding@resend.dev`, delivering **only to
`huzm651@gmail.com`**.

§63 changed the stakes. Every web joiner now gets an `autoCreated` account that
is **claimable by OTP — and not one of them can receive the code.** Account
deletion is equally unusable for anyone else, and Play requires a working
deletion route. Everything built in §63–§63f runs into this wall.

Runbook is §58, mostly a dashboard job. The rule that matters more than the rest:
Resend's records go on **`send`** and **`resend._domainkey`** only. **Never edit
the root MX, never add a second root `v=spf1`** — the client's live email is on
that domain and two SPF records is a permanent break.

### 🟠 PRIORITY 2 — the throwaway account, and what depends on it

uid **`JbZoPbthz2UUQgzSd04vQl4owJZ2`**, email **`huzm651@gmail.com`**. Left
mid-deletion-test in §57/§60. It occupies the user's real address in Firebase
Auth, so signing up with it in the app fails `EMAIL_EXISTS`.

⚠️ **New dependency, do not delete it blind.** Both live harnesses —
`server/test/join_identity_e2e.mjs` and `server/test/motive_check.mjs` — sign in
as this account to create and delete their disposable matches (Firestore rules
require a signed-in user for that). Its refresh token lives in the §61 session
scratchpad, `del_state.json`. Delete the account and both harnesses need a new
host before they run again. Cheap to swap, but it is not free.

### Release blockers, unchanged

- ⚠️ **`applicationId` is still `com.example.ynoapp`.** Decided value
  `org.nellab.yno`. Not a rename — new Firebase Android app, fresh
  `google-services.json`, all four SHA fingerprints re-registered. Blocks Play,
  `assetlinks.json` and the store URL together.
- 🔴 **FCM still sends from the admin key bundled in the APK.** Every build ships
  full project-admin credentials. The Worker holds its own service-account key
  now, so this is ~half a day, and it is the worst remaining exposure.
- 🔴 **The device run has still never happened.** Deferred six times. It gates
  **C17**, six §48 flows nobody has watched work, and now also **§63e's
  `finalizeMatch` change** — the one piece of the web-join work that could not be
  verified against live infrastructure. Everything else in §63 was.
- **Play Console** needs the deletion URL (`/app/delete-account`) pasted in.

### Small and cheap

- **Arabic review** — five strings added 2026-08-21 (`enterYourEmail`,
  `accountCreatedNote`, `signedInNote`, `alreadyInTitle`, `alreadyInBody`) join
  the existing queue (the §51 website copy, the `auth.delete*` keys,
  `مسودات المباريات`). Native speaker, not a dictionary.
- `support@nellab.org` **must become a real mailbox** — both legal documents name
  it and it is the account-deletion contact route. Hostinger already runs the MX.
- **`addGuestPlayer` is dead code** (found in §63f) — no callers anywhere in
  `lib/`. One-line delete, left in place deliberately.
- **`PLAY_STORE_URL` 404s** — `matchConfig.js`, one constant, or set it to `null`
  for the honest "not on the stores yet" text.
- **`og:image`** — a 1200×630 PNG; WhatsApp previews have no picture.
- **`src/App.test.js`** in the website project is the stale CRA scaffold and has
  never passed. Delete whenever convenient.
- Two dead l10n keys on the website: **`joinBtn`** (§63a) and **`couldNotLookup`**
  is still used by `LiveMatchPage`, so only `joinBtn` is actually dead.
- **A lawyer should read** the privacy policy and terms before submission.
- **Phase 2 deep links** — designed in full (spec §5), banner-marked
  "do not build yet".

### Decisions confirmed 2026-08-21, do not re-open

- An account that **exists but was never claimed stays a guest** on the web join.
  The user was asked directly and confirmed. See §63d/§63f.
- `isGuest` is **display only**; stats are decided by `earnsCareerStats` against
  the live `users/{uid}` document (§63e).
- A custom token is minted **only** for an account the request just created
  (§63). Never relax this — `/guest-join` is public and takes any address.

---

## 65. App UI pass — auth app bars, and "Join" means join a match (2026-08-21)

### (a) App bars removed from Login and Sign-up

Both were `YnoScaffold(appBarTitle: …)`. Sign-up's title said CREATE ACCOUNT
directly above a heading saying CREATE ACCOUNT; moving between the two screens is
done with the link at the bottom of each.

⚠️ **Two things travelled with the app bar and would have broken quietly:**

1. **`SafeArea(top: false)`** on both screens. That was only correct while the
   AppBar absorbed the status-bar inset — without the bar, the headings run under
   the notch. Flipped to a plain `SafeArea`.
2. **The AppBar carried the only back button**, and two routes push these
   screens: `welcome_screen` (which is also the **only** pre-auth place the Terms
   and Privacy Policy links appear) and **`post_match_screen:553`**, where a
   guest taps "Register now" from their scorecard. With no back affordance that
   guest is stranded on a signup form and loses their match result.

So both screens now show a **`BackChip`** — the app's own back control, the one
`ScreenHeader` already uses, not a new widget — rendered only when
`Navigator.canPop()`. `guest_join_screen` reaches sign-up via
`pushNamedAndRemoveUntil`, so there it correctly shows nothing.

### (b) "Join" now means join a MATCH. Team joining moved to the drawer.

Home → يلا نلعب → **Join** opened a second question (Match / Team tabs) before it
could do anything. Every player heading into a game answered a question that only
mattered to someone who was not trying to play.

- `showJoinByCodeSheet` is match-only: one field, one button. Its `allowTeam`
  parameter, `mode`, the `SegmentedTabs` and the whole `joinTeam` closure are
  gone. Gained an **`onSubmitted`** so the keyboard's enter key works — the exact
  omission that made client point C18 feel broken.
- The sheet row is now labelled **Join Match** (`home.joinMatch`, already existed).
- New **`lib/screens/join_team_screen.dart`** + **`Routes.joinTeam`**, reached
  from a new drawer row under **Play**. A straight lift of the old tab's logic,
  keeping both refusal cases — a disbanded team and one you are already in —
  since losing either turns a clear message into a silent no-op. Errors render
  **inline** rather than as a toast: on a full page the message belongs beside
  the field, and a toast fired on a sheet context was C18's other half.
  It navigates with `pushReplacementNamed` — returning to a code you have just
  spent is a dead end.

### (c) 🐛 The Help FAQ was describing screens that do not exist

Found while checking what the join change made stale. Three of five answers were
wrong, two of them for months:

| answer | claimed | reality |
|---|---|---|
| `faqStartA` | "or the Play tab" | the bottom nav bar was deleted in §39 |
| `faqJoinA` | "browse open games under **Find a Match**" | `find_match_screen` was deleted; every match is private and code-joined |
| `faqTeamA` | "Open **My Teams** from the menu" | My Teams is deliberately not in the drawer (§39) — it is on Home |

All three rewritten, EN + AR. Help copy naming a missing screen is worse than no
help at all.

### l10n

Archived in `.claude/l10n_removed_keys.md` and removed: **`home.joinWithCode`**,
**`home.joinByCode`**. Added: `drawer.joinTeam`, `home.enterTeamCode`,
`home.couldNotJoinTeam`. Reworded: `home.joinWithCodeSub` ('Enter a match or team
code' → 'Enter the match code').

⚠️ **`common.match` and `common.team` lost their only call site** (the removed
SegmentedTabs labels) and were **kept** — single generic words, likely wanted
again, cost nothing. Flagged rather than deleted.

`flutter analyze` clean · `flutter test` **75/75**.

🔴 **Not seen running.** No device or emulator run — the layout reasoning for (a)
in particular (status-bar inset, chip placement) is unverified by eye. An AVD
does exist: `Medium_Phone_API_36.1`.

### (d) Side A's team picker is a grid of badge tiles

Was: a labelled row of pill chips reading `🛡️ Name`, and — if you owned no teams
— a completely different empty-state signpost row. Two layouts for one choice,
and which one you saw depended on whether you happened to own a team.

Now one layout always: a short line, then a `Wrap` of **72px square badge tiles
with the team name underneath**, ending in a **"+" tile**. Own no teams and the
grid is just the "+".

- Badge rendering moved to a shared **`TeamBadge`** in `widgets/common.dart` —
  it was about to be a second copy of `teams_screen._badge`'s
  upload → preset emoji → first-letter fallback chain. `teams_screen._badge` is
  now a thin wrapper, so the two cannot drift. `TeamBadge` takes the three
  fields rather than a `TeamModel`, keeping `widgets/` out of `services/`.
  It also gained an `errorBuilder`: a dead Cloudinary URL used to render
  Flutter's grey broken-image box inside the badge.
- `Wrap`, not `GridView` — this sits inside a scrolling form, where a nested
  scrollable needs `shrinkWrap` plus disabled physics to behave. A Wrap of
  fixed-width tiles reads as a grid and just works.
- Team names are user-typed, so the label is `maxLines: 2` + ellipsis; a long
  name must not make its tile taller than its neighbours.

🔴 **The "+" tile forced a real fix.** `_savedTeams` was loaded with
`watchUserTeams(uid).first` — **a single read in `initState`**. Leaving to create
a team and coming back would not have refreshed the grid, so the new team would
be missing and the button would look broken. Now a live `StreamSubscription`,
cancelled in `dispose`.

`_teamChip` was removed (sole caller gone).

`flutter analyze` clean · `flutter test` **75/75**. Still unseen on a device.

### (e) The last tile is "Team A", not "+" (2026-08-21, same session)

Reversing (d)'s "+" tile at the user's direction. The grid's last tile now shows
the letter **A**, labelled **Team A**, and it is the *no saved team* option — the
default. Selected whenever `_teamAId == null`.

That closed something (d) had left open: the unlinked state lit **no** tile at
all, and the only route back to it was re-tapping the team you had already
picked. The grid now always shows exactly one choice lit.

- The tile carries a small **ⓘ**. Tapping it shows a tooltip for **4 seconds**:
  *"Start the match as Team A, then add players in the lobby with an invite or
  the match code."* It answers "what happens if I pick nothing?", which the tile
  alone cannot.
- ⚠️ `triggerMode: TooltipTriggerMode.manual` plus an explicit
  `ensureTooltipVisible()`. A tap-triggered `Tooltip` and the tile's own tap both
  enter the gesture arena, so asking for the explanation would also have changed
  the selection.
- ⚠️ Hidden by a `Timer`, **not** by `Tooltip.showDuration` — that only applies
  to the built-in tap/long-press triggers. Under a manual trigger the tooltip
  sits there until something else steals a tap. Cancelled in `dispose`.
- **`_useDefaultTeam` is deliberately not `_unlinkTeam`.** The latter (the text
  field's lock icon) leaves the old name behind on purpose, as an editable
  starting point. This one restores `Team A`, because a tile reading "Team A" lit
  above a field reading "Falcons" is a straight contradiction.

### 🔎 Found while making the tile honest

`'Team A'` and `'Team B'` were **three literals each** — the controller's initial
value and two `isEmpty` fallbacks at save time. Now `_kDefaultTeamA` /
`_kDefaultTeamB`, because the tile has to display exactly what gets stored and a
fourth copy is how that quietly stops being true.

⚠️ Deliberately **not** localised. They are written onto the match document and
read by every participant, so a match created in Arabic would otherwise show one
team name to its creator and a different one to an English player in the same
lobby.

### Copy and scope

- Heading reworded to **"Pick your team"** (`match.useYourTeam`).
- `match.newTeam` replaced by `match.defaultTeamInfo` (the tooltip);
  `match.noTeamsYetSub` rewritten again — it now reads "No saved teams — play as
  Team A and add players in the lobby."
- ⚠️ **The create-a-team shortcut has left this screen** — it was the "+". Teams
  are made on the Teams page again, which is what the original §14 note said
  ("no create-team shortcut here"). Worth knowing if someone later wonders where
  it went: it was added in (d) and removed in (e), hours apart, on request.
- The live `_savedTeams` subscription introduced in (d) was **kept**. Its
  original justification (the "+" leaving and returning) is gone, but it is
  correct for its own sake — a one-shot read goes stale the moment a team is
  created, renamed or left elsewhere. Its comment was rewritten so it no longer
  cites a button that does not exist.

`flutter analyze` clean · `flutter test` **75/75**.

🔴 Still unseen on a device. That is now **four** UI changes deep (§65a–e), and
the tooltip in particular — trigger arena, dismissal timing, position against
the tile — is the kind of thing only a real tap settles. AVD available:
`Medium_Phone_API_36.1`.

---

## 66. START HERE NEXT SESSION (2026-08-21, mid-session) — SUPERSEDED by §69

Supersedes **§64**, which was written mid-session and does not know about the UI
pass (§65). Everything §64 listed as open is still open unless repeated here.

### What this session did, in order

| § | |
|---|---|
| §63 | **Web join resolves the email to an account** — existing account joins as itself, unknown address gets an auto-created one. Server + website. |
| §63a | The `/join` form became **one card**; name and email no longer hidden behind the code. |
| §63b | "Just watching? Skip this" **removed** — and with it `/live`'s only entrance for a non-joiner. |
| §63c | The explanatory line under the email field **removed**. |
| §63d | **`isGuest` mirrors `autoCreated`** (the app's own `addTeamRoster` rule), and identity comes from the profile, not the form. |
| §63e | 🐛 **Post-match stats stopped trusting the join-time flag** — closed a real, pre-existing data-loss bug. |
| §63f | Both motives **verified field-for-field against the Dart source**, 23/23 live. |
| §65a | **App bars removed** from Login and Sign-up. |
| §65b | **"Join" means join a match.** Team joining moved to its own drawer page. |
| §65c | 🐛 The **Help FAQ** was describing three screens that no longer exist. |
| §65d–e | The side-A team picker became a **grid of badge tiles** ending in a **"Team A"** default tile with an info tooltip. |

### Green at end of session

| | |
|---|---|
| App | `flutter analyze` clean · `flutter test` **75/75** |
| Server | unit **31/31** · live e2e **62/62** · motive check **23/23** |
| Website | **54/54** · `main.e354082f.js` live and verified |
| Worker | `0c35712f-1888-4644-b1e0-40df94e4976e` |

### 🔴 PRIORITY 1 — Resend domain verification (§58)

Unchanged, unstarted, and **more consequential than it was**. `MAIL_FROM` is
still `onboarding@resend.dev`, delivering only to `huzm651@gmail.com`.

Every web joiner now gets an `autoCreated` account that is claimable by OTP —
and none of them can receive the code. Account deletion is equally unusable for
anyone else, and Play requires a working deletion route.

The rule that matters: Resend's records go on **`send`** and
**`resend._domainkey`** only. **Never edit the root MX, never add a second root
`v=spf1`** — the client's live email is on that domain.

### 🔴 PRIORITY 2 — the device run, which now gates a great deal

Deferred **seven** times. It gates:

- **C17**, the last open client point (§59 found the likely cause: `unfocus()`
  appears nowhere in `lib/`).
- Six §48 flows nobody has watched work.
- **§63e's `finalizeMatch` change** — the only part of the web-join work that
  could not be verified against live infrastructure.
- **All five UI changes in §65**, none of which has been seen running. The
  §65e tooltip especially: gesture-arena behaviour, dismissal timing and where
  it lands against a 72px tile are settled by a real tap, not by reading code.

An AVD exists: **`Medium_Phone_API_36.1`**. Everything in SESSION_PROGRESS before
§47 claiming otherwise is wrong.

### 🟠 PRIORITY 3 — the throwaway account, and what depends on it

uid **`JbZoPbthz2UUQgzSd04vQl4owJZ2`**, email **`huzm651@gmail.com`**. Occupies
the user's real address in Firebase Auth, so signing up with it fails
`EMAIL_EXISTS`.

⚠️ **Do not delete it blind.** Both live harnesses —
`server/test/join_identity_e2e.mjs` and `server/test/motive_check.mjs` — sign in
as this account to create and delete their disposable matches. Its refresh token
is in the §61 session scratchpad (`del_state.json`). Removing the account means
finding a new signed-in host before either harness runs again.

### Release blockers, unchanged

- ⚠️ **`applicationId` is still `com.example.ynoapp`** (decided: `org.nellab.yno`).
  New Firebase Android app, fresh `google-services.json`, four SHAs
  re-registered. Blocks Play, `assetlinks.json` and the store URL together.
- 🔴 **FCM still sends from the admin key bundled in the APK** — worst remaining
  exposure. The Worker holds its own service-account key, so ~half a day.
- **Play Console** needs the deletion URL (`/app/delete-account`) pasted in.

### Arabic review — the queue grew a lot this session

A native speaker, not a dictionary. Added 2026-08-21:

- **Website (§63):** `enterYourEmail`, `accountCreatedNote`, `signedInNote`,
  `alreadyInTitle`, `alreadyInBody`.
- **App (§65):** `drawer.joinTeam`, `home.enterTeamCode`,
  `home.couldNotJoinTeam`, `match.useYourTeam`, `match.useYourTeamSub`,
  `match.noTeamsYetSub`, `match.defaultTeamInfo`, `home.joinWithCodeSub`.
- **Rewritten (§65c):** `home.faqStartA`, `home.faqJoinA`, `home.faqTeamA` —
  these were factually wrong, so the Arabic is a fresh translation, not a tweak.

Plus the pre-existing queue: the §51 website copy, the `auth.delete*` keys, and
`مسودات المباريات`.

### Dead code and dead strings found this session

Flagged, deliberately **not** deleted unless noted:

- **`MatchRepository.addGuestPlayer` has no callers** (§63f). The lobby's Add
  Player sheet requires an email and calls `addNewPlayer`, so "host adds an
  accountless guest" does not exist in the UI. `guestJoin` survives only through
  `guest_join_screen`.
- **`common.match` / `common.team`** lost their only call site with the removed
  SegmentedTabs (§65b). Kept — single generic words.
- **`joinBtn`** on the website lost its caller in §63a. Kept.
- Removed and archived in `.claude/l10n_removed_keys.md`: `home.joinWithCode`,
  `home.joinByCode`, `match.noTeamsYet`, and the website's `justWatching` and
  `emailWhy`.

### Small and cheap

- `support@nellab.org` **must become a real mailbox** — both legal documents name
  it and it is the account-deletion contact route. Hostinger already runs the MX.
- **`PLAY_STORE_URL` 404s** — `matchConfig.js`, one constant, or `null` for the
  honest "not on the stores yet" text.
- **`og:image`** — a 1200×630 PNG; WhatsApp previews have no picture.
- **`src/App.test.js`** in the website project is the stale CRA scaffold and has
  never passed.
- **A lawyer should read** the privacy policy and terms before submission.
- **Phase 2 deep links** — designed in full, banner-marked "do not build yet".

### Decisions confirmed this session — do not re-open

- An account that **exists but was never claimed stays a guest** on the web join.
  Asked directly, confirmed (§63d/§63f).
- `isGuest` is **display only**; stats are decided by `earnsCareerStats` against
  the live `users/{uid}` document (§63e).
- A custom token is minted **only** for an account the request just created
  (§63). `/guest-join` is public and takes any address — never relax this.
- **Team creation is not reachable from match creation.** A "+" tile was added
  in §65d and removed in §65e, hours apart, on request. Teams are made on the
  Teams page.

---

## 67. ✅ PRIORITY 1 CLOSED — nellab.org verified, production sender live (2026-08-21)

The blocker §58 opened, §62/§64/§66 each re-listed as PRIORITY 1, and that made
both account claiming and account deletion unusable for every real user, is
**done**. `MAIL_FROM` is no longer Resend's shared test sender.

### The DNS, and the thing that had to not break

All three records went on `send` / `resend._domainkey`, exactly as §58 required.
Verified independently against `8.8.8.8` **after** the user added them:

| Type | Name | Value |
|---|---|---|
| `TXT` | `resend._domainkey` | DKIM `p=MIGf…IDAQAB` (218 chars — under the 255 single-string TXT limit, so no splitting) |
| `TXT` | `send` | `v=spf1 include:amazonses.com ~all` |
| `MX` | `send` | `feedback-smtp.ap-northeast-1.amazonses.com`, priority 10 |

⚠️ **The check that actually mattered** — the client's live email on the root,
confirmed untouched after the edit:

- `MX nellab.org` → still `mx1` (5) + `mx2.hostinger.com` (10)
- `TXT nellab.org` → still **exactly one** `v=spf1`, still Hostinger's, plus the
  Firebase `hosting-site=` ownership token

Region is **`ap-northeast-1`** (Tokyo). It only sets the return-path host, so it
does not affect delivery. Recorded because a Resend domain's region **cannot be
changed after creation** — switching means deleting and re-adding the domain.

### The swap

`server/wrangler.toml` — the commented line was uncommented and the test sender
deleted. The stale comment above `[vars]` (which told a future reader the domain
was *not* yet verified) was rewritten; leaving it would have been a false
instruction sitting directly above the line it described.

```toml
MAIL_FROM = "YNO <no-reply@nellab.org>"
```

A plain var, not a secret — `npx wrangler deploy`, nothing re-set.

| | |
|---|---|
| Version | `abf679e8-03d5-47ce-bc24-2356e734b493` (was `0c35712f-1888-4644-b1e0-40df94e4976e`) |
| Bindings at deploy | Cloudflare's own output echoed `env.MAIL_FROM ("YNO <no-reply@nellab.org>")` |
| Secrets | `SERVICE_ACCOUNT_JSON`, `OTP_PEPPER`, `RESEND_API_KEY` — all three still set |
| `/health` | `{"ok":true,"service":"yno-otp"}` |
| Unit tests | **31/31** |
| Live join e2e | **62/62**, cleanup pass confirmed every disposable document removed |

### 🟠 What is NOT yet proven — do not mark C7 fully closed

**No email has been observed arriving at a non-owner address.** The e2e harness
uses `@example.com` addresses and never calls `/request-otp`, so 62/62 proves the
deploy broke nothing — it says nothing about delivery.

The remaining test, offered and not yet run: create a disposable match →
`/guest-join` with an address the user can read (suggested
`ibralisyed+yno1@gmail.com`; Gmail plus-addressing reaches the real inbox while
Firebase Auth treats it as a separate account) → `/request-otp` → read the code →
complete the claim → delete the match and the account.

⚠️ Run it with `npx wrangler tail` streaming, so a failure names its step rather
than being guessed at. And **check the spam folder before calling it a failure** —
a sending domain with no reputation history is filed aggressively on first
contact.

### Follow-up now unblocked, but deliberately not done

Tightening `_dmarc` from `p=none` to `p=quarantine` — §58's rule stands: **only
after a real send has been observed**, never before, or legitimate mail starts
landing in spam.

---

## 68. Client batch (2026-08-21) — keyboard dismissal + team names are no longer typed

Two points. The first turned out to be **C17**, the last open point from the §48
batch — §59 had already diagnosed it and nobody had fixed it.

### (a) ✅ C17 — tapping outside a field now closes the keyboard

The client's report: the keyboard only went away via the phone's back button.

The cause was exactly what §59 predicted. **`unfocus`, `FocusScope` and
`FocusManager` appeared nowhere in `lib/`** — re-confirmed by grep before
touching anything. Nothing in the app ever dropped focus, so nothing ever closed
the keyboard.

New **`DismissKeyboard`** in `widgets/common.dart`, wrapped **once** around
`MaterialApp.builder` in `app.dart` — outside `ActiveMatchGate`, so it covers the
gate's own subtree — rather than copied into 34 screens.

⚠️ **Two choices are load-bearing, and both are easy to "tidy" into a bug:**

1. **`HitTestBehavior.translucent`, not `opaque`.** The child is hit-tested
   first, so buttons, rows and the text fields themselves keep working and this
   recogniser only wins the arena for taps that reach empty space. `opaque`
   swallows every tap in the app — the dismissal would work and nothing else
   would.
2. **`FocusManager.instance.primaryFocus`, not `FocusScope.of(context)`.** This
   widget sits **above** the Navigator, so its context resolves to the root
   scope; unfocusing that leaves the field inside the current route still
   focused and the keyboard still up.

**`test/dismiss_keyboard_test.dart` — 2 new tests, both green.** One asserts a
tap on empty space drops focus; the other asserts a button underneath still
fires, which is the `opaque` failure mode. 🔑 **This is the first §48-batch point
proven by test rather than by reading code** — no device needed for this one.

### (b) Team name fields removed — the name is derived, not typed

Client: *"we don't need to edit team names — Team A stays A, own team names
remain, same for team B; challenge someone or Team B is the default."*

Both `YnoTextField`s are gone from `_teamSide`. Each side now **displays** a
name that is always one of exactly two things: a linked team's own name, or the
constant default.

- `_teamA` / `_teamB` `TextEditingController`s → plain `String _teamAName` /
  `_teamBName` (+ `dispose` entries removed). A controller with no field is
  dead weight.
- `_teamAFinal` / `_teamBFinal` getters are what actually gets written.
- **`_unlinkTeam` now restores the default name**, and the separate
  `_useDefaultTeam` added in §65e is folded into it. §65e deliberately kept them
  apart because the lock icon left the old name as an *editable starting point* —
  with no field to edit, a side reading "Falcons" with nothing linked would show
  a name the user could neither explain nor change.
- The text field's lock icon went with the field. Nothing was lost: side A
  unlinks by tapping the lit tile or the "Team A" tile, side B by the challenge
  card's ✕.

🔴 **The trap this had to avoid.** `_loadMatch` still assigns `m.teamAName`
**verbatim**. A match created before this change can carry a hand-typed name, and
deriving the name from scratch on save would have **silently renamed** it to
"Team A" the next time its creator opened the edit screen. The strings are
loaded, displayed and written back untouched; only the *ability to type* is
gone.

### (c) The ⓘ for side B, and a shared tooltip

Client: *"add proper helper text so user knows what Team A or B means — like
Team A already has an info button, add something like this with Team B."*

New **`match.teamBInfo`** (EN + AR) on an ⓘ beside side B's name: *"The
opponent. Leave it as Team B and add their players in the lobby, or challenge a
real team with their code below."*

Placement is deliberately **not** symmetric: side A's ⓘ stays on its "Team A"
tile, next to the choice it describes. Side B has no tile grid — B is never
picked from a list — so its ⓘ sits against the name and carries the whole
explanation of the side.

§65e's tooltip mechanics are now a shared **`_InfoTip`** widget rather than a
second hand-rolled copy. Both warnings that made §65e subtle survive in its
doc comment: **`triggerMode: manual` + `ensureTooltipVisible()`** (a
tap-triggered Tooltip and the tile's own tap both enter the gesture arena, so
asking for the explanation would also change the selection) and **dismissal by
`Timer`, not `Tooltip.showDuration`** (which only applies to the built-in
triggers). `_defaultTeamTipKey`, `_tipTimer` and `_showDefaultTeamInfo` left the
State with it.

### 🐛 (d) Found while in there — two pre-existing wrong messages

**`match.savedTeamNameLocked` was rendering on side B.** It reads *"Saved team —
name locked. **Edit it in My Teams.**"*, and side B's linked team is one you
**challenged** — someone else's team, not in your My Teams and not yours to
rename. It has been showing on every challenge. Now scoped to side A; the
challenge card below already explains that side.

**The challenge notification could name a meaningless team.** The body was
`_teamA.text` with an "A player" fallback only when the field was *empty*. With
no field, an unlinked side A is always the literal string "Team A" — so the
recipient would have read *"Team A challenged you"*, which tells them nothing.
Now the fallback keys off `_teamAId == null` instead: a real linked team is
named, an unlinked side stays the generic `match.aPlayer`. Strictly better than
the old behaviour, not just preserved.

### l10n

Added: **`match.teamBInfo`** (EN + AR).

⚠️ **`match.team` and `match.nameLower` lost their only call site** — together
they built the removed field's hint (`"Team A name"`). **Kept, not deleted**,
following the §66 precedent for `common.match` / `common.team`: single generic
words, likely wanted again, cost nothing. Flagged here so the next l10n prune
knows they are orphans by choice.

Nothing archived to `.claude/l10n_removed_keys.md` this pass.
`match.savedTeamNameLocked`, `match.editTeamLinksLocked`, `match.aPlayer` and
`match.defaultTeamInfo` all still have exactly one call site — verified by grep,
not assumed.

### Green

`flutter analyze` clean · `flutter test` **77/77** (was 75; +2 for C17).

🔴 **Still unseen on a device.** (b) and (c) join the §65 backlog: the new ⓘ's
position against the name row, and how the name row reads without a field box
around it, are settled by looking at them. (a) is the exception — it is
test-covered.

---

## 69. 👉 START HERE NEXT SESSION (2026-08-21, end of session)

Supersedes **§66**. Two things it listed as blockers are **closed**; what
remains has been re-ranked accordingly.

### What this session did

| § | |
|---|---|
| §67 | ✅ **PRIORITY 1 CLOSED.** `nellab.org` verified in Resend, `MAIL_FROM` is now `no-reply@nellab.org`, Worker redeployed. |
| §68a | ✅ **C17 CLOSED** — the last open point of the §48 batch. Tapping outside a field now closes the keyboard, and it is **test-covered**. |
| §68b–c | Team name fields removed from match creation; names are derived, side B gained an ⓘ. |
| §68d | 🐛 Two pre-existing wrong messages found while tracing (b), neither reported by the client. |

### Green at end of session

| | |
|---|---|
| App | `flutter analyze` clean · `flutter test` **77/77** (was 75) |
| Worker | unit **31/31** · live join e2e **62/62** · version `abf679e8-03d5-47ce-bc24-2356e734b493` |
| Website | **54/54** · `main.e354082f.js` live (unchanged this session) |
| Sender | `YNO <no-reply@nellab.org>` — DKIM + return path verified |

---

### 🟠 PRIORITY 1 — finish the OTP delivery proof (15 minutes, needs the user)

**§67 is deployed but not proven.** No email has been observed arriving at an
address other than the Resend account owner's. The live e2e uses
`@example.com` addresses and **never calls `/request-otp`**, so 62/62 says the
deploy broke nothing and says nothing at all about delivery.

The test, already scoped and offered: create a disposable match → `/guest-join`
with an address the user can read → `/request-otp` → they read the code back →
complete the claim → delete the match and the account.

- Suggested address: **`ibralisyed+yno1@gmail.com`** — Gmail plus-addressing
  reaches the real inbox while Firebase Auth treats it as a separate account,
  so nothing collides with the user's real address.
- ⚠️ Run it with **`cd server && npx wrangler tail`** streaming, so a failure
  names its step instead of being guessed at.
- ⚠️ **Check the spam folder before calling it a failure.** A sending domain
  with no reputation history is filed aggressively on first contact.
- Only **after** a real send is observed may `_dmarc` go `p=none` →
  `p=quarantine`. Never before.

### 🔴 PRIORITY 2 — the device run

Deferred **seven** times, and it is now the single biggest blocker. ✅ **C17 has
left this backlog** (§68a is proven by `test/dismiss_keyboard_test.dart`). What
it still gates:

- **Six §48 flows** nobody has watched work.
- **§63e's `finalizeMatch` change** — the only part of the web-join work that
  could not be verified against live infrastructure.
- **All five §65 UI changes.** The §65e tooltip especially: gesture arena,
  dismissal timing, and where it lands against a 72px tile.
- **The §68 create-screen changes** — how the team name rows read now that no
  field box surrounds them, and where side B's new ⓘ sits against the name.
  Both are look-at-it questions.

AVD: **`Medium_Phone_API_36.1`**. Anything before §47 claiming no AVD exists is
wrong.

### 🟠 PRIORITY 3 — the throwaway account

uid **`JbZoPbthz2UUQgzSd04vQl4owJZ2`**, email **`huzm651@gmail.com`**. Occupies
the user's real address in Firebase Auth, so signup with it fails
`EMAIL_EXISTS`.

⚠️ **Do not delete it blind.** Both live harnesses —
`server/test/join_identity_e2e.mjs` and `server/test/motive_check.mjs` — sign in
as this account to create and delete their disposable matches. Its refresh token
is read from a **previous session's** scratchpad; verified present this session
at
`…/D--Flutter-ynoapp/ca529d78-1239-4103-9791-3c22a606f641/scratchpad/del_state.json`.
Removing the account means finding a new signed-in host first.

### Release blockers, unchanged

- ⚠️ **`applicationId` is still `com.example.ynoapp`** (decided:
  `org.nellab.yno`). Not a rename — new Firebase Android app, fresh
  `google-services.json`, four SHAs re-registered. Blocks Play,
  `assetlinks.json` and the store URL together.
- 🔴 **FCM still sends from the admin key bundled in the APK**
  (`assets/firebase_admin_key/service_account.json`, key `fade14a1…`). Worst
  remaining exposure — every APK ships full project-admin credentials. The
  Worker holds its own key already, so ~half a day. **Do not simply delete the
  file**: the app sends push directly from the device with it.
- **Play Console** needs `/app/delete-account` pasted in as the deletion URL —
  which now genuinely works, since §67 made the codes deliverable.

### Arabic review queue — grew again

A native speaker, not a dictionary.

- **Added §68:** `match.teamBInfo`.
- **Added §65:** `drawer.joinTeam`, `home.enterTeamCode`, `home.couldNotJoinTeam`,
  `match.useYourTeam`, `match.useYourTeamSub`, `match.noTeamsYetSub`,
  `match.defaultTeamInfo`, `home.joinWithCodeSub`.
- **Rewritten §65c:** `home.faqStartA`, `home.faqJoinA`, `home.faqTeamA` — fresh
  translations, not tweaks; the originals were factually wrong.
- **Added §63 (website):** `enterYourEmail`, `accountCreatedNote`,
  `signedInNote`, `alreadyInTitle`, `alreadyInBody`.
- Plus the pre-existing queue: the §51 website copy, the `auth.delete*` keys,
  and `مسودات المباريات`.

### Orphaned strings — kept on purpose, flagged so a prune knows

- **`match.team` + `match.nameLower`** (§68) — together they built the removed
  field's hint. Single generic words; kept per the §66 precedent.
- **`common.match` / `common.team`** (§65b) — same reasoning.
- **`joinBtn`** on the website (§63a) — lost its caller, kept.
- **`MatchRepository.addGuestPlayer` has no callers** (§63f). The lobby's Add
  Player sheet requires an email and calls `addNewPlayer`, so "host adds an
  accountless guest" does not exist in the UI.

Archived removals live in **`.claude/l10n_removed_keys.md`**. Nothing was
archived in §67–§68.

### Small and cheap

- **`support@nellab.org` must become a real mailbox** — both legal documents
  name it and it is the account-deletion contact route. Hostinger already runs
  the MX, so it is an hPanel add.
- **`PLAY_STORE_URL` 404s** — `matchConfig.js`, one constant, or `null` for the
  honest "not on the stores yet" text.
- **`og:image`** — a 1200×630 PNG; WhatsApp previews have no picture.
- **`src/App.test.js`** in the website project is stale CRA scaffold and has
  never passed.
- **A lawyer should read** the privacy policy and terms before submission.
- **Phase 2 deep links** — designed in full, banner-marked "do not build yet".

### Decisions confirmed — do not re-open

- **Resend records go on `send` and `resend._domainkey` only.** Never edit the
  root MX, never add a second root `v=spf1` — the client's live email is on that
  domain. Re-verified untouched after §67.
- **Resend region is `ap-northeast-1`** and **cannot be changed** without
  deleting and re-adding the domain. It only sets the return-path host.
- **No full-access Resend key exists** (§57a). Rotation needs the dashboard.
- **The client chose to keep password `123456`** for host-created accounts. It
  is a decision, not a bug. See the OTP memory before "fixing" it.
- **Team creation is not reachable from match creation.** Teams are made on the
  Teams page.
- **`'Team A'` / `'Team B'` are deliberately NOT localised** — they are written
  onto the match document and read by every participant.
- An account that **exists but was never claimed stays a guest** on the web
  join, and a custom token is minted **only** for an account the request just
  created. `/guest-join` is public and takes any address — never relax this.

---

## 70. ✅ PRIORITY 1 CLOSED — a real OTP was delivered to a real inbox (2026-08-29)

**§69's priority 1 is done.** A 6-digit code left the Worker, went through
Resend from `no-reply@nellab.org`, and **arrived in a third-party Gmail inbox —
not spam**. The user read it back and it was spent successfully. Delivery is no
longer an assumption.

Sender confirmed by the recipient as `nellab.org`. This is the first time any
address other than the Resend account owner's has been observed receiving mail
from this service.

### The blocker that had to be removed first

🔴 **`del_state.json` is GONE.** §69 said the throwaway host's refresh token was
"verified present" at the `ca529d78-…` scratchpad. That directory still exists
and is **empty** — session scratchpads do not survive. Both live harnesses read
it by absolute path:

- `test/join_identity_e2e.mjs:20`
- `test/motive_check.mjs`

**They cannot run as written.** Anything in §63/§69 that treats 62/62 as
re-runnable is now false until they are repointed.

🔴 **And `huzm651@gmail.com` does not take password `123456`** —
`accounts:signInWithPassword` returns `INVALID_LOGIN_CREDENTIALS`. So the
account cannot be recovered from a known password either. **§69's priority 3 is
now blocked on a password only the user has**, and the two harnesses above have
lost their host.

### The fix — the proof harness hosts itself

Rather than wait on that account, the new harness **creates its own host**:

```
accounts:signUp  ->  a throwaway  yno.otphost.<seed>@example.com
```

Legal because the live rules are permissive enough (`firestore.rules:56-58`
and `41-43`):

```
match /matches/{mid} { allow write: if signedIn(); }
match /users/{uid}   { allow write: if signedIn(); }
```

Any signed-in user may create and delete a match. **No admin credential, no
service-account key, and no pre-existing account is needed** to run the whole
flow. 🔑 **The same trick repoints `join_identity_e2e.mjs` and
`motive_check.mjs`** — neither actually needs *that* account, only *an*
account. That is the cheap fix for the broken harnesses; it was not done this
session.

### 🔴 The target address cannot be a real account

The user asked to send to `huzm651@gmail.com` instead. **It cannot work**, and
the reason is worth keeping:

`requestOtp` (`src/index.js:161`) gates on
`claimable = !!user && user.autoCreated === true`, else `not_claimable` 404 —
**and no mail is sent at all**. Only a host-created account can be claimed; a
real one must use password reset.

`users/JbZoPbthz2UUQgzSd04vQl4owJZ2` has **no `autoCreated` field** (its fields
are exactly `name, lastName, matchesPlayed, points, email, careerGoals,
firstName`). So the bare address would have produced a 404 and proved nothing.

⚠️ **Do not "fix" this by adding `autoCreated: true` to that profile.** It is
the super-admin in `firestore.rules`, the Firebase CLI login, and the Resend
account owner.

**`huzm651+yno1@gmail.com` was used instead** — same inbox, distinct address,
separate Firebase account. It is also a *stronger* proof than the bare address:
the old shared-sender restriction was an exact-address allowlist, so the bare
address is the one that would have delivered even before verification.

### Results

| check | |
|---|---|
| `/guest-join` creates the claimable account | ✅ `isNewAccount: true`, `isGuest: true` |
| `/request-otp` accepted | ✅ 200, no `console.error` in `wrangler tail` |
| **the email arrives, in the inbox, from `nellab.org`** | ✅ **user-confirmed** |
| the emailed code is accepted | ✅ 200 |
| a **custom token** comes back, not `{ok:true}` | ✅ the §49 requirement holds |
| the token is for the account the join created | ✅ `l81cfH5My…` |
| the same code cannot be spent twice | ✅ replay → `invalid_code` |

🔑 **`email.js:85` throws on any Resend rejection**, which surfaces as a 500 plus
a logged error. A clean 200 with a silent tail therefore means Resend *accepted*
the message — that is what makes the tail worth streaming.

### 🐛 A trap that bit again — `signInWithCustomToken` returns no `localId`

The first verify run reported a false FAIL on "the custom token really signs
in", with an **empty detail string** — the tell, because both `body.localId` and
`body.error` were `undefined`.

`accounts:signInWithCustomToken` returns `kind, idToken, refreshToken,
expiresIn, isNewUser` — **and no `localId`**. The uid is a claim *inside* the ID
token (`user_id`). Confirmed by probe this session.

⚠️ **`join_identity_e2e.mjs:149` already documents this exact trap in a comment.**
It was written after being hit once and hit again anyway, by a throwaway script
that did not read it. **Decode `user_id` from the ID token; never check
`localId`.** The three new scripts now do.

### New files — `server/test/`

The scratchpad losing `del_state.json` is precisely why these live in the repo
now:

| file | |
|---|---|
| `otp_delivery_send.mjs <email>` | disposable host + match → `/guest-join` → `/request-otp` |
| `otp_delivery_verify.mjs <code>` | spends the code; 5 assertions |
| `otp_delivery_cleanup.mjs` | removes every artefact |

State passes between them via `otp_state.json` (gitignored, alongside
`probe_uid.txt`).

⚠️ **Cleanup refuses to delete an account it did not create** — it exits on
`isNewAccount !== true`. Without that guard a mistyped target address points
`accounts:delete` at a real account.

`server/README.md`'s "Sender domain" section was **stale** — it still described
`onboarding@resend.dev` as current and told the reader to swap in nellab.org
once verified, which §67 had already done. Rewritten, plus a "Proving delivery
again" section.

### Cleaned up

Run 1 (`ibralisyed+yno1@gmail.com`, unusable — the user had no access to that
inbox) was fully removed: match, both subcollection docs, both profiles, and
**both auth accounts**. Nothing was left in the client's Firebase.

### Still open

- 🔴 **The device run** — now unambiguously the top item. Unchanged from §69.
- 🔴 **`join_identity_e2e.mjs` + `motive_check.mjs` are broken** (above). Fix is
  the self-hosting trick; ~20 minutes.
- 🟠 **The throwaway account** — now needs a password only the user has. If it is
  lost, the account can still be removed from the Firebase console.
- Everything else in §69's release-blocker list is unchanged: `applicationId`,
  the bundled FCM admin key, `support@nellab.org`, `PLAY_STORE_URL`, `og:image`.
- `_dmarc` may now go `p=none` → `p=quarantine`: §69's precondition ("only after
  a real send is observed") **has been met**.

---

## 71. 🔴 CORRECTION — there is NO AVD on this machine (2026-08-29)

**Every claim from §47 onward that `Medium_Phone_API_36.1` exists is FALSE.**
It is asserted in six places (§lines 137, 2504, 4912, 5006, 5066, 5411) and in
the memory file `yno-android-signing.md`. Checked directly this session:

```
$ flutter emulators
Unable to find any emulator sources. Please ensure you have some
Android AVD images available.

$ flutter devices
Windows (desktop) · Chrome (web) · Edge (web)      <- that is all
```

`~/.android/avd/` is empty. The name was repeated forward from session to
session and **never verified**.

⚠️ **The toolchain is NOT the problem** — do not go debugging it. `flutter
doctor` is clean: Flutter 3.35.6 stable, Android SDK 36.1.0, Android Studio
2025.1.4, "No issues found!". There is simply no AVD defined.

### What the device run therefore actually costs

It was being scheduled as "boot the AVD and look". It is not. First someone
must either:

- **create an AVD** — Android Studio Device Manager or `avdmanager`, which
  needs a system image **download** (multi-GB), or
- **attach a real phone** with USB debugging on.

🔑 **Ask the user which**; do not assume the emulator route. A real device is
often faster here and is the better test for the §65e tooltip's gesture arena
and the §68 create-screen layout, which are the "look at it" questions.

### ⚠️ Decide before running, either way

The app points at the client's **live** Firebase (`yno-app-e96f5`). A device run
signs in and **writes real data into the client's project** — matches, profiles,
notifications. That is exactly what §70's harness went to the trouble of
avoiding with disposable accounts and a full sweep.

Either use a throwaway account and clean up after, or get the client's
agreement that test data in their project is fine. Do not discover this
mid-session with a stray lobby already created.

### The pattern, twice in one day

`del_state.json` (§70) and this AVD were both **asserted as present in
SESSION_PROGRESS and both absent in reality**. Anything in these notes naming a
file, account, device or credential is a claim about a past machine state, not
a fact. **Verify before planning on it.** Both cost a detour today.

---

## 72. ✅ THE DEVICE RUN HAPPENED — found a crash on the join path, and fixed it (2026-08-29)

Eight deferrals ended. Ran on a **real phone**, not an emulator (there is none —
§71): Xiaomi **M2010J19SG** (`lime`), Android 12 / API 31, arm64, MIUI 14.

Driven entirely over `adb` — taps, text, `uiautomator dump` for coordinates,
`screencap` for the look-at-it questions. Throwaway account
`huzm651+ynotest@gmail.com` (uid `1W4xozza…`), swept afterwards.

### 🔴 The find: joining a match by code crashes the screen

**`lib/widgets/match_actions.dart` — `showJoinByCodeSheet`.** Enter a valid
code, tap Join: the player **is added to the match** and then the UI dies.

```
A TextEditingController was used after being disposed.
The relevant error-causing widget was:
  TextField  lib/widgets/inputs.dart:141:20
```

Red screen in debug. 🔑 **The write succeeds first** — `Yno Tester` was in
`matches/{id}/players` every time — so this is not data loss; it is the joiner
never arriving in the lobby they just joined. Reproduced **twice**, deliberately,
after resetting the match between runs.

⚠️ The first red screen quoted a *different* assertion
(`framework.dart:6171 '_dependents.isEmpty'`). §72 originally called that "the
same root cause, different cascade". **That was overconfident — see §74.** A
synthetic harness reproduces `_dependents.isEmpty` with a correctly owned
controller and no dispose anywhere, so it is a focus-scope teardown assertion
that can fire independently. The controller bug is real and fixed; whether the
`_dependents` one is a second, still-open fault is **unresolved**. It has not
recurred since the fix.

**Cause, exactly:**

```dart
final code = TextEditingController();
...
  Navigator.pop(sheetCtx);
  Navigator.pushNamed(context, route, arguments: match.id);  // over the closing sheet
...
await showModalBottomSheet<void>(...);
code.dispose();          // runs the instant the sheet POPS
```

`showModalBottomSheet` completes its future when the route is **popped**, not
when the exit animation finishes — the subtree keeps rebuilding throughout. So
`code.dispose()` killed a controller the `TextField` was still rebuilding with,
and the `pushNamed` immediately after the `pop` **forced exactly that rebuild**.
The two faults triggered each other, which is why it is 100% reproducible rather
than a race.

**Fix applied.** The sheet body is now `_JoinByCodeSheet`, a `StatefulWidget`
owning the controller (a `State.dispose()` runs when the route is really gone),
and it hands its destination back through `Navigator.pop(context, (route, id))`
so **the caller navigates after the sheet is gone**. Both halves are needed;
fixing either alone leaves the other live.

⚠️ **This pattern — `final c = TextEditingController(); await showModalBottomSheet(...); c.dispose();` — is a bug wherever it appears.** It was not audited
for elsewhere this session.

### ✅ Verified on the device by eye

| | |
|---|---|
| §65a | auth screens have their back-arrow app bar |
| §65b | "Join Match · Enter the match code" — Join means a MATCH |
| §68b | **both team-name fields are gone**; A and B read as headings beside their badges. Reads cleanly — no orphaned box, no "why can't I type here" |
| §68c | side B's ⓘ works, full `match.teamBInfo` text renders |
| §65e | 🔑 **the gesture arena holds** — tapping the ⓘ *inside* the Team A tile showed the tip and **did not change the selection**. This was the whole reason for `triggerMode: manual` |
| §68c | the `Timer` dismissal works — side B's tip vanished on its own |
| §48 C16 | `Custom · 4v4 · 5v5 · 6v6 · 7v7 · 8v8 · 9v9 · 11v11`, Custom first, description visible unselected. No 1v1/2v2/3v3 (D4 holds) |
| §48 C6/C13–15 | the empty own-team state renders real text ("No saved teams — play as Team A…") instead of nothing |
| §39 | new Home, no bottom bar |
| §48a C1 | **YALLA NELLAB** on Home — the spelling the client confirmed twice |

🟠 **Cosmetic:** both tooltips render *above* their trigger (`preferBelow: false`)
and clip the line above — B's covers the "Team A" caption, A's covers "Pick your
team". Legible, but it hides content while open.

🟠 **Also seen, not chased:** a cold start showed **"No internet connection"**
while the device had working network (`ping 8.8.8.8`, 0% loss). RETRY recovered
immediately. Looks like a connectivity-check race on startup. Not filed as a bug
— seen once.

ℹ️ `ActiveMatchGate` does **not** pull a user into a *lobby* match on launch,
only a live one. Worth knowing before reading §29's "sticky live match" as
covering both.

### ✅ The fix is verified ON THE DEVICE, and C11 with it

Rebuilt and repeated the exact steps: **0 exceptions**, and the join now lands in
the lobby it was supposed to —

    LOBBY  CODE · TEST FALCONS  DEV1428  https://nellab.org/join?code=DEV1428
           A  TEST FALCONS  NO CAPTAIN  1/5  ·  YT Yno Tester · Midfielder · YOU

That also confirms **§54** in passing: the lobby shares the real
`nellab.org/join` URL, not the dead `yno.app` one.

**✅ C11 — a player can leave a lobby, and the host really loses them.** Being a
non-admin in that lobby made this free to check. The bar reads "Waiting for the
admin to start the match." + **LEAVE MATCH**, and it is *confirmed*, per the §20
convention ("Leave this match? You will be taken off the te…" / CANCEL / LEAVE
MATCH). After confirming, Firestore agreed:

    players:     Dev Host     <- the tester player doc is gone
    playerUids:  5Ct9LGwB     <- and the uid left the array

Back to Home cleanly, no exception. 🔑 **This is the first §48-batch flow proven
against live infrastructure rather than by reading code.**

### Not reached

**C9 + C19** (a non-host held on "the host is deciding" until the shootout score
is entered) and **C8** (request to join a public team). Both need the second
participant to act *while* the phone watches, and the phone had no battery left
for it — it sat at **3%** the whole session.

The second actor is built and works: `scratchpad/mk_match.mjs` stands up a
disposable host and a lobby match with a join code, the same self-hosting trick
as §70. 🔑 **Move it into `server/test/` before it is lost** — a scratchpad
dying is exactly what §70 and §71 were about.

### ⚠️ Two device facts worth keeping

- 🔑 **MIUI refuses a USB install while the screen is LOCKED**, with the same
  `INSTALL_FAILED_USER_RESTRICTED` as a missing permission — so it looks like the
  toggle reverted when it did not. Cost two dead ends. Check
  `dumpsys window | grep mDreamingLockscreen`; wake with `input keyevent
  KEYCODE_POWER` and swipe up, then install.
- **MIUI blocks `adb install` silently.** `adb push` reports success and the file
  is then **discarded** (`ls` → No such file). Needs *Developer options →
  Install via USB*. `INSTALL_FAILED_USER_RESTRICTED` is the tell.
- ⚠️ **`flutter run` auto-uninstalls a differently-signed build of the same
  `applicationId`.** It removed the release APK that was on the phone
  (`INSTALL_FAILED_UPDATE_INCOMPATIBLE` → "Uninstalling old version…"). Debug and
  release keys differ, so this happens every time. `app-release.apk` is still in
  `build/app/outputs/flutter-apk/` to put back.
- `flutter attach` failed with its own tooling bug ("Bad state: Stream has
  already been listened to"). Use `flutter run` to get Dart stacks; **logcat does
  not carry them**.
- Flutter text fields ignore `input keyevent` (backspace/TAB) — only
  `input text` commits, via the IME. To retype a field, clear app data; to move
  between fields, close the keyboard and tap by dumped coordinates. TAB jumps to
  the CTA, not the next field.

### Green

`flutter analyze` clean · `flutter test` **77/77** (unchanged — the fix is a
lifecycle correction, and the existing suite has no join-sheet coverage).
🟠 **No test covers this crash.** A widget test that pumps the sheet, joins, and
settles the exit animation would have caught it and would guard the fix.

### Release APK restored (2026-08-29, end of session)

`app-release.apk` is back on the phone — debug uninstalled first (signatures
differ), release installed, verified as release by
`flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP ]` with **no DEBUGGABLE**,
versionName 1.0.0, and it launches. The phone is as it was before this session.

---

## 73. Harnesses repointed · the dispose-after-sheet audit (2026-08-29)

### ✅ Both live harnesses run again

§70 found them dead: each read a host refresh token from an absolute path inside
a **session scratchpad** that no longer exists. Neither needed *that* account,
only *an* account.

New **`server/test/_disposable_host.mjs`** — `createDisposableHost(apiKey, fsBase)`
signs up a throwaway via `accounts:signUp`, optionally gives it a profile, and
returns `destroy()`. Legal with no admin credential because
`firestore.rules` allows any signed-in user to write `matches/{mid}` and
`users/{uid}`. Both harnesses now call it and destroy the host in their existing
cleanup step (`auth:host` joins the removal list).

**Run live, not assumed:**

| | |
|---|---|
| `node test/motive_check.mjs` | **23/23** |
| `node test/join_identity_e2e.mjs` | **62/62** — the historical number, restored |
| `npm test` | **31/31** |

Both report *"everything this test created was removed"*, host included.

🔑 **Nothing in `server/test/` reads a scratchpad path any more.** That failure
mode is closed, not worked around.

### 🟠 The dispose-after-sheet audit — 4 more sites, none fixed

Grepped every `TextEditingController()` in `lib/`. Controllers held as **State
fields are fine** (disposed in `dispose()`). The dangerous shape is a
**local** created in a function, then disposed after an awaited sheet:

| site | |
|---|---|
| `lobby_screen.dart:871` — Add Player (name/contact/search) | 🟠 real user path, admin-facing |
| `team_manage_screen.dart:389` | 🟠 |
| `team_manage_screen.dart:564` (two controllers) | 🟠 |
| `team_manage_screen.dart:900` | 🟠 |
| `admin_dashboard.dart:609` (`showDialog`) | lowest risk — no keyboard inset, admin web only |

**All four sheets carry `MediaQuery…viewInsets` padding and a
`StatefulBuilder`; none does a `push` after `pop`.** That is the difference
from §72: the join sheet had *both* triggers, which is why it failed 100% of the
time. These have only the keyboard one — when the keyboard collapses during the
exit animation the sheet subtree rebuilds, and by then the controllers are
already disposed. **Latent, not theoretical.**

⚠️ **Deliberately NOT fixed this session.** The correct fix is the §72 one — move
the sheet body into a `StatefulWidget` that owns its controllers — and that is a
real refactor of four large sheets (`lobby_screen`'s is ~230 lines with 13
`setSheet` calls). **There is no device available to verify them on**, and
shipping four unverified refactors of live user paths is worse than shipping a
documented list. The phone sat at 3% all session and now has the release APK
back on it.

🔑 **Do these with a charged phone, one at a time, exercising each sheet after.**
Start with `lobby_screen` — it is the only one an ordinary user reaches.

---

## 74. All five dispose-after-sheet sites fixed (2026-08-29)

§73 listed four unfixed sites and deferred them for want of a device. Done now,
plus the `lobby_screen` one it called out first.

### What changed

| site | shape used |
|---|---|
| `lobby_screen.dart` — Add Player | **extracted `_AddPlayerSheet`** (StatefulWidget) |
| `team_manage_screen.dart` ×3 — invite / add-guest / disband | **controllers hoisted to `_TeamManageScreenState`** |
| `admin_dashboard.dart` — type-to-confirm | **controller hoisted to `_AdminDashboardState`** |

🔑 **Two shapes, deliberately, not inconsistency.** `lobby_screen`'s sheet was
self-contained, so the §72 extraction applies cleanly and it also moves the
invite toast to the caller, where the context outlives the sheet.
`team_manage_screen`'s three sheets call **State helper methods**
(`_friendsInviteList`, `_searchRow`), so extracting widgets would have dragged
those along for no safety gain. Hoisting to the State is equally correct — a
controller cannot outlive its owner — and far less surface. Each sheet does
`..clear()` on open so nothing carries between opens.

⚠️ **`_confirmDisband` keeps its `removeListener`.** The listener closes over
that call's `canConfirm` and `setSheetRef`; leaving it attached would let the
next open drive a dead sheet. Only the `dispose()` went.

🔴 **`_confirmDisband` was the worst of the four** — it has *both* triggers, like
the join sheet: `Navigator.pop(sheetCtx)` followed by `popUntil(...)`, plus a
listener on the controller. It was closer to a certain crash than §73 implied.

### Verified

`flutter analyze` clean · `flutter test` **77/77** · a re-grep confirms **no
function-local `TextEditingController` remains in `lib/`**, and no `dispose()`
follows an awaited sheet or dialog anywhere.

### 🟠 The regression test does NOT exist — three attempts, all removed

§72 said no test covered this crash. It still doesn't, and the honest reason:

A synthetic harness **did reproduce the real fault exactly** — same
"A TextEditingController was used after being disposed" on the same
`ChangeNotifier.addListener` stack, which is strong confirmation of the
diagnosis. But the harness also threw `_dependents.isEmpty` **in the fixed
configuration**, with a State-owned controller and no dispose at all. A test
that fails for a reason unrelated to its own claim is worse than no test, so it
was deleted rather than shipped green-by-luck.

🔑 **The useful by-product:** that is what falsified §72's "same root cause"
line, now corrected above. `_dependents.isEmpty` is a focus-scope teardown
assertion that fires on its own; it is **not** proven to be the controller bug's
cascade.

⚠️ **What would actually guard this** is a widget test over the *real* sheets,
which needs the repositories mocked — `MatchRepository`/`UserRepository` are
singletons reached via `.instance`, with no seam. That is the prerequisite, and
it is a bigger job than the fix was.

### ✅ Four of five verified on the device (see §75)

**None of these five has been opened on the phone.** The lobby extraction is the
one to watch — it is a real widget extraction, not a field move, and it changed
where the invite toast is raised. The other four are mechanical.

The phone has the **release APK** back on it (§72), so checking these means
installing the debug build again and then restoring release afterwards. Do it
with a charged phone: open Add Player (both tabs, invite someone), the three
team-manage sheets, and the admin type-to-confirm.

---

## 75. The five sheet fixes, verified on the phone (2026-08-29)

§74 shipped them unverified. Four are now exercised on the handset —
**0 exceptions across the entire session**, with `flutter run` attached the
whole time so any would have been caught.

🔑 **The fifth cannot be reached from a phone.** `admin_app.dart` is **web-only**
— `main.dart` runs `AdminApp` instead of `YnoApp` when `kIsWeb`. Its
type-to-confirm dialog needs a browser *and* a super-admin login, and
`huzm651@gmail.com`'s password is still unknown (§71). It is also the most
trivial of the five: a controller moved onto a State that already had a
`dispose()`. **Still unverified — say so, do not imply otherwise.**

### What was exercised

| sheet | what was done | |
|---|---|---|
| `lobby_screen` Add Player | opened as match admin, typed with the keyboard up, switched Guest/Registered tabs, dismissed **with the keyboard still up** | ✅ |
| `team_manage` Invite Player | typed a query, dismissed with the keyboard up | ✅ |
| `team_manage` Add Guest | filled **both** fields, dismissed with the keyboard up | ✅ |
| `team_manage` Disband | typed the team name, watched the listener enable DELETE, confirmed → `pop` **+ `popUntil`** | ✅ |

🔑 **The disband one is the real result.** It carries *both* triggers — the
keyboard-driven `viewInsets` rebuild and a navigation after the pop — the same
combination that made the join sheet fail 100% of the time in §72. It ran clean,
the team was deleted, and MY TEAMS came back reading "1 deleted teams".

Also confirmed incidentally: the `..clear()` on reopen works (both the
team_manage guest sheet and the extracted lobby sheet came back empty), and the
disband listener still drives the button now that the controller outlives the
sheet.

### 🟠 Not verified: the invite path's toast

`_AddPlayerSheet` pops with the invited player's name so the **caller** raises
the toast — the one behaviour change in the extraction, not just a move. It went
unexercised because the Registered tab's search returned nothing for a seeded
account.

⚠️ **That is not a bug in the sheet.** `UserRepository.search` (line 69) queries
`orderBy('usernameLower').startAt([lower]).endAt([lower])`, and the seeded
profile had no `usernameLower`. Adding it did not help either, and the IME
action may simply not be reaching `onSubmitted` under `adb`. Left alone.

🟠 **Worth a look later, unrelated to this work:** that query is
`startAt([lower]).endAt([lower])` with **no `\uf8ff`**, so it is an *exact*
match on the username — yet the field is labelled "SEARCH BY NAME OR PHONE" with
the hint "Type a name and hit enter to search". Typing a real name finds nobody.
Not filed as a client bug; nobody has reported it.

### Device notes, added to §72's list

- ⚠️ **MIUI's install permission does not stay granted.** The release install was
  refused again with `INSTALL_FAILED_USER_RESTRICTED` even with the screen
  unlocked, and went through after a wake + swipe. Budget a retry.
- `settings put global stay_on_while_plugged_in 3` keeps the screen awake for a
  long `adb` session — set it back to `0` afterwards, which was done.

### Left as found

Phone: **release APK reinstalled and verified as release** —
`flags=[ HAS_CODE ALLOW_CLEAR_USER_DATA ALLOW_BACKUP ]`, no `DEBUGGABLE`,
versionName 1.0.0, launches (pid 20670). Screen timeout restored.

Firebase: every artefact swept — the tester account, the invite-target account,
the match and the team, all confirmed 404. `users/JbZoPbthz2UUQgzSd04vQl4owJZ2`
untouched.

### Still true

`flutter analyze` clean · `flutter test` **77/77** · **no regression test for
this crash class** (§74 explains why three attempts were deleted).

---

## 76. 🔴 applicationId changed to org.nellab.yno — THE BUILD IS BLOCKED (2026-08-29)

The user asked for this ahead of a Play deployment. **The app cannot be built
until they finish the Firebase side** — this is expected, not a regression:

    FAILURE: Build failed with an exception.
    > No matching client found for package name 'org.nellab.yno'
    BUILD FAILED in 31s

### Changed (code side, done)

| file | |
|---|---|
| `android/app/build.gradle.kts:26` | `namespace` → `org.nellab.yno` |
| `android/app/build.gradle.kts:46` | `applicationId` → `org.nellab.yno` |
| `.../kotlin/com/example/ynoapp/MainActivity.kt` | **moved** to `.../kotlin/org/nellab/yno/MainActivity.kt`, `package` line updated; old dirs removed |

🔑 The manifest declares the activity as **`.MainActivity`** — relative to
`namespace` — so the Kotlin package had to move with it or the activity would
not resolve at launch.

⚠️ **`applicationId` is PERMANENT once published.** A published package name can
never be changed; a mistake means a new listing and no upgrade path for
installs. `com.example.*` is rejected by Play outright (reserved for samples),
which is why this was a release blocker from §49 onward.

### 🔴 NOT changed — the user's side

`android/app/google-services.json` still describes `com.example.ynoapp` (4
occurrences). It **cannot be hand-edited** — it carries per-app OAuth client IDs
and an API key that Firebase issues. It must be **downloaded** after registering
a new Android app.

You cannot rename an existing Firebase Android app; a new one must be added to
project **`yno-app-e96f5`**.

### The four SHAs to register (read off the real keystores this session)

    RELEASE  (android/app/yno-release.jks, alias 'yno')
      SHA1    19:6A:E2:4A:FB:57:C6:B3:51:91:42:65:2B:94:02:5E:FF:EF:50:CF
      SHA256  7D:3A:5A:21:25:D1:03:48:04:F8:E9:8E:0A:9E:80:F7:86:A7:1D:90:DD:A9:0E:A3:AA:C6:80:85:0D:30:FE:58

    DEBUG    (~/.android/debug.keystore, alias 'androiddebugkey')
      SHA1    11:01:FD:E9:23:79:18:E6:C5:86:16:C8:80:95:BA:07:0B:B6:A6:3D
      SHA256  18:14:8A:A8:77:CB:94:46:59:FA:7A:E6:AF:B3:93:D1:97:33:27:CE:72:5B:8C:D2:6E:FE:36:FD:B1:AC:FF:99

⚠️ **A fifth SHA comes later.** With Play App Signing, Google re-signs the
bundle, so production sign-in uses **Play's** certificate, not this release
keystore. Its SHA-1 is in Play Console → Setup → App signing and must also go
into Firebase, or Google sign-in works in testing and fails in the store. See
[[yno-android-signing]] — this trap is already documented there.

### Untouched on purpose

- **`android:label="ynoapp"`** — the name under the icon, still lowercase
  "ynoapp". A separate decision, not part of an applicationId change. Flagged to
  the user.
- `google-services.json.bak-pre-sha` — an older backup, left alone.
- iOS: `bundle_id` in google-services.json also reads `com.example.ynoapp`, but
  no iOS build has ever been attempted and Apple was deferred (§scope).

### 🔴 The thing that matters more than the rename

**Publishing makes the bundled Firebase admin key public.** Every build ships
`assets/firebase_admin_key/service_account.json` so the device can send FCM. A
Play release is downloadable by anyone, and unpacking an APK is trivial — that
key grants **full admin on the client's Firebase project**: read/write all data,
delete accounts, bypass every rule.

This has been "the worst remaining exposure" since §49; going public changes it
from a latent risk to an active one. The Worker already holds its own key, so
moving the send path is ~half a day. ⚠️ **Do not simply delete the file** —
push sends from the device with it today.

**Stated plainly to the user before they publish.**

---

## 77. org.nellab.yno builds — but the SHAs are MISSING (2026-08-29)

The user deleted the old `com.example.ynoapp` Firebase Android app, registered a
new one for `org.nellab.yno`, and dropped in the downloaded
`google-services.json`. **§76's block is cleared: `flutter build apk` succeeds.**

    √ Built build\app\outputs\flutter-apk\app-debug.apk
    flutter analyze -> No issues found!  ·  flutter test -> 77/77

### 🔑 The Dart side had to change too, and it is easy to miss

`main.dart:17` initialises from `DefaultFirebaseOptions.currentPlatform`, so the
Android config lives in **two** places. Replacing only
`android/app/google-services.json` leaves `lib/firebase_options.dart` pointing at
the **deleted** app — it compiles and launches, then fails at runtime.

`firebase_options.dart`'s android `appId` updated by hand:

    old  1:1082478194715:android:7946933b7c0efc91a2c8be   (deleted app)
    new  1:1082478194715:android:887a9e0ca1144002a2c8be

`apiKey` did **not** change — `AIzaSyBPjUowMJ…` is the project's Android key and
survived the re-registration.

### ✅ Deleting the old app was safe, and here is why

The Android app's key (`AIzaSyBPjUowMJ…`) is **not** the one the rest of the
system uses. The Worker (`wrangler.toml`), the website and all seven harnesses
run on `AIzaSyAC0lgsD_…`, which belongs to the separate **Web** app
registration. Verified before advising the deletion. Auth users, Firestore data,
rules and indexes are project-level and were never at risk.

### ✅ SHA fingerprints — RESOLVED same session (was a stale download)

The downloaded `google-services.json` contains **no `client_type: 1` entry and no
`certificate_hash`**. Those are created *by* SHA registration, so their absence
is proof none are attached.

Symptom to expect: `PlatformException / ApiException: 10 (DEVELOPER_ERROR)` on
"Continue with Google" — the rest of the app is unaffected.

🔑 **The file does not refresh itself.** Adding fingerprints in the console does
nothing to a JSON already on disk; it must be **re-downloaded** afterwards. That
is almost certainly what happened here — downloaded at creation, before the
fingerprints went on.

The four to attach are in §76. ⚠️ A **fifth** (Play App Signing's own
certificate) is needed after the first upload, or sign-in works in testing and
fails in the store — [[yno-android-signing]].

The web client (`client_type: 3`, `…-f3fb8e…`) **is** present and is unchanged
from the old app, so the serverClientId half of Google sign-in is already right.

**Fixed.** The user confirmed they had pasted the pre-fingerprint download; after
attaching the SHAs they re-downloaded. The current file verifies:

    client_type 1 entries : 2
    certificate_hash      : 196ae24…  -> release SHA-1 19:6A:E2:4A…
    certificate_hash      : 1101fde…  -> debug   SHA-1 11:01:FD:E9…
    client_type 3 (web)   : present
    mobilesdk_app_id      : unchanged (…887a9e0ca1144002a2c8be)

🔑 **Two OAuth clients for four fingerprints is correct** — only **SHA-1**
produces an OAuth client. The SHA-256s matter for App Links / `assetlinks.json`,
not for sign-in. Do not go hunting for two more.

The `appId` did not move on the re-download, so the hand-edit to
`firebase_options.dart` above is still valid. Rebuilt after: **build green**.

🟠 **Still unproven at runtime.** Config is structurally correct, but nobody has
watched "Continue with Google" actually work on `org.nellab.yno` — the phone's
screen was off and MIUI will not install or drive past a lock. **This is the one
thing the SHAs affect**, and it fails loudly (`ApiException: 10`) rather than
subtly, so one tap settles it: if the account picker appears, the SHAs are right;
no sign-in needs to be completed.

### 🟠 Two loose ends

- **The phone still has `com.example.ynoapp` installed** (the release APK
  restored in §75). It is now a *different package* from `org.nellab.yno`, so
  new builds install **alongside** it rather than replacing it. Uninstall the old
  one by hand once the new build is trusted.
- **iOS still reads `com.example.ynoapp`** — `firebase_options.dart`'s
  `iosBundleId` and a `client_type: 2` entry in the new JSON. Harmless today (no
  iOS build has ever been attempted, Apple deferred), but it will need the same
  treatment if iOS is ever picked up.

---

## 78. FCM sending moved to the Worker — the admin key is off the send path (2026-08-29)

The §49-onward "worst remaining exposure", started because a Play release makes
the bundled key publicly extractable (proved concretely in §77: unzipping the
`.aab` yields a full RSA private key for
`firebase-adminsdk-fbsvc@yno-app-e96f5.iam.gserviceaccount.com`).

✅ **FINISHED except for revoking the old key (step 3).** A real notification was
observed arriving on the handset, from a build with **no admin key in it**, and
the asset, its pubspec entry and the `googleapis_auth` dependency are all gone.
Details in the "Proven on the device" section below.

### Server — new `server/src/push.js`, `POST /send-push`

Deployed, version **`7052706a-814e-4fba-9f26-0eb5ed6ffefc`**. It needed no new
infrastructure: `google.js` already had `accessToken(env, scope)` with per-scope
caching and working WebCrypto RS256, so FCM was one more scope
(`.../auth/firebase.messaging`). Cost is unchanged — still the Workers free
plan.

🔑 **Two gates, both load-bearing:**

1. **The caller must present a Firebase ID token.** Verified through
   `userFromIdToken`. Without this the endpoint is an open spam relay aimed at
   real people's phones.
2. **The recipient's device tokens are resolved server-side, by uid.** The
   caller passes only a uid and **must never be allowed to pass tokens** —
   `users` is world-readable, so accepting caller-supplied tokens would let
   anyone who scraped one push to that device directly. That is the same
   impersonation hole moved to a new place.

🐛 **A silent-failure trap caught before deploy.** `firestore.js`'s `plain()`
has **no `arrayValue` branch** — it returns `null` for arrays. So
`fields(doc).fcmTokens` is `null`, not a list, and reading tokens that way would
have made every send a no-op that *looks* healthy (`sent:0, failed:0` is
indistinguishable from "user has no devices"). `push.js` reads
`doc.fields.fcmTokens.arrayValue.values` directly. **Do not "tidy" it to use
`fields()`.**

### App — `push_service.dart`

`sendToUser` now takes a **uid** and POSTs to the Worker.
`sendToToken` and the whole `_accessToken`/`ServiceAccountCredentials` path are
gone, along with the `rootBundle`/`googleapis_auth`/`flutter/services` imports
and the `adminKeyAsset`/`projectId` constants.

Only **one** call site sends — `notification_repository.emit` — and it already
had the recipient uid in hand, so the change there is one line. It still skips
the round trip when `fcmTokens` is empty.

`init`, `registerCurrentDevice` and `saveToken` are **untouched**: device-token
registration uses `firebase_messaging` and never needed the admin key.

### Verified

`flutter analyze` clean · `npm test` **31/31** · new
**`server/test/push_live.mjs` → 9/9** against the deployed Worker:

    1. THE AUTH GATE      no idToken / garbage idToken -> 401
                          missing uid / empty title+body -> 400
    2. RECIPIENT LOOKUP   signed-in caller accepted; a user with no devices and
                          an unknown uid are both successes, not errors
    3. THE ARRAY READ     a bogus token comes back failed:1 — proving it was
                          ATTEMPTED, i.e. fcmTokens really was parsed
    4. cleanup            disposable sender destroyed

🔑 **Check 3 is the one that matters.** It is what distinguishes a working
parser from the `plain()` trap above, which would otherwise report a healthy
`sent:0/failed:0` forever.

### ✅ Proven on the device (2026-08-29)

Installed on the Xiaomi handset as `org.nellab.yno`, signed in, device
registered an FCM token, then `POST /send-push` from a disposable sender:

    POST /send-push -> 200 {"ok":true,"sent":1,"failed":0}

and the phone's own notification service confirms it landed:

    pkg=org.nellab.yno   channel=default_channel   importance=4
    android.title = "YNO push test"
    android.text  = "Sent through the Worker, no key on the device."

🔑 **Then the key was deleted and the whole thing repeated.** Rebuilt, verified
the APK no longer contains `service_account.json`, reinstalled, signed in, sent
again — a **fresh** notification record (new id, new `when`) with the same
title and text. That is the part that matters: push works *because* the Worker
sends it, not because a stale key was still lying around.

0 exceptions across both runs.

**Removed:** `assets/firebase_admin_key/service_account.json`, the
`pubspec.yaml` assets entry (replaced with a do-not-re-add note) and the
`googleapis_auth` dependency. `flutter analyze` clean · `flutter test` 77/77 ·
`npm test` 31/31 · `push_live.mjs` 9/9.

Grep-confirmed after: no admin key file, no pubspec entry, no `googleapis_auth`,
and nothing in `lib/` referencing `service_account` or
`ServiceAccountCredentials`.

### 🔴 What is left

1. ~~Prove one real notification arrives.~~ ✅ done, above.
2. ~~Remove the asset, the pubspec entry and `googleapis_auth`.~~ ✅ done.
3. **Revoke key `fade14a1…`** — the only step remaining, and it is the user's. in Google Cloud → IAM → Service Accounts →
   `firebase-adminsdk-fbsvc@…` → Keys. ⚠️ Only after a new build is shipped:
   revoking kills push for anyone still on an old build.
   🔑 Verify first that the **Worker's own** `SERVICE_ACCOUNT_JSON` is a
   *different* key (§50a said a fresh one was generated for the server). If they
   are the same key, revoking it takes the Worker down with the app.

### Bonus fixed along the way

Push used to be sent **from the device** with project-admin rights, so a
repackaged APK could send arbitrary notifications to any user, impersonating
YNO. The Worker now checks who is asking. Two problems, one change.

### 🟠 Seen in the console, not chased

`E/GoogleApiManager: java.lang.SecurityException: Unknown calling package name
'com.google.android.gms'` appeared repeatedly on the handset. Common MIUI/Play
Services noise and **push worked regardless**, so it was not investigated —
but note that **Google sign-in on `org.nellab.yno` is still unproven** (§77),
and if it turns out to fail, this line is the first thing to look at.

---

## 79. 👉 START HERE — Play Store readiness audit (2026-08-29, end of session)

No code changed in this section. It is a **verified inventory** of the distance
between the repo as it stands and a live Play Store listing, done by reading the
build config, the signing setup and the artifact on disk. Everything marked ✅ or
🔴 below was checked this session against a file; nothing is recalled.

### The artifact already exists

    build/app/outputs/bundle/release/app-release.aab
    48,071,180 bytes · 2026-08-29 15:05 · built from current source

So the question is no longer "can we build a release bundle" — it is "what is
wrong with the one we have".

| | Verified | Where |
|---|---|---|
| ✅ | `applicationId = org.nellab.yno` (no `com.example.*`) | `android/app/build.gradle.kts:69` |
| ✅ | Release keystore wired, not the debug key | `build.gradle.kts:76-93`; `android/app/yno-release.jks` and `android/key.properties` both present |
| ✅ | `targetSdk`/`compileSdk` **36**, `minSdk` `max(23, …)` | `FlutterExtension.kt:23,34` (Flutter 3.35.6) — meets Play's API floor |
| ✅ | No admin service-account key inside the bundle | §78 |
| ✅ | Account-deletion URL live (`/app/delete-account`) | [[yno-website-pages]] |
| | `version: 1.0.0+1` → versionCode 1 | `pubspec.yaml:19` — correct for a first upload |

### 🔴 Blockers that are pure code, and small

**1. The app is unbranded.** This is the most visible thing wrong with it.

- `android/app/src/main/AndroidManifest.xml:5` — `android:label="ynoapp"`
- Every `android/app/src/main/res/mipmap-*/ic_launcher.png` is the **untouched
  Flutter template icon** — 442 / 544 / 721 / 1031 / 1443 bytes, all dated
  2025-10-09 (the `flutter create` date). That is the blue Flutter logo.
- No adaptive icon (`ic_launcher_foreground` / `mipmap-anydpi-v26` absent).
- `pubspec.yaml` has **no `flutter_launcher_icons` and no
  `flutter_native_splash`** — grep-confirmed, neither package is a dependency.
- Also still open from §2a: `google_fonts` fetches Barlow over the network on
  first run. Bundling the .ttf files removes a first-launch stall on a bad
  connection. Not a blocker; a quality item.

Estimated half a day, and it is the single highest-visibility fix left.

**2. 🔴 The keystore has no off-repo backup.** Repeating [[yno-android-signing]]
because a Play upload makes it *permanent*: this project has **no git history**,
and both `android/key.properties` and `android/app/yno-release.jks` are
gitignored. They exist on exactly one disk. Lose them after publishing and
`org.nellab.yno` can **never be updated again** — the package name is burned and
the app has to be re-listed from zero. Five minutes of work, unbounded downside.
**Do this before the first upload, not after.**

### ⚠️ The `123456` question — read before "fixing" it

`kAutoAccountPassword = '123456'` (`lib/services/auth_repository.dart:46`) is
still a working login for every auto-created player account, and the app's own
copy tells the match creator so (`lib/l10n/tr_match.dart:293`). The OTP flow
guards the *claim* path only — `otp_service.dart:69` documents this explicitly:

> ⚠️ Signs in with `kAutoAccountPassword`, **not** the custom token the service
> returns — a product decision (2026-08-18). The consequence is that
> `email + 123456` also still works on the normal login screen.

🔑 **This is on record as the client's decision, not an oversight** — the banner
at the top of this file and §50's first section both say the client overruled
the original security design mid-build and kept it deliberately. **Do not
silently "fix" it.**

But note what changes at publication: today the exposure is limited to people who
have the app. On Play it is public, and "knowing a player's email address is
enough to sign in as them" is the kind of thing that ends up in a review. The
right move is to **put it back to the client as a launch decision**, with the
cost attached: the service already returns a custom token, so closing it is
`verifyAndSignIn` using that token, randomising `kAutoAccountPassword`, and three
copy strings (`tr_match.dart:293-294`, `lobby_screen.dart:1083`,
`team_manage_screen.dart:583`). Small. Their call, not ours.

### 🟠 Sequenced around the upload

- **Before:** Google sign-in has **never been proven at runtime on
  `org.nellab.yno`** (§77). The SHAs are structurally verified but unwatched. It
  fails loudly (`ApiException: 10`), so **one tap settles it** — the account
  picker appearing is enough, no sign-in needs completing. If it *does* fail,
  §78's last note is the first place to look.
- **After the first upload:** register a **fifth SHA-1** — Play App Signing
  re-signs the bundle with Google's own certificate, and Google sign-in works in
  testing and **fails in production** until that fingerprint is in Firebase
  (Play Console → Setup → App signing → *App signing key certificate*).
- **After a keyless build is live:** revoke service-account key `fade14a1…`
  (§78 step 3). ⚠️ Confirm the Worker's `SERVICE_ACCOUNT_JSON` is a *different*
  key first, or revoking takes push down with it.

### The part that is genuinely not started: the Play Console

None of this exists yet, and it is most of the remaining calendar time. Nothing
here is code.

- Developer account + app record.
- **Store listing assets:** 512×512 icon, 1024×500 feature graphic, ≥2 phone
  screenshots, title / short / full description. The app is **EN + Arabic with
  RTL**, so an Arabic listing is expected — and §69's **Arabic review queue is
  still untouched and needs a native speaker**.
- **Data safety form** — the awkward one here. YNO collects email, name, photos
  (Cloudinary), device identifiers (FCM), and requests **`READ_CONTACTS`**
  (`AndroidManifest.xml:3`, for Community → Contacts). Contacts access draws
  extra scrutiny and needs a prominent in-app disclosure consistent with §41's
  two-step opt-in.
- Content rating questionnaire · target audience · ads declaration · privacy
  policy URL.
- **App access credentials for the reviewer.** YNO is auth-gated end to end;
  review fails without a working test login. Note the throwaway account
  (`huzm651@gmail.com`) is **password-locked and unusable** for this — a fresh
  reviewer account is needed.
- ⏰ 🔎 **The schedule driver, and it needs verifying against current policy:**
  a **personal** developer account is subject to Google's closed-testing
  requirement — **12 testers running a closed test for 14 continuous days**
  before production is unlocked. An **organisation** account is not. Confirm
  which account type this is before promising a date; it is the difference
  between one week and a month.

### Honest timeline

- **Internal testing track: ~2–3 days.** Icon + label, the `123456` decision
  from the client, one Google sign-in tap, rebuild, upload.
- **Public on Play: ~1 week** on an organisation account, **3–4 weeks** on a
  personal one — the extra three weeks are the 12-testers rule, not the code.

### Still unverified — and internal testing is what it is for

Unchanged from §75/§78, listed here so they are not lost behind the store work:
**C9 + C19 and C8** (both need a second participant acting while the phone
watches — `server/test/device_second_actor.mjs` exists for exactly this), the
**admin dashboard** dispose site (web-only, needs the unknown super-admin
password), and `_AddPlayerSheet`'s toast-from-caller behaviour change. Plus
§75's unresolved `_dependents.isEmpty` red screen, which fires independently of
the fixed controller bug and has not recurred.

Small ones still open from §69: `support@nellab.org` mailbox, `PLAY_STORE_URL`
404s (it lives in the website repo, **not** here — grep found no occurrence in
this tree), `og:image`, stale `src/App.test.js`, a lawyer on the legal docs.

## 80. 👉 START HERE — client batch: referral links, live extra time, six trims (2026-09-07)

Supersedes §79 as "start here". §79's Play Store audit is **unchanged and still
the release plan** — nothing below closes any of its blockers. Read §79 next.

Six client requests, all implemented. `flutter analyze` clean, debug APK builds,
website builds, website tests **61/61**. **None of it is device-verified.**

### 1. Referral links now actually carry the referral

🔴 **The bug was real and total.** `misc.shareMsgB` appended `kJoinBaseUrl` —
`https://nellab.org/join`, the **match-join** page — and the referral code sat
beside it as loose text. Every shared link went to the wrong page carrying
nothing; the friend had to read six characters off a WhatsApp message and retype
them. The referral *backend* (`referredBy`, `countReferrals`, signup validation)
was fine all along.

Both halves of the journey are handled now, because they are different
mechanisms and neither covers the other:

| Case | Mechanism | Package |
|---|---|---|
| App installed | App Link intent filter on `/r/*`, URI delivered to the app | `app_links` |
| App **not** installed | Play Store carries `referrer=` through the install | `android_play_install_referrer` |

Firebase Dynamic Links did both and was **shut down in August 2025** — do not
reach for it.

- `lib/services/referral_link_service.dart` (new) — resolves a code from either
  source, holds it in `SharedPreferences`, and **never applies it itself**.
  Install-referrer is read once per install (flagged in prefs).
- `links.dart` gains `kReferralBaseUrl` + `referralLink(code)` → `/r/<code>`.
  ⚠️ A **different path from `/join`** on purpose: different codes, different
  pages.
- Signup prefills the field and validates the code exactly as a typed one — a
  dead link is rejected with its own copy (`auth.referralLinkExpired`) rather
  than "check and try again", which is nonsense when the user typed nothing.
  Cleared only in `_enterApp()`, so backing out of signup does not lose it.
- **Already signed in →** Home raises a one-shot dialog saying a referral only
  counts at sign-up, then clears the code. That is the client's requested chip.
- Website: `/r/:code` (`ReferralPage.js`), routed standalone like `/join`. Shows
  the code large, copies it, and sends the visitor to Play **with `referrer=`
  attached**.

🔴 **Two things must be true before any of this works in the wild, and neither
is done:**

1. **`PLAY_STORE_URL` still 404s** — the listing does not exist (§79). Until it
   does, the not-installed path leads nowhere.
2. **`assetlinks.json` must be deployed and correct.**
   `public/.well-known/assetlinks.json` carries the release (`7D:3A:5A:21…`) and
   debug (`18:14:8A:A8…`) SHA-256s.
   ⚠️ **A THIRD is needed after the first upload** — Play App Signing re-signs
   the bundle with Google's certificate, so App Links work in testing and
   **fail in production** until that fingerprint is added. Same certificate as
   §79's "fifth SHA-1", different hash; both are needed.
   🔑 `firebase.json`'s `ignore` had `"**/.*"`, which matched `.well-known/` and
   meant the file **was never uploaded at all** — deploy reported success and
   the URL 404'd. Removed. Do not put it back. Full notes in
   `public/.well-known/README.md`.

### 2. Draw handling — and a leave-gate that had never once run

🔴 **Found and fixed: the "nobody leaves until the host decides" hold never
worked.** `endMatch` stamped `outcomeMethod: 'draw'` on a level match, while
`live_match_screen._awaitingHostDecision` requires `outcomeMethod == null`. So
the panel that pins the other players rendered **never**: everyone was released
to a scorecard reading "Draw" the instant End was tapped — exactly the complaint
the client raised. `endMatch` now leaves a level match's outcome null.

⚠️ That made a latent trap real — the hold has no other release, so a host whose
phone dies would strand everyone else in the match. Added `_hostDecisionGrace`
(3 minutes), after which a "view the result anyway" button appears.

**Extra time is a played period now, not a checkbox.** It used to ask "was extra
time played?" *after* `endMatch` — recording that it happened with no clock, no
goals, and nothing for anyone else to watch. `startExtraTime(id, minutes)` puts
the match back to `live` with the clock extended; the host picks 5/10/15/30. The
label everyone sees is football's own — **`EXTRA TIME · 90+10`** — on the live
screen, the in-app scoreboard, the scorecard, and the website's `/live`.

🔑 `MatchModel.regulationMin` doubles `durationMin` for two halves. That is why
the label cannot just print `durationMin`.

**Shootouts record who scored.** The +/− steppers captured only numbers, so a
scorecard could read 4–3 without naming a single taker. `recordShootout` writes
a `penalties` subcollection, and the score *is* the tally of picks, so the two
can never disagree.

⚠️ **Shootout kicks increment `players/{uid}.goals` and so land in
`careerGoals`. That is the client's explicit decision (2026-09-07) and it
departs from real football**, where shootout penalties never count toward a
player's tally. They deliberately do **not** touch `scoreA`/`scoreB` — team
`goalsFor` folds from those, so a 2–2 settled 4–3 still reads 2–2 everywhere.

### 3. The challenge notification was never late — the button lied

The client reported the challenged team being notified only at "start match".
Tracing it: the notification fires in `_create()`, on **Create Match** — and the
button beside the team-code field, labelled **"Challenge"**, only *looks the
team up*. It sends nothing. The chip then read "Challenged · their owner &
captain get notified", present tense.

🔑 **It cannot be sent any earlier.** The notification carries `match.id` and
Accept calls `acceptChallenge(matchId)` — there is no match to answer before
`_create()` runs. Chosen fix (the client picked it): button → **"Look up"**,
chip → **"They'll be notified when you create this match"**.

### 4–6. Trims

- **Match format picker removed.** Every new match stores `'Unlimited'`.
  ⚠️ The **field stays** — old matches carry real values like `'7v7'`, and
  `applyMatchStats` buckets goals by format for the profile breakdown.
  `MatchModel.hasFixedFormat` hides the new default from the six screens that
  print a format line, so history still displays.
- **Lobby's "＋ Invite a friend" removed.** ⚠️ Match invites still exist and the
  home popup still has a source (per-side Add Player, and challenge-accepted, in
  `match_repository.dart`). `match.inviteSentTo` / `inviteBtn` are **not**
  orphans.
- **The clock is a stopwatch.** It counted DOWN to `endsAt`; it counts UP now,
  and past the scheduled end reads `45:00 +02:30`. The old readout never matched
  the minute goals were being stamped with (`_elapsedMinutes` has always counted
  up).
  🔑 The whole thing rests on `startedAt` being pushed forward past every
  non-playing gap. It already was for pauses; **half-time and the
  outcome-screen gap now do it too** (new `halfTimeAt` field — deliberately not
  `pausedAt`, which would raise a PAUSED badge and a Resume button mid-interval).
  The cap comes from `endsAt - startedAt`, so it follows +5/+10 extends, the
  second half (→ 90:00) and extra time with no per-period bookkeeping. Ported to
  the website's `matchClock.js`; its tests asserted the countdown and were
  rewritten. 61/61 pass.

### A copy collision worth knowing about

`live.extra` (the pill once the clock passes its end — **stoppage**) and
`live.extraTimeOpt` (the period a host grants) both read `وقت إضافي` in Arabic.
Now that extra time is real, that was two different states under one word.
`live.extra` is now `ADDED` / `بدل الضائع`.

### What is NOT done

- 🔴 **Nothing here has run on a device.** The batch is analyzer- and
  build-verified only. The referral flow in particular cannot be fully exercised
  until the Play listing exists.
- 🔴 **`assetlinks.json` is written but not deployed**, and needs Google's
  fingerprint added after the first upload.
- 🟠 Arabic strings throughout this batch are unreviewed — they join §69's
  queue, which still needs a native speaker.
- 🟠 No regression test for the `endMatch` hold fix. §75's note stands: there is
  no seam for mocking the repository singletons.

## 81. Feedback: Report a Bug + Send a Suggestion, and an admin tab (2026-09-07)

Two new side-drawer rows and a place for the reports to land. Builds clean:
`flutter analyze` clean, debug APK builds, **web (admin panel) builds**.
Not device-verified, and **not usable until the rules are deployed** — see below.

### The shape

One collection, `feedback/{id}`, with a `type` of `bug` | `suggestion` — not two
collections. The admin panel wants one arrival-ordered list, so the split is a
filter, not a different kind of record.

| piece | where |
|---|---|
| `FeedbackReport` + `FeedbackType` / `FeedbackStatus` | `lib/services/models.dart` |
| submit / watch / status / delete | `lib/services/feedback_repository.dart` (new) |
| the form, both modes | `lib/screens/feedback_screen.dart` (new) |
| drawer rows | `side_drawer.dart`, under Help |
| admin list | `admin_dashboard.dart` → **FEEDBACK** tab (5 tabs now) |
| access | `firestore.rules` → `match /feedback/{fid}` |

Two routes (`Routes.reportBug`, `Routes.suggestion`) onto one screen, because
the drawer's `_item` helper navigates by name with **no arguments**; a single
route taking one would need a special case there.

Identity and build are captured at submit rather than asked for — a bug report
that doesn't say who sent it or which version it came from is usually
unactionable, and nobody types their app version correctly. The form says so
out loud (`feedback.attachedNote`), which is cheaper than a privacy complaint.

### 🔴 Deploy the rules or the feature is dead

`feedback` is a **new collection**. With no matching rule, Firestore denies by
default, so every submit fails until:

    firebase deploy --only firestore:rules --project yno-app-e96f5

⚠️ **`feedback` is deliberately NOT world-readable**, unlike `users`, `teams`,
`matches`, `friendships` and `rivalries`, which are all `allow read: if true`.
Reports carry an email address and free text, so only the super-admin and the
report's own author can read one. **Do not "make it consistent" with the rest of
the file.** Create is gated on the document being the caller's own
(`request.resource.data.uid == request.auth.uid`), pinned to `status: 'open'` so
nobody files something pre-resolved, and capped at 2000 characters — the same
number as `FeedbackRepository.maxMessageLength`, which also truncates, so the
cap holds even if the screen doesn't enforce it. Update and delete are
super-admin only: the author cannot edit a report after sending, so what the
admin reads is what was sent.

🟠 `watchMine()` needs a composite index on (`uid`, `createdAt desc`). Nothing
calls it yet — it exists so a "my reports" view costs nothing later. Firestore
prints a create-link the first time it runs.

### Two dead ends found in Help, one fixed

Memory says to report dummy data and dead navigation, and "Still Need Help?" was
both:

- ✅ **Fixed:** the card had no working action at all. It now leads to the two
  new screens. Someone who read the FAQ and didn't find their answer had, until
  now, no way to report anything from inside the app.
- 🔴 **Left alone, needs a product call:** the WhatsApp row toasts the literal
  string *"WhatsApp support"* — `home.whatsappSupport` is a label, not a number.
  There is no WhatsApp line. It should get a real number or be removed.
- 🟠 The email row toasts `support@nellab.org` without copying it or opening a
  mail client — and per §79 that mailbox still does not exist.

### 🔑 Unrelated landmine fixed while in the config

`firebase.json`'s `flutter` block still carried the **deleted** Firebase app's
id (`…7946933b7c0efc91a2c8be`, the old `com.example.ynoapp` app). Inert at
runtime — only `flutterfire configure` reads it — but rerunning that command
would have reconfigured against an app that no longer exists and could have
overwritten the correct values in `firebase_options.dart` and
`google-services.json`, which both correctly carry `…887a9e0ca1144002a2c8be`.
Now all three agree.

### Not done

- 🔴 Rules not deployed (above). Nothing works until they are.
- 🔴 Not run on a device or in the panel.
- 🟠 **No notification when feedback arrives.** The admin has to open the tab and
  look. Fine for now; worth knowing it is not a queue that chases anyone.
- 🟠 No screenshot attachment. Cloudinary is already wired
  (`storage_service.dart`), so it is a small addition if bug reports turn out to
  need it.
- 🟠 Arabic unreviewed, joining the queue from §69/§80.

### 🔴 §81 addendum — the rules deploy FAILED (2026-09-07)

`firebase deploy --only firestore:rules --project yno-app-e96f5` returned
**HTTP 403, "The caller does not have permission"** at the
`firebaserules...:test` step — the compile check that runs before publishing.

`firebase login:list` reports **`muhammadhuzaifamh777@gmail.com`**, and
`firebase projects:list` does **not list `yno-app-e96f5` at all**. That account
has no access to the project; per §78/§79 the owner is the throwaway
`huzm651@gmail.com`, which is password-locked.

**The user must run this, signed in as an account with access:**

    firebase login
    firebase deploy --only firestore:rules --project yno-app-e96f5

Until then **every feedback submit is denied** and both drawer screens show
"Could not send that". Nothing else in §81 is affected — the app and web builds
are green.

🔑 The rules are **not machine-verified**. The 403 blocked the server-side
compile, and `firebase emulators:exec --only firestore` was tested and does
**not** validate rules — a deliberately corrupted `firestore.rules` started and
ran the script cleanly, logging nothing. Do not read a clean emulator start as a
passing rules check. The user's own `firebase deploy` performs that compile
before publishing, so a syntax error fails safely rather than shipping.

🔑 firebase-tools 15 requires **JDK 21+**; the default `java` here is 17 and
JDK 25 lives at `C:\Program Files\Java\jdk-25`.

## 82. Trims + two auth fixes (2026-09-07)

`flutter analyze` clean, debug APK builds. Not device-verified.

### Removed

- **Help's WhatsApp row.** It was dummy — it toasted the literal string
  "WhatsApp support", because that is what `home.whatsappSupport` was: a label,
  not a number. Flagged in §81, removed here.
- **The joining-method picker.** Every new match is separate-teams; Open Lobby
  is gone from creation.
- **The timing picker and the duration stepper.** Matches are no longer given a
  length up front. The live screen runs the stopwatch from §80 and the host
  ends the match when they decide it is over.

⚠️ **`JoiningMethod` and `TimingMode` are NOT dead**, and neither are
`durationMin`/`endsAt`. Older matches carry `halves`, `openLobby` and a real
countdown-era `endsAt`, and the lobby, live screen, in-app scoreboard and the
website's `matchClock.js` all still honour them. A match created last month must
not start behaving like a stopwatch retroactively.

🔑 `_join`, `_timing` and `_durationMin` stay as **state** in
`match_create_screen`, not constants. `_loadMatch` overwrites them from the
match being edited and `_saveEdits` writes them back — making them `const` would
silently wipe an older match's two-halves clock the moment its creator opened
the edit screen to change something unrelated. Only the pickers and the
`_step*`/`_durationStepper`/`_timingRow` helpers were deleted.

🔑 **Extra time follows suit.** `startExtraTime(id, 0)` now means *open-ended*:
on a clockless match the outcome screen asks nothing and simply restarts play,
because making the host commit to "10 minutes" there would put back exactly the
pre-set length that was just removed. Timed (older) matches still get the 5/10/
15/30 picker, since extra time on a real clock has to know when it stops.
`extraTimeMin` still increments by 1 in the open-ended case — it is also the
flag the outcome screen reads to avoid offering extra time twice — and
`extraTimeLabel` correctly renders empty with no regulation clock to measure.

18 l10n keys archived in `.claude/l10n_removed_keys.md`. `live.extendClock` /
`live.min` / `live.minAdded` were **kept**: the live settings sheet still offers
+5/+10, gated on `timingMode != none`, which only old matches now satisfy.

### Google account selection now differs by screen

Client's call. `signInWithGoogle` takes `forceAccountPicker`:

- **Sign up → `true`.** `GoogleSignIn.signOut()` first, so the chooser always
  appears. That only forgets the *local* selection — it revokes nothing and
  clears nothing on Google's side. A phone with several accounts would otherwise
  silently reuse the last one, and the person creating a new account is exactly
  the one most likely to want a different one.
- **Log in → `false`.** `signInSilently()` reuses the remembered account with no
  UI, falling back to the interactive flow when there is nothing remembered.

### 🔴 Fixed: signed-in users could be bounced to Welcome after a reboot

`splash_screen._boot` read `AuthRepository.instance.currentUser`
**synchronously**. Firebase restores the persisted session from disk
*asynchronously* after `initializeApp`, so `currentUser` can still be null for a
moment on a cold start — which is precisely a post-reboot launch, when the disk
is slow and nothing is warm. The 1.5s splash delay usually covered it, which is
what made this intermittent rather than constant.

It now awaits `authState.first` (5s timeout, falling back to `currentUser`).
`authStateChanges()` does not emit until restoration has settled, so its first
event is the real answer.

🔑 **There was nothing to "enable" for persistence.** On Android/iOS the session
is always written to disk and `setPersistence` is web-only. The session already
survived reboots; the bug was asking before it had been read back. Do not add a
`setPersistence` call — it throws on mobile.

### Not done

- 🔴 Nothing device-verified. The reboot fix in particular wants a real
  reboot-and-launch, and the Google picker behaviour wants a phone with two
  Google accounts.
- 🔴 §81's rules deploy is **still outstanding** — feedback submits fail until
  it runs, and the CLI here is signed in as an account with no access to
  `yno-app-e96f5`.
- 🟠 Help's email row still only toasts `support@nellab.org` without copying it
  or opening mail, and that mailbox still does not exist.

## 83. Admin panel: referral reporting + editable point values (2026-09-07)

`flutter analyze` clean, debug APK builds, web (admin panel) builds.

### 🔴 First: the rules are STILL NOT DEPLOYED — proven, not assumed

A disposable account was signed up against the live project and made one write
to `feedback`. Result:

    🔴 WRITE DENIED (403) → PERMISSION_DENIED: Missing or insufficient permissions.

So **feedback submits fail in the app, and the admin FEEDBACK tab cannot read
anything** — it will render its permission-denied error state. The panel itself
is fine; it has nothing it is allowed to fetch.

`firebase deploy --only firestore:rules --project yno-app-e96f5` is still
blocked here: the CLI is signed in as `muhammadhuzaifamh777@gmail.com`, and
`firebase projects:list` does not include `yno-app-e96f5`.

**The rules file has grown again since** — `config/{doc}` was added this
session. One deploy now covers both `feedback` and `config`.

### Referral reporting in the users tab

- Search now also matches the **referral code**, so "who owns AB12CD?" is one
  query instead of a hunt.
- Filter chips: All / Referrers / Was referred / Auto-created.
- Every user card shows `code XXXXXX · N referred`, plus an `N referrals` badge.
- Tapping a referrer's card opens the list of accounts that used their code,
  newest first, with join dates and what it earned them.
- A summary line above the list: how many users have referred, and how many
  signups that is in total.

🔑 Counted **in memory** from the existing `watchUsers()` stream by grouping on
`referredBy`. `UserRepository.countReferrals` does a `where` query per user —
correct for one profile screen, but one read per row per rebuild here, which on
a few thousand users is a bill and a rate limit rather than a feature.

🔑 The counts are computed from the **unfiltered** list. Filtering to
"Referrers" and then counting would only ever count the rows still on screen.

### Point values are now editable, not compiled in

`kReferralPoints` (10), `kCommunityPlayerPoints` (20) and `kManOfMatchPoints`
(30) were `const` — changing what a referral was worth needed a new build in
every user's hands. They now live in `config/rewards` and the panel's **REWARDS**
tab edits them.

- `lib/services/rewards_config.dart` — `RewardsConfig` + `RewardsRepository`.
- `RewardsRepository.current` is a plain static so the widgets that used to
  interpolate a `const` still read it synchronously; `main()` awaits `load()`
  before the first frame and then `listen()`s, so an admin's edit reaches
  running apps without a restart.
- Award paths (`_applyReferral`, `finalizeMatch`, `resolveCommunityAward`) are
  async and read `current` at award time.

⚠️ **The defaults in `RewardsConfig` are load-bearing** and must stay 10/20/30.
They are what clients use before the document loads, if the read fails, and if
the document has never been created — a network blip must not silently change
what a match is worth. Each field also falls back independently, so a document
written with only one of the three does not zero the other two.

⚠️ **Changes are not retroactive.** Points already awarded were written to
`users/{uid}.points` at the old value; editing changes future awards only. The
tab says so.

🔑 Rules: `config/{doc}` is world-readable (every client shows these numbers,
some before sign-in) but **write is super-admin only** — `users` is writable by
any signed-in user, so a client that could write here could make a referral
worth 10,000 points and then award itself.

### Not done

- 🔴 Rules deploy (blocks feedback AND the rewards editor's save).
- 🔴 Nothing device- or panel-verified. In particular the REWARDS tab has never
  been opened, because signing into the panel needs the super-admin login.
- 🟠 The referral list dialog loads every user into memory. Fine at current
  scale; at tens of thousands it wants a real query and an index.

### ✅ §83 addendum — the rules ARE deployed, and verified (2026-09-07)

The user ran `firebase deploy --only firestore:rules --project yno-app-e96f5`
themselves; it compiled and released. Confirmed against the live project, not
taken on trust — a disposable account was signed up and used to probe five
boundaries:

| probe | result | wanted |
|---|---|---|
| write to `feedback` as its own author | ALLOWED | ALLOWED |
| read `config/rewards` | ALLOWED | ALLOWED |
| write `config` as a normal user | **DENIED** | DENIED |
| file feedback with someone else's `uid` | **DENIED** | DENIED |
| file feedback pre-set to `status: resolved` | **DENIED** | DENIED |
| list all `feedback` as a normal user | **DENIED** | DENIED |

So the feedback path and the rewards config are both live, and the collection is
confirmed **not** world-readable. `server/test/` has no harness for this; the
probes were throwaway scripts and cleaned up after themselves (row deleted,
account deleted).

`config/rewards` **does not exist yet** — reading it 404s, which is why the
defaults in `RewardsConfig` matter. Saving once in the panel's REWARDS tab
creates it.

## 84. 👉 START HERE — state of play at the end of 2026-09-07

Supersedes §80–§83 as "start here". **§79 remains the Play Store plan** and its
blockers are unchanged; everything below is what moved around it.

### Where the code is

`flutter analyze` clean. Debug APK builds. Web (admin panel) builds. A **release
`.aab` exists and is current** — `build/app/outputs/bundle/release/app-release.aab`,
48.9 MB, built 2026-09-07 20:53 from the code as it stands, signed with the
release key (`META-INF/YNO.RSA`), no service-account key inside.

⚠️ **Nothing in §80–§83 has run on a device.** Zero device runs since 2026-08-29.
That covers referral links, live extra time, shootout scorers, the stopwatch,
the feedback feature, the Google account-picker split, the reboot fix, the
admin panel's two new tabs. All analyzer- and build-verified only.

### ✅ Firestore rules — DEPLOYED and boundary-verified

The user deployed them. Verified against the live project with a disposable
account (both cleaned up afterwards), not taken on trust:

| probe | result |
|---|---|
| write `feedback` as its own author | ALLOWED ✅ |
| read `config/rewards` | ALLOWED ✅ |
| write `config` as a normal user | DENIED ✅ |
| file feedback under another user's `uid` | DENIED ✅ |
| file feedback pre-set to `resolved` | DENIED ✅ |
| list all `feedback` as a normal user | DENIED ✅ |

So bug reports save, the FEEDBACK tab can read, and reports are private to their
author and the super-admin.

🔑 **`config/rewards` does not exist yet** (reading it 404s). Every client runs
on the `RewardsConfig` defaults — 10 / 20 / 30 — until someone saves once in the
panel's REWARDS tab. That is correct behaviour, not a bug.

### 🔴 The website is NOT deployed — and the 200s lie

`D:\Web\yno`, the nellab.org React site. **A different Firebase project from the
app**: `yalla-nellab-12650`, not `yno-app-e96f5`. Deploying the app's rules did
nothing for it.

    cd D:\Web\yno && npm run build
    firebase deploy --only hosting --project yalla-nellab-12650

⚠️ **Do not check this with a status code.** `nellab.org/r/TESTCODE` returns
**HTTP 200** because the SPA rewrite sends every path to `index.html`. React
Router then finds no `/r` route in the deployed bundle and falls through to the
marketing homepage. Verify by grepping the live bundle instead:

    curl -s https://nellab.org/ | grep -o '/static/js/main\.[a-z0-9]*\.js'
    curl -s https://nellab.org/static/js/main.<hash>.js | grep -c refAutoApplied

`refAutoApplied` and `yno_referral` are this session's strings — **0 in the live
bundle** as of now. (`refWelcome` is 1, but that is the older dormant copy and
proves nothing.)

⚠️ **`/.well-known/assetlinks.json` serves `[]`** — 2 bytes, an empty array,
Firebase Hosting's default when no app is associated. Correct content type,
no fingerprints. App Links verification therefore fails and referral links open
in Chrome even on a phone that has YNO. The real file, with both SHA-256s, is in
`D:\Web\yno\public\.well-known\` and builds into `build/` correctly — it just
has never shipped.

### Why referral links are dead — three independent causes

1. `/r/<code>` route not deployed (above).
2. `assetlinks.json` empty (above).
3. **The Play listing 404s** — `org.nellab.yno` is not published, so the
   not-installed path, which is the entire point of the Install Referrer
   mechanism, leads to a dead URL.

(1) and (2) are one deploy. (3) needs the listing and nothing can shortcut it.

### The repo now exists — and it is PUBLIC

<https://github.com/Huzaifa-Muhammed/yno-app>, branch `main`, one commit
(`0593eb2`), 268 files. See [[yno-github-repo]].

🔴 **`lib/admin/admin_config.dart` is public and contains
`huzaifa@admin.com` / `123456`.** That file's own doc says the account is
**created on first successful login**, and the panel can wipe the database. If
that account does not exist yet, anyone reading the repo can create it.
**Closing it: log into the panel once (claims the account), then change the
password in Firebase Console → Authentication.** The durable fix is moving the
credentials to `--dart-define`; not done.

### Play Store — unchanged, and the developer account does not exist

The user shared `my.play/HeartyTooth145`, which redirects to
`play.google.com/profile/HeartyTooth145` — that is a **Play user/games profile**,
not a developer account. Publishing needs a separate **Play Console** account
(`play.google.com/console/signup`, one-time $25 + identity verification).

Blockers, all from §79 and all still true:

- 🔴 **Unbranded** — `android:label="ynoapp"`, every `ic_launcher.png` still the
  Flutter template (544–1443 bytes, dated 2025-10-09), no adaptive icon, and
  neither `flutter_launcher_icons` nor `flutter_native_splash` in `pubspec.yaml`.
  **The only code work left.** ~half a day.
- 🔴 **Keystore has no off-machine backup.** Permanent loss once published.
- 🔴 **No Play Console account.** ⏰ Personal vs organisation is chosen at signup
  and is the schedule driver — personal triggers 12 testers × 14 continuous days.
- ⚠️ The `123456` auto-account password is the client's standing decision; put it
  back to them as a launch call rather than "fixing" it.

After the first upload: register Play App Signing's **SHA-1 in Firebase**
(Google sign-in) **and its SHA-256 in `assetlinks.json`** (App Links). Same
certificate, two hashes, both break in production if missed.

### Suggested order next session

1. Log into the admin panel once + change the password (closes the public
   credential hole). `flutter run -d chrome`, `huzaifa@admin.com` / `123456`.
2. Save once in REWARDS to create `config/rewards`.
3. Send a test bug report from the app → confirm it lands in FEEDBACK.
4. Deploy the website → referral pages + assetlinks live.
5. Back up the keystore.
6. Branding pass (icon + label) — the last code blocker.
7. Register the Play Console account.

### Still open from before

C9 + C19 and C8 (need a second participant; `server/test/device_second_actor.mjs`
exists), the admin-dashboard dispose site (web-only, needs the super-admin
login — now reachable once the account exists), §75's `_dependents.isEmpty` red
screen, the Arabic review queue (now much larger — §80–§83 all added unreviewed
Arabic), `support@nellab.org` mailbox, `og:image`, stale `src/App.test.js`, a
lawyer on the legal docs, and revoking FCM key `fade14a1…` once a keyless build
is live.
