import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../data/auth_repository.dart';
import '../data/user_repository.dart';
import 'auth_state.dart';

/// Riverpod [Notifier] that manages auth operations and exposes [AuthState].
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Listen to Firebase auth state stream and keep controller in sync
    ref.listen<AsyncValue<User?>>(
      authStateChangesProvider,
      (previous, next) {
        next.when(
          data: (user) {
            if (user != null) {
              state = AuthState(status: AuthStatus.authenticated, user: user);
            } else {
              state = const AuthState(status: AuthStatus.unauthenticated);
            }
          },
          error: (err, stack) {
            state = AuthState(status: AuthStatus.error, errorMessage: err.toString());
          },
          loading: () {
            // Only update to loading if we aren't initial or already authenticated
            if (state.status == AuthStatus.initial) {
              state = state.copyWith(status: AuthStatus.loading);
            }
          },
        );
      },
    );
    return const AuthState();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  // ── Helpers ──────────────────────────────────────────────────
  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'لم يتم العثور على حساب بهذا البريد الإلكتروني.';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة.';
      case 'invalid-credential':
        return 'بيانات الاعتماد غير صحيحة. تحقق من البريد وكلمة المرور.';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مستخدم بالفعل.';
      case 'weak-password':
        return 'كلمة المرور ضعيفة. يجب أن تكون 6 أحرف على الأقل.';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح.';
      case 'too-many-requests':
        return 'محاولات كثيرة. الرجاء الانتظار ثم المحاولة مجددًا.';
      case 'network-request-failed':
        return 'فشل الاتصال بالشبكة. تحقق من الإنترنت.';
      case 'account-exists-with-different-credential':
        return 'الحساب موجود بطريقة تسجيل دخول مختلفة.';
      case 'operation-not-allowed':
        return 'تسجيل الدخول عبر Apple غير متاح على هذا الجهاز. تأكد من تسجيل الدخول إلى iCloud.';
      default:
        return 'حدث خطأ غير متوقع: ${e.message}';
    }
  }

  // ── Sign In ────────────────────────────────────────────────
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final credential = await _repo.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'حدث خطأ غير متوقع.',
      );
    }
  }

  // ── Sign Up ────────────────────────────────────────────────
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final credential = await _repo.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'حدث خطأ غير متوقع.',
      );
    }
  }

  // ── Google Sign-In ─────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final credential = await _repo.signInWithGoogle();
      if (credential == null) {
        // User cancelled
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException in signInWithGoogle: code=${e.code}, message=${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (e, stack) {
      debugPrint('Unexpected error in AuthController.signInWithGoogle: $e\n$stack');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'فشل تسجيل الدخول عبر Google. ($e)',
      );
    }
  }

  // ── Apple Sign-In ──────────────────────────────────────────
  Future<void> signInWithApple() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final credential = await _repo.signInWithApple();
      if (credential == null) {
        // User cancelled the Apple sign-in sheet — not an error.
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthController] Apple FirebaseAuthException: code=${e.code}, message=${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (e, stack) {
      debugPrint('[AuthController] Apple unexpected error: $e\n$stack');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'فشل تسجيل الدخول عبر Apple. ($e)',
      );
    }
  }

  // ── Guest Sign-In ─────────────────────────────────────────
  Future<void> signInAnonymously() async {
    debugPrint('[AuthController] signInAnonymously started');
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      debugPrint('[AuthController] Calling _repo.signInAnonymously...');
      final credential = await _repo.signInAnonymously();
      debugPrint('[AuthController] Repo returned credential for UID: ${credential.user?.uid}');
      final uid = credential.user?.uid;
      if (uid != null) {
        // Create a lightweight guest user doc (optional/resilient)
        try {
          debugPrint('[AuthController] Creating guest user doc in Firestore...');
          await ref.read(userRepositoryProvider).createUserDoc(
                uid: uid,
                fullName: 'زائر',
                isGuest: true,
              );
          debugPrint('[AuthController] Firestore user doc created');
        } catch (e) {
          debugPrint('[AuthController] Warning: Could not create guest user doc in Firestore: $e');
          // Proceed anyway as Firebase Auth was successful
        }
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: credential.user,
      );
      debugPrint('[AuthController] State updated to authenticated');
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthController] FirebaseAuthException: code=${e.code}, message=${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (e) {
      debugPrint('[AuthController] Generic exception: $e');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'فشل الدخول كزائر: $e',
      );
    }
  }

  // ── Upgrade anonymous → email/password ─────────────────────
  Future<void> linkAndUpgradeAnonymous({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final credential = await _repo.linkAnonymousWithEmailCredential(
        email: email,
        password: password,
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'حدث خطأ غير متوقع.',
      );
    }
  }

  // ── Upgrade anonymous → Google ────────────────────────────
  Future<void> linkAndUpgradeAnonymousWithGoogle() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final credential = await _repo.linkAnonymousWithGoogleCredential();
      if (credential == null) {
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (e, stack) {
      debugPrint('linkAndUpgradeAnonymousWithGoogle error: $e\n$stack');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'فشل الربط عبر Google.',
      );
    }
  }

  // ── Upgrade anonymous → Apple ─────────────────────────────────
  Future<void> linkAndUpgradeAnonymousWithApple() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final credential = await _repo.linkAnonymousWithAppleCredential();
      if (credential == null) {
        // User cancelled the Apple sign-in sheet — not an error.
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }
      state = AuthState(
        status: AuthStatus.authenticated,
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthController] Apple link FirebaseAuthException: code=${e.code}, message=${e.message}');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    } catch (e, stack) {
      debugPrint('[AuthController] Apple link unexpected error: $e\n$stack');
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: 'فشل الربط عبر Apple. ($e)',
      );
    }
  }

  // ── Sign Out ──────────────────────────────────────────────
  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading);
    await _repo.signOut();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Password Reset ──────────────────────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      await _repo.sendPasswordResetEmail(email);
      state = const AuthState(status: AuthStatus.unauthenticated);
    } on FirebaseAuthException catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        errorMessage: _mapFirebaseError(e),
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────
final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
