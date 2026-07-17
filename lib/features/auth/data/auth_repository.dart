import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/providers/firebase_providers.dart';

/// Abstract interface for authentication operations.
abstract class IAuthRepository {
  User? get currentUser;
  Stream<User?> get authStateChanges;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<UserCredential?> signInWithGoogle();

  Future<UserCredential?> signInWithApple();

  /// Signs in anonymously — every guest gets a stable Firebase UID.
  Future<UserCredential> signInAnonymously();

  /// Attempts to link an anonymous account to email/password credentials.
  /// Falls back to `createUserWithEmailAndPassword` if already linked.
  Future<UserCredential> linkAnonymousWithEmailCredential({
    required String email,
    required String password,
  });

  /// Attempts to link an anonymous account to a Google credential.
  Future<UserCredential?> linkAnonymousWithGoogleCredential();

  /// Attempts to link an anonymous account to an Apple credential.
  Future<UserCredential?> linkAnonymousWithAppleCredential();

  Future<void> signOut();

  Future<void> sendPasswordResetEmail(String email);
}

// ── Implementation ───────────────────────────────────────────
class AuthRepository implements IAuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  // google_sign_in v7: use the singleton — constructor was removed
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  /// Initializes google_sign_in exactly once.
  /// serverClientId is the Web Client ID — required for Firebase to verify the ID token.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize(
      serverClientId: '934105443254-o2sdu3n2avnn6ciqjpoadmiq2rmdidfd.apps.googleusercontent.com',
    );
    _googleSignInInitialized = true;
  }

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Email / Password ─────────────────────────────────────────
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ── Google Sign-In ───────────────────────────────────────────
  @override
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleInitialized();

    try {
      // v7 API: authenticate() replaces the old signIn()
      final GoogleSignInAccount googleUser =
          await _googleSignIn.authenticate();

      // v7 API: authentication is a synchronous getter, not a Future
      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      // v7 API: accessToken is no longer on GoogleSignInAuthentication;
      // Firebase only requires idToken for sign-in.
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      debugPrint('[GoogleSignIn] Exception: code=${e.code}, description=${e.description}');
      // NOTE: A SHA-1 fingerprint mismatch or missing OAuth client also
      // surfaces as GoogleSignInExceptionCode.canceled on Android.
      // If login silently fails here, verify your SHA-1 is registered in
      // Firebase Console for the correct package name.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('[GoogleSignIn] Sign-in dismissed. If unintentional, check SHA-1 fingerprint in Firebase Console.');
        return null;
      }
      rethrow;
    } catch (e, stack) {
      debugPrint('[GoogleSignIn] Unexpected error: $e\n$stack');
      rethrow;
    }
  }

  // ── Apple Sign-In ────────────────────────────────────────────
  @override
  Future<UserCredential?> signInWithApple() async {
    final rawNonce = _generateNonce();
    final shaNonce = _sha256ofString(rawNonce);

    WebAuthenticationOptions? webOptions;
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      webOptions = WebAuthenticationOptions(
        clientId: 'com.manbar.manbarAlmasjid.service',
        redirectUri: Uri.parse(
            'https://dinapp-3eadd.firebaseapp.com/__/auth/handler'),
      );
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: shaNonce,
      webAuthenticationOptions: webOptions,
    );

    final credential = OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    return _auth.signInWithCredential(credential);
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz.-_';
    final random = Random.secure();
    return List.generate(
        length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ── Anonymous Sign-In ────────────────────────────────────────
  @override
  Future<UserCredential> signInAnonymously() async {
    return _auth.signInAnonymously();
  }

  // ── Credential Linking (anonymous → real account) ────────────
  @override
  Future<UserCredential> linkAnonymousWithEmailCredential({
    required String email,
    required String password,
  }) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        final credential = EmailAuthProvider.credential(
          email: email.trim(),
          password: password,
        );
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        // If already linked or credential in use — fall back to normal sign-up
        if (e.code == 'provider-already-linked' ||
            e.code == 'credential-already-in-use' ||
            e.code == 'email-already-in-use') {
          return _auth.createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
        }
        rethrow;
      }
    }
    // Not anonymous — just create normally
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<UserCredential?> linkAnonymousWithGoogleCredential() async {
    await _ensureGoogleInitialized();
    try {
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        try {
          return await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'provider-already-linked') {
            return _auth.signInWithCredential(credential);
          }
          rethrow;
        }
      }
      return _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<UserCredential?> linkAnonymousWithAppleCredential() async {
    final rawNonce = _generateNonce();
    final shaNonce = _sha256ofString(rawNonce);

    WebAuthenticationOptions? webOptions;
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
      webOptions = WebAuthenticationOptions(
        clientId: 'com.manbar.manbarAlmasjid.service',
        redirectUri: Uri.parse(
            'https://dinapp-3eadd.firebaseapp.com/__/auth/handler'),
      );
    }

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: shaNonce,
      webAuthenticationOptions: webOptions,
    );

    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithCredential(credential);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use' ||
            e.code == 'provider-already-linked') {
          return _auth.signInWithCredential(credential);
        }
        rethrow;
      }
    }
    return _auth.signInWithCredential(credential);
  }

  // ── Sign Out ──────────────────────────────────────────────────
  @override
  Future<void> signOut() async {
    await _ensureGoogleInitialized();
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  // ── Password Reset ────────────────────────────────────────────
  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }
}

// ── Riverpod Provider ─────────────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(firebaseAuthProvider));
});
