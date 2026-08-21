import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../screens/full_test_report_screen.dart';
import '../screens/report_view_screen.dart';
import 'firestore_service.dart';

/// High-importance channel for test-result notifications. Android 8+ requires a
/// channel; this is what appears under Android Settings → Notifications.
const AndroidNotificationChannel testResultsChannel = AndroidNotificationChannel(
  'test_results',
  'Test Results',
  description: 'Notifications about published test results',
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Global navigator key so notification taps can navigate without a
/// BuildContext. Attached to MaterialApp in main.dart.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _firestore = FirestoreService();

  // Guards so the tap/foreground listeners are only wired once, even though
  // AuthGate may call init() on multiple rebuilds.
  bool _handlersReady = false;
  bool _initialChecked = false;

  Future<void> init(String uid) async {
    // FCM push notifications only work on Android/iOS, not web.
    if (kIsWeb) return;

    try {
      // Local notifications: create the channel + request POST_NOTIFICATIONS so
      // foreground messages can be shown as real Android system notifications.
      await _initLocalNotifications();

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final granted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (granted) {
        // Parent identity for the parents_token record.
        final user = FirebaseAuth.instance.currentUser;
        final phone = user?.phoneNumber ?? '';
        final email = user?.email ?? '';

        final token = await _messaging.getToken();
        if (token != null) {
          // parents_token/{uid} is the collection the Python OMR Test Manager
          // reads. saveParentToken preserves an existing valid token.
          await _firestore.saveParentToken(uid, token,
              phoneNumber: phone, email: email);
          // Keep the legacy users/{uid}.fcmToken write too, so nothing that
          // still reads it breaks during the transition.
          await _firestore.saveFcmToken(uid, token);
        }
        // Firebase rotates tokens (reinstall/restore/rotation) — persist the new
        // one when that actually happens.
        _messaging.onTokenRefresh.listen((t) {
          _firestore.saveParentToken(uid, t, phoneNumber: phone, email: email);
          _firestore.saveFcmToken(uid, t);
        });
      }

      _setupHandlers();
    } catch (e) {
      // Silently ignore FCM errors — the app still works without notifications.
      debugPrint('DEBUG: [FcmService.init] $e');
    }
  }

  void _setupHandlers() {
    if (!_handlersReady) {
      _handlersReady = true;

      // 1) Foreground: OS does not display FCM notifications while the app is
      //    open, so we render a real system notification via local notifications.
      FirebaseMessaging.onMessage.listen(_showForeground);

      // 2) Background (app alive, tapped from tray).
      FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    }

    // 3) Terminated (app was fully closed and launched by tapping the
    //    notification). Checked once.
    if (!_initialChecked) {
      _initialChecked = true;
      _messaging.getInitialMessage().then((message) {
        if (message != null) _handleTap(message);
      });
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = (jsonDecode(payload) as Map)
              .map((k, v) => MapEntry(k.toString(), v));
          _handleTapData(data);
        } catch (_) {}
      },
    );
    final androidImpl = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    // Create the channel (idempotent) and ask for POST_NOTIFICATIONS on 13+.
    await androidImpl?.createNotificationChannel(testResultsChannel);
    await androidImpl?.requestNotificationsPermission();
  }

  /// Foreground: Android does not auto-display FCM notifications while the app is
  /// open, so render a real system notification (heads-up), NOT an in-app banner.
  void _showForeground(RemoteMessage message) {
    final notif = message.notification;
    final title =
        notif?.title ?? message.data['title']?.toString() ?? 'Test Results';
    final body = notif?.body ?? message.data['body']?.toString() ?? '';

    _localNotifications.show(
      message.messageId.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          testResultsChannel.id,
          testResultsChannel.name,
          channelDescription: testResultsChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Opens the result for the notification's test + student. Navigation keys on
  /// testId + roll_no from the payload (never by name), so a parent with several
  /// children always lands on the right child's result.
  Future<void> _handleTap(RemoteMessage message) => _handleTapData(message.data);

  Future<void> _handleTapData(Map<String, dynamic> data) async {
    if (data['type'] != 'result_published') return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final testId = (data['testId'] ?? '').toString();
    final roll = (data['roll_no'] ?? '').toString();

    // Primary: the OMR result written by the Test Manager at
    // results/{testId}_{roll_no}. This is the collection this notification is about.
    if (testId.isNotEmpty && roll.isNotEmpty) {
      try {
        final result = await _firestore.getResult(testId, roll);
        if (result != null) {
          nav.push(MaterialPageRoute(
              builder: (_) => FullTestReportScreen(result: result)));
          return;
        }
      } catch (e) {
        debugPrint('DEBUG: [FcmService._handleTap] result lookup: $e');
      }
    }

    // Fallback: a rich published studentReport, only if one was actually linked.
    final reportId = (data['reportId'] ?? '').toString();
    if (reportId.isNotEmpty) {
      try {
        final report = await _firestore.getReportById(reportId);
        if (report != null) {
          nav.push(MaterialPageRoute(
              builder: (_) => ReportViewScreen(report: report)));
          return;
        }
      } catch (e) {
        debugPrint('DEBUG: [FcmService._handleTap] report lookup: $e');
      }
    }

    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not open the result. Please open it from your dashboard.'),
        ),
      );
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No-op: the OS renders the notification tray entry from the FCM
  // `notification` block while the app is backgrounded/terminated. Tap
  // handling happens in onMessageOpenedApp / getInitialMessage.
}
