import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firestore_service.dart';

class FcmService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestoreService _firestore = FirestoreService();

  Future<void> init(String uid) async {
    // FCM push notifications only work on Android/iOS, not web
    if (kIsWeb) return;

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await _messaging.getToken();
        if (token != null) {
          await _firestore.saveFcmToken(uid, token);
        }
        _messaging.onTokenRefresh
            .listen((t) => _firestore.saveFcmToken(uid, t));
      }

      FirebaseMessaging.onMessage.listen((message) {
        // Handle foreground message
      });
    } catch (e) {
      // Silently ignore FCM errors — app works without notifications
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}
