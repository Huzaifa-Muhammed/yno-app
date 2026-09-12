
## Removed 2026-08-03 — bottom nav + Matches page (§39)

The bottom navigation bar and the Matches page were deleted; the Matches page
was replaced by a single-draft **Draft Match** page whose strings live under the
new `draft.*` cluster (see `tr_common.dart`). `nav.community` survived — it is
still used as the Community page title and a profile stat label.

### tr_common.dart — `nav.*` (bottom bar labels)
```
  'nav.home': ['Home', 'الرئيسية'],
  'nav.matches': ['Matches', 'المباريات'],
  'nav.create': ['Create', 'إنشاء'],
  'nav.profile': ['Profile', 'الملف'],
```

### tr_common.dart — `matches.*` (the deleted Matches page)
Note: `matches.draftBadge`, `matches.draftWarning`, `matches.draftDeletesIn`
and `matches.draftDeletesSoon` were not lost — they were carried over verbatim
as `draft.badge` / `draft.warning` / `draft.deletesIn` / `draft.deletesSoon`.
```
  'matches.title': ['Matches', 'المباريات'],
  'matches.searchHint': ['Search matches…', 'ابحث عن المباريات…'],
  'matches.ongoing': ['Ongoing', 'جارية'],
  'matches.played': ['Played', 'المُنتهية'],
  'matches.drafts': ['Drafts', 'مسودات'],
  'matches.draftBadge': ['DRAFT', 'مسودة'],
  'matches.draftWarning': [
    'Not started yet. A draft is deleted 2 days after it\'s created if the match still hasn\'t started — its data will be lost. Open it and press Start to keep it.',
    'لم تبدأ بعد. تُحذف المسودة بعد يومين من إنشائها إذا لم تبدأ المباراة — وستُفقد بياناتها. افتحها واضغط ابدأ للاحتفاظ بها.'
  ],
  'matches.draftDeletesIn': ['Deletes in', 'تُحذف خلال'],
  'matches.draftDeletesSoon': ['Deletes soon', 'تُحذف قريبًا'],
  'matches.empty': [
    'No matches yet. Create one or join with a code.',
    'لا توجد مباريات بعد. أنشئ مباراة أو انضم برمز.'
  ],
  'matches.noResults': ['No matches match your search.', 'لا توجد نتائج مطابقة لبحثك.'],
  'matches.createMatch': ['Create Match', 'إنشاء مباراة'],
  'matches.joinByCode': ['Join by Code', 'الانضمام برمز'],
```

## Removed 2026-08-03 — settings audit (§40)

`home.privacy` / `home.privacySettings` backed a settings row that only popped a
toast and changed nothing; it was replaced by a real public/private profile
toggle reusing the existing `profile.publicProfile*` / `profile.privateProfile*`
keys. `home.contactSyncOff` was rendered unconditionally — it said "Off" even
when the toggle was on — and was replaced by the state-neutral
`home.contactSyncSub`.

### tr_home.dart
```
  'home.privacy': ['Privacy', 'الخصوصية'],
  'home.privacySettings': ['Privacy settings', 'إعدادات الخصوصية'],
  'home.contactSyncOff': [
    'Off · contacts never leave your phone',
    'معطّل · لا تغادر جهات اتصالك هاتفك أبدًا'
  ],
```

## Removed 2026-08-03 — contact sync consolidated (§41)

`social.noContactsMatchedGated` said device-contact access "ships later" — it
already shipped (§8), and the Friends page now runs the real lookup. Replaced by
`social.noContactsMatched`.

### tr_social.dart
```
  'social.noContactsMatchedGated': [
    'No contacts matched. Device-contact access ships later — no contact data is stored.',
    'لا توجد جهات اتصال مطابقة. الوصول إلى جهات اتصال الجهاز سيتوفّر لاحقاً — لا يتم تخزين أي بيانات لجهات الاتصال.'
  ],
```

## Removed 2026-08-03 — drawer trimmed (§42)

The drawer's points card and its "Made in Dubai" footer were removed. The footer
is now built at runtime as `YNO v{AppVersion.current}` — deliberately NOT a
translated key, since it is a brand name plus a number and was carrying a
hard-coded `v1.0.0` in both languages.

### tr_home.dart
```
  'home.ynoPoints': ['YNO POINTS', 'نقاط YNO'],
  'home.redeemInV2': ['Redeem\nin V2', 'استبدلها\nفي الإصدار 2'],
  'home.drawerFooter': [
    'YNO v1.0.0 · Made in Dubai',
    'YNO v1.0.0 · صُنع في دبي'
  ],
```

