// match cluster strings. {key: [English, العربية]}. Filled by the translation pass.
const Map<String, List<String>> trMatch = {
  // Shared / toasts
  'match.needLogin': ['You need to be logged in.', 'يجب تسجيل الدخول.'],
  'match.vs': ['vs', 'ضد'],
  'match.aPlayer': ['A player', 'أحد اللاعبين'],

  // ---- Destructive confirmations (lobby) ----
  'match.remove': ['Remove', 'إزالة'],
  'match.removePlayerQ': ['Remove player?', 'إزالة اللاعب؟'],
  'match.removePlayerBody': [
    'will be removed from the lobby.',
    'ستتم إزالته من الغرفة.'
  ],
  // Leaving a lobby (a player removing themselves).
  'match.leaveMatch': ['Leave match', 'مغادرة المباراة'],
  'match.leaveMatchQ': ['Leave this match?', 'مغادرة هذه المباراة؟'],
  'match.leaveMatchBody': [
    'You will be taken off the team sheet. If you are the captain, the host has to pick a new one before the match can start. You can rejoin with the code.',
    'ستتم إزالتك من قائمة الفريق. إذا كنت الكابتن، على المضيف اختيار كابتن جديد قبل أن تبدأ المباراة. يمكنك الانضمام مجددًا بالرمز.'
  ],
  'match.leaveMatchFailed': [
    'Could not leave — the match may have already started.',
    'تعذّرت المغادرة — ربما بدأت المباراة بالفعل.'
  ],

  // ---- Saved teams & challenges (create screen) ----
  'match.savedTeamNameLocked': [
    'Saved team — name locked. Edit it in My Teams.',
    'فريق محفوظ — الاسم ثابت. عدّله من فرقي.'
  ],
  'match.challengeTeam': ['Challenge a real team', 'تحدَّ فريقًا حقيقيًا'],
  'match.challengeExplain': [
    'Playing against a team that already uses YNO? Ask them for their team code and enter it here — their squad joins automatically and the result counts for both clubs.',
    'ستلعب ضد فريق يستخدم YNO؟ اطلب منهم رمز الفريق وأدخله هنا — سينضم فريقهم تلقائيًا وتُحتسب النتيجة للناديين.'
  ],
  'match.challengeCodeHint': ['Team code', 'رمز الفريق'],
  // Side A — using one of your own saved teams.
  // Heading over the side-A team grid. Short on purpose — the tiles below it
  // are self-explanatory once you know they are yours to pick from.
  'match.useYourTeam': ['Pick your team', 'اختر فريقك'],
  'match.useYourTeamSub': [
    'Its players join automatically and the result counts towards the team.',
    'ينضم لاعبوه تلقائيًا وتُحتسب النتيجة لصالح الفريق.'
  ],
  // Shown in the same place when the grid holds nothing but the "Team A" tile.
  'match.noTeamsYetSub': [
    'No saved teams — play as Team A and add players in the lobby.',
    'لا توجد فرق محفوظة — العب باسم Team A وأضف اللاعبين في الردهة.'
  ],
  // The ⓘ on the "Team A" tile. Answers "what happens if I pick nothing?",
  // which the tile alone cannot.
  'match.defaultTeamInfo': [
    'Start the match as Team A, then add players in the lobby with an invite or the match code.',
    'ابدأ المباراة باسم Team A، ثم أضف اللاعبين في الردهة عبر دعوة أو رمز المباراة.'
  ],
  // The ⓘ beside side B's name. Side A's sits on its "Team A" tile; side B has
  // no tile grid, so this is its equivalent — and it has to carry the whole
  // explanation of the side, since B is never something you pick from a list.
  'match.teamBInfo': [
    'The opponent. Leave it as Team B and add their players in the lobby, or challenge a real team with their code below.',
    'الفريق الخصم. اتركه باسم Team B وأضف لاعبيه في الردهة، أو تحدَّ فريقًا حقيقيًا برمزه بالأسفل.'
  ],
  // The button only *looks up* the team by its invite code and sets it as the
  // opponent — it sends nothing. The challenge notification fires in
  // `_create()`, when the match document exists to attach it to (Accept calls
  // `acceptChallenge(matchId)`, so there is nothing to answer before then).
  // It used to read "Challenge", which made people believe the opponent had
  // already been told and left them confused when the alert only landed after
  // Create Match.
  'match.challengeFetch': ['Look up', 'بحث'],
  // Future tense for the same reason: the old "get notified" read as done.
  'match.challengeWillNotify': [
    "They'll be notified when you create this match",
    'سيصل إليهم إشعار عند إنشائك هذه المباراة'
  ],
  'match.teamCodeNotFound': [
    'No team found with that code.',
    'لا يوجد فريق بهذا الرمز.'
  ],
  'match.cannotChallengeOwnTeam': [
    "That's your own team — pick it from the chips above.",
    'هذا فريقك — اختره من الأزرار بالأعلى.'
  ],
  'match.teamAlreadyOnSideA': [
    'That team is already on side A.',
    'هذا الفريق موجود بالفعل في الجهة أ.'
  ],
  'match.couldNotFetchTeam': [
    'Could not look up that team.',
    'تعذّر البحث عن هذا الفريق.'
  ],
  'match.challengeNotifTitle': ['Team challenged', 'تم تحدي فريقك'],
  'match.challengeNotifBody': ['want to play', 'يريد اللعب ضد'],

  // ---- Challenge popup (captain answers) ----
  'match.challengeDialogTitle': ['Challenge received', 'تحدٍّ جديد'],
  'match.challengeAccept': ['Accept', 'قبول'],
  'match.challengeDecline': ['Decline', 'رفض'],
  'match.challengeLater': ['Decide later', 'لاحقًا'],
  'match.challengeDeclined': ['Challenge declined.', 'تم رفض التحدي.'],
  'match.challengeAnswerFailed': [
    'Could not answer the challenge.',
    'تعذّر الرد على التحدي.'
  ],
  'match.challengeBannerOne': ['challenged your team', 'تحدّى فريقك'],
  'match.challengeBannerMany': [
    'pending challenges',
    'تحديات في انتظار ردّك'
  ],

  // ---- Create match screen ----
  'match.createMatchTitle': ['Create Match', 'إنشاء مباراة'],
  'match.matchName': ['Match name', 'اسم المباراة'],
  'match.matchNameHint': [
    'Auto-generated if left blank',
    'يُنشأ تلقائيًا إذا تُرك فارغًا'
  ],
  'match.upTo50': ['Up to 50 characters.', 'حتى 50 حرفًا.'],
  'match.teamSetup': ['Team setup', 'إعداد الفرق'],
  // `format` / `formatUnlimited` / `unlimitedHint` went with the format picker
  // on 2026-09-07 — archived in .claude/l10n_removed_keys.md. Every new match
  // is created with no fixed side size, and `MatchModel.hasFixedFormat` hides
  // the stored 'Unlimited' from the cards that used to print it.
  // The JOINING METHOD and TIMING keys stood here and went with their pickers
  // on 2026-09-07 — archived in .claude/l10n_removed_keys.md. Every new match
  // is separate-teams and runs on a stopwatch the host stops by hand.
  //
  // ⚠️ Both fields still exist on the match document and older matches still
  // carry real values, so `JoiningMethod` and `TimingMode` are very much alive
  // in the model and on the live screen — it is only the copy for choosing
  // them that is gone.
  'match.adminMode': ['Admin mode', 'وضع المشرف'],
  'match.adminOnly': ['Not playing (referee)', 'مشرف غير لاعب (حكم)'],
  'match.playingAdmin': ['Playing admin', 'مشرف لاعب'],
  'match.adminOnlySub': [
    'You are not on a team — no stats tracked for you.',
    'لست ضمن فريق — لا تُسجّل إحصائيات لك.'
  ],
  'match.playingAdminSub': [
    'You join Team A and your stats are tracked like everyone.',
    'تنضم إلى الفريق A وتُسجّل إحصائياتك كالجميع.'
  ],
  'match.adminModeHint': [
    'This cannot be changed after the match starts.',
    'لا يمكن تغيير هذا بعد بدء المباراة.'
  ],
  'match.creating': ['Creating…', 'جارٍ الإنشاء…'],

  // ---- Editing a match from the lobby (creation "page 1") ----
  'match.editMatchTitle': ['Edit Match', 'تعديل المباراة'],
  'match.editMatchDetails': ['Edit match details', 'تعديل تفاصيل المباراة'],
  'match.saveChanges': ['Save changes', 'حفظ التعديلات'],
  'match.matchUpdated': ['Match updated', 'تم تحديث المباراة'],
  'match.editTeamLinksLocked': [
    'Saved teams & challenges can\'t be changed here — manage the line-up in the lobby.',
    'لا يمكن تغيير الفرق المحفوظة أو التحديات هنا — أدر التشكيلة من اللوبي.'
  ],
  'match.startedNoEdit': [
    'The match has already started — settings are locked.',
    'بدأت المباراة بالفعل — الإعدادات مقفلة.'
  ],
  'match.couldNotSaveMatch': [
    'Could not save the changes. Try again.',
    'تعذّر حفظ التعديلات. حاول مجددًا.'
  ],
  'match.team': ['Team', 'فريق'],
  'match.nameLower': ['name', 'اسم'],

  'match.couldNotCreateMatch': [
    'Could not create the match. Try again.',
    'تعذّر إنشاء المباراة. حاول مجددًا.'
  ],

  // ---- Guest join screen ----
  'match.joinMatchTitle': ['Join Match', 'الانضمام إلى مباراة'],
  'match.invitedToPlay': ["You've been invited to play", 'تمت دعوتك للعب'],
  'match.matchCode': ['Match code', 'رمز المباراة'],
  'match.matchCodeHint': ['e.g. AB12CD', 'مثال: AB12CD'],
  'match.find': ['Find', 'بحث'],
  'match.enterMatchCode': ['Enter the match code.', 'أدخل رمز المباراة.'],
  'match.noMatchForCode': [
    'No match found for that code.',
    'لا توجد مباراة بهذا الرمز.'
  ],
  'match.couldNotLookup': [
    'Could not look up that code.',
    'تعذّر البحث عن هذا الرمز.'
  ],
  'match.findMatchFirst': ['Find your match first.', 'ابحث عن مباراتك أولاً.'],
  'match.enterYourName': ['Enter your name.', 'أدخل اسمك.'],
  'match.couldNotJoin': ['Could not join. Try again.', 'تعذّر الانضمام. حاول مجددًا.'],
  'match.live': ['LIVE', 'مباشر'],
  'match.lobbyOpen': ['Lobby open', 'اللوبي مفتوح'],
  'match.youWillJoin': ['You will join', 'ستنضم إلى'],
  'match.matchStartedApprove': [
    'Match already started — the admin approves you before you play.',
    'بدأت المباراة بالفعل — يوافق المشرف عليك قبل أن تلعب.'
  ],
  'match.yourName': ['Your name', 'اسمك'],
  'match.fullName': ['Full name', 'الاسم الكامل'],
  'match.phoneOrEmail': ['Phone or email', 'الهاتف أو البريد الإلكتروني'],
  'match.contactHintGuest': [
    'So your stats are saved for later',
    'كي تُحفظ إحصائياتك لاحقًا'
  ],
  'match.noAccountSync': [
    'No account needed. Give a phone or email and your match history syncs automatically when you sign up.',
    'لا حاجة لحساب. أدخل هاتفًا أو بريدًا وستتزامن سجلات مبارياتك تلقائيًا عند التسجيل.'
  ],
  'match.joining': ['Joining…', 'جارٍ الانضمام…'],
  'match.joinTheMatch': ['Join the Match', 'انضم إلى المباراة'],
  'match.followLive': ['Follow Match Live', 'تابع المباراة مباشرة'],
  'match.createAccountInstead': [
    'Create a YNO account instead',
    'أنشئ حساب YNO بدلاً من ذلك'
  ],

  // ---- Lobby screen ----
  'match.lobbyTitle': ['Lobby', 'اللوبي'],
  'match.assignCaptainFor': ['Assign a captain for', 'عيّن قائدًا لـ'],
  'match.firstSuffix': ['first.', 'أولاً.'],
  'match.toStartSuffix': ['to start.', 'للبدء.'],
  'match.matchCodeLabel': ['MATCH CODE', 'رمز المباراة'],
  'match.codeLabel': ['CODE', 'الرمز'],
  'match.oneSharedLink': [
    'One shared link — you assign players to teams.',
    'رابط واحد مشترك — توزّع اللاعبين على الفرق.'
  ],
  'match.joinCodeLandPre': [
    'Players who join with this code land on',
    'اللاعبون الذين ينضمون بهذا الرمز ينضمون إلى'
  ],
  'match.codeCopied': ['Code copied', 'تم نسخ الرمز'],
  'match.shareInvite': [
    'Join my match on YNO! Code:',
    'انضم إلى مباراتي على YNO! الرمز:'
  ],
  'match.linkCopied': ['Share link copied', 'تم نسخ رابط المشاركة'],
  'match.waitingToJoin': ['WAITING TO JOIN', 'في انتظار الانضمام'],
  'match.guest': ['Guest', 'ضيف'],
  'match.wants': ['wants', 'يريد'],
  'match.midGame': ['mid-game', 'أثناء اللعب'],
  'match.approved': ['approved', 'تمت الموافقة عليه'],
  'match.declined': ['declined', 'تم رفضه'],
  'match.noCaptain': ['No captain', 'لا يوجد قائد'],
  'match.noPlayersYet': ['No players yet.', 'لا لاعبين بعد.'],
  'match.addPlayer': ['Add player', 'إضافة لاعب'],
  'match.emptySlot': ['Empty slot', 'مكان فارغ'],
  'match.admin': ['Admin', 'مشرف'],
  'match.waitingAdminStart': [
    'Waiting for the admin to start the match.',
    'في انتظار أن يبدأ المشرف المباراة.'
  ],
  'match.starting': ['Starting…', 'جارٍ البدء…'],
  'match.startMatch': ['Start Match', 'ابدأ المباراة'],
  'match.makeCaptainOf': ['Make captain of', 'اجعله قائد'],
  'match.isNowCaptain': ['is now captain', 'أصبح قائدًا الآن'],
  'match.moveTo': ['Move to', 'انقل إلى'],
  'match.movedTo': ['Moved to', 'تم النقل إلى'],
  'match.removeFromLobby': ['Remove from lobby', 'إزالة من اللوبي'],
  'match.removed': ['removed', 'تمت إزالته'],
  'match.cantRemoveAdmin': ["You can't remove the admin.", 'لا يمكنك إزالة المشرف.'],
  'match.thatsYou': ["That's you.", 'هذا أنت.'],
  'match.addPlayerLabel': ['ADD PLAYER', 'إضافة لاعب'],
  'match.registered': ['Registered', 'مسجّل'],
  'match.moreOptions': ['More options', 'خيارات إضافية'],
  'match.moreOptionsSub': [
    'Joining, timing & admin mode — all optional',
    'طريقة الانضمام والتوقيت ووضع المشرف — كلها اختيارية'
  ],
  'match.name': ['Name', 'الاسم'],
  'match.email': ['Email', 'البريد الإلكتروني'],
  'match.guestEmailHint': ['player@example.com', 'player@example.com'],
  'match.guestAccountHint': [
    "We'll create an account for this player (password 123456) so they can log in and claim their stats.",
    'سننشئ حسابًا لهذا اللاعب (كلمة المرور 123456) حتى يتمكن من تسجيل الدخول والمطالبة بإحصائياته.'
  ],
  'match.guestEmailRequired': [
    'Enter a valid email for the player.',
    'أدخل بريدًا إلكترونيًا صالحًا للاعب.'
  ],
  'match.playerNameHint': ['Player name', 'اسم اللاعب'],
  'match.adding': ['Adding…', 'جارٍ الإضافة…'],
  'match.addGuest': ['Add Guest', 'إضافة ضيف'],
  'match.enterName': ['Enter a name.', 'أدخل اسمًا.'],
  'match.couldNotAddPlayer': ['Could not add player.', 'تعذّرت إضافة اللاعب.'],
  'match.searchByNamePhone': [
    'Search by name or phone',
    'ابحث بالاسم أو الهاتف'
  ],
  'match.startTyping': ['Start typing…', 'ابدأ الكتابة…'],
  'match.typeToSearch': [
    'Type a name and hit enter to search.',
    'اكتب اسمًا واضغط إدخال للبحث.'
  ],
  // `inviteFriendLabel` / `inviteFriendSub` / `noFriendsYet` / `inviteFriend`
  // / `matchInviteTitle` / `tapToJoin` were removed with the lobby's "Invite a
  // friend" sheet on 2026-09-07 — see .claude/l10n_removed_keys.md.
  //
  // ⚠️ `inviteSentTo` and `inviteBtn` are NOT orphans: the per-side Add Player
  // sheet still invites registered players onto a specific team, and it uses
  // both. Match-invite notifications still exist too (match_repository.dart) —
  // only this one entry point went.
  'match.inviteSentTo': ['Invite sent to', 'تم إرسال الدعوة إلى'],
  'match.inviteBtn': ['Invite', 'دعوة'],
  // ---- Registered-player invites (popup on the invited player's home) -----
  'match.invitedTag': ['Invited', 'مدعو'],
  'match.inviteCancelled': ['Invite cancelled for', 'تم إلغاء دعوة'],
  'match.inviteDialogTitle': ['Match Invite', 'دعوة لمباراة'],
  'match.inviteNotifBody': ['invited you to join', 'دعاك للانضمام إلى'],
  'match.joiningSide': ['Joining', 'الانضمام إلى'],
  'match.inviteAcceptJoin': ['Accept & Join', 'قبول وانضمام'],
  'match.inviteDeclined': ['Invite declined.', 'تم رفض الدعوة.'],
  'match.inviteBannerOne': ['invited you to a match', 'دعاك إلى مباراة'],
  'match.inviteBannerMany': [
    'match invites waiting',
    'دعوات مباريات في الانتظار'
  ],
};
