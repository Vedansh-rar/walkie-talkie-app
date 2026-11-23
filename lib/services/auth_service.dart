import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_config.dart';

/// Thrown when someone taps "Continue with Google" before the app has a
/// real Firebase/Google Cloud project wired up (see [auth_config.dart]).
/// Kept distinct from a plain sign-in failure so the login screen can show
/// a friendly "not configured yet" message instead of a generic error.
class GoogleSignInNotConfigured implements Exception {}

/// Wraps Firebase Auth + Google Sign-In (package v7's `initialize()` /
/// `authenticate()` flow — the API was rewritten from v6's `signIn()`, so
/// this intentionally sticks close to the documented snippet rather than
/// any older pattern).
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;
  bool _googleInitialized = false;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
    _googleInitialized = true;
  }

  /// Runs the full Google → Firebase sign-in flow. Returns the signed-in
  /// [User], or `null` if the person closed the Google chooser without
  /// picking an account.
  Future<User?> signInWithGoogle() async {
    if (!isGoogleSignInConfigured) {
      throw GoogleSignInNotConfigured();
    }

    await _ensureGoogleInitialized();

    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('Google Sign-In is not supported on this platform.');
    }

    GoogleSignInAccount? googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } catch (error) {
      // Covers the person backing out of the account chooser, which the
      // package surfaces as an exception rather than a null return.
      debugPrint('Google sign-in cancelled or failed: $error');
      return null;
    }

    final idToken = googleUser.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }
}
