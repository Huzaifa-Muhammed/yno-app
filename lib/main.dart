import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin/admin_app.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'services/app_version.dart';
import 'services/push_service.dart';
import 'services/referral_link_service.dart';
import 'services/rewards_config.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  SystemChrome.setSystemUIOverlayStyle(AppTheme.overlay);
  // Read the real build version once so Settings/About never hard-code it.
  await AppVersion.load();
  // Point values (referral / MOTM / community) are set by the admin panel, not
  // compiled in. Awaited before the first frame so a "+10 pts" label never
  // paints a stale number, then kept live so an admin's edit reaches running
  // apps without a restart. Both calls swallow their own failures — the app
  // falls back to the defaults in `RewardsConfig` rather than refusing to boot.
  await RewardsRepository.instance.load();
  RewardsRepository.instance.listen();

  // The web build is the super-admin control panel, not the player app.
  if (kIsWeb) {
    runApp(const AdminApp());
    return;
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Resolve any referral code the user arrived with — a tapped
  // nellab.org/r/<code> link, or the Play Store referrer left behind by an
  // install that started from one. Awaited before `runApp` so the code is
  // already in hand if the very first screen is signup; it swallows its own
  // failures, so a store or plugin problem can't block launch.
  await ReferralLinkService.instance.init();
  runApp(const YnoApp());
  // Wire push once the first frame (and navigator) exists.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    PushService.instance.init(ynoNavigatorKey);
  });
}
