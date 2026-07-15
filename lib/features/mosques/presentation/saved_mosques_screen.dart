import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../data/mosque_repository.dart';
import '../domain/mosque_model.dart';

class SavedMosquesScreen extends ConsumerWidget {
  const SavedMosquesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followedAsync = ref.watch(followedMosquesProvider);
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('saved_mosques_title'),
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: followedAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.emerald),
        ),
        error: (e, _) => Center(
          child: Text(
            context.tr('failed_load_saved_mosques'),
            style: GoogleFonts.tajawal(color: AppColors.grey700),
          ),
        ),
        data: (mosques) {
          if (isGuest) {
            return _GuestState(onDiscover: () => context.go('/nearby-mosques'));
          }

          if (mosques.isEmpty) {
            return _EmptyState(onDiscover: () => context.go('/nearby-mosques'));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 108),
            itemCount: mosques.length,
            itemBuilder: (ctx, i) {
              final mosque = mosques[i];
              return _FollowedMosqueCard(
                mosque: mosque,
                onUnfollow: () => _unfollow(context, ref, mosque.id),
                onTap: () => context.push('/mosque/${mosque.id}'),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unfollow(
      BuildContext ctx, WidgetRef ref, String mosqueId) async {
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    await ref.read(mosqueRepositoryProvider).unfollowMosque(uid, mosqueId);
    if (ctx.mounted) ctx.showSnackBar(ctx.tr('unfollow_success'));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Followed mosque card
// ─────────────────────────────────────────────────────────────────────────────
class _FollowedMosqueCard extends ConsumerWidget {
  const _FollowedMosqueCard({
    required this.mosque,
    required this.onUnfollow,
    required this.onTap,
  });

  final MosqueModel mosque;
  final VoidCallback onUnfollow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userLoc = ref.read(userLocationProvider);
    double? dist;
    if (userLoc != null) {
      dist = LocationService.calculateDistance(
        startLat: userLoc.latitude,
        startLng: userLoc.longitude,
        endLat: mosque.geopoint.latitude,
        endLng: mosque.geopoint.longitude,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              // Mosque avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.emeraldPale,
                  borderRadius: BorderRadius.circular(12),
                  image: mosque.photo != null
                      ? DecorationImage(
                          image: NetworkImage(mosque.photo!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: mosque.photo == null
                    ? const Center(
                        child: Icon(Icons.mosque_rounded,
                            color: AppColors.emerald, size: 28),
                      )
                    : null,
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Text(
                            mosque.name,
                            style: GoogleFonts.tajawal(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.emeraldDark,
                            ),
                            textDirection: TextDirection.rtl,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (mosque.verified) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded,
                              color: AppColors.gold, size: 15),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      mosque.address,
                      style: GoogleFonts.tajawal(
                          fontSize: 12, color: AppColors.grey500),
                      textDirection: TextDirection.rtl,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dist != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPale,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          dist < 1
                              ? '${(dist * 1000).round()} ${context.tr('meters') == 'meters' ? 'm' : 'م'}'
                              : '${dist.toStringAsFixed(1)} ${context.tr('km') == 'km' ? 'km' : 'كم'}',
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
              ),

              // Unfollow button
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.heart_broken_rounded,
                    color: AppColors.error, size: 22),
                tooltip: context.tr('unfollow_dialog_title'),
                onPressed: () => _confirmUnfollow(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmUnfollow(BuildContext ctx) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(
          ctx.tr('unfollow_dialog_title'),
          style: GoogleFonts.tajawal(fontWeight: FontWeight.w800),
        ),
        content: Text(
          ctx.tr('unfollow_dialog_desc', args: {'{name}': mosque.name}),
          style: GoogleFonts.tajawal(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('cancel'), style: GoogleFonts.tajawal()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onUnfollow();
            },
            child: Text(ctx.tr('unfollow_confirm_btn'), style: GoogleFonts.tajawal()),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty & guest states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onDiscover});
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decorative mosque icon illustration
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.emeraldPale,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.mosque_rounded,
                    size: 60, color: AppColors.emerald),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.tr('no_followed_mosques'),
              style: GoogleFonts.tajawal(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('no_followed_desc'),
              style: GoogleFonts.tajawal(
                  fontSize: 14, color: AppColors.grey500, height: 1.7),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onDiscover,
              icon: const Icon(Icons.explore_rounded),
              label: Text(
                context.tr('explore_nearby'),
                style: GoogleFonts.tajawal(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestState extends StatelessWidget {
  const _GuestState({required this.onDiscover});
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.lock_outline_rounded,
                    size: 48, color: AppColors.grey500),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.tr('member_feature_title'),
              style: GoogleFonts.tajawal(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('member_feature_desc'),
              style: GoogleFonts.tajawal(
                  fontSize: 13, color: AppColors.grey500, height: 1.7),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/register'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                context.tr('create_account'),
                style: GoogleFonts.tajawal(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onDiscover,
              child: Text(
                context.tr('browse_without_account'),
                style: GoogleFonts.tajawal(color: AppColors.grey500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
