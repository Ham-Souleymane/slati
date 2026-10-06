import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';

/// Wraps any action that requires a real (non-anonymous / non-guest) account.
///
/// Usage:
/// ```dart
/// guestGuard(
///   ref: ref,
///   context: context,
///   action: () => doSomething(),
///   featureName: 'التعليق', // optional — shown in the prompt
/// );
/// ```
///
/// If the user is a guest (unauthenticated or anonymous), shows a contextual
/// bottom sheet prompting them to register or sign in.
/// Otherwise, calls [action] immediately.
void guestGuard({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback action,
  /// Optional: short label of the locked feature (e.g. 'التعليق').
  String? featureName,
}) {
  final isGuest = ref.read(isGuestProvider);
  if (isGuest) {
    _showGuestPrompt(context, featureName: featureName);
  } else {
    action();
  }
}

void _showGuestPrompt(BuildContext context, {String? featureName}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _GuestPromptSheet(featureName: featureName),
  );
}

class _GuestPromptSheet extends StatelessWidget {
  const _GuestPromptSheet({this.featureName});

  final String? featureName;

  @override
  Widget build(BuildContext context) {
    final featureLabel = featureName ?? 'التفاعل مع المحتوى';

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Icon badge
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.emeraldDark, AppColors.emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.gold,
              size: 34,
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            'يتطلب هذا حساباً',
            style: GoogleFonts.tajawal(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColors.emeraldDark,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Contextual sub-message
          Text(
            'لاستخدام "$featureLabel" يجب أن يكون لديك حساب.\nسجّل مجاناً في ثوانٍ أو سجّل الدخول إن كنت تملك حساباً.',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              color: AppColors.grey500,
              height: 1.65,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          // Primary CTA — Register
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.push(AppRoutes.register);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'إنشاء حساب مجاني',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Secondary CTA — Login
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.push(AppRoutes.login);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.emeraldDark,
                side: BorderSide(
                  color: AppColors.emerald.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'تسجيل الدخول',
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.emeraldDark,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Dismiss
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ليس الآن',
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: AppColors.grey500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
