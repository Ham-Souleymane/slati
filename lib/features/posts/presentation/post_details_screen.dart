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
  final PostModel? post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postAsync = ref.watch(postStreamProvider(postId));

    return postAsync.when(
      loading: () {
        if (post != null) return _PostDetailsBody(post: post!);
        return Scaffold(
          backgroundColor: const Color(0xFFF0F3FF),
          appBar: _buildAppBar(context),
          body: const Center(
            child: CircularProgressIndicator(color: AppColors.emerald),
          ),
        );
      },
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFFF0F3FF),
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
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.emeraldDark),
        onPressed: () => context.pop(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────
class _PostDetailsBody extends ConsumerWidget {
  const _PostDetailsBody({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final likesCount =
        ref.watch(postLikesCountProvider(post.id)).asData?.value ?? post.likeCount;
    final commentsCount =
        ref.watch(postCommentsCountProvider(post.id)).asData?.value ?? post.commentCount;
    final isSaved =
        ref.watch(savedPostIdsProvider).asData?.value.contains(post.id) ?? false;
    final isLiked =
        ref.watch(isPostLikedProvider(post.id)).asData?.value ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F3FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.emeraldDark),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          context.tr('posts_tab'),
          style: GoogleFonts.tajawal(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: AppColors.emeraldDark,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: isSaved ? AppColors.emerald : AppColors.grey500,
            ),
            onPressed: () => _toggleSave(context, ref, isSaved, isGuest),
            tooltip: isSaved ? context.tr('saved_snack') : context.tr('save_post_snack'),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Article Card ────────────────────────────────────
                Container(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header: author + follow ──────────────────
                      _PostHeader(post: post),

                      // ── Image ────────────────────────────────────
                      if (post.photoUrl != null && post.photoUrl!.trim().isNotEmpty)
                        _PostImage(photoUrl: post.photoUrl!),

                      // ── Content ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Category badge
                            Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                _CategoryBadge(category: post.category),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Post text
                            Text(
                              post.text,
                              style: GoogleFonts.tajawal(
                                fontSize: 15,
                                height: 1.75,
                                color: AppColors.charcoal,
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                            ),
                            // Event card
                            if (post.isEvent) ...[
                              const SizedBox(height: 16),
                              _EventInfoCard(post: post),
                            ],
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),

                      // ── Metrics Row ──────────────────────────────
                      _MetricsRow(
                        likesCount: likesCount,
                        commentsCount: commentsCount,
                        post: post,
                        onViewMosque: () =>
                            context.push('/mosque/${post.mosqueId}'),
                      ),

                      // ── Action Bar ───────────────────────────────
                      _ActionBar(
                        isLiked: isLiked,
                        onLike: () => _toggleLike(context, ref, isLiked),
                        onShare: () => _share(context),
                      ),

                      // ── Comment Input ────────────────────────────
                      _CommentInputRow(postId: post.id, isGuest: isGuest),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Comments Section ─────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.tr('comments_title'),
                        style: GoogleFonts.tajawal(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.emeraldDark,
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 12),
                      _CommentsSection(postId: post.id),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
              ],
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

  Future<void> _toggleLike(
      BuildContext context, WidgetRef ref, bool isLiked) async {
    if (ref.read(isGuestProvider)) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    await ref
        .read(postRepositoryProvider)
        .toggleLikePost(uid, post.id, isLiked);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post Header (author + date + follow button)
// ─────────────────────────────────────────────────────────────────────────────
class _PostHeader extends ConsumerWidget {
  const _PostHeader({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mosquesMap = ref.watch(mosquesMapProvider);
    final mosque = mosquesMap[post.mosqueId] ??
        ref.watch(mosqueByIdProvider(post.mosqueId)).asData?.value;

    final displayName = (mosque != null && mosque.name.isNotEmpty)
        ? mosque.name
        : post.mosqueName.isNotEmpty
            ? post.mosqueName
            : 'مسجد';
    final displayPhoto = mosque?.photo ?? post.mosquePhoto;
    final displayVerified = mosque?.verified ?? post.verified;

    final isFollowing =
        ref.watch(isFollowingProvider(post.mosqueId)).asData?.value ?? false;
    final isGuest = ref.watch(isGuestProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.emeraldPale,
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.25), width: 1.2),
                image: displayPhoto != null
                    ? DecorationImage(
                        image: NetworkImage(displayPhoto), fit: BoxFit.cover)
                    : null,
              ),
              child: displayPhoto == null
                  ? const Icon(Icons.mosque_rounded,
                      color: AppColors.emerald, size: 22)
                  : null,
            ),
            const SizedBox(width: 10),
            // Name + date (aligned right next to avatar)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: GoogleFonts.tajawal(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (displayVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            color: AppColors.gold, size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDate(context, post.createdAt),
                        style: GoogleFonts.tajawal(
                            fontSize: 12, color: AppColors.grey500),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.public_rounded,
                          size: 13, color: AppColors.grey500),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Follow button
            GestureDetector(
              onTap: () => _toggleFollow(context, ref, isGuest, isFollowing),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isFollowing ? AppColors.emerald : Colors.transparent,
                  border: Border.all(
                    color: isFollowing ? AppColors.emerald : AppColors.grey300,
                    width: 1.2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFollowing ? Icons.check_rounded : Icons.add_rounded,
                      size: 15,
                      color: isFollowing ? Colors.white : AppColors.grey700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isFollowing
                          ? context.tr('post_following_btn')
                          : context.tr('post_follow_btn'),
                      style: GoogleFonts.tajawal(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isFollowing ? Colors.white : AppColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow(BuildContext context, WidgetRef ref,
      bool isGuest, bool isFollowing) async {
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
        context.showSnackBar(context
            .tr('mosque_follow_snack')
            .replaceAll('{name}', post.mosqueName));
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
// Post Image (full-width 4:5 ratio)
// ─────────────────────────────────────────────────────────────────────────────
class _PostImage extends StatelessWidget {
  const _PostImage({required this.photoUrl});
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        decoration: const BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: Color(0xFFBFC9C3), width: 0.5),
          ),
        ),
        child: Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.grey100,
            child: const Center(
              child: Icon(Icons.broken_image_rounded,
                  color: AppColors.grey300, size: 40),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Badge
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
    if (category == 'دروس' || category == 'cat_lessons') {
      catKey = 'cat_lessons';
    } else if (category == 'إعلانات' || category == 'cat_announcements') {
      catKey = 'cat_announcements';
    } else if (category == 'أنشطة' || category == 'cat_activities') {
      catKey = 'cat_activities';
    }

    final (fg, bg) =
        colors[catKey] ?? (AppColors.emerald, AppColors.emeraldPale);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        context.tr(catKey),
        style: GoogleFonts.tajawal(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metrics Row
// ─────────────────────────────────────────────────────────────────────────────
class _MetricsRow extends StatelessWidget {
  const _MetricsRow({
    required this.likesCount,
    required this.commentsCount,
    required this.post,
    required this.onViewMosque,
  });
  final int likesCount;
  final int commentsCount;
  final PostModel post;
  final VoidCallback onViewMosque;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // Like count with bubble
          if (likesCount > 0) ...[
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppColors.emeraldDark,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.thumb_up_rounded,
                    size: 10, color: Colors.white),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$likesCount',
              style:
                  GoogleFonts.tajawal(fontSize: 13, color: AppColors.grey500),
            ),
          ],
          const Spacer(),
          // Comments
          Text(
            '$commentsCount ${context.tr('comments_count').replaceAll('{count}', '').trim()}',
            style:
                GoogleFonts.tajawal(fontSize: 13, color: AppColors.grey500),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(width: 14),
          // View mosque
          GestureDetector(
            onTap: onViewMosque,
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.mosque_outlined,
                    size: 14, color: AppColors.grey500),
                const SizedBox(width: 4),
                Text(
                  context.tr('view_mosque'),
                  style: GoogleFonts.tajawal(
                      fontSize: 13, color: AppColors.grey500),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Bar (Like / Comment / Share)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isLiked,
    required this.onLike,
    required this.onShare,
  });
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(height: 0, thickness: 0.5, color: Color(0xFFDDE3F0)),
        Row(
          textDirection: TextDirection.rtl,
          children: [
            _ActionBtn(
              icon: isLiked
                  ? Icons.thumb_up_rounded
                  : Icons.thumb_up_alt_outlined,
              label: context.tr('feed_like_tooltip'),
              color: isLiked ? AppColors.emeraldDark : AppColors.grey500,
              onTap: onLike,
            ),
            _ActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: context.tr('feed_comment_tooltip'),
              color: AppColors.grey500,
              onTap: () {},
            ),
            _ActionBtn(
              icon: Icons.share_rounded,
              label: context.tr('share_post'),
              color: AppColors.grey500,
              onTap: onShare,
            ),
          ],
        ),
        const Divider(height: 0, thickness: 0.5, color: Color(0xFFDDE3F0)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.tajawal(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
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
// Comment Input Row (pill style)
// ─────────────────────────────────────────────────────────────────────────────
class _CommentInputRow extends ConsumerStatefulWidget {
  const _CommentInputRow({required this.postId, required this.isGuest});
  final String postId;
  final bool isGuest;

  @override
  ConsumerState<_CommentInputRow> createState() => _CommentInputRowState();
}

class _CommentInputRowState extends ConsumerState<_CommentInputRow> {
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
        await ref.read(postRepositoryProvider).addComment(
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
      if (mounted) {
        context.showSnackBar(context.tr('comment_failed'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          // User avatar placeholder
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.grey100,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.grey300, width: 0.8),
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.grey500, size: 18),
          ),
          const SizedBox(width: 10),
          // Pill input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  // Send icon (LTR-side left)
                  _isSubmitting
                      ? const Padding(
                          padding: EdgeInsets.all(8),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.emerald),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(Icons.send_rounded,
                              color: AppColors.emerald, size: 20),
                          onPressed: _submit,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          splashRadius: 18,
                        ),
                  // TextField
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      maxLength: 500,
                      buildCounter: (ctx,
                              {required currentLength,
                              required isFocused,
                              maxLength}) =>
                          const SizedBox.shrink(),
                      decoration: InputDecoration(
                        hintText: context.tr('comment_hint'),
                        hintStyle: GoogleFonts.tajawal(
                            color: AppColors.grey500, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 10),
                        isDense: true,
                      ),
                      style: GoogleFonts.tajawal(
                          fontSize: 13, color: AppColors.charcoal),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Info Card
// ─────────────────────────────────────────────────────────────────────────────
class _EventInfoCard extends StatelessWidget {
  const _EventInfoCard({required this.post});
  final PostModel post;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldPale,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('event_details'),
            style: GoogleFonts.tajawal(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
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
          Icon(icon, size: 15, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.tajawal(
                      fontSize: 10, color: AppColors.grey500),
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  value,
                  style: GoogleFonts.tajawal(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Comments Section
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _CommentsSection extends ConsumerWidget {
  const _CommentsSection({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(postCommentsProvider(postId));

    return commentsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppColors.emerald),
        ),
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
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                context.tr('no_comments_yet'),
                style: GoogleFonts.tajawal(
                    fontSize: 13, color: AppColors.grey500),
              ),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: comments.length,
          itemBuilder: (ctx, i) => _CommentTile(comment: comments[i]),
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Comment Tile
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});
  final CommentModel comment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
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
                    color: AppColors.emerald, size: 16)
                : null,
          ),
          const SizedBox(width: 10),
          // Bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3FF),
                borderRadius: BorderRadius.circular(14),
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
                            fontSize: 10, color: AppColors.grey500),
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
    if (diff.inMinutes < 60) {
      return context
          .tr('elapsed_minutes')
          .replaceAll('{count}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return context
          .tr('elapsed_hours')
          .replaceAll('{count}', '${diff.inHours}');
    }
    return context
        .tr('elapsed_days')
        .replaceAll('{count}', '${diff.inDays}');
  }
}

