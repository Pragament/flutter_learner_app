import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';

/// Listens to auth state and shows either the login or the dashboard.
class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final _auth = AuthService();
  final _fcm = FcmService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.authState,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        // Register this device for push once we know who is signed in.
        _fcm.init(user.uid);
        return DashboardScreen();
      },
    );
  }
}
