import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../data/mosque_repository.dart';
import '../domain/mosque_model.dart';
import '../domain/mosque_prayer_times_model.dart';
import '../../posts/data/post_repository.dart';
import '../../posts/domain/post_model.dart';
import '../../posts/presentation/feed_screen.dart'; // to use PostCard

class MosqueDetailsScreen extends ConsumerStatefulWidget {
  const MosqueDetailsScreen({required this.mosqueId, super.key});
  final String mosqueId;

  @override
  ConsumerState<MosqueDetailsScreen> createState() =>
      _MosqueDetailsScreenState();
}

class _MosqueDetailsScreenState extends ConsumerState<MosqueDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: 1);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double _distanceKm(MosqueModel mosque) {
    final userLoc = ref.read(userLocationProvider);
    if (userLoc == null) return 0;
    return LocationService.calculateDistance(
      startLat: userLoc.latitude,
      startLng: userLoc.longitude,
      endLat: mosque.geopoint.latitude,
      endLng: mosque.geopoint.longitude,
    );
  }

  Future<void> _openDirections(MosqueModel mosque) async {
    final lat = mosque.geopoint.latitude;
    final lng = mosque.geopoint.longitude;
    final url =
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) context.showSnackBar(context.tr('maps_launch_failed'), isError: true);
    }
  }

  Future<void> _share(MosqueModel mosque) async {
    await Clipboard.setData(ClipboardData(text: mosque.name));
    if (mounted) context.showSnackBar(context.tr('mosque_share_copied'));
  }

  Future<void> _toggleFollow(MosqueModel mosque, bool isFollowing) async {
    final isGuest = ref.read(isGuestProvider);
    if (isGuest) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    final repo = ref.read(mosqueRepositoryProvider);
    if (isFollowing) {
      await repo.unfollowMosque(uid, mosque.id);
      if (mounted) context.showSnackBar(context.tr('mosque_unfollow_snack').replaceAll('{name}', mosque.name));
    } else {
      await repo.followMosque(uid, mosque);
      if (mounted) context.showSnackBar(context.tr('mosque_follow_snack').replaceAll('{name}', mosque.name));
    }
  }

  Future<void> _toggleFollowImam(MosqueModel mosque, bool isFollowingImam) async {
    final isGuest = ref.read(isGuestProvider);
    if (isGuest) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null || mosque.imamId == null) return;
    final repo = ref.read(mosqueRepositoryProvider);
    if (isFollowingImam) {
      await repo.unfollowImam(uid, mosque.imamId!);
      if (mounted) context.showSnackBar(context.tr('imam_unfollow_snack'));
    } else {
      await repo.followImam(uid, mosque.imamId!);
      if (mounted) context.showSnackBar(context.tr('imam_follow_snack'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mosqueAsync = ref.watch(mosqueProvider(widget.mosqueId));
    final prayerTimesAsync =
        ref.watch(mosqueTodayPrayerTimesProvider(widget.mosqueId));
    final isGuest = ref.watch(isGuestProvider);
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.mosqueId));
    final isFollowing = isFollowingAsync.asData?.value ?? false;

    return mosqueAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.emeraldDark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
        ),
        body: Center(
          child: Text(context.tr('mosque_load_error'),
              style: GoogleFonts.tajawal(color: AppColors.grey700)),
        ),
      ),
      data: (mosque) {
        if (mosque == null) {
          return Scaffold(
            backgroundColor: AppColors.cream,
            appBar: AppBar(
              backgroundColor: AppColors.emeraldDark,
              leading: IconButton(
                icon:
                    const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
              ),
            ),
            body: Center(
              child: Text(context.tr('mosque_not_found'),
                  style: GoogleFonts.tajawal(color: AppColors.grey700)),
            ),
          );
        }

        final dist = _distanceKm(mosque);
        final isFollowingImamAsync = mosque.imamId != null
            ? ref.watch(isFollowingImamProvider(mosque.imamId!))
            : const AsyncValue<bool>.data(false);
        final isFollowingImam = isFollowingImamAsync.asData?.value ?? false;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            backgroundColor: const Color(0xFFF0F3FF),
            body: NestedScrollView(
              headerSliverBuilder: (ctx, innerScrolled) => [
                // 1. Cover Photo AppBar
                SliverAppBar(
                  expandedHeight: 200,
                  pinned: true,
                  backgroundColor: AppColors.emeraldDark,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.share_rounded, color: Colors.white),
                      onPressed: () => _share(mosque),
                      tooltip: context.tr('share'),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    title: innerScrolled
                        ? Text(
                            mosque.name,
                            style: GoogleFonts.tajawal(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : null,
                    background: _CoverPhoto(mosque: mosque),
                  ),
                ),

                // 2. Mosque Info Card (Name, address, actions, mini prayer times)
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MosqueHeader(
                          mosque: mosque,
                          distanceKm: dist,
                          onDirections: () => _openDirections(mosque),
                          onFollow: () => _toggleFollow(mosque, isFollowing),
                          onSave: () => context.go('/saved-mosques'),
                          isFollowing: isFollowing,
                          isFollowingImam: isFollowingImam,
                          onFollowImam: () => _toggleFollowImam(mosque, isFollowingImam),
                        ),
                        const SizedBox(height: 12),
                        _MiniPrayerCard(prayerTimesAsync: prayerTimesAsync),
                      ],
                    ),
                  ),
                ),

                // 3. Pinned TabBar
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SliverTabBarDelegate(
                    TabBar(
                      controller: _tabController,
                      labelColor: AppColors.emeraldDark,
                      unselectedLabelColor: AppColors.grey500,
                      indicatorColor: AppColors.emerald,
                      indicatorWeight: 3,
                      labelStyle: GoogleFonts.tajawal(
                          fontSize: 14, fontWeight: FontWeight.w700),
                      unselectedLabelStyle:
                          GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.w500),
                      tabs: [
                        Tab(text: context.tr('posts_tab')),
                        Tab(text: context.tr('prayer_times_tab')),
                        Tab(text: context.tr('about_mosque_tab')),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 0: المنشورات
                  _MosquePostsTab(mosqueId: mosque.id),
                  // Tab 1: أوقات الصلاة
                  _PrayerTimesTab(
                    prayerTimesAsync: prayerTimesAsync,
                    mosque: mosque,
                  ),
                  // Tab 2: عن المسجد
                  _AboutTab(mosque: mosque),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFDDE3F0), width: 0.5)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cover Photo