### tr_home.dart — also removed (About screen footer)
Note this line also carried the copyright; removing it removed that too.
```
  'home.madeInDubai': [
    'Made in Dubai · © 2026 YNO',
    'صُنع في دبي · © 2026 YNO'
  ],
```

## 2026-08-18 — client feedback pass (C19 penalty shootout)

### `lib/l10n/tr_live.dart`
Replaced by `live.shootoutOpt` / `live.shootoutOptSub`: the outcome screen no
longer offers "Team A win on penalties" as a bare winner pick, it opens a
shootout score sheet instead.

```dart
  'live.winOnPenalties': ['win on penalties', 'فاز بركلات الترجيح'],
```

### `lib/l10n/tr_match.dart` — C21, match code regeneration removed
The lobby no longer offers "↻ Regenerate": a match code is issued once and never
rotates. `MatchRepository.regenerateCode` is left in place, uncalled.
**Team** invite-code regeneration (`teams.regenCode*`) is untouched.

```dart
  'match.regenCodeQ': ['Generate a new code?', 'إنشاء رمز جديد؟'],
  'match.regenCodeBody': [
    'The current code stops working. Anyone you already shared it with will need the new one.',
    'سيتوقف الرمز الحالي عن العمل. أي شخص شاركته معه سيحتاج إلى الرمز الجديد.'
  ],
  'match.newCodeGenerated': ['New code generated', 'تم إنشاء رمز جديد'],
  'match.regenerate': ['Regenerate', 'إعادة توليد'],
```

### `lib/l10n/tr_common.dart` — C2, Draft page became My Matches
`draft_screen.dart` was replaced by `matches_screen.dart` (ongoing · draft ·
played), so the page-level titles moved to the new `matches.*` cluster. The rest
of the `draft.*` cluster is still live — it describes the draft card, which is
now a section of the Matches page.

```dart
  'draft.title': ['Draft Match', 'مسودة المباراة'],
  'draft.emptyTitle': ['No draft match', 'لا توجد مسودة'],
  'drawer.draftMatch': ['Draft Match', 'مسودة المباراة'],
```

### `lib/l10n/tr_teams.dart` — C21/D8, team code regeneration removed
The team profile no longer offers ↻: a team invite code is issued once at
creation and never rotates. `TeamRepository.regenerateInviteCode` is left in
place, uncalled.

```dart
  'teams.regenerate': ['Generate', 'إنشاء'],
  'teams.regenCodeQ': ['Generate a new code?', 'إنشاء رمز جديد؟'],
  'teams.regenCodeBody': [
    'The current code stops working. Anyone you already gave it to — to join or to challenge you — will need the new one.',
    'سيتوقف الرمز الحالي عن العمل. أي شخص أعطيته إياه — للانضمام أو لتحدّيك — سيحتاج إلى الرمز الجديد.'
  ],
  'teams.newCodeGenerated': ['New code generated', 'تم إنشاء رمز جديد'],
```

## 2026-08-18 — email-OTP claim flow

`auth.accountExistsAutoBody` was **not removed**, but its value changed. It used
to be rendered as `'<body> $kAutoAccountPassword'`, i.e. it ended with a colon
and the sign-up dialog printed the shared default password after it. The claim
flow replaced that, and `kAutoAccountPassword` no longer exists. Old value:

```
'An account already exists for this email — it was created when someone added you to a match or team. Log in with this password, or use a different email:',
'يوجد حساب بالفعل بهذا البريد الإلكتروني — تم إنشاؤه عندما أضافك أحدهم إلى مباراة أو فريق. سجّل الدخول بكلمة المرور هذه، أو استخدم بريدًا مختلفًا:'
```

### `misc.shareMsgB` — domain changed (2026-08-18)

Not removed; the referral share link moved from `yno.app` (never ours) to
`join.nellab.org`. Old value:

```
' when you sign up — we both earn points! https://yno.app',
' عند التسجيل — كلانا يكسب نقاطًا! https://yno.app'
```

## 2026-08-20 — "My Matches" renamed to "Draft Matches"

Client instruction: the page is thought of as the drafts page, so it should say
so. `drawer.myMatches` was also **renamed as a key** to `drawer.draftMatches`,
since a key called `myMatches` holding "Draft Matches" is the kind of drift the
l10n sweep exists to prevent.

| key | old EN | old AR |
|---|---|---|
| `matches.title` | `My Matches` | `مبارياتي` |
| `drawer.myMatches` (key gone) | `My Matches` | `مبارياتي` |

New value for both: `Draft Matches` / `مسودات المباريات`.

