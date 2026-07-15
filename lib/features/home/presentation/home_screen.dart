import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/application/auth_controller.dart';
import '../../prayer_times/data/prayer_method_mapper.dart';
import '../../prayer_times/data/prayer_service.dart';
import '../../prayer_times/domain/prayer_times_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();

  // Animations
  late AnimationController _heroController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;

  @override
  void initState() {
    super.initState();

    // Hero card animation
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOut));

    _heroController.forward();

    // Tick every second to update countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _heroController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final userLocation = ref.watch(userLocationProvider);
    final prayerTimesAsync = ref.watch(prayerTimesProvider);
    final methodAsync = ref.watch(activePrayerMethodProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          // ── Top App Bar ─────────────────────────────────────────
          _HomeAppBar(
            locationName: userLocation?.name ?? '',
            isGuest: isGuest,
          ),

          // ── Content ─────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),

                // ── Hero Next Prayer Card ────────────────────────
                prayerTimesAsync.when(
                  loading: () => _NextPrayerCardSkeleton(),
                  error: (e, _) => _ErrorCard(onRetry: () => ref.invalidate(prayerTimesProvider)),
                  data: (times) => times == null
                      ? _ErrorCard(onRetry: () => ref.invalidate(prayerTimesProvider))
                      : FadeTransition(
                          opacity: _heroFade,
                          child: SlideTransition(
                            position: _heroSlide,
                            child: _NextPrayerHeroCard(
                              times: times,
                              now: _now,
                            ),
                          ),
                        ),
                ),

                const SizedBox(height: 20),

                // ── Today's Prayer Times Grid ────────────────────
                prayerTimesAsync.when(
                  loading: () => _PrayerGridSkeleton(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (times) => times == null
                      ? const SizedBox.shrink()
                      : _TodayPrayerGrid(times: times, now: _now),
                ),

                const SizedBox(height: 20),

                // ── Calculation Method Badge ─────────────────────
                methodAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (id) => _MethodBadge(
                    methodId: id,
                    onTap: () => _showMethodPicker(context),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Guest upgrade banner ─────────────────────────
                if (isGuest) _GuestUpgradeBanner(),

                // ── Nav bar spacer ───────────────────────────────
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Method picker sheet ──────────────────────────────────────
  void _showMethodPicker(BuildContext context) {
    final override = ref.read(prayerMethodOverrideProvider);
    showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MethodPickerSheet(currentMethodId: override),
    ).then((selected) {
      if (selected != null) {
        ref
            .read(prayerMethodOverrideProvider.notifier)
            .setMethod(selected == 0 ? null : selected);
        ref.invalidate(prayerTimesProvider);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Bar
// ─────────────────────────────────────────────────────────────────────────────

class _HomeAppBar extends ConsumerWidget {
  const _HomeAppBar({required this.locationName, required this.isGuest});
  final String locationName;
  final bool isGuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('app_title'),
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),

          if (locationName.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.emeraldPale,
                  size: 12,
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    locationName,
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: AppColors.emeraldPale,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        // Notification bell
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined, color: AppColors.goldLight),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {}, // placeholder
          tooltip: AppLocalizations.of(context)?.translate('notifications') ?? 'Notifications',
        ),
        // Sign out
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppColors.goldLight),
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          tooltip: AppLocalizations.of(context)?.translate('sign_out') ?? 'Sign Out',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero "Next Prayer" Card
// ─────────────────────────────────────────────────────────────────────────────

class _NextPrayerHeroCard extends StatelessWidget {
  const _NextPrayerHeroCard({required this.times, required this.now});
  final PrayerTimes times;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = times.nextPrayer(now);
    final remaining = next != null ? times.timeUntilNextPrayer(now) : null;

    final prayerName = next?.key ?? 'الفجر';
    final prayerTime = next?.value ?? times.fajr;
    final icon = _iconForPrayer(prayerName);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.emeraldDark, Color(0xFF065F46), Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldDark.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circular glow
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: AppColors.goldLight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          next != null
                              ? AppLocalizations.of(context)?.translate('next_prayer') ?? 'Next Prayer'
                              : AppLocalizations.of(context)?.translate('prayers_ended') ?? 'Prayers ended',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color: AppColors.emeraldPale.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        Text(
                          context.tr(prayerName),
                          style: GoogleFonts.tajawal(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),

                    const Spacer(),
                    Text(
                      prayerTime,
                      style: GoogleFonts.tajawal(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),

                if (remaining != null) ...[
                  const SizedBox(height: 20),
                  // Countdown bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          color: AppColors.goldLight,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${AppLocalizations.of(context)?.translate('remaining_time') ?? 'Remaining: '}${_formatDuration(remaining)}',
                          style: GoogleFonts.tajawal(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  IconData _iconForPrayer(String name) {
    switch (name) {
      case 'الفجر':
        return Icons.wb_twilight_rounded;
      case 'الشروق':
        return Icons.wb_sunny_outlined;
      case 'الظهر':
        return Icons.wb_sunny_rounded;
      case 'العصر':
        return Icons.cloud_done_rounded;
      case 'المغرب':
        return Icons.nights_stay_outlined;
      case 'العشاء':
        return Icons.nightlight_round;
      default:
        return Icons.access_time_rounded;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Prayer Times Grid
// ─────────────────────────────────────────────────────────────────────────────

class _TodayPrayerGrid extends StatelessWidget {
  const _TodayPrayerGrid({required this.times, required this.now});
  final PrayerTimes times;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = times.nextPrayer(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, right: 4),
          child: Text(
            AppLocalizations.of(context)?.translate('today_prayer_times') ?? "Today's Times",
            style: GoogleFonts.tajawal(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.emeraldDark,
            ),
          ),
        ),
        ...times.allPrayers.map((entry) {
          final isNext = entry.key == next?.key;
          final localizedName = AppLocalizations.of(context)?.translate(entry.key) ?? entry.key;
          final dt = PrayerTimes.timeToDateTime(entry.value, now);
          final isPast = dt != null && dt.isBefore(now);

          return _PrayerRow(
            name: localizedName,
            time: entry.value,
            isNext: isNext,
            isPast: isPast,
          );
        }),
      ],
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.name,
    required this.time,
    required this.isNext,
    required this.isPast,
  });
  final String name;
  final String time;
  final bool isNext;
  final bool isPast;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.emeraldDark.withValues(alpha: 0.06)
            : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext ? AppColors.emerald : AppColors.divider,
          width: isNext ? 1.5 : 1,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: AppColors.emerald.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Time (RTL — on the right)
          Text(
            time,
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isNext
                  ? AppColors.emerald
                  : isPast
                      ? AppColors.grey300
                      : AppColors.charcoal,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Prayer name
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNext)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    AppLocalizations.of(context)?.translate('next_prayer') ?? 'Next',
                    style: GoogleFonts.tajawal(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              Text(
                name,
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                  color: isNext
                      ? AppColors.emeraldDark
                      : isPast
                          ? AppColors.grey300
                          : AppColors.grey700,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(width: 8),
              Icon(
                isPast ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: isPast ? AppColors.success : AppColors.grey300,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calculation Method Badge
// ─────────────────────────────────────────────────────────────────────────────

class _MethodBadge extends StatelessWidget {
  const _MethodBadge({required this.methodId, required this.onTap});
  final int methodId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.calculate_outlined, size: 16, color: AppColors.grey500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('calc_method_label').replaceAll('{method}', context.tr('method_$methodId')),
                style: GoogleFonts.tajawal(
                  fontSize: 12,
                  color: AppColors.grey500,
                ),
                textDirection: TextDirection.rtl,
                overflow: TextOverflow.ellipsis,
              ),


            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 20, color: AppColors.grey500),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guest Upgrade Banner
// ─────────────────────────────────────────────────────────────────────────────

class _GuestUpgradeBanner extends StatelessWidget {
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
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.person_add_alt_1_rounded,
              color: AppColors.gold, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.of(context)?.translate('guest_upgrade_title') ?? 'Create a free account',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.gold,
                  ),
                  textAlign: TextAlign.end,
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)?.translate('guest_upgrade_desc') ?? 'Save your preferences and track times across devices.',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: AppColors.grey700,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Bounded width prevents the button from receiving infinite constraints
          // when the surrounding SliverList layout is interrupted by navigation.
          SizedBox(
            width: 72,
            child: ElevatedButton(
              onPressed: () => context.go(AppRoutes.register),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                AppLocalizations.of(context)?.translate('create_account') ?? 'Sign up',
                style: GoogleFonts.tajawal(
                    fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Method Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _MethodPickerSheet extends StatefulWidget {
  const _MethodPickerSheet({this.currentMethodId});
  final int? currentMethodId;

  @override
  State<_MethodPickerSheet> createState() => _MethodPickerSheetState();
}

class _MethodPickerSheetState extends State<_MethodPickerSheet> {
  late int? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentMethodId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('calc_method_title'),
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldDark,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),

                TextButton(
                  onPressed: () {
                    // Auto-detect (no override) -> return 0 sentinel
                    Navigator.of(context).pop(0);
                  },
                  child: Text(
                    context.tr('auto'),
                    style: GoogleFonts.tajawal(
                      color: AppColors.emerald,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: PrayerMethodMapper.allMethods.length,
              itemBuilder: (ctx, i) {
                final entry = PrayerMethodMapper.allMethods[i];
                final isSelected = _selected == entry.key;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Text(
                    context.tr('method_${entry.key}'),
                    style: GoogleFonts.tajawal(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      color: isSelected ? AppColors.emerald : AppColors.charcoal,
                    ),
                    textDirection: TextDirection.rtl,
                  ),

                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.emerald)
                      : null,
                  onTap: () {
                    setState(() => _selected = entry.key);
                    Navigator.of(context).pop(entry.key);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeletons & Error States
// ─────────────────────────────────────────────────────────────────────────────

class _NextPrayerCardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.grey100,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

class _PrayerGridSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        6,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Shimmer(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.grey100,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.grey300, size: 42),
          const SizedBox(height: 12),
          Text(
            context.tr('prayer_load_failed'),
            style: GoogleFonts.tajawal(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.grey500,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('check_internet_retry'),
            style: GoogleFonts.tajawal(fontSize: 12, color: AppColors.grey300),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              context.tr('retry'),
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
            ),

            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple shimmer effect widget.
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Opacity(opacity: _anim.value, child: child),
      child: widget.child,
    );
  }
}