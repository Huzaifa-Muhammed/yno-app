import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'otp_service.dart' show kOtpServiceUrl;

/// Top-level background handler (must be a top-level or static function).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background/terminated messages are surfaced by the OS automatically.
}

/// Client-side FCM: registers this device's token, shows foreground
/// notifications and routes taps.
///
/// Sending lives on the Worker (`server/src/push.js`) — see [sendToUser]. It
/// used to happen here with a bundled Admin key, which shipped project-admin
/// credentials in every APK.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final _messaging = FirebaseMessaging.instance;
  final _local = FlutterLocalNotificationsPlugin();
  final _db = FirebaseFirestore.instance;

  GlobalKey<NavigatorState>? _navKey;
  bool _initialised = false;

  /// Call once at app startup with the app's navigator key.
  Future<void> init(GlobalKey<NavigatorState> navKey) async {
    _navKey = navKey;
    if (_initialised) return;
    _initialised = true;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) {
        final payload = r.payload;
        if (payload != null) _routeFromPayload(jsonDecode(payload) as Map);
      },
    );

    FirebaseMessaging.onMessage.listen(_showLocal);
    FirebaseMessaging.onMessageOpenedApp
        .listen((m) => _routeFromPayload(m.data));
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _routeFromPayload(initial.data);

    _messaging.onTokenRefresh.listen(saveToken);
  }

  /// Ask permission (used by the onboarding notifications screen).
  Future<bool> requestPermission() async {
    final s = await _messaging.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Register the current device token onto the signed-in user's doc.
  Future<void> registerCurrentDevice() async {
    final token = await _messaging.getToken();
    if (token != null) await saveToken(token);
  }

  Future<void> saveToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
  }

  Future<void> _showLocal(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'default_channel',
        'YNO Notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _local.show(
      n.hashCode,
      n.title ?? 'YNO',
      n.body ?? '',
      details,
      payload: jsonEncode(message.data),
    );
  }

  void _routeFromPayload(Map data) {
    final route = data['route']?.toString();
    if (route == null || route.isEmpty) return;
    final arg = data['arg']?.toString();
    _navKey?.currentState?.pushNamed(route, arguments: arg);
  }

  // ---- Sending (via the Worker — no key on the device) -------------------

  /// Send a push to every device [uid] has registered.
  ///
  /// 🔑 This used to sign an FCM request **on the device**, using an Admin
  /// service-account key bundled in the APK. That key granted full admin on the
  /// Firebase project and anyone could unzip a release build and read it, so
  /// the send moved to the Worker (`server/src/push.js`).
  ///
  /// ⚠️ Only the recipient's **uid** goes over the wire. The Worker resolves
  /// their device tokens itself — do not "optimise" this by sending the tokens
  /// we already have in [AppUser.fcmTokens]. `users` is world-readable, so a
  /// server that accepted caller-supplied tokens could be pointed at anyone's
  /// phone by anyone.
  ///
  /// Best-effort, exactly as before: the bell document in Firestore is the
  /// durable record, and no caller awaits a delivery guarantee.
  Future<void> sendToUser(
    String uid, {
    required String title,
    required String body,
    String? route,
    String? arg,
  }) async {
    // The sender's ID token is what proves to the Worker that a real signed-in
    // user is asking. Without it the endpoint would be an open spam relay.
    final idToken =
        await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) return;

    try {
      await http.post(
        Uri.parse('$kOtpServiceUrl/send-push'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'idToken': idToken,
          'uid': uid,
          'title': title,
          'body': body,
          if (route != null) 'route': route,
          if (arg != null) 'arg': arg,
        }),
      );
    } catch (_) {/* best-effort */}
  }
}