⚠️ The Arabic is mine, not a native speaker's — `مسودات المباريات` reads as
"match drafts", which fits the page better than a literal "المباريات المسودة".
Worth confirming alongside the website's new Arabic strings.

⚠️ Note the page still shows **three** sections — *Playing now*, *Draft* and
*Played* — so the title now names one of the three. Flagged to the user; their
call, and easily reverted (two values in `tr_common.dart`).

## Removed 2026-08-21 — Join means "join a match" (§65)

The Let's Play sheet's Join step used to open a Match / Team tab pair, so every
player heading into a game answered "match or team?" first. Joining a team moved
to its own drawer page (`Routes.joinTeam`, `join_team_screen.dart`) and the
sheet now goes straight to one match-code field.

### tr_home.dart — the two-mode titles
```
  'home.joinWithCode': ['Join with Code', 'انضم بالرمز'],
  'home.joinByCode': ['JOIN BY CODE', 'الانضمام بالرمز'],
```
`home.joinWithCode` was the sheet row's label — now `home.joinMatch`, which
already existed. `home.joinByCode` was the sheet's title when it could do both;
`home.joinAMatch` was already there for the match-only case and is now used
unconditionally.

Not lost, only re-pointed: `home.joinTeamPrompt`, `home.teamCodeHint`,
`home.joinTeam` and `home.noTeamFound` all moved to `join_team_screen`, and
`home.joinWithCodeSub` was **reworded** from 'Enter a match or team code' to
'Enter the match code'.

### Kept, though currently unused
`common.match` and `common.team` lost their only call site (the SegmentedTabs
labels). Left in place — they are single generic words, likely to be wanted
again, and cost nothing.

### Also removed 2026-08-21 — the side-A team picker became a grid (§65d)

```
  'match.noTeamsYet': ['You don\'t have a team yet', 'ليس لديك فريق بعد'],
```
Its empty-state row was replaced by a grid containing only the "+" tile, so the
two-line signpost lost its title. `match.noTeamsYetSub` survives — it is now the
one line shown above an empty grid, **reworded** from 'Create one and you can
field it in a match, with its players and stats. Tap to create a team.' to
'You have no teams yet — tap + to create one.'

`match.useYourTeam` was reworded from 'Or use one of your teams' to 'Pick one of
your teams', and `match.useYourTeamSub` shortened. Added: `match.newTeam`.

## 2026-09-07 — extra time became a played period; the shootout takes scorers

Removed from `tr_live.dart`. Extra time used to be a question asked *after*
`endMatch` ("was extra time played?"), recording that it happened without any of
it being played in the app. It now restarts the clock and sends everyone back to
the live screen, so there is no retrospective question left to confirm.

| key | English | Arabic |
|---|---|---|
| `live.extraTimeQ` | Extra time was played? | هل لُعب وقت إضافي؟ |
| `live.extraTimeConfirm` | Only choose this if the teams actually played extra time. | اختر هذا فقط إذا لعب الفريقان وقتًا إضافيًا بالفعل. |
| `live.shootoutHint` | Enter how many penalties each team scored. | أدخل عدد الركلات التي سجّلها كل فريق. |

`shootoutHint` went with the +/− steppers: the sheet no longer takes a number,
it takes the players who converted, and the score is the tally of those picks.
Its replacement is `live.shootoutPickHint`.

## 2026-09-07 — the match-format picker, and the lobby's "Invite a friend"

**Format picker** (`match_create_screen.dart`). The chip row offering Custom /
4v4 / 5v5 / 6v6 / 7v7 / 8v8 / 9v9 / 11v11 was removed at the client's request;
every new match now stores `'Unlimited'` (no fixed side size).

| key | English | Arabic |
|---|---|---|
| `match.format` | Format | الصيغة |
| `match.formatUnlimited` | Custom | مخصص |
| `match.unlimitedHint` | Custom — no fixed squad size. Play with any number of players per side and balance the teams yourself. | مخصص — لا عدد ثابت للاعبين. العب بأي عدد في كل فريق ووازن الفرق بنفسك. |

⚠️ The `format` **field** is still written and still read — matches created
before this change carry real values like `'7v7'`, and `applyMatchStats` buckets
goals by format for the profile breakdown. `MatchModel.hasFixedFormat` is what
hides the new default from the six screens that print a format line.

**Lobby "Invite a friend" sheet.** Removed at the client's request; it
overlapped the per-side Add Player invite and the share codes, and dropped
people into the match with no side.

