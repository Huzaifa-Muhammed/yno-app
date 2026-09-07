// teams cluster strings. {key: [English, العربية]}. Filled by the translation pass.
const Map<String, List<String>> trTeams = {
  // Teams list
  'teams.createTeam': ['Create Team', 'إنشاء فريق'],
  'teams.all': ['All', 'الكل'],
  'teams.discoverTeams': ['Discover Teams', 'اكتشف الفِرق'],
  'teams.discoverSub': ['Find public teams to challenge', 'ابحث عن فِرق عامة لتتحداها'],
  'teams.deletedTeams': ['Deleted Teams', 'الفِرق المحذوفة'],
  'teams.disbandedTeamsLabel': ['deleted teams', 'فرق محذوفة'],
  'teams.noTeamsFilter': ['No teams for this filter.', 'لا توجد فِرق مطابقة لهذا الفلتر.'],
  'teams.played': ['played', 'مباراة'],
  'teams.pending': ['PENDING', 'معلّق'],
  'teams.members': ['members', 'عضو'],
  'teams.createFirst': ['Create your first team', 'أنشئ فريقك الأول'],
  'teams.createFirstSub': [
    'Group players you play with regularly.',
    'اجمع اللاعبين الذين تلعب معهم بانتظام.'
  ],

  // Create wizard
  'teams.uploadFailed': ['Upload failed. Try again.', 'فشل الرفع. حاول مرة أخرى.'],
  'teams.uploadBadgeError': ['Could not upload the badge.', 'تعذّر رفع الشعار.'],
  'teams.pickNameFirst': ['Pick an available team name first.', 'اختر اسم فريق متاحًا أولًا.'],
  'teams.chooseBadge': ['Choose or upload a badge.', 'اختر شعارًا أو ارفع واحدًا.'],
  'teams.needLogin': ['You need to be logged in.', 'يجب تسجيل الدخول.'],
  'teams.createError': [
    'Could not create the team. Try again.',
    'تعذّر إنشاء الفريق. حاول مرة أخرى.'
  ],
  'teams.step': ['STEP', 'الخطوة'],
  'teams.of': ['OF', 'من'],
  'teams.creating': ['Creating…', 'جارٍ الإنشاء…'],
  'teams.nameHintEmpty': [
    "Unique across YNO. Letters, numbers, hyphens (-) and apostrophes (').",
    "فريد على YNO. حروف وأرقام وشرطات (-) وفواصل عليا (')."
  ],
  'teams.nameHintInvalid': [
    'Max 40 chars — only letters, numbers, hyphen and apostrophe.',
    '40 حرفًا كحد أقصى — حروف وأرقام وشرطة وفاصلة عليا فقط.'
  ],
  'teams.checkingAvailability': ['Checking availability…', 'جارٍ التحقق من التوفر…'],
  'teams.nameAvailable': ['is available.', 'متاح.'],
  'teams.nameTaken': ['✕ That name is taken. Try another.', '✕ هذا الاسم مستخدم. جرّب اسمًا آخر.'],
  'teams.teamName': ['Team name', 'اسم الفريق'],
  'teams.nameHintExample': ['e.g. Al Quoz FC', 'مثال: Al Quoz FC'],
  'teams.teamBadge': ['Team badge', 'شعار الفريق'],
  'teams.badgeHelp': [
    'Upload a PNG (shown in its natural shape) or pick a preset. JPG is not supported.',
    'ارفع صورة PNG (تظهر بشكلها الطبيعي) أو اختر شعارًا جاهزًا. صيغة JPG غير مدعومة.'
  ],
  'teams.uploading': ['Uploading…', 'جارٍ الرفع…'],
  'teams.uploadPng': ['Upload PNG', 'رفع PNG'],
  'teams.orPickPreset': ['Or pick a preset', 'أو اختر شعارًا جاهزًا'],
  'teams.privacy': ['Privacy', 'الخصوصية'],
  'teams.privacyHint': ['You can change this any time.', 'يمكنك تغيير هذا في أي وقت.'],
  'teams.private': ['Private', 'خاص'],
  'teams.privateSubDefault': [
    'Only findable via team invite code. (Default)',
    'يُعثر عليه فقط عبر رمز دعوة الفريق. (افتراضي)'
  ],
  'teams.public': ['Public', 'عام'],
  'teams.publicSub': [
    'Searchable and can receive match requests from anyone.',
    'قابل للبحث ويمكنه تلقّي طلبات المباريات من أي شخص.'
  ],
  'teams.review': ['Review', 'مراجعة'],
  'teams.name': ['Name', 'الاسم'],
  'teams.badge': ['Badge', 'الشعار'],
  'teams.customPng': ['Custom PNG', 'PNG مخصص'],
  'teams.preset': ['Preset', 'جاهز'],

  // Profile
  'teams.team': ['Team', 'الفريق'],
  'teams.disbanded': ['DELETED', 'محذوف'],
  'teams.matchRecord': ['Match Record', 'سجل المباريات'],
  'teams.scoring': ['Scoring', 'التهديف'],
  'teams.recognition': ['Recognition', 'التكريم'],
  'teams.roster': ['Roster', 'التشكيلة'],
  'teams.inviteCodeCopied': ['Invite code copied', 'تم نسخ رمز الدعوة'],
  'teams.inviteCode': ['INVITE CODE', 'رمز الدعوة'],
  'teams.statPlayed': ['Played', 'المباريات'],
  'teams.wins': ['Wins', 'الانتصارات'],
  'teams.losses': ['Losses', 'الخسائر'],
  'teams.draws': ['Draws', 'التعادلات'],
  'teams.winPct': ['Win %', 'نسبة الفوز %'],
  'teams.currStreak': ['Curr. Streak', 'السلسلة الحالية'],
  'teams.longestWin': ['Longest winning streak', 'أطول سلسلة انتصارات'],
  'teams.longestUnbeaten': ['Longest unbeaten streak', 'أطول سلسلة دون خسارة'],
  'teams.formLast5': ['Form (last 5)', 'الأداء (آخر 5)'],
  'teams.formLast10': ['Form (last 10)', 'الأداء (آخر 10)'],
  'teams.goalsFor': ['Goals For', 'الأهداف المسجّلة'],
  'teams.conceded': ['Conceded', 'الأهداف المستقبَلة'],
  'teams.cleanSheets': ['Clean Sheets', 'الشِّباك النظيفة'],
  'teams.goalsPerMatch': ['Goals / Match', 'أهداف / مباراة'],
  'teams.concededPerMatch': ['Conceded / Match', 'استقبال / مباراة'],
  'teams.goalDiff': ['Goal Diff', 'فارق الأهداف'],
  'teams.motm': ['Man of the Match', 'رجل المباراة'],
  'teams.communityAwards': ['Community Awards', 'جوائز المجتمع'],
  'teams.viceShort': ['VICE', 'نائب'],
  'teams.rivalTeams': ['Rival Teams', 'الفِرق المنافسة'],

  // Manage
  'teams.noAccess': [
    'Only the owner or captain can manage this team.',
    'يمكن للمالك أو القائد فقط إدارة هذا الفريق.'
  ],
  'teams.invitePlayer': ['Invite Player', 'دعوة لاعب'],
  'teams.addGuest': ['Add Guest', 'إضافة ضيف'],
  'teams.pendingInvites': ['Pending Invites', 'الدعوات المعلّقة'],
  // Join requests — a player asking to join, the mirror of an invite.
  'teams.joinRequests': ['Join Requests', 'طلبات الانضمام'],
  'teams.requestToJoin': ['Request to Join', 'طلب الانضمام'],
  'teams.requestSent': ['Request sent', 'تم إرسال الطلب'],
  'teams.requestPending': ['Request sent · tap to withdraw', 'تم إرسال الطلب · اضغط للسحب'],
  'teams.requestAccepted': ['Player added to the team', 'تمت إضافة اللاعب إلى الفريق'],
  'teams.withdrawRequestQ': ['Withdraw your request?', 'سحب طلبك؟'],
  'teams.withdrawRequestBody': [
    'Your request to join this team will be removed. You can ask again later.',
    'سيُحذف طلب انضمامك إلى هذا الفريق. يمكنك الطلب مجددًا لاحقًا.'
  ],
  'teams.withdrawRequest': ['Withdraw', 'سحب'],
  'teams.requestWithdrawn': ['Request withdrawn', 'تم سحب الطلب'],
  'teams.privateJoinNote': [
    'This team is private — you need their team code to join. Ask the owner or captain for it.',
    'هذا الفريق خاص — تحتاج إلى رمز الفريق للانضمام. اطلبه من المالك أو الكابتن.'
  ],
  'teams.vice': ['Vice', 'نائب'],
  'teams.makeCaptain': ['Make Captain', 'تعيين قائدًا'],
  'teams.captainAssigned': ['Captain assigned', 'تم تعيين القائد'],
  'teams.makeCaptainConfirm': [
    'Make this player captain of the team? The current captain becomes a player.',
    'تعيين هذا اللاعب قائدًا للفريق؟ سيصبح القائد الحالي لاعبًا.'
  ],
  'teams.guestEmail': ['Email', 'البريد الإلكتروني'],
  'teams.guestEmailHint': ['guest@example.com', 'guest@example.com'],
  'teams.guestAccountHint': [
    "We'll create an account for this player so they can log in and claim their profile.",
    'سننشئ حسابًا لهذا اللاعب حتى يتمكن من تسجيل الدخول واستلام ملفه الشخصي.'
  ],
  'teams.guestEmailRequired': [
    'Enter a valid email for the guest.',
    'أدخل بريدًا إلكترونيًا صالحًا للضيف.'
  ],
  'teams.couldNotAddGuest': [
    "Couldn't add that player. Try again.",
    'تعذّر إضافة هذا اللاعب. حاول مجددًا.'
  ],
  'teams.alreadyMember': [
    "You're already in this team.",
    'أنت بالفعل في هذا الفريق.'
  ],
  'teams.joinedTeam': ['Joined the team!', 'انضممت إلى الفريق!'],
  'teams.identityLockedNote': [
    "The team name and icon can't be changed after the team is created — choose them carefully.",
    'لا يمكن تغيير اسم الفريق وشعاره بعد إنشائه — اخترهما بعناية.'
  ],
  'teams.reject': ['Reject', 'رفض'],
  'teams.inviteAccepted': ['Joined the team!', 'انضممت إلى الفريق!'],
  'teams.inviteRejected': ['Invitation rejected', 'تم رفض الدعوة'],
  'teams.inviteFriends': ['Invite friends', 'دعوة الأصدقاء'],
  'teams.addVice': ['Add as Vice Captain', 'إضافة كنائب قائد'],
  'teams.maxVice': ['Max 4 vice captains.', '4 نواب قائد كحد أقصى.'],
  'teams.viceAdded': ['Vice captain added', 'تمت إضافة نائب القائد'],
  'teams.removeVice': ['Remove Vice Captain', 'إزالة نائب القائد'],
  'teams.viceRemoved': ['Vice captain removed', 'تمت إزالة نائب القائد'],
  'teams.removeFromTeam': ['Remove from Team', 'إزالة من الفريق'],
  'teams.playerRemoved': ['Player removed', 'تمت إزالة اللاعب'],
  'teams.remove': ['Remove', 'إزالة'],
  'teams.removePlayerTitle': ['Remove player?', 'إزالة اللاعب؟'],
  'teams.removePlayerBody': [
    'will be removed from',
    'ستتم إزالته من'
  ],
  'teams.revoke': ['Revoke', 'إلغاء الدعوة'],
  'teams.revokeInviteQ': ['Revoke invite?', 'إلغاء الدعوة؟'],
  'teams.revokeInviteBody': [
    'will no longer be able to accept and join the team.',
    'لن يتمكن بعد الآن من قبول الدعوة والانضمام إلى الفريق.'
  ],
  'teams.leave': ['Leave', 'مغادرة'],
  'teams.leaveTeamTitle': ['Leave team?', 'مغادرة الفريق؟'],
  'teams.leaveTeamBody': [
    "You'll be removed from the roster of",
    'ستتم إزالتك من تشكيلة'
  ],
  'teams.searchHint': [
    'Search by username, full name or phone number.',
    'ابحث باسم المستخدم أو الاسم الكامل أو رقم الهاتف.'
  ],
  'teams.typeToSearch': ['Type a name and hit search.', 'اكتب اسمًا واضغط بحث.'],
  'teams.member': ['MEMBER', 'عضو'],
  'teams.invite': ['INVITE', 'دعوة'],
  'teams.inviteSent': ['Invite sent', 'تم إرسال الدعوة'],
  'teams.guestName': ['Guest name', 'اسم الضيف'],
  'teams.adding': ['Adding…', 'جارٍ الإضافة…'],
  'teams.guestAdded': ['Guest added', 'تمت إضافة الضيف'],
  'teams.noPendingInvites': ['No pending invites.', 'لا توجد دعوات معلّقة.'],
  'teams.expired': ['EXPIRED', 'منتهية'],
  'teams.expiry7': ['7-day expiry', 'صلاحية 7 أيام'],
  'teams.shareCodeMessage': [
    'Challenge my team on YNO —',
    'تحدَّ فريقي على YNO —'
  ],
  'teams.inviteCodeCaptainOnly': [
    'Only the owner and captain can see this code. It never changes — share it carefully.',
    'المالك والقائد فقط يمكنهما رؤية هذا الرمز. لا يتغيّر أبدًا — شاركه بحذر.'
  ],

  // Edit team (rename / re-badge)
  'teams.editTeam': ['Edit team', 'تعديل الفريق'],
  'teams.publicSubShort': [
    'Searchable, open to match requests.',
    'قابل للبحث ومفتوح لطلبات المباريات.'
  ],
  'teams.privateSubShort': ['Only findable via invite code.', 'يُعثر عليه فقط عبر رمز الدعوة.'],
  'teams.makePrivate': ['MAKE PRIVATE', 'اجعله خاصًا'],
  'teams.makePublic': ['MAKE PUBLIC', 'اجعله عامًا'],
  'teams.disbandTeam': ['Delete Team', 'حذف الفريق'],
  'teams.restorable6': ['Restorable within 6 months.', 'قابل للاستعادة خلال 6 أشهر.'],
  'teams.disbandTypePrefix': ['Type the team name', 'اكتب اسم الفريق'],
  'teams.disbandTypeSuffix': [
    'to confirm. The team can be restored within 6 months.',
    'للتأكيد. يمكن استعادة الفريق خلال 6 أشهر.'
  ],
  'teams.disband': ['Delete', 'حذف'],
  'teams.leaveTeam': ['Leave Team', 'مغادرة الفريق'],

  // Discover
  'teams.noTeamForCode': ['No team found for that code.', 'لم يُعثر على فريق بهذا الرمز.'],
  'teams.discover': ['Discover', 'اكتشاف'],
  'teams.joinWithCode': ['Join with Invite Code', 'انضم برمز الدعوة'],
  'teams.inviteCodeHint': ['Team invite code', 'رمز دعوة الفريق'],
  'teams.find': ['Find', 'بحث'],
  'teams.searchPublic': ['Search Public Teams', 'ابحث في الفِرق العامة'],
  'teams.teamNameHint': ['Team name…', 'اسم الفريق…'],
  'teams.noPublicTeams': ['No public teams found.', 'لم يُعثر على فِرق عامة.'],

  // Deleted teams
  'teams.noDisbanded': ['No deleted teams.', 'لا توجد فِرق محذوفة.'],
  'teams.teamRestored': ['Team restored', 'تمت استعادة الفريق'],
  'teams.disbandedWord': ['Deleted', 'محذوف'],
  'teams.restoring': ['Restoring…', 'جارٍ الاستعادة…'],
  'teams.restoreTeam': ['Restore Team', 'استعادة الفريق'],
  'teams.cannotReactivate': [
    'Cannot reactivate (6-month window passed)',
    'لا يمكن إعادة التفعيل (انتهت مهلة الـ6 أشهر)'
  ],
};
