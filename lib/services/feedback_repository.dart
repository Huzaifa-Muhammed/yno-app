import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'auth_repository.dart';
import 'models.dart';
import 'user_repository.dart';

/// Bug reports and suggestions sent from the side drawer (`feedback/{id}`).
///
/// One collection for both, distinguished by [FeedbackReport.type] — the admin
/// panel wants them in one arrival-ordered list, and the split is a filter.
///
/// ⚠️ Read access is closed. `firestore.rules` lets the super-admin read
/// everything here and lets an author read only their own; nobody else can read
/// any of it. Reports carry an email address and free text, so this must not
/// drift towards the world-readable treatment `users` gets.
class FeedbackRepository {
  FeedbackRepository._();
  static final FeedbackRepository instance = FeedbackRepository._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _feedback =>
      _db.collection('feedback');

  /// Longest message accepted. Generous for a bug report, small enough that a
  /// pasted logfile or a runaway paste can't push the document towards
  /// Firestore's 1 MB ceiling. The screen enforces the same number so the user
  /// is stopped by a counter rather than by a write failing.
  static const maxMessageLength = 2000;

  /// Which platform this build is running on, for the report's header.
  ///
  /// `defaultTargetPlatform` rather than `dart:io`'s `Platform` so this stays
  /// compilable on web — the admin panel is a web build of this same app.
  String get _platform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      final p => p.name,
    };
  }

  /// File a report. Returns the new document's id.
  ///
  /// Identity and build are captured here rather than asked for on the form:
  /// a bug report that doesn't say who sent it or what version it came from is
  /// usually unactionable, and nobody types their own app version correctly.
  ///
  /// The profile lookup is best-effort — a failed read costs the name and email
  /// on the report, which is far better than losing the report itself.
  Future<String> submit({
    required FeedbackType type,
    required String message,
  }) async {
    final uid = AuthRepository.instance.uid;
    if (uid == null) throw StateError('not-signed-in');
    final text = message.trim();
    if (text.isEmpty) throw StateError('empty-message');

    AppUser? me;
    try {
      me = await UserRepository.instance.getUser(uid);
    } catch (_) {/* send it anyway, unattributed */}

    final ref = await _feedback.add({
      'type': type.id,
      // Truncated as well as validated in the UI: the cap is a storage
      // guarantee, so it cannot depend on the screen having enforced it.
      'message': text.length > maxMessageLength
          ? text.substring(0, maxMessageLength)
          : text,
      'status': FeedbackStatus.open.id,
      'uid': uid,
      'userName': me?.name ?? '',
      'userEmail': me?.email ?? '',
      'appVersion': AppVersion.current,
      'platform': _platform,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Every report, newest first — the admin panel's list.
  ///
  /// Unfiltered on purpose: the panel filters by type and status in memory.
  /// A `where` on either would need a composite index for the `orderBy`, and
  /// this collection is small enough that the query would cost more to maintain
  /// than it saves.
  Stream<List<FeedbackReport>> watchAll() => _feedback
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FeedbackReport.fromDoc).toList());

  /// A user's own reports, newest first.
  ///
  /// ⚠️ Needs the composite index on (`uid`, `createdAt desc`) — Firestore will
  /// print a link to create it the first time this runs. Rules allow it: an
  /// author may read their own reports.
  Stream<List<FeedbackReport>> watchMine(String uid) => _feedback
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map(FeedbackReport.fromDoc).toList());

  /// Admin: mark a report handled, or put it back in the queue.
  Future<void> setStatus(String id, FeedbackStatus status) =>
      _feedback.doc(id).update({'status': status.id});

  /// Admin: remove a report for good. Spam, or a duplicate.
  Future<void> delete(String id) => _feedback.doc(id).delete();
}
