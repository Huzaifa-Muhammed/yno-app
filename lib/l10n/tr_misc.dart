// misc cluster strings. {key: [English, العربية]}. Filled by the translation pass.

const Map<String, List<String>> trMisc = {
  // Notifications
  'misc.notifications': ['Notifications', 'الإشعارات'],
  'misc.markAllRead': ['Mark all read', 'تحديد الكل كمقروء'],
  'misc.allMarkedRead': ['All marked as read', 'تم تحديد الكل كمقروء'],
  'misc.allCaughtUp': ["You're all caught up", 'لا يوجد جديد'],
  'misc.notifEmptyBody': [
    'Match invites, results and social activity show up here.',
    'تظهر هنا دعوات المباريات والنتائج والنشاط الاجتماعي.'
  ],
  'misc.tapToOpen': ['Tap to open →', 'اضغط للفتح ←'],
  'misc.justNow': ['just now', 'الآن'],
  'misc.minAgo': ['m ago', 'د'],
  'misc.hourAgo': ['h ago', 'س'],
  'misc.dayAgo': ['d ago', 'ي'],
  'misc.weekAgo': ['w ago', 'أ'],

  // Referral
  'misc.referEarn': ['Refer & Earn', 'الإحالة والكسب'],
  'misc.inviteEarnHeadline': ['INVITE FRIENDS,\nEARN POINTS', 'ادعُ أصدقاءك،\nواكسب النقاط'],
  'misc.rewardYou': ['You ', 'أنت '],
  'misc.rewardFriend': ['and your friend', 'وصديقك'],
  'misc.rewardEachEarn': [' each earn ', ' تكسبان معًا '],
  'misc.points': ['points', 'نقطة'],
  'misc.rewardMoment': [
    ' the moment they sign up with your code.',
    ' بمجرد تسجيله باستخدام رمزك.'
  ],
  'misc.yourCode': ['YOUR CODE', 'رمزك'],
  'misc.friendsJoined': ['Friends joined', 'الأصدقاء المنضمّون'],
  'misc.pointsFromReferrals': ['Points from referrals', 'نقاط من الإحالات'],
  'misc.whoJoined': ['WHO JOINED WITH YOUR CODE', 'من انضم برمزك'],
  'misc.referralFooter': [
    'Friends enter your code on the referral step during sign-up. '
        'Points are credited automatically to both of you.',
    'يُدخل أصدقاؤك رمزك في خطوة الإحالة أثناء التسجيل. '
        'وتُضاف النقاط تلقائيًا لكليكما.'
  ],
  'misc.noReferralsYet': ['No referrals yet', 'لا توجد إحالات بعد'],
  'misc.shareToEarn': ['Share your code to start earning.', 'شارِك رمزك لتبدأ الكسب.'],
  'misc.codeCopied': ['Code copied', 'تم نسخ الرمز'],
  'misc.couldNotShare': ['Could not open share', 'تعذّر فتح المشاركة'],
  'misc.joined': ['Joined', 'انضم في'],
  'misc.ynoPlayer': ['YNO player', 'لاعب YNO'],
  'misc.pts': ['pts', 'نقطة'],
  'misc.shareSubject': ['Join me on YNO', 'انضم إليّ على YNO'],
  'misc.shareMsgA': [
    'Join me on YNO ⚽ Use my referral code ',
    'انضم إليّ على YNO ⚽ استخدم رمز الإحالة الخاص بي '
  ],
  // ⚠️ The URL here is [referralLink], NOT [kJoinBaseUrl] — they are different
  // pages for different codes. This used to append the *match join* page with
  // the referral code sitting beside it as loose text, so a friend who tapped
  // the link arrived at a match-join form with nothing filled in and the code
  // as something to read and retype. The message is interpolated per language
  // from a const, so a domain change can no longer update English and miss
  // Arabic.
  //
  // The code stays in the body as well as in the link: WhatsApp previews strip
  // to the URL on some clients, and it is what someone reads out loud.
  'misc.shareMsgB': [
    ' when you sign up — we both earn points! ',
    ' عند التسجيل — كلانا يكسب نقاطًا! '
  ],
  // Shown when a referral link is opened by somebody who ALREADY has an
  // account. A referral is written to `referredBy` at signup and nowhere else,
  // so there is genuinely nothing to apply — the honest move is to say so
  // rather than let the code sit unused and look broken later.
  'misc.referralTooLateTitle': [
    'Invite codes work at sign-up',
    'رموز الدعوة تعمل عند التسجيل'
  ],
  'misc.referralTooLateBody': [
    'You already have a YNO account, so this code can\'t be added to it — a '
        'referral only counts when the account is created. Share your own code '
        'instead and earn points when a friend joins.',
    'لديك حساب YNO بالفعل، لذا لا يمكن إضافة هذا الرمز إليه — تُحتسب الإحالة '
        'عند إنشاء الحساب فقط. شارك رمزك الخاص بدلًا من ذلك واكسب نقاطًا عند '
        'انضمام صديق.'
  ],

  // ---- Report a Bug / Send a Suggestion (side drawer) ---------------------
  // One screen serves both; these are the strings that differ between them.
  // The drawer labels themselves are `drawer.reportBug` / `drawer.suggestion`
  // in tr_common.dart, next to the other drawer rows.
  'feedback.bugBlurb': [
    'Something not working? Tell us what went wrong and we will look into it.',
    'هناك شيء لا يعمل؟ أخبرنا بما حدث وسنتحقق منه.'
  ],
  'feedback.ideaBlurb': [
    'Got an idea for YNO? We read every suggestion that comes in.',
    'لديك فكرة لـ YNO؟ نقرأ كل اقتراح يصلنا.'
  ],
  'feedback.whatHappened': ['What happened?', 'ماذا حدث؟'],
  'feedback.yourIdea': ['Your idea', 'فكرتك'],
  'feedback.bugHint': [
    'What were you doing when it went wrong? The more detail, the faster we can fix it.',
    'ماذا كنت تفعل عندما حدث الخطأ؟ كلما زادت التفاصيل، أسرعنا في الإصلاح.'
  ],
  'feedback.ideaHint': [
    'What would you like YNO to do?',
    'ما الذي تودّ أن يفعله YNO؟'
  ],
  'feedback.send': ['Send', 'إرسال'],
  'feedback.sending': ['Sending…', 'جارٍ الإرسال…'],
  'feedback.sendFailed': [
    'Could not send that — check your connection and try again.',
    'تعذّر الإرسال — تحقق من اتصالك وحاول مجددًا.'
  ],
  // Said out loud because it is collected without being asked for. It also
  // saves the reporter from typing any of it themselves.
  'feedback.attachedNote': [
    'Your name, email, app version and device type are sent with this so we can follow up.',
    'يُرسل معه اسمك وبريدك الإلكتروني وإصدار التطبيق ونوع الجهاز حتى نتمكن من المتابعة.'
  ],
  'feedback.thanksTitle': ['Thank you!', 'شكرًا لك!'],
  'feedback.thanksBug': [
    'Your report is with the YNO team. If we need more detail, we will reach out by email.',
    'وصل بلاغك إلى فريق YNO. إذا احتجنا مزيدًا من التفاصيل سنتواصل معك عبر البريد الإلكتروني.'
  ],
  'feedback.thanksIdea': [
    'Your suggestion is with the YNO team. The best ideas here come from players.',
    'وصل اقتراحك إلى فريق YNO. أفضل الأفكار هنا تأتي من اللاعبين.'
  ],
  'feedback.reportAnother': ['Report something else', 'أبلغ عن شيء آخر'],
  'feedback.suggestAnother': ['Suggest something else', 'اقترح شيئًا آخر'],
};
