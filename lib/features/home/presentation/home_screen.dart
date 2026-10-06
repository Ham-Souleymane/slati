import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../auth/application/auth_controller.dart';
import '../../mosques/data/mosque_repository.dart';
import '../../posts/data/post_repository.dart';
import '../../posts/domain/post_model.dart';
import '../../posts/presentation/feed_screen.dart';
import '../../prayer_times/data/prayer_service.dart';
import '../../prayer_times/domain/prayer_times_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _seedIfNeeded();
        _checkPermissionsPrompt();
      }
    });
  }

  Future<void> _checkPermissionsPrompt() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      final sp = await SharedPreferences.getInstance();
      final hasChecked = sp.getBool('has_prompted_exact_alarm') ?? false;
      if (hasChecked) return;

      final hasExact = await NotificationService.instance.hasExactAlarmPermission();
      if (!hasExact && mounted) {
        await sp.setBool('has_prompted_exact_alarm', true);
        // Capture context before async gap
        if (!mounted) return;
        final localContext = context;
        final isAr = Localizations.localeOf(localContext).languageCode == 'ar';
        final shouldOpen = await showDialog<bool>(
          context: localContext,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isAr ? 'تفعيل تنبيهات الأذان في موعدها ⏰' : 'Enable Accurate Prayer Alarms ⏰',
              style: GoogleFonts.tajawal(fontWeight: FontWeight.w800, color: AppColors.emeraldDark),
            ),
            content: Text(
              isAr
                  ? 'لضمان انطلاق صوت الأذان بدقة عند دخول وقت الصلاة حتى عندما تكون الشاشة مغلقة أو التطبيق مغلقاً، يرجى تفعيل إذن "المنبهات والتذكيرات".'
                  : 'To ensure the Adhan rings accurately when prayer time arrives even when the screen is locked, please enable "Alarms & Reminders" permission.',
              style: GoogleFonts.tajawal(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(isAr ? 'لاحقاً' : 'Later', style: GoogleFonts.tajawal(color: AppColors.grey700)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Text(isAr ? 'تفعيل الآن' : 'Enable Now', style: GoogleFonts.tajawal(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );

        if (shouldOpen == true) {
          await NotificationService.instance.requestExactAlarmPermission();
        }
      }
    } catch (e) {
      debugPrint('[HomeScreen] Permission prompt error: $e');
    }
  }

  Future<void> _seedIfNeeded() async {
    final loc = ref.read(userLocationProvider);
    if (loc == null) return;
    await ref.read(postRepositoryProvider).seedMockPostsIfEmpty(
          loc.latitude,
          loc.longitude,
        );
  }

  @override
  void dispose() {
    _heroController.dispose();
    super.dispose();
  }

  Future<void> _toggleSave(
      PostModel post, bool isSaved, bool isGuest) async {
    if (isGuest) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    final repo = ref.read(postRepositoryProvider);
    if (isSaved) {
      await repo.unsavePost(uid, post.id);
      if (mounted) context.showSnackBar(context.tr('unsave_post_success'));
    } else {
      await repo.savePost(uid, post);
      if (mounted) context.showSnackBar(context.tr('save_post_success'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final userLocation = ref.watch(userLocationProvider);
    final prayerTimesAsync = ref.watch(prayerTimesProvider);
    final savedIdsAsync = ref.watch(savedPostIdsProvider);
    final savedIds = savedIdsAsync.asData?.value ?? {};
    final followedMosquesAsync = ref.watch(followedMosquesProvider);
    final followedMosqueIds =
        (followedMosquesAsync.asData?.value ?? []).map((m) => m.id).toSet();
    final paginatedPostsState = ref.watch(paginatedPostsNotifierProvider);

    ref.listen<AsyncValue<PrayerTimes?>>(prayerTimesProvider, (prev, next) {
      final times = next.asData?.value;
      if (times != null) {
        NotificationService.instance.syncPrayerAlerts(times);
        final city = ref.read(userCityProvider).asData?.value;
        NotificationService.instance.updateOngoingPrayerStatus(
          times: times,
          cityName: city,
        );
      }
    });

    final cachedTimes = prayerTimesAsync.asData?.value;
    if (cachedTimes != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationService.instance.syncPrayerAlerts(cachedTimes);
        final city = ref.read(userCityProvider).asData?.value;
        NotificationService.instance.updateOngoingPrayerStatus(
          times: cachedTimes,
          cityName: city,
        );
      });
    }

    ref.listen<AsyncValue<String?>>(userCityProvider, (prev, next) {
      final city = next.asData?.value;
      final times = ref.read(prayerTimesProvider).asData?.value;
      if (times != null && city != null) {
        NotificationService.instance.updateOngoingPrayerStatus(
          times: times,
          cityName: city,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 300) {
            ref.read(paginatedPostsNotifierProvider.notifier).fetchNextPage();
          }
          return false;
        },
        child: RefreshIndicator(
          color: AppColors.emerald,
          onRefresh: () async {
            ref.invalidate(prayerTimesProvider);
            await ref.read(paginatedPostsNotifierProvider.notifier).refresh();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Top App Bar ─────────────────────────────────────────
              _HomeAppBar(
                locationName: userLocation?.name ?? '',
                isGuest: isGuest,
              ),

              // ── Content ─────────────────────────────────────────────
              // ── Top Header Section ──────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Hero Next Prayer Card ────────────────────────
                    prayerTimesAsync.when(
                      loading: () => _NextPrayerCardSkeleton(),
                      error: (e, _) => _ErrorCard(
                        onRetry: () => ref.invalidate(prayerTimesProvider),
                      ),
                      data: (times) => times == null
                          ? _ErrorCard(
                              onRetry: () => ref.invalidate(prayerTimesProvider),
                            )
                          : FadeTransition(
                              opacity: _heroFade,
                              child: SlideTransition(
                                position: _heroSlide,
                                child: _NextPrayerHeroCard(
                                  times: times,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 16),

                    // ── Banners Carousel ──────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      clipBehavior: Clip.none,
                      child: Row(
                        children: [
                          // 1. Followed Posts Banner
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.8,
                            child: GestureDetector(
                              onTap: () => context.go('/feed?tab=followed'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.emeraldDark, Color(0xFF065F46)],
                                    begin: Alignment.topRight,
                                    end: Alignment.bottomLeft,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.emeraldDark.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.dynamic_feed_rounded,
                                        color: AppColors.gold,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'منشورات المساجد',
                                            style: GoogleFonts.tajawal(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'أحدث منشورات من تتابع',
                                            style: GoogleFonts.tajawal(
                                              fontSize: 12,
                                              color: Colors.white.withValues(alpha: 0.75),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_back_ios_rounded,
                                      size: 16,
                                      color: AppColors.gold,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 12),
                          
                          // 2. WhatsApp Banner
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width * 0.8,
                            child: _WhatsAppChannelBanner(),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Guest upgrade banner ─────────────────────────
                    if (isGuest) ...[
                      _GuestUpgradeBanner(),
                      const SizedBox(height: 16),
                    ],
                  ]),
                ),
              ),

              // ── Posts Paginated Feed List ──────────────────────────
              if (paginatedPostsState.isLoading && paginatedPostsState.posts.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _Shimmer(
                          child: Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.grey100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      childCount: 3,
                    ),
                  ),
                )
              else if (paginatedPostsState.error != null && paginatedPostsState.posts.isEmpty)
                SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.tr('feed_load_posts_failed'),
                            style: GoogleFonts.tajawal(
                              color: AppColors.grey700,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            paginatedPostsState.error.toString(),
                            style: GoogleFonts.tajawal(
                              color: AppColors.grey500,
                              fontSize: 11,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else () {
                final posts = paginatedPostsState.posts;
                if (posts.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.article_outlined,
                                size: 56, color: AppColors.grey300),
                            const SizedBox(height: 12),
                            Text(
                              context.tr('feed_empty_posts'),
                              style: GoogleFonts.tajawal(
                                fontSize: 15,
                                color: AppColors.grey500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final itemCount = posts.length + (paginatedPostsState.isLoadingMore ? 1 : 0);
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.builder(
                    itemCount: itemCount,
                    itemBuilder: (context, index) {
                      if (index >= posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.emerald,
                              ),
                            ),
                          ),
                        );
                      }

                      final post = posts[index];
                      final isSaved = savedIds.contains(post.id);
                      final isFollowing = followedMosqueIds.contains(post.mosqueId);
                      return RepaintBoundary(
                        child: PostCard(
                          key: ValueKey(post.id),
                          post: post,
                          isSaved: isSaved,
                          isGuest: isGuest,
                          isFollowing: isFollowing,
                          onSave: () => _toggleSave(post, isSaved, isGuest),
                          onTap: () => context.push(
                            '/post/${post.id}',
                            extra: post,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }(),
            ],
          ),
        ),
      ),
    );
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
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined,
                  color: AppColors.goldLight),
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
          onPressed: () {},
          tooltip: AppLocalizations.of(context)?.translate('notifications') ??
              'Notifications',
        ),
        IconButton(
          icon: const Icon(Icons.logout_rounded, color: AppColors.goldLight),
          onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
          tooltip: AppLocalizations.of(context)?.translate('sign_out') ??
              'Sign Out',
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero "Next Prayer" Card
// ─────────────────────────────────────────────────────────────────────────────

class _NextPrayerHeroCard extends StatefulWidget {
  const _NextPrayerHeroCard({required this.times});
  final PrayerTimes times;

  @override
  State<_NextPrayerHeroCard> createState() => _NextPrayerHeroCardState();
}

class _NextPrayerHeroCardState extends State<_NextPrayerHeroCard> {
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final next = widget.times.nextPrayer(_now);
    Duration? remaining;
    String prayerName;
    String prayerTime;

    if (next != null) {
      remaining = widget.times.timeUntilNextPrayer(_now);
      prayerName = next.key;
      prayerTime = next.value;
    } else {
      // If today's prayers are over, count down to tomorrow's Fajr
      final tomorrowFajr = NotificationService.parseTimeToDateTime(
        widget.times.fajr,
        _now.add(const Duration(days: 1)),
        'الفجر',
      );
      if (tomorrowFajr != null) {
        remaining = tomorrowFajr.difference(_now);
      } else {
        remaining = widget.times.timeUntilNextPrayer(_now);
      }
      prayerName = 'الفجر';
      prayerTime = widget.times.fajr;
    }

    final icon = _iconForPrayer(prayerName);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.emeraldDark,
            Color(0xFF065F46),
            Color(0xFF047857)
          ],
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
            padding: const EdgeInsets.all(20),
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
                              ? AppLocalizations.of(context)
                                      ?.translate('next_prayer') ??
                                  'Next Prayer'
                              : 'الصلاة القادمة (غداً)',
                          style: GoogleFonts.tajawal(
                            fontSize: 13,
                            color:
                                AppColors.emeraldPale.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        Text(
                          context.tr(prayerName),
                          style: GoogleFonts.tajawal(
                            fontSize: 24,
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
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                if (remaining != null && !remaining.isNegative) ...[
                  const SizedBox(height: 16),
                  // Big & Prominent Countdown Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              color: AppColors.goldLight,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'الوقت المتبقي للأذان',
                              style: GoogleFonts.tajawal(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.emeraldPale,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Hours : Minutes : Seconds large blocks (Left to Right)
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildCountdownUnit(
                                value: remaining.inHours.toString().padLeft(2, '0'),
                                label: 'ساعة',
                              ),
                              _buildCountdownColon(),
                              _buildCountdownUnit(
                                value: (remaining.inMinutes % 60)
                                    .toString()
                                    .padLeft(2, '0'),
                                label: 'دقيقة',
                              ),
                              _buildCountdownColon(),
                              _buildCountdownUnit(
                                value: (remaining.inSeconds % 60)
                                    .toString()
                                    .padLeft(2, '0'),
                                label: 'ثانية',
                              ),
                            ],
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

  Widget _buildCountdownUnit({required String value, required String label}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.tajawal(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.goldLight,
              height: 1.05,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.tajawal(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.emeraldPale.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownColon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        ':',
        style: GoogleFonts.tajawal(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: AppColors.gold.withValues(alpha: 0.8),
        ),
      ),
    );
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
// WhatsApp Channel Banner
// ─────────────────────────────────────────────────────────────────────────────

class _WhatsAppChannelBanner extends StatelessWidget {
  static const _channelUrl =
      'https://whatsapp.com/channel/0029VbDitEW9MF8usnUyMI0y';

  Future<void> _openChannel() async {
    final uri = Uri.parse(_channelUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openChannel,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A6B3C), Color(0xFF128C7E)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF128C7E).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: AppColors.gold,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'قناتنا على الواتساب',
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'تابعنا للحصول على آخر الأخبار والتحديثات',
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_rounded,
              size: 16,
              color: AppColors.gold,
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldPale,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.stars_rounded,
              color: AppColors.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.translate('upgrade_title') ??
                      'Unlock Full Access',
                  style: GoogleFonts.tajawal(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                Text(
                  AppLocalizations.of(context)?.translate('upgrade_subtitle') ??
                      'Create an account to follow mosques & get alerts',
                  style: GoogleFonts.tajawal(
                    fontSize: 12,
                    color: AppColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)?.translate('register_btn') ??
                    'Register',
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
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
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.grey300, size: 42),
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
                borderRadius: BorderRadius.circular(12),
              ),
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

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
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