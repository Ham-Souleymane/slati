import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/firebase_providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';

/// Wraps any action that requires a real (non-anonymous) account.
///
/// Usage:
/// ```dart
/// GuestGuard(
///   ref: ref,
///   context: context,
///   action: () => doSomething(),
/// );
/// ```
///
/// If the user is anonymous, shows a bottom sheet prompting them to register.
/// Otherwise, calls [action] immediately.
void guestGuard({
  required BuildContext context,
  required WidgetRef ref,
  required VoidCallback action,
}) {
  final isGuest = ref.read(isGuestProvider);
  if (isGuest) {
    _showGuestPrompt(context);
  } else {
    action();
  }
}

void _showGuestPrompt(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _GuestPromptSheet(),
  );
}

class _GuestPromptSheet extends StatelessWidget {
  const _GuestPromptSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 40,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.emeraldDark, AppColors.emerald],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppColors.gold,
              size: 32,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'أنشئ حساباً للمتابعة والتفاعل',
            style: GoogleFonts.tajawal(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.emeraldDark,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'سجّل حسابك مجاناً لتتمكن من الإعجاب بالمنشورات،\nمتابعة المساجد، وتلقّي الإشعارات.',
            style: GoogleFonts.tajawal(
              fontSize: 14,
              color: AppColors.grey500,
              height: 1.6,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.go(AppRoutes.register);
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
                'إنشاء حساب',
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
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
