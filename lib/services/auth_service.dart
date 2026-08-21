import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants.dart';

enum AppMode { parent, staff }

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final ValueNotifier<AppMode?> preferredMode = ValueNotifier(null);

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web — use Firebase popup directly, no serverClientId needed
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        provider.addScope('profile');
        final result = await _auth.signInWithPopup(provider);
        return result.user;
      } else {
        // Android/iOS — use google_sign_in package
        await GoogleSignIn.instance.initialize(
          serverClientId: kGoogleServerClientId,
        );
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) throw Exception('No ID token received');
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        final result = await _auth.signInWithCredential(credential);
        return result.user;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    if (!kIsWeb) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
    preferredMode.value = null;
  }
}
