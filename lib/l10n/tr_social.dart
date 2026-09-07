// social cluster strings. {key: [English, العربية]}. Filled by the translation pass.
const Map<String, List<String>> trSocial = {
  // ---- Friends screen ----------------------------------------------------
  'social.aPlayer': ['A player', 'لاعب'],
  'social.playerFallback': ['Player', 'لاعب'],
  'social.signInToManage': ['Sign in to manage friends', 'سجّل الدخول لإدارة الأصدقاء'],
  'social.addBySearch': ['Add by search', 'الإضافة عبر البحث'],
  'social.searchHint': ['Username or name', 'اسم المستخدم أو الاسم'],
  'social.noPlayersFoundFor': [
    'No players found for',
    'لم يتم العثور على لاعبين مطابقين لـ'
  ],
  'social.contactSync': ['Contact sync', 'مزامنة جهات الاتصال'],
  'social.contactSyncSubtitle': [
    'Match phone contacts to YNO accounts',
    'طابق جهات اتصال الهاتف مع حسابات YNO'
  ],
  // Contact sync is switched on in Settings only; this page points there.
  'social.contactSyncEnableInSettings': [
    'Turn on Contact sync in Settings to find friends from your contacts',
    'فعّل مزامنة جهات الاتصال من الإعدادات للعثور على أصدقائك'
  ],
  'social.openSettings': ['Settings', 'الإعدادات'],
  'social.refresh': ['Refresh', 'تحديث'],
  'social.noContactsMatched': [
    'None of your contacts are on YNO yet. Nothing from your address book is stored.',
    'لا أحد من جهات اتصالك على YNO بعد. لا يتم تخزين أي شيء من دفتر عناوينك.'
  ],
  'social.suggestedFromContacts': [
    'Suggested from contacts',
    'مقترحون من جهات الاتصال'
  ],
  'social.requestsReceived': ['Requests received', 'الطلبات الواردة'],
  'social.requestsSent': ['Requests sent', 'الطلبات المرسلة'],
  'social.noFriendsYet': [
    'No friends yet. Search a username above or turn on contact sync.',
    'لا يوجد أصدقاء بعد. ابحث عن اسم مستخدم بالأعلى أو فعّل مزامنة جهات الاتصال.'
  ],
  'social.statusFriends': ['Friends', 'أصدقاء'],
  'social.pending': ['Pending', 'قيد الانتظار'],
  'social.accept': ['Accept', 'قبول'],
  'social.decline': ['Decline', 'رفض'],
  'social.requestSent': ['Friend request sent', 'تم إرسال طلب الصداقة'],
  'social.friendAdded': ['Friend added', 'تمت إضافة الصديق'],
  'social.requestDeclined': ['Request declined', 'تم رفض الطلب'],
  'social.requestCancelled': ['Request cancelled', 'تم إلغاء الطلب'],

  // ---- Compare screen ----------------------------------------------------
  'social.compare': ['Compare', 'مقارنة'],
  'social.matches': ['Matches', 'المباريات'],
  'social.goals': ['Goals', 'الأهداف'],
  'social.assists': ['Assists', 'التمريرات الحاسمة'],
  'social.wins': ['Wins', 'الانتصارات'],
  'social.losses': ['Losses', 'الخسائر'],
  'social.winRate': ['Win rate', 'نسبة الفوز'],
  'social.motm': ['MOTM', 'رجل المباراة'],
  'social.goalsPerMatch': ['Goals / match', 'أهداف لكل مباراة'],
  'social.youName': ['You', 'أنت'],
  'social.friendName': ['Friend', 'صديق'],
  'social.friendTag': ['Friend', 'صديق'],
  'social.deadEven': ['Dead even', 'تعادل تام'],
  'social.each': ['each', 'لكلٍّ'],
  'social.youLead': ['You lead', 'أنت متقدّم'],
  'social.friendLeads': ['Friend leads', 'الصديق متقدّم'],
  'social.couldntLoadFriend': [
    "Couldn't load this friend's profile.",
    'تعذّر تحميل ملف هذا الصديق.'
  ],
  'social.me': ['Me', 'أنا'],
  'social.vs': ['vs', 'ضد'],
  'social.compareYoursOnYno': [
    'Compare yours on YNO.',
    'قارن إحصائياتك على YNO.'
  ],
  'social.shareSubject': ['YNO stat comparison', 'مقارنة إحصائيات YNO'],

  // ---- Community screen --------------------------------------------------
  'social.winPct': ['Win %', 'نسبة الفوز %'],
  'social.weekly': ['Weekly', 'أسبوعي'],
  'social.monthly': ['Monthly', 'شهري'],
  'social.allTime': ['All time', 'كل الأوقات'],
  'social.global': ['Global', 'عالمي'],
  'social.contacts': ['Contacts', 'جهات الاتصال'],
  'social.rankedBy': ['RANKED BY', 'مُرتّب حسب'],
  'social.signInLeaderboard': [
    'Sign in to see your friends leaderboard.',
    'سجّل الدخول لرؤية لوحة متصدّري أصدقائك.'
  ],
  'social.buildLeaderboard': [
    'Add friends to build your leaderboard. Only you are here so far.',
    'أضف أصدقاء لبناء لوحة المتصدّرين. أنت الوحيد هنا حتى الآن.'
  ],
  'social.globalRankedByPoints': [
    'Global · ranked by points',
    'عالمي · مُرتّب حسب النقاط'
  ],
  'social.noPlayersYet': [
    'No players yet. Play a match to climb the board.',
    'لا يوجد لاعبون بعد. العب مباراة لتتسلّق لوحة المتصدّرين.'
  ],
  'social.peopleYouKnow': ['People you know on YNO', 'أشخاص تعرفهم على YNO'],
  'social.contactsPrivacy': [
    'YNO checks your phone contacts against registered players. Your contacts are never uploaded or stored — only matched.',
    'يقارن YNO جهات اتصال هاتفك باللاعبين المسجّلين. لا يتم رفع جهات اتصالك أو تخزينها أبداً — تتم مطابقتها فقط.'
  ],
  'social.checkingContacts': ['Checking contacts…', 'جارٍ فحص جهات الاتصال…'],
  'social.findFromContacts': [
    'Find friends from contacts',
    'ابحث عن أصدقاء من جهات الاتصال'
  ],
  'social.noContactsOnYno': [
    'None of your contacts are on YNO yet. Invite them with your referral code!',
    'لا أحد من جهات اتصالك على YNO بعد. ادعُهم برمز الإحالة الخاص بك!'
  ],
  'social.refreshContacts': ['Refresh contacts', 'تحديث جهات الاتصال'],
  'social.requested': ['Requested', 'تم الطلب'],
  'social.requestSentTo': [
    'Friend request sent to',
    'تم إرسال طلب صداقة إلى'
  ],
  'social.contactsPermissionDenied': [
    'Contacts permission denied. Enable it in Settings to find friends.',
    'تم رفض إذن الوصول إلى جهات الاتصال. فعّله من الإعدادات للعثور على الأصدقاء.'
  ],
  'social.couldNotReadContacts': [
    'Could not read contacts. Try again.',
    'تعذّرت قراءة جهات الاتصال. حاول مرة أخرى.'
  ],
  'social.outfieldPlayer': ['Outfield player', 'لاعب ميداني'],
};
