// auth cluster strings. {key: [English, العربية]}. Filled by the translation pass.
const Map<String, List<String>> trAuth = {
  // ---- Welcome ----------------------------------------------------------
  'auth.taglinePlay': ['PLAY', 'العب'],
  'auth.taglineEarn': ['EARN', 'اكسب'],
  'auth.taglineRecognised': ['BE RECOGNISED', 'كن معروفًا'],
  'auth.welcomeSubtitle': [
    'The stats home for street & amateur football in Dubai. Log a match, build your legend.',
    'مركز الإحصائيات لكرة القدم في الشوارع والهواة في دبي. سجّل مباراة وابنِ أسطورتك.'
  ],
  'auth.createAccount': ['Create Account', 'إنشاء حساب'],
  'auth.login': ['Log In', 'تسجيل الدخول'],

  // ---- Single-page sign up ----------------------------------------------
  'auth.signupSub': [
    'Just the essentials — you can add the rest later.',
    'الأساسيات فقط — يمكنك إضافة الباقي لاحقًا.'
  ],
  'auth.fullNameLabel': ['Full name', 'الاسم الكامل'],
  'auth.fullNameHint': ['e.g. Ali Raza', 'مثال: علي رضا'],
  'auth.pwMin8': ['Password must be at least 8 characters.', 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.'],
  'auth.referralChecking': ['Checking code…', 'جارٍ التحقق من الرمز…'],
  'auth.referralValid': ['✓ Valid referral code', '✓ رمز إحالة صالح'],
  'auth.referralInvalid': ['✗ Code not found — check and try again', '✗ الرمز غير موجود — تحقق وحاول مجددًا'],
  // Shown instead of `referralValid` when the code filled itself in from a
  // tapped nellab.org/r/<code> link (or the Play Store referrer that survived
  // the install) rather than being typed. A field that populates on its own
  // otherwise reads as a glitch.
  'auth.referralFromLink': [
    '✓ Invite applied from your link',
    '✓ تم تطبيق الدعوة من الرابط'
  ],
  // A link whose code no longer resolves. Deliberately not `referralInvalid`:
  // there is nothing here for the user to "check and try again" — they typed
  // nothing, so telling them to correct it sends them looking for a mistake
  // they did not make.
  'auth.referralLinkExpired': [
    '✗ This invite link is no longer valid',
    '✗ لم يعد رابط الدعوة هذا صالحًا'
  ],
  'auth.consent': [
    'By creating an account you agree to our Terms & Privacy Policy.',
    'بإنشاء حساب فإنك توافق على الشروط وسياسة الخصوصية.'
  ],
  'auth.agreePrefix': [
    "By continuing you agree to YNO's",
    'بالمتابعة، فإنك توافق على'
  ],
  'auth.terms': ['Terms', 'الشروط'],
  'auth.and': ['&', 'و'],
  'auth.privacyPolicy': ['Privacy Policy', 'سياسة الخصوصية'],

  // ---- Splash (offline) -------------------------------------------------
  'auth.offlineMessage': [
    'No internet connection.\nCheck your network and try again.',
    'لا يوجد اتصال بالإنترنت.\nتحقق من شبكتك وحاول مرة أخرى.'
  ],

  // ---- Forgot password --------------------------------------------------
  'auth.resetPasswordTitle': ['Reset Password', 'إعادة تعيين كلمة المرور'],
  'auth.resetPasswordHeading': ['RESET\nPASSWORD', 'إعادة تعيين\nكلمة المرور'],
  'auth.resetPasswordSub': [
    "Enter your email and we'll send you a reset link.",
    'أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين.'
  ],
  'auth.emailLabel': ['Email address', 'البريد الإلكتروني'],
  'auth.invalidEmail': [
    'Enter a valid email address.',
    'أدخل بريدًا إلكترونيًا صالحًا.'
  ],
  'auth.recoveryInfo': [
    'If your phone and email are both lost, an account cannot be recovered in V1.',
    'إذا فقدت هاتفك وبريدك الإلكتروني معًا، فلا يمكن استرداد الحساب في الإصدار الأول.'
  ],
  'auth.sending': ['Sending…', 'جارٍ الإرسال…'],
  'auth.sendResetLink': ['Send Reset Link', 'إرسال رابط إعادة التعيين'],
  'auth.checkEmailHeading': ['CHECK YOUR\nEMAIL', 'تحقق من\nبريدك الإلكتروني'],
  'auth.resetSentPrefix': [
    'We sent a password reset link to\n',
    'أرسلنا رابط إعادة تعيين كلمة المرور إلى\n'
  ],
  'auth.resetSentSuffix': [
    '.\n\nOpen it, set a new password, then log back in.',
    '.\n\nافتحه، وعيّن كلمة مرور جديدة، ثم سجّل الدخول من جديد.'
  ],
  'auth.backToLogin': ['Back to Log In', 'العودة إلى تسجيل الدخول'],
  'auth.sendAgain': ["Didn't get it? Send again", 'لم يصلك؟ أعد الإرسال'],

  // ---- Login ------------------------------------------------------------
  'auth.accountDeactivatedTitle': ['ACCOUNT DEACTIVATED', 'الحساب معطّل'],
  'auth.deactivatedBody1': [
    'Your account is deactivated until ',
    'حسابك معطّل حتى '
  ],
  'auth.deactivatedBody2': [
    '. Reactivate now to log in?',
    '. هل تريد إعادة تفعيله الآن لتسجيل الدخول؟'
  ],
  'auth.notYet': ['Not yet', 'ليس الآن'],
  'auth.reactivate': ['Reactivate', 'إعادة التفعيل'],
  'auth.enterEmailPassword': [
    'Enter your email and password.',
    'أدخل بريدك الإلكتروني وكلمة المرور.'
  ],
  'auth.googleFailed': [
    'Google sign-in failed. Try again.',
    'فشل تسجيل الدخول عبر Google. حاول مرة أخرى.'
  ],
  'auth.welcomeBackHeading': ['WELCOME\nBACK', 'مرحبًا بك\nمن جديد'],
  'auth.loginSub': [
    'Log in to pick up where you left off.',
    'سجّل الدخول لتكمل من حيث توقفت.'
  ],
  'auth.continueWithGoogle': ['Continue with Google', 'المتابعة عبر Google'],
  'auth.or': ['OR', 'أو'],
  'auth.passwordLabel': ['Password', 'كلمة المرور'],
  'auth.passwordHint': ['Your password', 'كلمة المرور الخاصة بك'],
  'auth.forgotPassword': ['Forgot password?', 'نسيت كلمة المرور؟'],
  'auth.loggingIn': ['Logging in…', 'جارٍ تسجيل الدخول…'],
  'auth.newHere': ['New here?  ', 'جديد هنا؟  '],
  'auth.createAnAccount': ['Create an account', 'أنشئ حسابًا'],

  // ---- Football / sport profile ----------------------------------------
  'auth.pickOptionToContinue': [
    'Pick an option to continue.',
    'اختر خيارًا للمتابعة.'
  ],
  'auth.saveProfileFailed': [
    'Could not save your profile. Try again.',
    'تعذّر حفظ ملفك الشخصي. حاول مرة أخرى.'
  ],
  'auth.sportProfileTitle': ['Sport Profile', 'الملف الرياضي'],
  'auth.finishSetup': ['Finish Setup', 'إنهاء الإعداد'],
  'auth.positionTitle': ['Preferred position', 'المركز المفضّل'],
  'auth.positionSub': ['Where do you play best?', 'أين تلعب بأفضل شكل؟'],
  'auth.posGoalkeeper': ['Goalkeeper', 'حارس مرمى'],
  'auth.posDefender': ['Defender', 'مدافع'],
  'auth.posMidfielder': ['Midfielder', 'لاعب وسط'],
  'auth.posForward': ['Forward', 'مهاجم'],

  // ---- Signup: method ---------------------------------------------------
  'auth.pleaseWait': ['Please wait…', 'يرجى الانتظار…'],

  // ---- Signup: password -------------------------------------------------
  'auth.passwordHint8': ['At least 8 characters', '8 أحرف على الأقل'],

  // ---- Signup: name -----------------------------------------------------
  'auth.nameRequired': [
    'Enter your first and last name.',
    'أدخل اسمك الأول واسم عائلتك.'
  ],

  // ---- Signup: referral -------------------------------------------------
  'auth.referralLabel': ['Referral code', 'رمز الإحالة'],

  // ---- Signup: done + bottom bar ---------------------------------------
  'auth.creatingAccount': ['Creating account…', 'جارٍ إنشاء الحساب…'],
  'auth.signupFailed': [
    'Could not complete sign up. Try again.',
    'تعذّر إكمال التسجيل. حاول مرة أخرى.'
  ],
  'auth.accountExistsTitle': [
    'We already have your data',
    'لدينا بياناتك بالفعل'
  ],
  'auth.accountExistsAutoBody': [
    'An account already exists for this email — it was created when someone added you to a match or team. Claim it and we will email you a code, or use a different email.',
    'يوجد حساب بالفعل بهذا البريد الإلكتروني — تم إنشاؤه عندما أضافك أحدهم إلى مباراة أو فريق. استعده وسنرسل لك رمزًا عبر البريد، أو استخدم بريدًا مختلفًا.'
  ],
  'auth.accountExistsRealBody': [
    'An account already exists for this email. Log in instead, or use a different email.',
    'يوجد حساب بالفعل بهذا البريد الإلكتروني. سجّل الدخول بدلاً من ذلك، أو استخدم بريدًا مختلفًا.'
  ],
  'auth.logInAction': ['Log in', 'تسجيل الدخول'],
  'auth.useAnotherEmail': ['Use another email', 'استخدم بريدًا آخر'],

  // ---- Claim an auto-created account (email OTP) ------------------------
  'auth.claimAction': ['Claim my account', 'استعادة حسابي'],
  'auth.claimTitle': ['Claim account', 'استعادة الحساب'],
  'auth.claimHeading': ['CLAIM YOUR ACCOUNT', 'استعد حسابك'],
  'auth.claimSub': [
    'Someone set this account up for you. We will email you a 6-digit code to confirm it is yours, then you can choose a password.',
    'قام أحدهم بإنشاء هذا الحساب من أجلك. سنرسل إلى بريدك رمزًا من 6 أرقام للتأكد من أنه حسابك، ثم يمكنك اختيار كلمة مرور.'
  ],
  'auth.claimPrompt': [
    'Account made for you? ',
    'هل أنشأ أحدهم حسابًا لك؟ '
  ],
  'auth.claimDone': ['Your password is set.', 'تم تعيين كلمة المرور.'],

  'auth.otpHeading': ['ENTER THE CODE', 'أدخل الرمز'],
  'auth.otpSentTo': ['We sent a 6-digit code to', 'أرسلنا رمزًا من 6 أرقام إلى'],
  'auth.otpCodeLabel': ['Verification code', 'رمز التحقق'],
  'auth.otpVerify': ['Verify', 'تحقق'],
  'auth.otpVerifying': ['Verifying…', 'جارٍ التحقق…'],
  'auth.otpResend': ['Send a new code', 'إرسال رمز جديد'],
  'auth.otpResendIn': ['You can ask for a new code in', 'يمكنك طلب رمز جديد خلال'],
  'auth.otpSixDigits': [
    'Enter the 6-digit code.',
    'أدخل الرمز المكوّن من 6 أرقام.'
  ],

  'auth.setPwHeading': ['SET A PASSWORD', 'عيّن كلمة مرور'],
  'auth.setPwSub': [
    'This is the password you will use to log in from now on.',
    'هذه هي كلمة المرور التي ستستخدمها لتسجيل الدخول من الآن فصاعدًا.'
  ],
  'auth.setPwAction': ['Save and continue', 'حفظ ومتابعة'],
  'auth.setPwSaving': ['Saving…', 'جارٍ الحفظ…'],
  'auth.setPwLater': ['Skip for now', 'تخطَّ الآن'],
  'auth.newPasswordLabel': ['New password', 'كلمة المرور الجديدة'],
  'auth.confirmPasswordLabel': ['Confirm password', 'تأكيد كلمة المرور'],
  'auth.pwMismatch': [
    'Passwords do not match.',
    'كلمتا المرور غير متطابقتين.'
  ],
  'auth.pwLooksGood': ['Looks good.', 'تبدو جيدة.'],

  'auth.otpErrNetwork': [
    'Could not reach the server. Check your connection.',
    'تعذّر الوصول إلى الخادم. تحقق من اتصالك.'
  ],
  'auth.otpErrGeneric': [
    'Something went wrong. Try again.',
    'حدث خطأ ما. حاول مرة أخرى.'
  ],
  'auth.otpErrRateLimited': [
    'Too many requests. Try again in',
    'طلبات كثيرة جدًا. حاول مرة أخرى خلال'
  ],
  'auth.otpErrNotClaimable': [
    'No account created by a host was found for that email.',
    'لم يتم العثور على حساب أنشأه مضيف لهذا البريد الإلكتروني.'
  ],
  'auth.otpErrInvalidCode': [
    'That code is not valid.',
    'هذا الرمز غير صالح.'
  ],
  'auth.otpErrExpired': [
    'That code has expired. Request a new one.',
    'انتهت صلاحية الرمز. اطلب رمزًا جديدًا.'
  ],
  'auth.otpErrTooManyAttempts': [
    'Too many incorrect attempts. Request a new code.',
    'محاولات خاطئة كثيرة. اطلب رمزًا جديدًا.'
  ],
  'auth.otpErrInvalidRequest': [
    'Check the email address and try again.',
    'تحقق من عنوان البريد الإلكتروني وحاول مرة أخرى.'
  ],
  'auth.otpSecondsShort': ['s', 'ث'],
  'auth.otpMinutesShort': ['m', 'د'],

  // ---- Account deletion (Settings -> Delete account) --------------------
  // Worded to be unmistakable. A user who skims must still understand that
  // this is permanent, and a user who receives the email unexpectedly must
  // understand that someone is trying to destroy their account.
  'auth.deleteTitle': ['Delete Account', 'حذف الحساب'],
  'auth.deleteRow': ['Delete my account', 'حذف حسابي'],
  'auth.deleteWarnTitle': ['This cannot be undone', 'لا يمكن التراجع عن هذا'],
  'auth.deleteWarnBody': [
    'Deleting your account is permanent. We cannot restore it, and you cannot sign in again with this email unless you create a new account from scratch.',
    'حذف حسابك نهائي. لا يمكننا استعادته، ولن تتمكن من تسجيل الدخول بهذا البريد مجددًا إلا بإنشاء حساب جديد من البداية.'
  ],
  'auth.deleteLosesTitle': ['YOU WILL LOSE', 'ستفقد'],
  'auth.deleteLoses1': [
    'Your profile, photo and career statistics',
    'ملفك الشخصي وصورتك وإحصائياتك'
  ],
  'auth.deleteLoses2': [
    'Your teams, friends and invitations',
    'فرقك وأصدقاؤك ودعواتك'
  ],
  'auth.deleteLoses3': [
    'Your points and referral rewards',
    'نقاطك ومكافآت الإحالة'
  ],
  'auth.deleteKeepsBody': [
    'Matches you played in stay on record for the other players, but they will no longer be linked to you.',
    'تبقى المباريات التي لعبتها مسجّلة لدى اللاعبين الآخرين، لكنها لن تكون مرتبطة بك بعد الآن.'
  ],
  'auth.deleteCodeToPre': [
    'To confirm, we will email a one-time code to',
    'للتأكيد، سنرسل رمزًا لمرة واحدة إلى'
  ],
  'auth.deleteWait': ['Read this first —', 'اقرأ هذا أولًا —'],
  'auth.deleteContinue': ['Continue', 'متابعة'],
  'auth.deleteCodeSentTitle': ['Enter the code', 'أدخل الرمز'],
  'auth.deleteCodeSentBody': ['We sent a 6-digit code to', 'أرسلنا رمزًا من 6 أرقام إلى'],
  'auth.deleteConfirmFinal': ['Delete my account permanently', 'احذف حسابي نهائيًا'],
  'auth.deleteDeleting': ['Deleting…', 'جارٍ الحذف…'],
  'auth.deleteDone': ['Your account has been deleted.', 'تم حذف حسابك.'],
  'auth.otpErrUnauthorised': [
    'Please sign in again and retry.',
    'يرجى تسجيل الدخول مجددًا والمحاولة من جديد.'
  ],
};
