// profile cluster strings. {key: [English, العربية]}. Filled by the translation pass.
const Map<String, List<String>> trProfile = {
  // Titles
  'profile.title': ['Profile', 'الملف الشخصي'],
  'profile.editTitle': ['Edit Profile', 'تعديل الملف الشخصي'],

  // Stat tile labels
  'profile.matches': ['Matches', 'المباريات'],
  'profile.goals': ['Goals', 'الأهداف'],
  'profile.assists': ['Assists', 'التمريرات الحاسمة'],
  'profile.winPct': ['Win %', 'نسبة الفوز'],
  'profile.wins': ['Wins', 'الانتصارات'],
  'profile.losses': ['Losses', 'الهزائم'],
  'profile.draws': ['Draws', 'التعادلات'],
  'profile.awards': ['Awards', 'الجوائز'],
  'profile.careerGoals': ['Career Goals', 'أهداف المسيرة'],
  'profile.careerAssists': ['Career Assists', 'تمريرات المسيرة'],
  'profile.goalsPerMatch': ['Goals / Match', 'أهداف / مباراة'],
  'profile.assistsPerMatch': ['Assists / Match', 'تمريرات / مباراة'],
  'profile.goalContributions': ['Goal Contributions', 'المساهمات التهديفية'],
  'profile.contribPerMatch': ['Contrib / Match', 'مساهمات / مباراة'],
  'profile.hatTricks': ['Hat Tricks', 'الهاتريك'],
  'profile.bestMatch': ['Best Match', 'أفضل مباراة'],
  'profile.motm': ['Man of the Match', 'رجل المباراة'],
  'profile.totalMotm': ['Total MOTM', 'إجمالي جوائز الأفضل'],

  // Section headers
  'profile.matchHistory': ['Match History', 'سجل المباريات'],
  'profile.matchRecord': ['Match Record', 'سجل النتائج'],
  'profile.scoring': ['Scoring', 'التسجيل'],
  'profile.scoringRecognition': ['Scoring & Recognition', 'التسجيل والتقدير'],
  'profile.recognition': ['Recognition', 'التقدير'],
  'profile.historicalTeams': ['Historical Teams', 'الفرق السابقة'],
  'profile.playedWith': ["Players I've Played With", 'اللاعبون الذين لعبت معهم'],
  'profile.about': ['About', 'نبذة'],

  // Empty / muted states
  'profile.emptyFirstMatch': [
    'Play your first match to start building your record.',
    'العب أول مباراة لك لبدء بناء سجلك.'
  ],
  'profile.noTeams': ['You are not part of any team yet.', 'لست عضواً في أي فريق بعد.'],
  'profile.noPastTeams': ['No past teams yet.', 'لا توجد فرق سابقة بعد.'],
  'profile.noPlayedWith': [
    'No one yet — play a match to build this list.',
    'لا أحد بعد — العب مباراة لبناء هذه القائمة.'
  ],
  'profile.noMatchesYet': ['No matches yet', 'لا مباريات بعد'],
  'profile.noMatchesPlayed': ['No matches played yet.', 'لم تُلعب أي مباريات بعد.'],
  'profile.noGoalsRecorded': ['No goals recorded yet', 'لم تُسجَّل أهداف بعد'],

  // Teams / played-with
  'profile.disbanded': ['Disbanded', 'منحل'],
  'profile.played': ['Played', 'لعبت'],
  'profile.pending': ['Pending', 'قيد الانتظار'],
  'profile.friendRequestSent': ['Friend request sent', 'تم إرسال طلب الصداقة'],
  'profile.aPlayer': ['A player', 'لاعب'],

  // About rows / referral
  'profile.dob': ['Date of birth', 'تاريخ الميلاد'],
  'profile.phone': ['Phone', 'الهاتف'],
  'profile.email': ['Email', 'البريد الإلكتروني'],
  'profile.memberSince': ['Member since', 'عضو منذ'],
  'profile.referralCode': ['REFERRAL CODE', 'رمز الإحالة'],
  'profile.referralCopied': ['Referral code copied', 'تم نسخ رمز الإحالة'],
  'profile.couldNotOpenLink': ['Could not open link', 'تعذّر فتح الرابط'],
  'profile.referralShareMsg1': [
    'Join me on YNO! Use my referral code',
    'انضم إليّ على YNO! استخدم رمز الإحالة الخاص بي'
  ],
  'profile.referralShareMsg2': ['when you sign up.', 'عند التسجيل.'],

  // Public profile
  'profile.unavailable': ['Profile unavailable', 'الملف الشخصي غير متاح'],
  'profile.deactivated': ['This account is currently deactivated.', 'هذا الحساب معطّل حالياً.'],
  'profile.follow': ['Follow', 'متابعة'],
  'profile.following': ['Following', 'تتابع'],
  'profile.unfollowed': ['Unfollowed', 'تم إلغاء المتابعة'],
  'profile.addFriend': ['Add Friend', 'إضافة صديق'],
  'profile.form': ['FORM', 'الأداء'],
  'profile.shareCheck': ['Check out', 'اطّلع على'],
  'profile.shareOnYno': ['on YNO', 'على YNO'],
  'profile.thisPlayer': ['this player', 'هذا اللاعب'],

  // Stats screen
  'profile.allTime': ['All Time', 'كل الأوقات'],
  'profile.thisMonth': ['This Month', 'هذا الشهر'],
  'profile.thisWeek': ['This Week', 'هذا الأسبوع'],
  'profile.career': ['CAREER', 'المسيرة'],
  'profile.noFormYet': ['Current form: no matches yet', 'الأداء الحالي: لا مباريات بعد'],
  'profile.currentStreak': ['Current streak', 'السلسلة الحالية'],
  'profile.longestStreak': ['Longest streak', 'أطول سلسلة'],
  'profile.longestUnbeaten': ['Longest unbeaten', 'أطول سلسلة دون هزيمة'],
  'profile.goalsByFormat': ['Goals by format', 'الأهداف حسب النظام'],
  'profile.statsInfoAllTime': [
    '📊 Every stat is calculated automatically from match data. New players show 0 until their first finished match.',
    '📊 تُحتسب كل الإحصائيات تلقائياً من بيانات المباريات. يظهر للاعبين الجدد 0 حتى أول مباراة منتهية.'
  ],
  'profile.statsInfoWindowed': [
    '📊 Match record, scoring, assists and recognition above cover the selected window. Form, streaks and surface/format breakdowns are lifetime records.',
    '📊 يغطي سجل المباريات والتسجيل والتمريرات والتقدير أعلاه الفترة المحددة. أما الأداء والسلاسل وتوزيع الملاعب/الأنظمة فهي سجلات المسيرة الكاملة.'
  ],

  // Edit profile — field labels
  'profile.fullName': ['Full name', 'الاسم الكامل'],
  'profile.yourNameHint': ['Your name', 'اسمك'],
  'profile.username': ['Username', 'اسم المستخدم'],
  'profile.usernameHint': ['username', 'اسم المستخدم'],
  'profile.position': ['Position', 'المركز'],
  'profile.preferredFoot': ['Preferred foot', 'القدم المفضلة'],
  'profile.skillLevel': ['Skill level', 'مستوى المهارة'],
  'profile.selectDate': ['Select date', 'اختر التاريخ'],
  'profile.locked': ['Locked', 'مقفل'],
  'profile.editableOnce': ['Editable once', 'قابل للتعديل مرة واحدة'],
  'profile.socialLinks': ['Social Links', 'روابط التواصل'],
  'profile.privacy': ['Privacy', 'الخصوصية'],
  'profile.publicProfile': ['Public profile', 'ملف عام'],
  'profile.privateProfile': ['Private profile', 'ملف خاص'],
  'profile.publicProfileSub': [
    'Anyone can see your stats and match history.',
    'يمكن لأي شخص رؤية إحصائياتك وسجل مبارياتك.'
  ],
  'profile.privateProfileSub': [
    'Only friends can see your stats and match history.',
    'يمكن للأصدقاء فقط رؤية إحصائياتك وسجل مبارياتك.'
  ],
  'profile.privateTitle': ['This profile is private', 'هذا الملف خاص'],
  'profile.privateBody': [
    'Send a friend request to see their stats and match history.',
    'أرسل طلب صداقة لرؤية إحصائياته وسجل مبارياته.'
  ],
  'profile.visOff': ['Off', 'مغلق'],
  'profile.visPublic': ['Public', 'عام'],
  'profile.saveChanges': ['Save Changes', 'حفظ التغييرات'],
  'profile.changePassword': ['Change Password', 'تغيير كلمة المرور'],
  'profile.currentPassword': ['Current password', 'كلمة المرور الحالية'],
  'profile.newPassword': ['New password', 'كلمة المرور الجديدة'],
  'profile.updating': ['Updating…', 'جارٍ التحديث…'],
  'profile.updatePassword': ['Update Password', 'تحديث كلمة المرور'],
  'profile.uploading': ['Uploading…', 'جارٍ الرفع…'],
  'profile.changePhoto': ['Change photo', 'تغيير الصورة'],
  'profile.accountInfoNote': [
    'ℹ️ Account creation date is a permanent record and can’t be changed. Date of birth can be set once, then locks.',
    'ℹ️ تاريخ إنشاء الحساب سجل دائم لا يمكن تغييره. يمكن ضبط تاريخ الميلاد مرة واحدة ثم يُقفل.'
  ],

  // Edit profile — username availability notes
  'profile.usernameCooldownNote': [
    'Changing your username is limited — a cooldown applies each change.',
    'تغيير اسم المستخدم محدود — تُطبّق فترة انتظار عند كل تغيير.'
  ],
  'profile.usernameAvailable': [
    '✓ Available. A cooldown applies after you change it.',
    '✓ متاح. تُطبّق فترة انتظار بعد تغييره.'
  ],
  'profile.usernameTakenNote': ['✗ That username is already taken.', '✗ اسم المستخدم هذا مستخدم بالفعل.'],
  'profile.checking': ['Checking…', 'جارٍ التحقق…'],

  // Edit profile — toasts / validation
  'profile.uploadFailed': ['Upload failed. Try again.', 'فشل الرفع. حاول مرة أخرى.'],
  'profile.uploadPhotoError': ['Could not upload the photo.', 'تعذّر رفع الصورة.'],
  'profile.dobLockedToast': ['Date of birth is locked and can’t be changed.', 'تاريخ الميلاد مقفل ولا يمكن تغييره.'],
  'profile.nameEmpty': ['Name cannot be empty.', 'لا يمكن أن يكون الاسم فارغاً.'],
  'profile.usernameEmpty': ['Username cannot be empty.', 'لا يمكن أن يكون اسم المستخدم فارغاً.'],
  'profile.usernameTaken': ['That username is taken.', 'اسم المستخدم هذا مستخدم بالفعل.'],
  'profile.profileSaved': ['Profile saved', 'تم حفظ الملف الشخصي'],
  'profile.saveError': ['Could not save. Try again.', 'تعذّر الحفظ. حاول مرة أخرى.'],
  'profile.pwEnterBoth': ['Enter your current and new password.', 'أدخل كلمة المرور الحالية والجديدة.'],
  'profile.pwTooShort': [
    'New password must be at least 6 characters.',
    'يجب أن تتكون كلمة المرور الجديدة من 6 أحرف على الأقل.'
  ],
  'profile.pwNoAccount': ['Not signed in with a password account.', 'لست مسجّلاً الدخول بحساب كلمة مرور.'],
  'profile.pwUpdated': ['Password updated', 'تم تحديث كلمة المرور'],
  'profile.pwUpdateError': ['Could not update password.', 'تعذّر تحديث كلمة المرور.'],

  // Attribute values (position / foot / skill / language chips)
  'profile.posGoalkeeper': ['Goalkeeper', 'حارس مرمى'],
  'profile.posDefender': ['Defender', 'مدافع'],
  'profile.posMidfielder': ['Midfielder', 'لاعب وسط'],
  'profile.posForward': ['Forward', 'مهاجم'],
  'profile.footLeft': ['Left', 'يسرى'],
  'profile.footRight': ['Right', 'يمنى'],
  'profile.footBoth': ['Both', 'كلتاهما'],
  'profile.skillBeginner': ['Beginner', 'مبتدئ'],
  'profile.skillIntermediate': ['Intermediate', 'متوسط'],
  'profile.skillAdvanced': ['Advanced', 'متقدم'],
  'profile.langEnglish': ['English', 'الإنجليزية'],
  'profile.langArabic': ['Arabic', 'العربية'],
};
