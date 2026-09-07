import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:googleapis_auth/auth.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationServices {

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  /// Handles background notifications
  static Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print('Received background notification: ${message.notification?.title}');
  }

  /// Request permissions for notifications (Call this at app startup)
  Future<void> requestPermissions() async {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ User granted permission for notifications');
    } else {
      print('❌ User declined notification permissions');
    }
  }

  /// Initializes Firebase Messaging and local notifications
  Future<void> initializeNotifications(BuildContext context) async {
    // Request permissions
    await requestPermissions();

    // Foreground notification listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('📩 Foreground notification received: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Background & terminated state notifications
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Handle when the app is opened by a notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('🚀 App opened from notification: ${message.notification?.title}');
      _handleNavigation(context, message); // Pass context here
    });

    // Handle if the app was launched from a notification (terminated state)
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('🚀 App opened from notification: ${message.notification?.title}');
        _handleNavigation(context, message);
      }
    });

    // Initialize local notifications
    _initializeLocalNotifications();
  }

  /// handle navigation when click on notification
  void _handleNavigation(BuildContext context, RemoteMessage message) {
    // Check if 'type' is available in data
    String? type = message.data['type'];

    if (type != null) {
      if (type == 'work') {
        // Navigate to work page
        Navigator.pushNamed(context, '/workerNotificationPage');
      } else if (type == 'chat') {
        // Navigate to chat page
        Navigator.pushNamed(context, '/chatPage');
      }
    }
  }

  /// Initializes local notifications (Foreground Notifications)
  void _initializeLocalNotifications() {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    _localNotificationsPlugin.initialize(settings);
  }

  /// Displays local notifications when a push notification is received in the foreground
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotificationsPlugin.show(
      0,
      message.notification?.title ?? 'No Title',
      message.notification?.body ?? 'No Body',
      platformDetails,
    );
  }

  Future<String> getAccessToken() async {
    final serviceAccount = json.decode(await rootBundle.loadString('assets/firebase_admin_key/innomerch-hub-firebase-adminsdk-jwaft-accf66b12b.json'));

    final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccount);

    final client = await clientViaServiceAccount(
      accountCredentials,
      ['https://www.googleapis.com/auth/firebase.messaging'],
    );

    return client.credentials.accessToken.data;
  }

  /// Send a push notification to a specific device using its FCM token
  Future<void> sendNotification(String token, String title, String body, String type) async {
    String accessToken = await getAccessToken();

    const String projectId = "innomerch-hub";

    final Uri url = Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send');

    final Map<String, dynamic> payload = {
      "message": {
        "token": token,
        "notification": {
          "title": title,
          "body": body,
        },
        "data": {
          "type": type,
        }
      }
    };

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $accessToken",
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      print("Notification sent successfully!");
    } else {
      print("Error sending notification: ${response.body}");
    }
  }

}
