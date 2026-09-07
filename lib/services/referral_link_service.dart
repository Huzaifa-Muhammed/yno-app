import 'dart:async';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolves the referral code a new user arrived with, from either half of the
/// link journey.
///
/// A referral link (`https://nellab.org/r/AB12CD`) is shared into WhatsApp and
/// tapped by someone who may or may not have YNO installed. Those are two
/// completely different mechanisms:
///
/// * **Installed** — Android matches the URL against the App Link intent filter
///   in `AndroidManifest.xml` and hands it straight to us. `app_links` delivers
///   it, either as the link that cold-started the app ([AppLinks.getInitialLink])
///   or on [AppLinks.uriLinkStream] if the app was already running.
///
/// * **Not installed** — the website sends them to the Play Store with
///   `&referrer=<code>` appended. The Store carries that string through the
///   install, and the Install Referrer API reads it back on first launch. This
///   is the only mechanism that survives an install; without it the code is
///   lost the moment the browser opens the store listing.
///
/// Firebase Dynamic Links used to paper over both and was shut down in August
/// 2025, which is why this is assembled by hand.
///
/// Whatever is found is **held**, not applied — see [pendingCode]. Nothing here
/// signs anybody in or writes to Firestore.
class ReferralLinkService {
  ReferralLinkService._();
  static final ReferralLinkService instance = ReferralLinkService._();

  static const _prefsPendingKey = 'pending_referral_code';
  static const _prefsReferrerCheckedKey = 'install_referrer_checked';

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  /// The code a new account should be credited to, once one is being created.
  ///
  /// Deliberately *not* consumed on read: the signup screen prefills from it,
  /// the user may back out to the welcome screen, and the code has to survive
  /// that. [clearPending] is called only once an account actually exists.
  String? _pending;
  String? get pendingCode => _pending;

  /// Fires when a code arrives while the app is already open, so a screen that
  /// is currently showing (signup, most importantly) can pick it up rather than
  /// waiting for the next cold start.
  final _found = StreamController<String>.broadcast();
  Stream<String> get onCode => _found.stream;

  /// Call once, from `main()`, before the first frame.
  ///
  /// Never throws: a referral is a bonus, and a store or plugin failure here
  /// must not stop the app from launching. Every branch is individually
  /// guarded for that reason.
  Future<void> init() async {
    await _restorePending();
    await _checkInitialLink();
    _listenForLinks();
    // Ordered last: the Install Referrer is only consulted when nothing better
    // was found, since a link the user just tapped beats a referrer string left
    // over from whenever they installed.
    if (_pending == null) await _checkInstallReferrer();
  }

  /// A code found on a previous launch that has not been spent yet — the app
  /// may well have been killed between the install and the user getting round
  /// to signing up.
  Future<void> _restorePending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsPendingKey);
      if (saved != null && saved.isNotEmpty) _pending = saved;
    } catch (_) {/* no stored code; carry on */}
  }

  Future<void> _checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) await _handleUri(uri);
    } catch (_) {/* not launched from a link */}
  }

  void _listenForLinks() {
    try {
      _sub = _appLinks.uriLinkStream.listen(
        (uri) => _handleUri(uri),
        onError: (_) {/* a malformed link is not worth surfacing */},
      );
    } catch (_) {/* platform without link support */}
  }

  /// Read the Play Store's `referrer` string, exactly once per install.
  ///
  /// The check is flagged in preferences rather than repeated because the value
  /// never changes for the life of an install, and the API call binds a service
  /// to the Play Store app — cheap, but pointless on every launch forever. The
  /// flag is written even when nothing is found, so an organic installer pays
  /// this cost once and never again.
  Future<void> _checkInstallReferrer() async {
    if (!defaultTargetPlatform.isAndroid || kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefsReferrerCheckedKey) == true) return;
      await prefs.setBool(_prefsReferrerCheckedKey, true);

      final details = await AndroidPlayInstallReferrer.installReferrer;
      final raw = details.installReferrer;
      if (raw == null || raw.isEmpty) return;
      final code = _codeFromReferrer(raw);
      if (code != null) await _store(code);
    } catch (_) {
      // Thrown on devices with no Play Store (an emulator without Play
      // services, a sideloaded APK, most of China). Organic install; move on.
    }
  }

  /// Pull the referral code out of a tapped `https://nellab.org/r/<code>`.
  ///
  /// Tolerates a query form (`/r?code=AB12CD`) as well, because that is what a
  /// hand-edited or forwarded link tends to degrade into, and rejecting it
  /// would lose a referral for no reason.
  Future<void> _handleUri(Uri uri) async {
    final segments = uri.pathSegments;
    String? code;
    final rIndex = segments.indexOf('r');
    if (rIndex != -1 && rIndex + 1 < segments.length) {
      code = segments[rIndex + 1];
    }
    code ??= uri.queryParameters['code'] ?? uri.queryParameters['ref'];
    final clean = _normalise(code);
    if (clean != null) await _store(clean);
  }

  /// Referral codes travel as `utm_source=...&referrer=AB12CD` or bare.
  ///
  /// The Play Store hands back whatever the linking page put in `referrer`,
  /// URL-encoded, and campaigns from other sources land here too — so this
  /// parses the string as a query rather than trusting it to be just a code.
  String? _codeFromReferrer(String raw) {
    final decoded = Uri.decodeComponent(raw);
    final params = Uri.splitQueryString(decoded);
    // `utm_content` is the fallback because that is where the Play Console's
    // own campaign builder puts a free-text value.
    final candidate = params['referrer'] ??
        params['ref'] ??
        params['code'] ??
        params['utm_content'] ??
        (params.isEmpty ? decoded : null);
    return _normalise(candidate);
  }

  /// Referral codes are the same shape as every other code in the app: short,
  /// alphanumeric, upper case. Anything else is somebody else's campaign
  /// string and must not be offered to the user as a code to sign up with.
  String? _normalise(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim().toUpperCase();
    if (trimmed.isEmpty || trimmed.length > 12) return null;
    if (!RegExp(r'^[A-Z0-9]+$').hasMatch(trimmed)) return null;
    return trimmed;
  }

  Future<void> _store(String code) async {
    _pending = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsPendingKey, code);
    } catch (_) {/* in-memory only for this run */}
    if (!_found.isClosed) _found.add(code);
  }

  /// Spend the code. Called once an account has been created with it — or when
  /// the user is told it can't be applied — so it is not re-offered forever.
  Future<void> clearPending() async {
    _pending = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsPendingKey);
    } catch (_) {/* nothing stored */}
  }

  void dispose() {
    _sub?.cancel();
    _found.close();
  }
}

extension on TargetPlatform {
  bool get isAndroid => this == TargetPlatform.android;
}
