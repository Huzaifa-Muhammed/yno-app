// home cluster strings. {key: [English, العربية]}. Filled by the translation pass.
const Map<String, List<String>> trHome = {
  // Home screen
  'home.letsPlay': ["LET'S PLAY", 'هيا نلعب'],
  // Subtitles for the two rows of the Let's Play sheet.
  'home.createMatchSub': ['Set up a new match', 'أنشئ مباراة جديدة'],
  // ⚠️ Was 'Enter a match or team code' until 2026-08-21. The sheet's Join row
  // no longer offers teams — that moved to the drawer — and a subtitle that
  // promises a choice the screen does not offer is worse than none.
  'home.joinWithCodeSub': [
    'Enter the match code',
    'أدخل رمز المباراة'
  ],
  'home.joinAMatch': ['JOIN A MATCH', 'الانضمام إلى مباراة'],
  'home.joinCodePrompt': [
    'Enter the code the match admin shared with you.',
    'أدخل الرمز الذي شاركه معك مشرف المباراة.'
  ],
  'home.matchCodeHint': ['Match code', 'رمز المباراة'],
  'home.joining': ['Joining…', 'جارٍ الانضمام…'],
  'home.joinMatch': ['Join Match', 'انضم إلى المباراة'],
  'home.noMatchFound': [
    'No match found for that code.',
    'لم يتم العثور على مباراة بهذا الرمز.'
  ],
  'home.joinTeamPrompt': [
    'Enter the code the team owner or captain shared with you.',
    'أدخل الرمز الذي شاركه معك مالك الفريق أو القائد.'
  ],
  'home.teamCodeHint': ['Team code', 'رمز الفريق'],
  'home.joinTeam': ['Join Team', 'انضم إلى الفريق'],
  'home.noTeamFound': [
    'No team found for that code.',
    'لم يتم العثور على فريق بهذا الرمز.'
  ],
  // join_team_screen shows its refusals inline, so it needs the two cases the
  // old bottom sheet never had: an empty field and a failed write.
  'home.enterTeamCode': ['Enter the team code.', 'أدخل رمز الفريق.'],
  'home.couldNotJoinTeam': [
    'Could not join that team. Try again.',
    'تعذّر الانضمام إلى هذا الفريق. حاول مجددًا.'
  ],

  // Settings screen
  'home.notifications': ['Notifications', 'الإشعارات'],
  'home.matchTeamAlerts': ['Match & team alerts', 'تنبيهات المباريات والفريق'],
  'home.friendActivity': [
    'Friend activity & follows',
    'نشاط الأصدقاء والمتابعات'
  ],
  'home.account': ['Account', 'الحساب'],
  'home.editProfile': ['Edit profile', 'تعديل الملف الشخصي'],
  'home.contactSync': ['Contact sync', 'مزامنة جهات الاتصال'],
  // State-neutral: the switch already shows on/off, so the subtitle only has
  // to carry the reassurance (which is true either way — matching is a lookup,
  // contacts are never stored).
  'home.contactSyncSub': [
    'Contacts never leave your phone',
    'لا تغادر جهات اتصالك هاتفك أبدًا'
  ],
  'home.deactivateAccount': ['Deactivate account', 'إلغاء تنشيط الحساب'],
  'home.support': ['Support', 'الدعم'],
  'home.dangerZone': ['Danger Zone', 'منطقة الخطر'],
  'home.deleteAllMyData': ['Delete all my data', 'حذف جميع بياناتي'],
  'home.deleteAllMyDataSub': [
    'Permanently erase your account — cannot be undone',
    'امحُ حسابك نهائيًا — لا يمكن التراجع'
  ],
  'home.deactivateTitle': ['DEACTIVATE ACCOUNT', 'إلغاء تنشيط الحساب'],
  'home.deactivateBody': [
    "Your profile is hidden and you're signed out. It reactivates when you log back in after the period — or sooner if you choose. Maximum one month.",
    'يُخفى ملفك الشخصي ويتم تسجيل خروجك. يُعاد تنشيطه عند تسجيل دخولك مرة أخرى بعد انتهاء المدة — أو قبل ذلك إن أردت. الحد الأقصى شهر واحد.'
  ],
  'home.days': ['days', 'أيام'],
  'home.oneMonth30': ['1 month (30 days)', 'شهر واحد (30 يومًا)'],
  'home.deleteAllDataTitle': ['DELETE ALL DATA', 'حذف جميع البيانات'],
  'home.deleteAllDataBody': [
    'This permanently erases your profile, stats, match history, teams you own, friends and notifications. This cannot be undone.',
    'يؤدي هذا إلى محو ملفك الشخصي وإحصائياتك وسجل مبارياتك والفرق التي تملكها وأصدقائك وإشعاراتك نهائيًا. لا يمكن التراجع عن ذلك.'
  ],
  'home.signedIn': ['Signed in', 'مُسجّل الدخول'],

  // Help screen
  'home.frequentlyAsked': ['Frequently Asked', 'الأسئلة الشائعة'],
  'home.stillNeedHelp': ['Still Need Help?', 'ما زلت بحاجة إلى مساعدة؟'],
  'home.contactYnoTeam': ['Contact the YNO team', 'تواصل مع فريق YNO'],
  'home.contactBlurb': [
    'Reach out and we usually reply within a day.',
    'تواصل معنا وعادةً ما نردّ خلال يوم واحد.'
  ],
  'home.faqStartQ': ['How do I start a match?', 'كيف أبدأ مباراة؟'],
  // ⚠️ These three answers described screens that no longer exist. Corrected
  // 2026-08-21 (§65). What they claimed, and why each was wrong:
  //   faqStart — "or the Play tab": the bottom nav bar was deleted in §39.
  //   faqJoin  — "browse open games under Find a Match": `find_match_screen`
  //              was deleted; every match is private and joined by code.
  //              Also said "Join with Code", now "Join Match".
  //   faqTeam  — "Open My Teams from the menu": My Teams is deliberately NOT
  //              in the drawer (it is on Home), and joining by code is now its
  //              own drawer page.
  // Help copy that names a missing screen is worse than no help at all.
  'home.faqStartA': [
    'Tap the big يلا نلعب button on Home, choose Create Match, then set it up. Share the code so friends can join.',
    'اضغط على زر يلا نلعب الكبير في الرئيسية، اختر «إنشاء مباراة»، ثم جهّزها. شارك الرمز لينضم أصدقاؤك.'
  ],
  'home.faqJoinQ': ['How do I join a match?', 'كيف أنضم إلى مباراة؟'],
  'home.faqJoinA': [
    'Tap the big يلا نلعب button on Home, choose Join Match, and enter the code the match admin shared with you.',
    'اضغط على زر يلا نلعب الكبير في الرئيسية، اختر «انضم إلى المباراة»، وأدخل الرمز الذي شاركه معك مشرف المباراة.'
  ],
  'home.faqPointsQ': ['How do I earn YNO points?', 'كيف أكسب نقاط YNO؟'],
  'home.faqPointsA': [
    'Points are earned by playing matches, community recognition and referring friends. A rewards store to spend them arrives in V2.',
    'تُكتسب النقاط بلعب المباريات وتقدير المجتمع ودعوة الأصدقاء. وسيصل متجر المكافآت لإنفاقها في الإصدار الثاني.'
  ],
  'home.faqTeamQ': [
    'How do I create or join a team?',
    'كيف أنشئ فريقًا أو أنضم إليه؟'
  ],
  'home.faqTeamA': [
    'Tap My Teams on Home to create one or manage the teams you are in. To join a team someone invited you to, open the menu and choose Join a Team, then enter their invite code.',
    'اضغط «فِرقي» في الرئيسية لإنشاء فريق أو إدارة فِرقك. وللانضمام إلى فريق دعاك إليه أحدهم، افتح القائمة واختر «الانضمام إلى فريق»، ثم أدخل رمز الدعوة.'
  ],

  // About screen
  'home.termsTitle': ['Terms & Conditions', 'الشروط والأحكام'],
  'home.termsBody': [
    'By using YNO you agree to play fair, log matches honestly and treat other players with respect. Accounts that abuse the stats system, harass others or attempt to game points may be suspended. YNO is provided as-is while we build towards V2.',
    'باستخدامك YNO فإنك توافق على اللعب النزيه وتسجيل المباريات بأمانة ومعاملة اللاعبين الآخرين باحترام. قد يتم تعليق الحسابات التي تسيء استخدام نظام الإحصائيات أو تضايق الآخرين أو تحاول التلاعب بالنقاط. يُقدَّم YNO كما هو بينما نعمل نحو الإصدار الثاني.'
  ],
  'home.privacyTitle': ['Privacy Policy', 'سياسة الخصوصية'],
  'home.privacyBody': [
    'We store only what YNO needs to run: your profile, matches, teams, friends and stats. Contacts never leave your phone unless you enable contact sync. We do not sell your data. You can request account deletion at any time from Settings.',
    'نخزّن فقط ما يحتاجه YNO للعمل: ملفك الشخصي ومبارياتك وفرقك وأصدقاؤك وإحصائياتك. لا تغادر جهات الاتصال هاتفك ما لم تفعّل مزامنة جهات الاتصال. نحن لا نبيع بياناتك. ويمكنك طلب حذف الحساب في أي وقت من الإعدادات.'
  ],
  'home.readFullTerms': ['Read the full Terms & Conditions →', 'اقرأ الشروط والأحكام كاملة ←'],
  'home.readFullPrivacy': ['Read the full Privacy Policy →', 'اقرأ سياسة الخصوصية كاملة ←'],
  'home.version': ['VERSION', 'الإصدار'],

  // Side drawer
  'home.sectionProfile': ['Profile', 'الملف الشخصي'],
  'home.sectionPlay': ['Play', 'العب'],
  'home.sectionMore': ['More', 'المزيد'],
  'home.logoutTitle': ['LOG OUT?', 'تسجيل الخروج؟'],
  'home.logoutBody': [
    'You will need to sign in again to get back into YNO.',
    'ستحتاج إلى تسجيل الدخول مرة أخرى للعودة إلى YNO.'
  ],
  'home.languageSheetTitle': ['LANGUAGE', 'اللغة'],
};
