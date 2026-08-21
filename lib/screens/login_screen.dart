import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final FirestoreService _firestore = FirestoreService();
  bool _busy = false;
  String? _error;

  Future<void> _signIn(bool asStaff) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await _auth.signInWithGoogle();
      if (user == null) {
        setState(() => _busy = false);
        return;
      }
      debugPrint('DEBUG: Signed in with Google. Email: [${user.email}]');

      if (asStaff) {
        final roles = await _firestore.findStaffRolesForEmail(user.email ?? '');
        if (roles.isEmpty) {
          // Not a teacher/admin - sign out and show error
          await _auth.signOut();
          setState(() {
            _error =
                'You are not registered as a teacher/admin for any school.';
          });
          return;
        }
        AuthService.preferredMode.value = AppMode.staff;
      } else {
        AuthService.preferredMode.value = AppMode.parent;
      }
      // AuthGate's stream rebuilds and routes to the correct dashboard automatically.
    } catch (e) {
      String msg = 'Sign-in failed. Please try again.';
      if (e.toString().contains('network-request-failed')) {
        msg = 'No internet connection. Please check your network.';
      } else if (e.toString().contains('failed-precondition')) {
        msg = 'Database error. Please contact support.';
      }
      setState(() => _error = msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school, size: 80, color: Colors.indigo),
              const SizedBox(height: 24),
              Text('School Reports',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade900,
                      )),
              const SizedBox(height: 8),
              const Text('Access test reports and academic progress',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 48),
              if (_busy)
                const CircularProgressIndicator()
              else ...[
                _LoginButton(
                  label: 'Parent Login',
                  subtitle: 'View your child\'s reports',
                  icon: Icons.family_restroom,
                  onPressed: () => _signIn(false),
                  color: Colors.indigo,
                ),
                const SizedBox(height: 16),
                _LoginButton(
                  label: 'Teacher/Admin Login',
                  subtitle: 'Manage school records',
                  icon: Icons.admin_panel_settings,
                  onPressed: () => _signIn(true),
                  color: Colors.teal,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;

  const _LoginButton({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color titleColor = color is MaterialColor ? (color as MaterialColor).shade900 : color;
    final Color subtitleColor = color is MaterialColor ? (color as MaterialColor).shade700 : color;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          side: BorderSide(color: color.withOpacity(0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: color.withOpacity(0.02),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      )),
                  Text(subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                      )),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
