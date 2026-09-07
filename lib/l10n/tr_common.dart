// Shared strings (actions, nav, common labels). {key: [English, العربية]}.
// Agents: reuse these `common.*` keys for shared actions instead of adding
// duplicates in feature clusters.
const Map<String, List<String>> trCommon = {
  // Actions
  'common.cancel': ['Cancel', 'إلغاء'],
  'common.save': ['Save', 'حفظ'],
  'common.confirm': ['Confirm', 'تأكيد'],
  'common.saving': ['Saving…', 'جارٍ الحفظ…'],
  'common.done': ['Done', 'تم'],
  'common.gotIt': ['Got it', 'فهمت'],
  'common.back': ['Back', 'رجوع'],
  'common.continue': ['Continue', 'متابعة'],
  'common.delete': ['Delete', 'حذف'],
  'common.add': ['Add', 'إضافة'],
  'common.edit': ['Edit', 'تعديل'],
  'common.share': ['Share', 'مشاركة'],
  'common.copy': ['Copy', 'نسخ'],
  'common.search': ['Search', 'بحث'],
  'common.retry': ['Retry', 'إعادة المحاولة'],
  'common.close': ['Close', 'إغلاق'],
  'common.create': ['Create', 'إنشاء'],
  'common.loading': ['Loading…', 'جارٍ التحميل…'],
  'common.you': ['YOU', 'أنت'],

  // Section labels (the bottom nav is gone; these survive as page/stat labels)
  // The PAGE title. Kept separate from `nav.community` below, which is also
  // the profile's Community-award stat label — renaming that one would have
  // relabelled an award count "Your Friends".
  'nav.yourFriends': ['Your Friends', 'أصدقاؤك'],
  'nav.community': ['Community', 'المجتمع'],
  'common.match': ['Match', 'مباراة'],
  'common.team': ['Team', 'فريق'],

  // Draft Matches page — the one draft, plus the ongoing match and played history.
  'matches.title': ['Draft Matches', 'مسودات المباريات'],
  'matches.ongoing': ['Playing now', 'تُلعب الآن'],
  'matches.liveNow': ['Live', 'مباشر'],
  'matches.draft': ['Draft', 'مسودة'],
  'matches.played': ['Played', 'مباريات سابقة'],
  'matches.emptyTitle': ['No matches yet', 'لا توجد مباريات بعد'],

  // Draft match — the user's ONE created-but-never-started match.
  'draft.badge': ['DRAFT', 'مسودة'],
  'draft.warning': [
    'Not started yet. A draft is deleted 2 days after it\'s created if the match still hasn\'t started — its data will be lost. Open it and press Start to keep it.',
    'لم تبدأ بعد. تُحذف المسودة بعد يومين من إنشائها إذا لم تبدأ المباراة — وستُفقد بياناتها. افتحها واضغط ابدأ للاحتفاظ بها.'
  ],
  'draft.deletesIn': ['Deletes in', 'تُحذف خلال'],
  'draft.deletesSoon': ['Deletes soon', 'تُحذف قريبًا'],
  'draft.emptyBody': [
    'A match you create but never start waits here. You can hold only one draft at a time.',
    'المباراة التي تنشئها ولا تبدأها تنتظر هنا. يمكنك الاحتفاظ بمسودة واحدة فقط في كل مرة.'
  ],
  'draft.createMatch': ['Create Match', 'إنشاء مباراة'],
  'draft.resume': ['Open & Continue', 'افتح وتابع'],
  'draft.delete': ['Delete Draft', 'حذف المسودة'],
  'draft.deleteTitle': ['Delete this draft?', 'حذف هذه المسودة؟'],
  'draft.deleteBody': [
    'This permanently deletes the draft and everything set up in it:',
    'سيؤدي هذا إلى حذف المسودة وكل ما تم إعداده فيها نهائيًا:'
  ],
  'draft.deleted': ['Draft deleted', 'تم حذف المسودة'],
  'draft.deleteFailed': ['Couldn\'t delete the draft', 'تعذّر حذف المسودة'],
  'draft.existsTitle': ['You already have a draft', 'لديك مسودة بالفعل'],
  'draft.existsBody': [
    'You can hold only one draft at a time. Continue it or delete it before creating a new match:',
    'يمكنك الاحتفاظ بمسودة واحدة فقط. تابعها أو احذفها قبل إنشاء مباراة جديدة:'
  ],
  'draft.deleteAndCreate': ['Delete it & start new', 'احذفها وابدأ جديدة'],

  // Side drawer
  'drawer.myProfile': ['My Profile', 'ملفي الشخصي'],
  'drawer.myTeams': ['My Teams', 'فِرقي'],
  'drawer.friends': ['Friends', 'الأصدقاء'],
  'drawer.createMatch': ['Create a Match', 'إنشاء مباراة'],
  'drawer.draftMatches': ['Draft Matches', 'مسودات المباريات'],
  'drawer.joinTeam': ['Join a Team', 'الانضمام إلى فريق'],
  'drawer.referral': ['Referral', 'الإحالة'],
  'drawer.settings': ['Settings', 'الإعدادات'],
  'drawer.help': ['Help & Support', 'المساعدة والدعم'],
  'drawer.reportBug': ['Report a Bug', 'الإبلاغ عن مشكلة'],
  'drawer.suggestion': ['Send a Suggestion', 'إرسال اقتراح'],
  'drawer.about': ['About YNO', 'عن YNO'],
  'drawer.language': ['Language', 'اللغة'],
  'drawer.logout': ['Log Out', 'تسجيل الخروج'],

  // Roles / badges
  'role.owner': ['Owner', 'المالك'],
  'role.captain': ['Captain', 'القائد'],
  'role.vice': ['Vice Captain', 'نائب القائد'],
  'role.player': ['Player', 'لاعب'],
  'badge.admin': ['ADMIN', 'مشرف'],
  'badge.guest': ['GUEST', 'ضيف'],

  // Results
  'result.win': ['Win', 'فوز'],
  'result.loss': ['Loss', 'خسارة'],
  'result.draw': ['Draw', 'تعادل'],
};
