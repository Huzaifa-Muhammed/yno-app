import 'package:flutter/widgets.dart';

import 'tr_common.dart';
import 'tr_auth.dart';
import 'tr_home.dart';
import 'tr_teams.dart';
import 'tr_social.dart';
import 'tr_match.dart';
import 'tr_live.dart';
import 'tr_profile.dart';
import 'tr_misc.dart';

/// Lightweight app localisation.
///
/// Each feature cluster contributes a `{key: [en, ar]}` map (tr_*.dart) which
/// is merged here. Screens read strings via the top-level [tr] function. The
/// current locale lives in [L.locale] (a [ValueNotifier]); MaterialApp rebuilds
/// the whole tree when it changes, so every `tr(...)` re-resolves to the new
/// language and layout flips RTL for Arabic automatically.
class L {
  L._();

  /// Locales the app ships.
  static const supported = [Locale('en'), Locale('ar')];

  static final ValueNotifier<Locale> locale = ValueNotifier(const Locale('en'));

  static bool get isAr => locale.value.languageCode == 'ar';

  static final Map<String, List<String>> _t = {};
  static bool _registered = false;

  static void _ensure() {
    if (_registered) return;
    _registered = true;
    _t
      ..addAll(trCommon)
      ..addAll(trAuth)
      ..addAll(trHome)
      ..addAll(trTeams)
      ..addAll(trSocial)
      ..addAll(trMatch)
      ..addAll(trLive)
      ..addAll(trProfile)
      ..addAll(trMisc);
  }

  /// Resolve a key to the active language (falls back to the key itself, then
  /// to English if the Arabic value is missing).
  static String t(String key) {
    _ensure();
    final v = _t[key];
    if (v == null || v.isEmpty) return key;
    if (isAr) return v.length > 1 && v[1].isNotEmpty ? v[1] : v[0];
    return v[0];
  }

  /// Set the active language. Accepts an ISO code (`en`/`ar`) or the stored
  /// human label (`English`/`Arabic`/`العربية`).
  static void setLanguage(String value) {
    final ar = value == 'ar' || value == 'Arabic' || value == 'العربية';
    final next = Locale(ar ? 'ar' : 'en');
    if (locale.value.languageCode != next.languageCode) locale.value = next;
  }

  /// Human label stored on the user profile for the active language.
  static String get label => isAr ? 'Arabic' : 'English';
}

/// Shorthand used across every screen: `tr('common.save')`.
String tr(String key) => L.t(key);
