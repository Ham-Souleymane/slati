import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import 'widgets/apple_sign_in_button.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/google_sign_in_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    await ref.read(authControllerProvider.notifier).signInWithEmailAndPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      context.showSnackBar(state.errorMessage ?? context.tr('error_occurred'), isError: true);
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      context.showSnackBar(
          state.errorMessage ?? context.tr('login_google_failed'),
          isError: true);
    }
  }

  Future<void> _signInWithApple() async {
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signInWithApple();
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      context.showSnackBar(
          state.errorMessage ?? context.tr('login_apple_failed'),
          isError: true);
    }
  }

  Future<void> _continueAsGuest() async {
    debugPrint('[LoginScreen] Continue as Guest clicked');
    FocusScope.of(context).unfocus();
    debugPrint('[LoginScreen] Calling signInAnonymously...');
    await ref.read(authControllerProvider.notifier).signInAnonymously();
    debugPrint('[LoginScreen] signInAnonymously returned');
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    debugPrint('[LoginScreen] AuthState status: ${state.status}, error: ${state.errorMessage}');
    if (state.hasError) {
      context.showSnackBar(
          state.errorMessage ?? context.tr('login_guest_failed'),
          isError: true);
    }
  }

  Widget _buildLanguageToggle() {
    final currentLocale = ref.watch(localeProvider);
    final isAr = currentLocale.languageCode == 'ar';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final newLocale = isAr ? const Locale('en') : const Locale('ar', 'AE');
            ref.read(localeProvider.notifier).setLocale(newLocale);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.language_rounded,
                  size: 16,
                  color: AppColors.emerald,
                ),
                const SizedBox(width: 6),
                Text(
                  isAr ? 'English' : 'العربية',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    ref.listen<AuthState>(authControllerProvider, (_, next) {
      if (next.hasError) {
        context.showSnackBar(next.errorMessage ?? context.tr('error_occurred'), isError: true);
      }
    });

    final currentLocale = ref.watch(localeProvider);
    final isAr = currentLocale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      Align(
                        alignment: isAr ? Alignment.centerLeft : Alignment.centerRight,
                        child: _buildLanguageToggle(),
                      ),
                      const SizedBox(height: 16),
                      _buildHeader(),
                      const SizedBox(height: 36),
                      _buildCard(isLoading, authState),
                      const SizedBox(height: 16),
                      _buildGuestButton(isLoading, authState),
                      const SizedBox(height: 16),
                      _buildRegisterLink(),
                      const Spacer(),
                      _buildFooter(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Column(
      children: [
        Image.asset(
          'assets/images/app_icon.png',
          width: 90,
          height: 90,
        ),
        const SizedBox(height: 20),
        Text(
          context.tr('app_title'),
          style: GoogleFonts.tajawal(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.emeraldDark,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('welcome'),
          style: GoogleFonts.tajawal(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.emeraldDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          context.tr('login_subtitle'),
          style: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.grey500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Card ──────────────────────────────────────────────────────
  Widget _buildCard(bool isLoading, AuthState authState) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldDark.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Email
            AuthTextField(
              label: context.tr('email'),
              hint: 'you@example.com',
              controller: _emailController,
              focusNode: _emailFocusNode,
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return context.tr('email_required');
                if (!v.trim().isValidEmail) return context.tr('email_invalid');
                return null;
              },
              onFieldSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_passwordFocusNode),
            ),
            const SizedBox(height: 16),

            // Password
            AuthTextField(
              label: context.tr('password'),
              hint: '••••••••',
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              validator: (v) {
                if (v == null || v.isEmpty) return context.tr('password_required');
                if (v.length < 6) return context.tr('password_too_short');
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),

            // Forgot password
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading ? null : _showForgotPasswordSheet,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.tr('forgot_password_question'),
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Primary CTA
            _PrimaryButton(
              label: context.tr('login_btn'),
              isLoading: isLoading,
              onPressed: _submit,
            ),

            const SizedBox(height: 16),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.divider)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    context.tr('or'),
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      color: AppColors.grey500,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.divider)),
              ],
            ),

            const SizedBox(height: 16),

            // Google
            GoogleSignInButton(
              onPressed: isLoading ? null : _signInWithGoogle,
              isLoading: isLoading && authState.isLoading,
            ),

            // Apple
            const SizedBox(height: 12),
            AppleSignInButton(
              onPressed: isLoading ? null : _signInWithApple,
              isLoading: isLoading && authState.isLoading,
            ),
          ],
        ),
      ),
    );
  }

  // ── Guest Button ──────────────────────────────────────────────
  Widget _buildGuestButton(bool isLoading, AuthState authState) {
    return TextButton(
      onPressed: isLoading ? null : _continueAsGuest,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        foregroundColor: AppColors.grey500,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading && authState.isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.grey500),
              ),
            )
          else
            const Icon(Icons.visibility_outlined,
                size: 18, color: AppColors.grey500),
          const SizedBox(width: 8),
          Text(
            context.tr('continue_as_guest'),
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.grey500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Register link ─────────────────────────────────────────────
  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.tr('no_account_question'),
          style: GoogleFonts.tajawal(
            fontSize: 14,
            color: AppColors.grey500,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.go(AppRoutes.register),
          child: Text(
            context.tr('create_account'),
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.emerald,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.emerald,
            ),
          ),
        ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Text(
      context.tr('copyright'),
      style: GoogleFonts.tajawal(
        fontSize: 11,
        color: AppColors.grey300,
        fontWeight: FontWeight.w400,
      ),
      textAlign: TextAlign.center,
    );
  }

  // ── Forgot Password Sheet ────────────────────────────────────
  void _showForgotPasswordSheet() {
    final emailController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ForgotPasswordSheet(
        emailController: emailController,
        onSend: (email) async {
          Navigator.pop(context);
          await ref
              .read(authControllerProvider.notifier)
              .sendPasswordResetEmail(email);
          if (!mounted) return;
          context.showSnackBar(context.tr('reset_email_sent', args: {'{email}': email}));
        },
      ),
    );
  }
}

// ── Primary Button ─────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [AppColors.emerald, AppColors.emeraldMedium],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isLoading ? null : onPressed,
          child: SizedBox(
            height: 54,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppColors.white),
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Forgot Password Bottom Sheet ──────────────────────────────
class _ForgotPasswordSheet extends StatefulWidget {
  const _ForgotPasswordSheet({
    required this.emailController,
    required this.onSend,
  });

  final TextEditingController emailController;
  final void Function(String email) onSend;

  @override
  State<_ForgotPasswordSheet> createState() => _ForgotPasswordSheetState();
}

class _ForgotPasswordSheetState extends State<_ForgotPasswordSheet> {
  final _key = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('reset_password_title'),
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.emeraldDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('reset_password_subtitle'),
              style: GoogleFonts.tajawal(
                fontSize: 14,
                color: AppColors.grey500,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: widget.emailController,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: context.tr('email'),
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return context.tr('email_required');
                if (!v.trim().isValidEmail) return context.tr('email_invalid');
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (_key.currentState!.validate()) {
                  widget.onSend(widget.emailController.text.trim());
                }
              },
              child: Text(context.tr('send')),
            ),
          ],
        ),
      ),
    );
  }
}
