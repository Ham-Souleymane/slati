import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../../features/prayer_times/domain/adhan_sound.dart';
import '../application/auth_controller.dart';
import '../data/user_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Profile Screen
// ─────────────────────────────────────────────────────────────────────────────

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final currentUserAsync = ref.watch(currentUserProvider);
    final firebaseUser = ref.watch(authStateChangesProvider).asData?.value;

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────
          _ProfileAppBar(isGuest: isGuest),

          // ── Content ──────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),

                // ── Avatar + name hero ────────────────────────
                currentUserAsync.when(
                  loading: () => _AvatarSkeleton(),
                  error: (_, __) => _AvatarHero(
                    name: firebaseUser?.displayName ?? context.tr('anonymous'),
                    email: firebaseUser?.email,
                    photoUrl: firebaseUser?.photoURL,
                    isGuest: isGuest,
                  ),
                  data: (user) => _AvatarHero(
                    name: user?.fullName ?? firebaseUser?.displayName ?? context.tr('anonymous'),
                    email: user?.email ?? firebaseUser?.email,
                    photoUrl: user?.photoUrl ?? firebaseUser?.photoURL,
                    isGuest: isGuest,
                  ),

                ),

                const SizedBox(height: 16),

                // ── Guest upgrade card ────────────────────────
                if (isGuest) ...[
                  _GuestUpgradeCard(),
                  const SizedBox(height: 24),
                ],

                // ── Account section ───────────────────────────
                if (!isGuest) ...[
                  _SectionHeader(title: AppLocalizations.of(context)?.translate('profile_title') ?? 'Account'),
                  const SizedBox(height: 8),
                  _SettingsCard(
                    items: [
                      _SettingsTile(
                        icon: Icons.person_outline_rounded,
                        label: context.tr('edit_name'),
                        onTap: () => _showEditNameSheet(context, ref, firebaseUser),
                      ),
                      _SettingsTile(
                        icon: Icons.lock_outline_rounded,
                        label: context.tr('change_password'),
                        onTap: () => _showResetPasswordDialog(context, ref, firebaseUser),
                      ),

                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Mosques section ───────────────────────────
                _SectionHeader(title: context.tr('nav_mosques')),
                const SizedBox(height: 8),
                _SettingsCard(
                  items: [
                    _SettingsTile(
                      icon: Icons.inbox_rounded,
                      label: context.tr('incoming_questions'),
                      onTap: () => context.push(AppRoutes.minbarQuestions),
                    ),
                    _SettingsTile(
                      icon: Icons.bookmark_rounded,
                      label: AppLocalizations.of(context)?.translate('followed_mosques') ?? 'Followed Mosques',
                      onTap: () => context.push(AppRoutes.savedMosques),
                    ),
                    _SettingsTile(
                      icon: Icons.add_location_alt_rounded,
                      label: context.tr('add_mosque_title'),
                      onTap: () {
                        if (isGuest) {
                          context.showGuestUpgradeSheet();
                          return;
                        }
                        context.push('/add-mosque');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ── Preferences section ───────────────────────
                _SectionHeader(title: AppLocalizations.of(context)?.translate('preferences') ?? 'Preferences'),
                const SizedBox(height: 8),
                _SettingsCard(
                  items: [
                    // ── Adhan Sound tile ───────────────────────
                    _SettingsTile(
                      icon: Icons.mosque_rounded,
                      label: AppLocalizations.of(context)?.translate('adhan_sound_settings') ?? 'Adhan Sound & Alerts',
                      trailing: const _AdhanSoundSubtitle(),
                      onTap: () => context.push(AppRoutes.adhanSoundSettings),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      label: AppLocalizations.of(context)?.translate('notifications') ?? 'Notifications',
                      trailing: const _ComingSoonBadge(),
                      onTap: () {},
                    ),
                    // ── Language switcher tile ─────────────────
                    _LanguageSwitcherTile(),
                  ],
                ),

                const SizedBox(height: 20),

                // ── About section ─────────────────────────────
                _SectionHeader(title: AppLocalizations.of(context)?.translate('about_app') ?? 'About'),
                const SizedBox(height: 8),
                _SettingsCard(
                  items: [
                    _SettingsTile(
                      icon: Icons.info_outline_rounded,
                      label: AppLocalizations.of(context)?.translate('about_salati') ?? 'About Salati Qourbak',
                      onTap: () => _showAboutDialog(context),
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      label: AppLocalizations.of(context)?.translate('privacy_policy') ?? 'Privacy Policy',
                      onTap: () => context.push(AppRoutes.privacyPolicy),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Sign out ──────────────────────────────────
                _SignOutButton(isGuest: isGuest),

                // ── Delete account (authenticated only) ───────
                if (!isGuest) ...[
                  const SizedBox(height: 12),
                  _DeleteAccountButton(),
                ],

                // ── Nav bar spacer ────────────────────────────
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Dialogs / Sheets ────────────────────────────────────────

  void _showEditNameSheet(BuildContext context, WidgetRef ref, User? user) {
    final controller = TextEditingController(text: user?.displayName ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditNameSheet(controller: controller, firebaseUser: user),
    );
  }

  void _showResetPasswordDialog(BuildContext context, WidgetRef ref, User? user) {
    final email = user?.email ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('reset_password_title'),
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.emeraldDark),
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          context.tr('reset_email_sent_to').replaceAll('{email}', email),
          style: GoogleFonts.tajawal(color: AppColors.grey700, height: 1.5),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel'), style: GoogleFonts.tajawal(color: AppColors.grey500)),
          ),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (email.isNotEmpty) {
                await ref
                    .read(authControllerProvider.notifier)
                    .sendPasswordResetEmail(email);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.tr('reset_email_sent_short'), style: GoogleFonts.tajawal()),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text(context.tr('send'), style: GoogleFonts.tajawal(color: Colors.white)),
          ),

        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: context.tr('app_name'),
      applicationVersion: '1.0.0',
      applicationLegalese: context.tr('app_legal'),

    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({required this.isGuest});
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: AppColors.emeraldDark,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.emeraldDark, AppColors.emerald],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Text(
        'الملف الشخصي',
        style: GoogleFonts.tajawal(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar Hero
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarHero extends StatelessWidget {
  const _AvatarHero({
    required this.name,
    required this.isGuest,
    this.email,
    this.photoUrl,
  });
  final String name;
  final String? email;
  final String? photoUrl;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emeraldDark, Color(0xFF065F46), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldDark.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 2),
              color: AppColors.emeraldMedium,
            ),
            child: photoUrl != null
                ? ClipOval(
                    child: Image.network(
                      photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _AvatarPlaceholder(name: name),
                    ),
                  )
                : _AvatarPlaceholder(name: name),
          ),

          const SizedBox(height: 8),

          // Name
          Text(
            name,
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),

          if (email != null) ...[
            const SizedBox(height: 2),
            Text(
              email!,
              style: GoogleFonts.tajawal(
                fontSize: 12,
                color: AppColors.emeraldPale.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 8),

          // Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isGuest
                  ? AppColors.gold.withValues(alpha: 0.2)
                  : AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isGuest
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : AppColors.success.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isGuest ? Icons.person_outline_rounded : Icons.verified_user_rounded,
                  size: 13,
                  color: isGuest ? AppColors.goldLight : AppColors.success,
                ),
                const SizedBox(width: 5),
                Text(
                  isGuest ? context.tr('guest_user') : context.tr('registered_user'),
                  style: GoogleFonts.tajawal(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isGuest ? AppColors.goldLight : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : context.tr('anonymous')[0].toUpperCase();

    return Center(
      child: Text(
        initial,
        style: GoogleFonts.tajawal(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar skeleton loader
// ─────────────────────────────────────────────────────────────────────────────

class _AvatarSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.emeraldDark.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guest Upgrade Card
// ─────────────────────────────────────────────────────────────────────────────

class _GuestUpgradeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldPale, Color(0xFFFFF8E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: AppColors.gold, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.tr('create_account_free'),
                  style: GoogleFonts.tajawal(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('guest_upgrade_card_desc'),
            style: GoogleFonts.tajawal(
              fontSize: 13,
              color: AppColors.grey700,
              height: 1.5,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.go(AppRoutes.login),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('sign_in_link'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.register),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(context.tr('register_title'), style: GoogleFonts.tajawal(fontWeight: FontWeight.w800)),
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        title,
        style: GoogleFonts.tajawal(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.grey700,
          letterSpacing: 0.3,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Adhan Sound Subtitle (shows current selection inline in the tile)
// ─────────────────────────────────────────────────────────────────────────────

class _AdhanSoundSubtitle extends StatefulWidget {
  const _AdhanSoundSubtitle();

  @override
  State<_AdhanSoundSubtitle> createState() => _AdhanSoundSubtitleState();
}

class _AdhanSoundSubtitleState extends State<_AdhanSoundSubtitle> {
  String? _soundId;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final soundId = await NotificationService.instance.getSelectedAdhanSound();
    final muted = await NotificationService.instance.isAdhanMuted();
    if (mounted) {
      setState(() {
        _soundId = soundId;
        _muted = muted;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_soundId == null) {
      return const SizedBox.shrink();
    }
    final option = AdhanSoundOption.findById(_muted ? 'silent' : _soundId);
    final locale = Localizations.localeOf(context);
    final isAr = locale.languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _muted ? AppColors.grey100 : AppColors.emeraldPale.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _muted ? Icons.notifications_off_rounded : Icons.music_note_rounded,
            size: 12,
            color: _muted ? AppColors.grey500 : AppColors.emerald,
          ),
          const SizedBox(width: 4),
          Text(
            _muted
                ? (isAr ? 'صامت' : 'Silent')
                : (isAr ? 'مكة' : 'Makkah')
                    .replaceFirst('مكة', option.id == 'adhan_madina' ? 'المدينة' : (option.id == 'adhan_default' ? 'كلاسيكي' : 'مكة'))
                    .replaceFirst('Makkah', option.id == 'adhan_madina' ? 'Madina' : (option.id == 'adhan_default' ? 'Classic' : 'Makkah')),
            style: GoogleFonts.tajawal(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _muted ? AppColors.grey500 : AppColors.emerald,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Card
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              Divider(height: 1, color: AppColors.divider, indent: 52),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppColors.error : AppColors.emeraldDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Arrow (RTL layout)
              Icon(Icons.chevron_left_rounded, color: AppColors.grey300, size: 20),
              const Spacer(),
              // Label
              Text(
                label,
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDestructive ? AppColors.error : AppColors.charcoal,
                ),
                textDirection: TextDirection.rtl,
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
              const SizedBox(width: 12),
              // Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coming Soon Badge
// ─────────────────────────────────────────────────────────────────────────────

class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.goldPale,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Text(
        'قريباً',
        style: GoogleFonts.tajawal(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language Switcher Tile
// ─────────────────────────────────────────────────────────────────────────────

class _LanguageSwitcherTile extends ConsumerWidget {
  const _LanguageSwitcherTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(localeProvider);
    final isArabic = currentLocale.languageCode == 'ar';

    return _SettingsTile(
      icon: Icons.language_outlined,
      label: AppLocalizations.of(context)?.translate('language') ?? 'Language',
      trailing: Text(
        isArabic ? 'العربية' : 'English',
        style: GoogleFonts.tajawal(
          fontSize: 13,
          color: AppColors.grey500,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: () => _showLanguagePicker(context, ref, currentLocale),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref, Locale currentLocale) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).padding.bottom + 24),
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
            Text(
              AppLocalizations.of(context)?.translate('select_language') ?? 'Select Language',
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.emeraldDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _LanguageOptionTile(
              label: 'العربية',
              isSelected: currentLocale.languageCode == 'ar',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('ar', 'AE'));
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
            _LanguageOptionTile(
              label: 'English',
              isSelected: currentLocale.languageCode == 'en',
              onTap: () {
                ref.read(localeProvider.notifier).setLocale(const Locale('en', 'US'));
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.emeraldDark.withValues(alpha: 0.06) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.emerald : AppColors.divider,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.emerald,
                  size: 20,
                )
              else
                const SizedBox(width: 20),
              const Spacer(),
              Text(
                label,
                style: GoogleFonts.tajawal(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.emeraldDark : AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sign Out Button
// ─────────────────────────────────────────────────────────────────────────────

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton({required this.isGuest});
  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.logout_rounded),
        label: Text(
          isGuest ? context.tr('guest_exit_btn') : context.tr('sign_out_btn'),
          style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.w700),
        ),

        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.emeraldDark,
          side: const BorderSide(color: AppColors.emeraldDark, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: () async {
          HapticFeedback.mediumImpact();
          await ref.read(authControllerProvider.notifier).signOut();
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Delete Account Button
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteAccountButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        icon: const Icon(Icons.delete_forever_rounded, size: 18),
        label: Text(
          context.tr('delete_account'),
          style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w600),
        ),

        style: TextButton.styleFrom(
          foregroundColor: AppColors.error,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () => _confirmDelete(context, ref),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.tr('delete_account'),
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w800,
            color: AppColors.error,
          ),
          textDirection: TextDirection.rtl,
        ),
        content: Text(
          context.tr('delete_account_confirm'),
          style: GoogleFonts.tajawal(color: AppColors.grey700, height: 1.5),
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel'), style: GoogleFonts.tajawal(color: AppColors.grey500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).signOut();
            },
            child: Text(context.tr('delete'), style: GoogleFonts.tajawal(color: Colors.white)),
          ),

        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Name Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditNameSheet extends ConsumerStatefulWidget {
  const _EditNameSheet({
    required this.controller,
    required this.firebaseUser,
  });

  final TextEditingController controller;
  final User? firebaseUser;

  @override
  ConsumerState<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends ConsumerState<_EditNameSheet> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    context.tr('edit_name'),
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldDark,
                    ),
                    textDirection: TextDirection.rtl,
                  ),

                  const SizedBox(height: 16),
                  TextField(
                    controller: widget.controller,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.tajawal(fontSize: 15, color: AppColors.charcoal),
                    decoration: InputDecoration(
                      hintText: context.tr('full_name'),

                      hintStyle: GoogleFonts.tajawal(color: AppColors.grey300),
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.emerald, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving
                          ? null
                          : () async {
                              setState(() => _saving = true);
                              final newName = widget.controller.text.trim();
                              if (newName.isNotEmpty && widget.firebaseUser != null) {
                                try {
                                  await widget.firebaseUser!.updateDisplayName(newName);
                                  final uid = widget.firebaseUser!.uid;
                                  await ref
                                      .read(userRepositoryProvider)
                                      .updateUserDoc(uid, {'fullName': newName});
                                } catch (_) {}
                              }
                              setState(() => _saving = false);
                              if (!mounted) return;
                              Navigator.of(context).pop();
                            },
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              context.tr('save'),
                              style: GoogleFonts.tajawal(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),

                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
