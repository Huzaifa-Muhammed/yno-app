import 'package:package_info_plus/package_info_plus.dart';

/// The running build's version, read once from the platform package info at
/// startup so screens can show it synchronously.
///
/// Settings and the About page both used to hard-code `1.0.0`, which would have
/// quietly gone stale at the first version bump. They now read [current], which
/// comes from `pubspec.yaml` by way of the built app — there is nothing to keep
/// in sync by hand.
class AppVersion {
  AppVersion._();

  /// e.g. `1.0.0`. Empty until [load] has run, or if the platform channel
  /// fails — callers must hide the version rather than print a guess.
  static String current = '';

  static Future<void> load() async {
    try {
      current = (await PackageInfo.fromPlatform()).version;
    } catch (_) {
      // Leave it empty; a missing version reads better than a wrong one.
    }
  }
}
