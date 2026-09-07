import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';
import 'push_service.dart';

/// Per-user notifications (`users/{uid}/notifications/{id}`) + push dispatch.
class NotificationRepository {
  NotificationRepository._();
  static final NotificationRepository instance = NotificationRepository._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watch(String uid) => _col(uid)
      .orderBy('at', descending: true)
      .snapshots()
      .map((s) => s.docs.map(AppNotification.fromDoc).toList());

  /// Unread count for the bell badge.
  Stream<int> watchUnread(String uid) => _col(uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  /// Log a bell notification only (no push). Kept for simple call sites.
  Future<void> add(
    String uid, {
    required String title,
    required String body,
    NotifCategory category = NotifCategory.general,
    String? route,
    String? arg,
  }) =>
      _col(uid).add({
        'title': title,
        'body': body,
        'category': category.name,
        if (route != null) 'route': route,
        if (arg != null) 'arg': arg,
        'read': false,
        'at': FieldValue.serverTimestamp(),
      });

  /// The main entry point: log the bell doc AND, when the category is a
  /// "phone" event the target opted into, push to all their devices.
  /// Best-effort — never throws to the caller.
  Future<void> emit(
    String uid, {
    required String title,
    required String body,
    required NotifCategory category,
    String? route,
    String? arg,
    bool forcePush = false,
  }) async {
    try {
      await add(uid,
          title: title, body: body, category: category, route: route, arg: arg);
    } catch (_) {/* bell is best-effort */}

    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists) return;
      final u = AppUser.fromDoc(snap);
      final wantsPush = forcePush || _shouldPush(u, category);
      // The uid, not the tokens — the Worker resolves those itself. Still
      // gated on `fcmTokens` being non-empty so we skip a pointless round trip
      // for a user with no device registered.
      if (wantsPush && u.fcmTokens.isNotEmpty) {
        await PushService.instance.sendToUser(uid,
            title: title, body: body, route: route, arg: arg);
      }
    } catch (_) {/* push is best-effort */}
  }

  bool _shouldPush(AppUser u, NotifCategory category) {
    if (kPhoneNotifCategories.contains(category)) return u.notifyMatchAlerts;
    // Social categories (friend/follow/points) are opt-in.
    if (category == NotifCategory.friend ||
        category == NotifCategory.follow ||
        category == NotifCategory.points) {
      return u.notifyFriendActivity;
    }
    return false;
  }

  /// Delete a user's notifications whose `arg` matches [arg] (optionally only
  /// those of [category]). Used to clear a resolved challenge from the other
  /// recipients once one of them has answered.
  Future<void> clearByArg(String uid, String arg,
      {NotifCategory? category}) async {
    final snap = await _col(uid).where('arg', isEqualTo: arg).get();
    for (final d in snap.docs) {
      if (category == null || d.data()['category'] == category.name) {
        try {
          await d.reference.delete();
        } catch (_) {/* best-effort */}
      }
    }
  }

  /// Delete a single notification (e.g. after acting on a team invite).
  Future<void> remove(String uid, String id) => _col(uid).doc(id).delete();

  Future<void> markRead(String uid, String id) =>
      _col(uid).doc(id).update({'read': true});

  Future<void> markAllRead(String uid) async {
    final snap = await _col(uid).where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }
}
