import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../data/user_repository.dart';
import 'widgets/apple_sign_in_button.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/google_sign_in_button.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isSubmitting = false;

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

    // Pre-fill if already authenticated via Google/Apple on register screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(firebaseAuthProvider).currentUser;
      if (user != null && !user.isAnonymous) {
        if (user.email != null) _emailController.text = user.email!;
        if (user.displayName != null && user.displayName!.isNotEmpty) {
          _fullNameController.text = user.displayName!;
        }
      }
    });

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // ── Submit ────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSubmitting = true);

    final controller = ref.read(authControllerProvider.notifier);
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    final isAnon = currentUser?.isAnonymous ?? false;

    // Step 1: Create or upgrade Firebase Auth account
    if (isAnon) {
      await controller.linkAndUpgradeAnonymous(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } else {
      await controller.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }
    // If user was already authenticated via Google/Apple (non-anon), skip

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      setState(() => _isSubmitting = false);
      context.showSnackBar(
        authState.errorMessage ?? context.tr('error_occurred'),
        isError: true,
      );
      return;
    }

    // Step 2: Write users/{uid} doc
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid != null) {
      try {
        await ref.read(userRepositoryProvider).createUserDoc(
              uid: uid,
              fullName: _fullNameController.text.trim(),
              phone: _phoneController.text.trim().isNotEmpty
                  ? _phoneController.text.trim()
                  : null,
              email: _emailController.text.trim().isNotEmpty
                  ? _emailController.text.trim()
                  : null,
              city: _cityController.text.trim().isNotEmpty
                  ? _cityController.text.trim()
                  : null,
              isGuest: false,
            );
      } catch (e) {
        // Non-fatal: doc creation failed, but auth succeeded
        debugPrint('RegisterScreen: user doc creation failed: $e');
      }
    }

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    // Step 3: Route to home
    context.go(AppRoutes.home);
  }

  // ── Google / Apple (used as upgrade paths too) ────────────────
  Future<void> _signUpWithGoogle() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    final isAnon =
        ref.read(firebaseAuthProvider).currentUser?.isAnonymous ?? false;

    if (isAnon) {
      await controller.linkAndUpgradeAnonymousWithGoogle();
    } else {
      await controller.signInWithGoogle();
    }

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError && state.errorMessage != null && state.errorMessage!.isNotEmpty) {
      context.showSnackBar(
        state.errorMessage!,
        isError: true,
      );
      return;
    }
    // User cancelled — do nothing (also catches anonymous users who didn't complete sign-in)
    final currentUserAfterGoogle = ref.read(firebaseAuthProvider).currentUser;
    if (currentUserAfterGoogle == null || currentUserAfterGoogle.isAnonymous) return;

    // Create user doc from Google profile
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user != null) {
      try {
        await ref.read(userRepositoryProvider).createUserDoc(
              uid: user.uid,
              fullName: user.displayName ?? context.tr('anonymous'),
              email: user.email,
              photoUrl: user.photoURL,
              isGuest: false,
            );
      } catch (e) {
        debugPrint('RegisterScreen: Google user doc creation failed: $e');
      }
    }

    if (mounted) context.go(AppRoutes.home);
  }

  Future<void> _signUpWithApple() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(authControllerProvider.notifier);
    final isAnon =
        ref.read(firebaseAuthProvider).currentUser?.isAnonymous ?? false;

    if (isAnon) {
      await controller.linkAndUpgradeAnonymousWithApple();
    } else {
      await controller.signInWithApple();
    }

    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError && state.errorMessage != null && state.errorMessage!.isNotEmpty) {
      context.showSnackBar(
        state.errorMessage!,
        isError: true,
      );
      return;
    }
    // User cancelled — do nothing (also catches anonymous users who didn't complete sign-in)
    final currentUserAfterApple = ref.read(firebaseAuthProvider).currentUser;
    if (currentUserAfterApple == null || currentUserAfterApple.isAnonymous) return;

    final user = currentUserAfterApple;
    // Apple only provides name on first sign-in; fall back gracefully
    final fullName = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : context.tr('anonymous');
    try {
      await ref.read(userRepositoryProvider).createUserDoc(
            uid: user.uid,
            fullName: fullName,
            email: user.email,
            photoUrl: user.photoURL,
            isGuest: false,
          );
    } catch (e) {
      debugPrint('RegisterScreen: Apple user doc creation failed: $e');
    }

    if (mounted) context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = _isSubmitting || authState.isLoading;

    // NOTE: Error snackbars are shown directly inside each action method
    // (_submit, _signUpWithGoogle, _signUpWithApple) to avoid stale-state
    // double-fires that a global ref.listen would cause.


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
                      const SizedBox(height: 24),
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildForm(isLoading, authState),
                      const SizedBox(height: 20),
                      _buildLoginLink(),
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
        // Back button row
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.emeraldDark, size: 20),
              onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.login),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Image.asset(
          'assets/images/app_icon.png',
          width: 84,
          height: 84,
        ),
        const SizedBox(height: 16),
        Text(
          context.tr('register_title'),
          style: GoogleFonts.tajawal(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: AppColors.emeraldDark,
            height: 1.2,
          ),
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('register_subtitle'),
          style: GoogleFonts.tajawal(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.grey500,
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
        ),

      ],
    );
  }

  // ── Form ──────────────────────────────────────────────────────
  Widget _buildForm(bool isLoading, AuthState authState) {
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
            // Full name
            AuthTextField(
              label: context.tr('full_name'),
              hint: context.tr('full_name_hint'),
              controller: _fullNameController,
              prefixIcon: Icons.person_outline_rounded,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return context.tr('full_name_required');
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone (optional if email given, but label says phone or email)
            AuthTextField(
              label: context.tr('phone_optional'),
              hint: '+966 5XX XXX XXXX',
              controller: _phoneController,
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Email
            AuthTextField(
              label: context.tr('email'),
              hint: 'you@example.com',
              controller: _emailController,
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return context.tr('email_required');
                }
                if (!v.trim().isValidEmail) {
                  return context.tr('email_invalid');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            AuthTextField(
              label: context.tr('password'),
              hint: '••••••••',
              controller: _passwordController,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) {
                if (v == null || v.isEmpty) return context.tr('password_required');
                if (v.length < 6) return context.tr('password_too_short');
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm password
            AuthTextField(
              label: context.tr('confirm_password'),
              hint: '••••••••',
              controller: _confirmPasswordController,
              prefixIcon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return context.tr('confirm_password_required');
                if (v != _passwordController.text) {
                  return context.tr('passwords_mismatch');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // City (optional)
            AuthTextField(
              label: context.tr('city_optional'),
              hint: context.tr('city_hint'),
              controller: _cityController,
              prefixIcon: Icons.location_city_outlined,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
            ),


            const SizedBox(height: 24),

            // Primary CTA
            _PrimaryButton(
              label: context.tr('create_account_btn'),
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
                    ),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.divider)),
              ],
            ),

            const SizedBox(height: 16),

            // Google
            GoogleSignInButton(
              label: context.tr('continue_with_google'),
              onPressed: isLoading ? null : _signUpWithGoogle,
              isLoading: isLoading && authState.isLoading,
            ),
            const SizedBox(height: 12),

            // Apple
            AppleSignInButton(
              label: context.tr('continue_with_apple'),
              onPressed: isLoading ? null : _signUpWithApple,
              isLoading: isLoading && authState.isLoading,
            ),

          ],
        ),
      ),
    );
  }

  // ── Login link ────────────────────────────────────────────────
  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          context.tr('already_have_account'),
          style: GoogleFonts.tajawal(
            fontSize: 14,
            color: AppColors.grey500,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () => context.go(AppRoutes.login),
          child: Text(
            context.tr('sign_in_link'),
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
      textDirection: TextDirection.rtl,
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
