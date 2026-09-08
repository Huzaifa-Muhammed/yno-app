import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// How many points each reward is worth (`config/rewards`).
///
/// These were three `const` ints — `kReferralPoints` (10),
/// `kCommunityPlayerPoints` (20) and `kManOfMatchPoints` (30) — which meant
/// changing what a referral is worth required a new build in every user's
/// hands. They are now one Firestore document the super-admin panel edits, and
/// the change reaches every client without a release.
///
/// ⚠️ The defaults below are load-bearing. They are what every client uses
/// before the document has loaded, and what the app falls back to if the read
/// fails or the document has never been created. They must stay equal to the
/// original constants, or a network blip would silently change what a match is
/// worth.
class RewardsConfig {
  const RewardsConfig({
    this.referralPoints = 10,
    this.communityPlayerPoints = 20,
    this.manOfMatchPoints = 30,
  });

  /// Awarded to BOTH sides of a referral — the referrer and the new account.
  final int referralPoints;

  /// Awarded to the community-vote winner.
  final int communityPlayerPoints;

  /// Awarded to the algorithm Man of the Match.
  final int manOfMatchPoints;

  Map<String, dynamic> toMap() => {
        'referralPoints': referralPoints,
        'communityPlayerPoints': communityPlayerPoints,
        'manOfMatchPoints': manOfMatchPoints,
      };

  factory RewardsConfig.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const RewardsConfig();
    const fallback = RewardsConfig();
    // Each field falls back independently: a document written with only one of
    // the three (an older panel, a hand edit) must not zero the other two.
    int read(String key, int fallbackValue) {
      final v = d[key];
      if (v is int && v >= 0) return v;
      if (v is num && v >= 0) return v.toInt();
      return fallbackValue;
    }

    return RewardsConfig(
      referralPoints: read('referralPoints', fallback.referralPoints),
      communityPlayerPoints:
          read('communityPlayerPoints', fallback.communityPlayerPoints),
      manOfMatchPoints: read('manOfMatchPoints', fallback.manOfMatchPoints),
    );
  }

  RewardsConfig copyWith({
    int? referralPoints,
    int? communityPlayerPoints,
    int? manOfMatchPoints,
  }) =>
      RewardsConfig(
        referralPoints: referralPoints ?? this.referralPoints,
        communityPlayerPoints:
            communityPlayerPoints ?? this.communityPlayerPoints,
        manOfMatchPoints: manOfMatchPoints ?? this.manOfMatchPoints,
      );
}

/// Reads and writes [RewardsConfig].
///
/// [current] is a plain static so the widgets that used to interpolate a
/// `const` can keep doing so synchronously — a `FutureBuilder` around every
/// "+10 pts" label would be a lot of machinery for three integers.
///
/// It is kept fresh two ways: [load] awaits it once during startup, before the
/// first frame, and [listen] then subscribes so an admin's edit reaches running
/// apps without a restart. The award paths (`_applyReferral`,
/// `finalizeMatch`, `resolveCommunityAward`) are all async and read [current]
/// at the moment they award, so they use the newest value the client has seen.
class RewardsRepository {
  RewardsRepository._();
  static final RewardsRepository instance = RewardsRepository._();

  static const _docPath = 'rewards';

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('config').doc(_docPath);

  /// The values every caller should use. Never null — see the class note on
  /// why the defaults matter.
  static RewardsConfig current = const RewardsConfig();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  /// Read once at startup. Swallows its own failures: a missing document or an
  /// offline start must leave the app running on the defaults, not blocked.
  Future<void> load() async {
    try {
      final snap = await _doc.get();
      current = RewardsConfig.fromMap(snap.data());
    } catch (_) {/* defaults */}
  }

  /// Keep [current] up to date for the life of the process.
  void listen() {
    _sub?.cancel();
    try {
      _sub = _doc.snapshots().listen(
            (snap) => current = RewardsConfig.fromMap(snap.data()),
            onError: (_) {/* keep the last good value */},
          );
    } catch (_) {/* stay on whatever load() found */}
  }

  /// Live values, for the admin panel's editor.
  Stream<RewardsConfig> watch() =>
      _doc.snapshots().map((s) => RewardsConfig.fromMap(s.data()));

  /// Super-admin only — enforced by `firestore.rules`, not here.
  ///
  /// `set` with merge rather than `update`, because `config/rewards` does not
  /// exist until the first save and `update` fails on a missing document.
  Future<void> save(RewardsConfig cfg) =>
      _doc.set(cfg.toMap(), SetOptions(merge: true));

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}
