import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../mosques/data/mosque_repository.dart';
import '../data/post_repository.dart';
import '../domain/post_model.dart';
import '../domain/comment_model.dart';

class PostDetailsScreen extends ConsumerWidget {
  const PostDetailsScreen({required this.postId, this.post, super.key});

  final String postId;
  // Optionally passed directly from the Feed (avoids refetch)
  final PostModel? post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postStreamProvider(postId));

    return postAsync.when(
      loading: () {
        if (post != null) {
          return _PostDetailsBody(post: post!);
        }
        return Scaffold(
          backgroundColor: AppColors.cream,
          appBar: _buildAppBar(context),
          body: const Center(
            child: CircularProgressIndicator(color: AppColors.emerald),
          ),
        );
      },
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: _buildAppBar(context),
        body: Center(
          child: Text(
            context.tr('post_not_found'),
            style: GoogleFonts.tajawal(color: AppColors.grey500),
          ),
        ),
      ),

      data: (p) => _PostDetailsBody(post: p),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.emeraldDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
    );
  }
}

class _PostDetailsBody extends ConsumerWidget {
  const _PostDetailsBody({required this.post});

  final PostModel post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final likesCountAsync = ref.watch(postLikesCountProvider(post.id));
    final likesCount = likesCountAsync.asData?.value ?? post.likeCount;
    final commentsCountAsync = ref.watch(postCommentsCountProvider(post.id));
    final commentsCount = commentsCountAsync.asData?.value ?? post.commentCount;
    final savedIdsAsync = ref.watch(savedPostIdsProvider);
    final isSaved = savedIdsAsync.asData?.value.contains(post.id) ?? false;
    final isLikedAsync = ref.watch(isPostLikedProvider(post.id));
    final isLiked = isLikedAsync.asData?.value ?? false;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomScrollView(
        slivers: [
          // ── Collapsing image header / solid app bar ───────────
          SliverAppBar(
            expandedHeight: post.photoUrl != null && post.photoUrl!.trim().isNotEmpty ? 240 : 80,
            pinned: true,
            backgroundColor: AppColors.emeraldDark,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
            flexibleSpace: post.photoUrl != null && post.photoUrl!.trim().isNotEmpty
                ? FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          post.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('Error loading post details image (${post.photoUrl}): $error');
                            return Container(
                              color: AppColors.grey100,
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image_rounded,
                                  color: AppColors.grey300,
                                  size: 40,
                                ),
                              ),
                            );
                          },
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                AppColors.emeraldDark,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.45, 1.0],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),

          // ── Content ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Mosque author card
                  _MosqueAuthorCard(post: post),
                  const SizedBox(height: 16),

                  // Category badge
                  Align(
                    alignment: Alignment.centerRight,
                    child: _CategoryBadge(category: post.category),
                  ),
                  const SizedBox(height: 12),

                  // Full post text
                  Text(
                    post.text,
                    style: GoogleFonts.tajawal(
                      fontSize: 15,
                      height: 1.8,
                      color: AppColors.charcoal,
                    ),
                    textDirection: TextDirection.rtl,
                  ),

                  // Event info card
                  if (post.isEvent) ...[
                    const SizedBox(height: 20),
                    _EventInfoCard(post: post),
                  ],

                  // Likes and comments counts row
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      IconButton(
                        icon: Icon(
                          isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isLiked ? Colors.red : AppColors.grey500,
                        ),
                        onPressed: () => _toggleLike(context, ref, isLiked),
                      ),
                      Text(
                        context.tr('likes_count').replaceAll('{count}', '$likesCount'),
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey700,
                        ),
                      ),
                      const SizedBox(width: 24),
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppColors.grey500,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.tr('comments_count').replaceAll('{count}', '$commentsCount'),
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.grey700,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action footer (save, share, mosque details)
                  _ActionFooter(
                    post: post,
                    isSaved: isSaved,
                    isGuest: isGuest,
                    onSave: () => _toggleSave(context, ref, isSaved, isGuest),
                    onShare: () => _share(context),
                    onViewMosque: () => context.push('/mosque/${post.mosqueId}'),
                  ),

                  const SizedBox(height: 28),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 16),

                  // Comments section title
                  Text(
                    context.tr('comments_title'),
                    style: GoogleFonts.tajawal(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.emeraldDark,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),


                  // Comment Input
                  _CommentInput(postId: post.id, isGuest: isGuest),
                  const SizedBox(height: 16),

                  // Comments list
                  _CommentsSection(postId: post.id),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSave(
      BuildContext ctx, WidgetRef ref, bool isSaved, bool isGuest) async {
    if (isGuest) {
      ctx.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    final repo = ref.read(postRepositoryProvider);
    if (isSaved) {
      await repo.unsavePost(uid, post.id);
      if (ctx.mounted) ctx.showSnackBar(ctx.tr('unsave_post_snack'));
    } else {
      await repo.savePost(uid, post);
      if (ctx.mounted) ctx.showSnackBar(ctx.tr('save_post_snack'));
    }
  }

  Future<void> _share(BuildContext ctx) async {
    await Clipboard.setData(ClipboardData(text: post.text));
    if (ctx.mounted) ctx.showSnackBar(ctx.tr('copy_post_snack'));
  }


  Future<void> _toggleLike(BuildContext context, WidgetRef ref, bool isLiked) async {
    if (ref.read(isGuestProvider)) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    
    await ref.read(postRepositoryProvider).toggleLikePost(uid, post.id, isLiked);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mosque author card
// ─────────────────────────────────────────────────────────────────────────────
class _MosqueAuthorCard extends ConsumerWidget {
  const _MosqueAuthorCard({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch live mosque data to show real name, photo and imam
    final mosqueAsync = ref.watch(mosqueByIdProvider(post.mosqueId));
    final mosque = mosqueAsync.asData?.value;
    final displayName = (mosque?.name.isNotEmpty == true)
        ? mosque!.name
        : (post.mosqueName.isNotEmpty && post.mosqueName != 'مسجد')
            ? post.mosqueName
            : context.tr('mosque_label_default');

    final displayPhoto = mosque?.photo ?? post.mosquePhoto;
    final displayVerified = mosque?.verified ?? post.verified;
    final liveImamId = mosque?.imamId ?? post.imamId;

    final isFollowingAsync = ref.watch(isFollowingProvider(post.mosqueId));
    final isFollowing = isFollowingAsync.asData?.value ?? false;
    final isGuest = ref.watch(isGuestProvider);

    final imamNameAsync = liveImamId != null
        ? ref.watch(imamNameProvider(liveImamId))
        : const AsyncValue<String?>.data(null);
    final imamName = imamNameAsync.asData?.value;

    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.emeraldPale,
              shape: BoxShape.circle,
              border:
                  Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
              image: displayPhoto != null
                  ? DecorationImage(
                      image: NetworkImage(displayPhoto),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: displayPhoto == null
                ? const Icon(Icons.mosque_rounded,
                    color: AppColors.emerald, size: 26)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.tajawal(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                    if (displayVerified) ...[
                      const SizedBox(width: 5),
                      const Icon(Icons.verified_rounded,
                          color: AppColors.gold, size: 16),
                    ],
                  ],
                ),
                if (imamName != null && imamName.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    textDirection: TextDirection.rtl,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_rounded, size: 12, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        context.tr('imam_mosque_label').replaceAll('{name}', imamName),
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),

                    ],
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  _formatDate(context, post.createdAt),
                  style: GoogleFonts.tajawal(
                      fontSize: 12, color: AppColors.grey500),
                ),

              ],
            ),
          ),
          // Follow button
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _toggleFollow(context, ref, isGuest, isFollowing),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFollowing
                    ? AppColors.emerald
                    : Colors.transparent,
                border: Border.all(
                  color: isFollowing
                      ? AppColors.emerald
                      : AppColors.divider,
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isFollowing
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 14,
                    color: isFollowing
                        ? Colors.white
                        : AppColors.grey500,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isFollowing ? context.tr('post_following_btn') : context.tr('post_follow_btn'),
                    style: GoogleFonts.tajawal(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isFollowing
                          ? Colors.white
                          : AppColors.grey500,
                    ),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleFollow(
      BuildContext context, WidgetRef ref, bool isGuest, bool isFollowing) async {
    if (isGuest) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    final mosqueRepo = ref.read(mosqueRepositoryProvider);
    if (isFollowing) {
      await mosqueRepo.unfollowMosque(uid, post.mosqueId);
    } else {
      final mosqueAsync = ref.read(mosqueByIdProvider(post.mosqueId));
      final mosque = mosqueAsync.asData?.value;
      if (mosque != null) {
        await mosqueRepo.followMosque(uid, mosque);
      } else {
        await mosqueRepo.followMosqueById(uid, post.mosqueId);
      }
      if (context.mounted) {
        context.showSnackBar(context.tr('mosque_follow_snack').replaceAll('{name}', post.mosqueName));
      }
    }
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final days = [
      context.tr('day_mon'),
      context.tr('day_tue'),
      context.tr('day_wed'),
      context.tr('day_thu'),
      context.tr('day_fri'),
      context.tr('day_sat'),
      context.tr('day_sun'),
    ];
    final months = [
      context.tr('month_jan'),
      context.tr('month_feb'),
      context.tr('month_mar'),
      context.tr('month_apr'),
      context.tr('month_may'),
      context.tr('month_jun'),
      context.tr('month_jul'),
      context.tr('month_aug'),
      context.tr('month_sep'),
      context.tr('month_oct'),
      context.tr('month_nov'),
      context.tr('month_dec'),
    ];
    return '${days[dt.weekday - 1]}، ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// Category badge
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});
  final String category;

  @override
  Widget build(BuildContext context) {
    const colors = {
      'cat_lessons': (Color(0xFF1D4ED8), Color(0xFFEFF6FF)),
      'cat_announcements': (Color(0xFFD97706), Color(0xFFFFFBEB)),
      'cat_activities': (Color(0xFF059669), Color(0xFFECFDF5)),
    };
    String catKey = category;
    if (category == 'دروس' || category == 'cat_lessons') catKey = 'cat_lessons';
    else if (category == 'إعلانات' || category == 'cat_announcements') catKey = 'cat_announcements';
    else if (category == 'أنشطة' || category == 'cat_activities') catKey = 'cat_activities';
    else if (category == 'الكل' || category == 'cat_all') catKey = 'cat_all';

    final (fg, bg) = colors[catKey] ??
        (AppColors.emerald, AppColors.emeraldPale);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Text(
        context.tr(catKey),
        style: GoogleFonts.tajawal(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );

  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event info card
// ─────────────────────────────────────────────────────────────────────────────
class _EventInfoCard extends StatelessWidget {
  const _EventInfoCard({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.goldPale,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            context.tr('event_details'),
            style: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(height: 10),
          if (post.eventDate != null)
            _EventRow(
              icon: Icons.calendar_today_rounded,
              label: context.tr('event_date'),
              value: post.eventDate!,
            ),
          if (post.eventTime != null)
            _EventRow(
              icon: Icons.access_time_rounded,
              label: context.tr('event_time'),
              value: post.eventTime!,
            ),
          if (post.eventLocation != null)
            _EventRow(
              icon: Icons.location_on_rounded,
              label: context.tr('event_location'),
              value: post.eventLocation!,
            ),
        ],
      ),
    );

  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Icon(icon, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.tajawal(
                    fontSize: 10, color: AppColors.grey500),
              ),
              Text(
                value,
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action footer
// ─────────────────────────────────────────────────────────────────────────────
class _ActionFooter extends StatelessWidget {
  const _ActionFooter({
    required this.post,
    required this.isSaved,
    required this.isGuest,
    required this.onSave,
    required this.onShare,
    required this.onViewMosque,
  });

  final PostModel post;
  final bool isSaved;
  final bool isGuest;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onViewMosque;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Save button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            ),
            label: Text(
              isSaved ? context.tr('saved_snack') : context.tr('save_post_snack'),
              style: GoogleFonts.tajawal(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isSaved ? AppColors.success : AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded),
                label: Text(
                  context.tr('share_post'),
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.emerald,
                  side: const BorderSide(color: AppColors.emerald),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onViewMosque,
                icon: const Icon(Icons.mosque_rounded),
                label: Text(
                  context.tr('view_mosque'),
                  style: GoogleFonts.tajawal(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.charcoal,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments Section Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _CommentsSection extends ConsumerWidget {
  const _CommentsSection({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(postCommentsProvider(postId));

    return commentsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      ),
      error: (e, _) => Center(
        child: Text(
          context.tr('comments_load_failed'),
          style: GoogleFonts.tajawal(color: AppColors.grey500),
        ),
      ),
      data: (comments) {
        if (comments.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                context.tr('no_comments_yet'),
                style: GoogleFonts.tajawal(
                  fontSize: 13,
                  color: AppColors.grey500,
                ),
              ),
            ),
          );
        }


        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (ctx, i) {
            final comment = comments[i];
            return _CommentTile(comment: comment);
          },
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final CommentModel comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.emeraldPale,
              shape: BoxShape.circle,
              image: comment.userPhotoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(comment.userPhotoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: comment.userPhotoUrl == null
                ? const Icon(Icons.person_rounded,
                    color: AppColors.emerald, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          // Comment box
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    textDirection: TextDirection.rtl,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        comment.userName,
                        style: GoogleFonts.tajawal(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                      Text(
                        _elapsed(context, comment.createdAt),
                        style: GoogleFonts.tajawal(
                          fontSize: 10,
                          color: AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.text,
                    style: GoogleFonts.tajawal(
                      fontSize: 13,
                      color: AppColors.charcoal,
                      height: 1.4,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _elapsed(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return context.tr('elapsed_now');
    if (diff.inMinutes < 60) return context.tr('elapsed_minutes').replaceAll('{count}', '${diff.inMinutes}');
    if (diff.inHours < 24) return context.tr('elapsed_hours').replaceAll('{count}', '${diff.inHours}');
    return context.tr('elapsed_days').replaceAll('{count}', '${diff.inDays}');
  }

}

class _CommentInput extends ConsumerStatefulWidget {
  const _CommentInput({required this.postId, required this.isGuest});
  final String postId;
  final bool isGuest;

  @override
  ConsumerState<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends ConsumerState<_CommentInput> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.isGuest) {
      context.showGuestUpgradeSheet();
      return;
    }
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > 500) {
      context.showSnackBar(context.tr('comment_limit_error'), isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = ref.read(authStateChangesProvider).asData?.value;
      if (user != null) {
        final repo = ref.read(postRepositoryProvider);
        await repo.addComment(
          widget.postId,
          user.uid,
          user.displayName ?? context.tr('anonymous'),
          user.photoURL,
          text,
        );
        _controller.clear();
        if (mounted) context.showSnackBar(context.tr('comment_added'));
      }
    } catch (e) {
      if (mounted) context.showSnackBar(context.tr('comment_failed'), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textDirection: TextDirection.rtl,
              maxLines: null,
              maxLength: 500,
              buildCounter: (ctx, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
              decoration: InputDecoration(
                hintText: context.tr('comment_hint'),
                hintStyle: GoogleFonts.tajawal(color: AppColors.grey500),
                border: InputBorder.none,
                isDense: true,
              ),
              style: GoogleFonts.tajawal(fontSize: 14),
            ),
          ),

          const SizedBox(width: 8),
          _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppColors.emerald),
                  onPressed: _submit,
                ),
        ],
      ),
    );
  }
}