// ─────────────────────────────────────────────────────────────────────────────

class _CoverPhoto extends StatelessWidget {
  const _CoverPhoto({required this.mosque});
  final MosqueModel mosque;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (mosque.photo != null)
          Image.network(
            mosque.photo!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder(),
          )
        else
          _placeholder(),
        // Gradient overlay for legibility
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, AppColors.emeraldDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.4, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.emeraldDark, AppColors.emeraldMedium],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.mosque_rounded, size: 64, color: Colors.white24),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mosque Header Info
// ─────────────────────────────────────────────────────────────────────────────

class _MosqueHeader extends StatelessWidget {
  const _MosqueHeader({
    required this.mosque,
    required this.distanceKm,
    required this.onDirections,
    required this.onFollow,
    required this.onSave,
    required this.isFollowing,
    required this.isFollowingImam,
    required this.onFollowImam,
  });

  final MosqueModel mosque;
  final double distanceKm;
  final bool isFollowing;
  final bool isFollowingImam;
  final VoidCallback onDirections;
  final VoidCallback onFollow;
  final VoidCallback onSave;
  final VoidCallback onFollowImam;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Name + verified
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                mosque.name,
                style: GoogleFonts.tajawal(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.charcoal,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            if (mosque.verified) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: context.tr('verified_mosque'),
                child: const Icon(Icons.verified_rounded,
                    color: AppColors.gold, size: 20),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // Address + distance
        Row(
          children: [
            const Icon(Icons.location_on_rounded,
                size: 14, color: AppColors.grey500),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                mosque.address,
                style: GoogleFonts.tajawal(
                    fontSize: 12, color: AppColors.grey700),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (distanceKm > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPale,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  distanceKm < 1
                      ? '${(distanceKm * 1000).round()} ${context.tr('meters')}'
                      : '${distanceKm.toStringAsFixed(1)} ${context.tr('km')}',
                  style: GoogleFonts.tajawal(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emerald,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // Action row 1: Directions + Save Mosque
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                icon: Icons.directions_rounded,
                label: context.tr('directions'),
                color: AppColors.emerald,
                filled: true,
                onTap: onDirections,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _ActionBtn(
                icon: Icons.bookmark_rounded,
                label: context.tr('mosque_my_mosques'),
                color: AppColors.emeraldMedium,
                filled: false,
                onTap: onSave,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Action row 2: Follow Mosque + Follow Imam (if imamId is set)
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                icon: isFollowing
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: isFollowing ? context.tr('following') : context.tr('mosque_follow_btn'),
                color: isFollowing ? AppColors.emerald : AppColors.grey500,
                filled: isFollowing,
                onTap: onFollow,
              ),
            ),
            if (mosque.imamId != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _ActionBtn(
                  icon: isFollowingImam
                      ? Icons.stars_rounded
                      : Icons.stars_outlined,
                  label: isFollowingImam ? context.tr('imam_following_btn') : context.tr('imam_follow_btn'),
                  color: isFollowingImam ? AppColors.gold : AppColors.grey500,
                  filled: isFollowingImam,
                  onTap: onFollowImam,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          border: filled ? null : Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 14, color: filled ? Colors.white : AppColors.grey700),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.tajawal(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : AppColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini prayer card (shown in header)
// ─────────────────────────────────────────────────────────────────────────────

class _MiniPrayerCard extends StatelessWidget {
  const _MiniPrayerCard({required this.prayerTimesAsync});
  final AsyncValue<MosquePrayerTimes?> prayerTimesAsync;

  @override
  Widget build(BuildContext context) {
    return prayerTimesAsync.when(
      loading: () => _skeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (times) {
        if (times == null) return _noTimesCard(context);
        final now = DateTime.now();
        final next = times.nextPrayer(now);
        final prayers = [
          MapEntry('الفجر', times.fajr),
          MapEntry('الظهر', times.dhuhr),
          MapEntry('العصر', times.asr),
          MapEntry('المغرب', times.maghrib),
          MapEntry('العشاء', times.isha),
        ];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
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
              Row(
                children: [
                  const Icon(Icons.schedule_rounded,
                      size: 14, color: AppColors.emerald),
                  const SizedBox(width: 6),
                  Text(
                    context.tr('today_times'),
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.emeraldDark,
                    ),
                  ),
                  if (times.imamName != null) ...[
                    const Spacer(),
                    Text(
                      context.tr('imam_label').replaceAll('{name}', times.imamName!),
                      style: GoogleFonts.tajawal(
                          fontSize: 10, color: AppColors.grey500),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: prayers.map((e) {
                  final isNext = next?.key == e.key;
                  return Column(
                    children: [
                      Text(
                        e.value,
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isNext
                              ? AppColors.emerald
                              : AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.tr(e.key),
                        style: GoogleFonts.tajawal(
                          fontSize: 10,
                          color: isNext
                              ? AppColors.emerald
                              : AppColors.grey500,
                        ),
                      ),
                      if (isNext)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.emerald,
                          ),
                        ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _skeleton() {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: AppColors.grey100,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _noTimesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.grey500),
          const SizedBox(width: 8),
          Text(
            context.tr('no_times_today'),
            style: GoogleFonts.tajawal(
                fontSize: 12, color: AppColors.grey700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Prayer Times
// ─────────────────────────────────────────────────────────────────────────────

class _PrayerTimesTab extends StatelessWidget {
  const _PrayerTimesTab({
    required this.prayerTimesAsync,
    required this.mosque,
  });
  final AsyncValue<MosquePrayerTimes?> prayerTimesAsync;
  final MosqueModel mosque;

  @override
  Widget build(BuildContext context) {
    return prayerTimesAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (e, _) => Center(
        child: Text(context.tr('prayer_times_error'),
            style: GoogleFonts.tajawal(color: AppColors.grey700)),
      ),
      data: (times) {
        if (times == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.schedule_rounded,
                    size: 48, color: AppColors.grey300),
                const SizedBox(height: 12),
                Text(
                  context.tr('no_prayer_times_today'),
                  style: GoogleFonts.tajawal(
                      fontSize: 15, color: AppColors.grey500),
                ),
                const SizedBox(height: 4),
                Text(
                  context.tr('imam_updates_daily'),
                  style: GoogleFonts.tajawal(
                      fontSize: 12, color: AppColors.grey300),
                ),
              ],
            ),
          );
        }

        final now = DateTime.now();
        final next = times.nextPrayer(now);
        final prayers = times.allPrayers;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...prayers.map((entry) {
              final dt = MosquePrayerTimes.timeToDateTime(entry.value, now);
              final isPast = dt != null && dt.isBefore(now);
              final isNext = entry.key == next?.key;
              return _PrayerRow(
                name: entry.key,
                time: entry.value,
                isNext: isNext,
                isPast: isPast,
              );
            }),
            if (times.jumuah != null) ...[
              const SizedBox(height: 8),
              _JumuahCard(time: times.jumuah!),
            ],
            if (times.imamName != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Text(
                  context.tr('prayer_source_imam').replaceAll('{name}', times.imamName!),
                  style: GoogleFonts.tajawal(
                      fontSize: 11, color: AppColors.grey500),
                ),
              ),
            ],
          ],
        );
      },
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
  final String name, time;
  final bool isNext, isPast;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.emeraldDark
            : isPast
                ? AppColors.grey100
                : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isNext ? AppColors.emeraldMedium : AppColors.divider,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: AppColors.emeraldDark.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isPast
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: isPast ? AppColors.success : AppColors.grey300,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr(name),
                style: GoogleFonts.tajawal(
                  fontSize: 16,
                  fontWeight: isNext ? FontWeight.w800 : FontWeight.w600,
                  color: isNext
                      ? Colors.white
                      : isPast
                          ? AppColors.grey300
                          : AppColors.grey700,
                ),
              ),
              if (isNext) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    context.tr('next_badge'),
                    style: GoogleFonts.tajawal(
                      fontSize: 10,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const Spacer(),
          Text(
            time,
            style: GoogleFonts.tajawal(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isNext
                  ? AppColors.gold
                  : isPast
                      ? AppColors.grey300
                      : AppColors.charcoal,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _JumuahCard extends StatelessWidget {
  const _JumuahCard({required this.time});
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.goldPale, Color(0xFFFFF8E1)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mosque_rounded, color: AppColors.gold, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('jumuah_friday'),
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
              Text(
                time,
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.charcoal,
                  letterSpacing: 1,
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
// Tab: Posts
// ─────────────────────────────────────────────────────────────────────────────

class _MosquePostsTab extends ConsumerWidget {
  const _MosquePostsTab({required this.mosqueId});
  final String mosqueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(mosquePostsStreamProvider(mosqueId));
    final isGuest = ref.watch(isGuestProvider);
    final savedIdsAsync = ref.watch(savedPostIdsProvider);
    final savedIds = savedIdsAsync.asData?.value ?? {};
    final isFollowingAsync = ref.watch(isFollowingProvider(mosqueId));
    final isFollowing = isFollowingAsync.asData?.value ?? false;

    return postsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('posts_load_failed'),
                  style: GoogleFonts.tajawal(
                      color: AppColors.grey700,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(e.toString(),
                  style: GoogleFonts.tajawal(color: AppColors.grey500, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      data: (posts) {
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.article_outlined,
                    size: 52, color: AppColors.grey300),
                const SizedBox(height: 12),
                Text(
                  context.tr('no_mosque_posts'),
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.grey500,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
          itemCount: posts.length,
          itemBuilder: (ctx, i) {
            final post = posts[i];
            final isSaved = savedIds.contains(post.id);
            return PostCard(
              post: post,
              isSaved: isSaved,
              isGuest: isGuest,
              isFollowing: isFollowing,
              onSave: () => _toggleSave(context, ref, post, isSaved, isGuest),
              onTap: () => context.push('/post/${post.id}', extra: post),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleSave(
      BuildContext context, WidgetRef ref, PostModel post, bool isSaved, bool isGuest) async {
    if (isGuest) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    final repo = ref.read(postRepositoryProvider);
    if (isSaved) {
      await repo.unsavePost(uid, post.id);
      if (context.mounted) context.showSnackBar(context.tr('unsave_post_snack'));
    } else {
      await repo.savePost(uid, post);
      if (context.mounted) context.showSnackBar(context.tr('save_post_snack'));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: About
// ─────────────────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.mosque});
  final MosqueModel mosque;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoTile(
          icon: Icons.location_on_rounded,
          label: context.tr('info_address'),
          value: mosque.address,
        ),
        if (mosque.contactPhone != null)
          _InfoTile(
            icon: Icons.phone_rounded,
            label: context.tr('info_phone'),
            value: mosque.contactPhone!,
          ),
        if (mosque.capacity != null)
          _InfoTile(
            icon: Icons.people_rounded,
            label: context.tr('info_capacity'),
            value: '${mosque.capacity} ${context.tr('capacity_unit')}',
          ),
        if (mosque.city.isNotEmpty)
          _InfoTile(
            icon: Icons.location_city_rounded,
            label: context.tr('info_city'),
            value: '${mosque.city}, ${mosque.country}',
          ),
        _InfoTile(
          icon: Icons.verified_rounded,
          label: context.tr('info_verified'),
          value: mosque.verified ? context.tr('mosque_verified_yes') : context.tr('mosque_verified_no'),
          valueColor:
              mosque.verified ? AppColors.success : AppColors.grey500,
        ),
        if (mosque.createdAt != null)
          _InfoTile(
            icon: Icons.calendar_today_rounded,
            label: context.tr('info_date_added'),
            value:
                '${mosque.createdAt!.day}/${mosque.createdAt!.month}/${mosque.createdAt!.year}',
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.emerald),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.tajawal(
                      fontSize: 11, color: AppColors.grey500),
                ),
                Text(
                  value,
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? AppColors.charcoal,
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