| key | English | Arabic |
|---|---|---|
| `match.inviteFriend` | Invite a friend | ادعُ صديقًا |
| `match.inviteFriendLabel` | INVITE A FRIEND | ادعُ صديقًا |
| `match.inviteFriendSub` | They get an in-app invite to join this lobby. | يصلهم دعوة داخل التطبيق للانضمام إلى هذا اللوبي. |
| `match.noFriendsYet` | No friends yet. Share the code to invite anyone. | لا أصدقاء بعد. شارك الرمز لدعوة أي شخص. |
| `match.matchInviteTitle` | Match invite | دعوة مباراة |
| `match.tapToJoin` | — tap to join. | — انقر للانضمام. |

⚠️ `match.inviteSentTo` and `match.inviteBtn` were NOT removed — the per-side
Add Player sheet still uses both.

## 2026-09-07 (second batch) — WhatsApp row, joining method, timing

**Help's WhatsApp row.** Removed as dummy: it toasted the literal string
"WhatsApp support" because that is what the key was — a label, not a number.
There is no WhatsApp support line.

| key | English | Arabic |
|---|---|---|
| `home.whatsappSupport` | WhatsApp support | دعم واتساب |

**Joining method picker.** Every new match is separate-teams; the open-lobby
option is gone from creation.

| key | English | Arabic |
|---|---|---|
| `match.joiningMethod` | Joining method | طريقة الانضمام |
| `match.separateTeams` | Separate Teams | فرق منفصلة |
| `match.separateTeamsSub` | Two links & two codes. Players land on their side automatically. | رابطان ورمزان. ينضم اللاعبون إلى فريقهم تلقائيًا. |
| `match.openLobby` | Open Lobby | لوبي مفتوح |
| `match.openLobbySub` | One shared link. You assign players to teams manually. | رابط واحد مشترك. توزّع اللاعبين على الفرق يدويًا. |

**Timing picker + duration stepper.** Matches are no longer given a length up
front — the live screen runs a stopwatch and the host ends the match by hand.

| key | English | Arabic |
|---|---|---|
| `match.timing` | Timing | التوقيت |
| `match.noTimer` | No timer | بدون مؤقّت |
| `match.noTimerSub` | Untimed kickabout | لعب دون توقيت |
| `match.fullMatch` | Full match | مباراة كاملة |
| `match.fullMatchSub` | One running clock | ساعة واحدة متواصلة |
| `match.twoHalves` | Two halves | شوطان |
| `match.twoHalvesSub` | Duration is per half | المدة لكل شوط |
| `match.durationPerHalf` | Duration per half | مدة الشوط |
| `match.duration` | Duration | المدة |
| `match.minutes` | minutes | دقيقة |
| `match.durationMaxHint` | Set any length up to 45 minutes — hold − or + to move faster. | اختر أي مدة حتى 45 دقيقة — استمر بالضغط على − أو + للتغيير بسرعة. |
| `match.extendClockHint` | You can extend the clock while the match is live. | يمكنك تمديد الوقت أثناء المباراة. |

⚠️ **`JoiningMethod` and `TimingMode` are NOT dead.** Both fields stay on the
match document, older matches carry real values (`halves`, `openLobby`, a
countdown-era `endsAt`), and the lobby, live screen, in-app scoreboard and the
website's `matchClock.js` all still honour them. `_join`, `_timing` and
`_durationMin` also remain as *state* in `match_create_screen`, because
`_loadMatch`/`_saveEdits` round-trip them — turning them into constants would
wipe an older match's clock the moment its creator opened the edit screen.

`live.extendClock` / `live.min` / `live.minAdded` were kept: the live settings
sheet still offers +5/+10, gated on `timingMode != none`, which only old matches
now satisfy.

## Removed 2026-09-12 — the lobby's share-link button

The match lobby's code card lost its 🔗 share button and the tappable
`https://nellab.org/join?code=…` row beneath the hint. Joining by link is
paused at the client's request; the **code itself stays** — it is what the
in-app Join screen and the web `/join` page take — and players are otherwise
added from Add Player (a guest by name, or a registered player by username
search). Teams were deliberately left alone: their invite code still shares.

`match.oneSharedLink` was **not lost** — it was reworded and renamed to
`match.oneSharedCode` ('One shared link' → 'One shared code'), since the card
no longer hands out a link.

### tr_match.dart — `match.*` (share-link strings)
```
  'match.shareInvite': [
    'Join my match on YNO! Code:',
    'انضم إلى مباراتي على YNO! الرمز:'
  ],
  'match.linkCopied': ['Share link copied', 'تم نسخ رابط المشاركة'],
```
