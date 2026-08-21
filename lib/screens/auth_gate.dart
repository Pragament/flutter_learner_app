import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/staff_role.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import '../services/firestore_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'staff_dashboard_screen.dart';

/// Listens to auth state and shows either the login screen, the Parent
/// dashboard, or — for a signed-in Teacher/Admin — the Staff dashboard.
class AuthGate extends StatelessWidget {
  AuthGate({super.key});

  final _auth = AuthService();
  final _fcm = FcmService();
  final _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppMode?>(
      valueListenable: AuthService.preferredMode,
      builder: (context, mode, _) {
        return StreamBuilder<User?>(
          stream: _auth.authState,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final user = snapshot.data;
            if (user == null || mode == null) return const LoginScreen();

            // Register this device for push once we know who is signed in.
            _fcm.init(user.uid);

            if (mode == AppMode.staff) {
              return FutureBuilder<List<StaffRole>>(
                future: _firestore.findStaffRolesForEmail(user.email ?? ''),
                builder: (context, roleSnap) {
                  if (roleSnap.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final staffRoles = roleSnap.data ?? [];
                  if (staffRoles.isNotEmpty) {
                    return StaffDashboardScreen(staffRoles: staffRoles);
                  }
                  // Should theoretically not happen due to login screen checks,
                  // but handles stale auth sessions.
                  return const LoginScreen();
                },
              );
            }

            // Default to Parent mode
            return DashboardScreen();
          },
        );
      },
    );
  }
}
