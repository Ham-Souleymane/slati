import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/extensions.dart';
import '../../mosques/data/mosque_repository.dart';
import '../data/post_repository.dart';
import '../domain/post_model.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _seedIfNeeded();
  }

  @override
  void didUpdateWidget(FeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      _tabController.animateTo(widget.initialTabIndex.clamp(0, 1));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final savedIdsAsync = ref.watch(savedPostIdsProvider);
    final savedIds = savedIdsAsync.asData?.value ?? {};
    final followedMosquesAsync = ref.watch(followedMosquesProvider);
    final followedMosqueIds =
        (followedMosquesAsync.asData?.value ?? []).map((m) => m.id).toSet();
    final postsAsync = ref.watch(postsStreamProvider(null));

    return Scaffold(
      backgroundColor: AppColors.cream,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: AppColors.emeraldDark,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          context.tr('feed_title'),
          style: GoogleFonts.tajawal(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: AppColors.gold,
            unselectedLabelColor: Colors.white60,
            labelStyle: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            unselectedLabelStyle: GoogleFonts.tajawal(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            tabs: [
              Tab(text: context.tr('tab_all')),
              Tab(text: context.tr('tab_followed')),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: For You (FYP) ────────────────────────────────
          _FypTab(
            savedIds: savedIds,
            isGuest: isGuest,
            followedMosqueIds: followedMosqueIds,
            onGoToFollowedPosts: () => _tabController.animateTo(1),
            onSave: _toggleSave,
          ),

          // ── Tab 2: Followed Mosques & Imams ──────────────────────
          _FollowedTab(
            postsAsync: postsAsync,
            savedIds: savedIds,
            isGuest: isGuest,
            followedMosqueIds: followedMosqueIds,
            onSave: _toggleSave,
          ),
        ],
      ),
    );
  }

  Future<void> _toggleSave(PostModel post, bool isSaved, bool isGuest) async {
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: For You
// ─────────────────────────────────────────────────────────────────────────────

class _FypTab extends ConsumerWidget {
  const _FypTab({
    required this.savedIds,
    required this.isGuest,
    required this.followedMosqueIds,
    required this.onGoToFollowedPosts,
    required this.onSave,
  });

  final Set<String> savedIds;
  final bool isGuest;
  final Set<String> followedMosqueIds;
  final VoidCallback onGoToFollowedPosts;
  final Future<void> Function(PostModel, bool, bool) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paginatedState = ref.watch(paginatedPostsNotifierProvider);

    return Column(
      children: [
        // ── Followed Posts Navigation Banner Button ───────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: GestureDetector(
            onTap: onGoToFollowedPosts,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.dynamic_feed_rounded,
                      color: AppColors.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'منشورات المساجد المتابعة',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.charcoal,
                          ),
                        ),
                        Text(
                          'عرض منشورات وأنشطة المساجد التي تتابعها فقط',
                          style: GoogleFonts.tajawal(
                            fontSize: 11,
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.grey300,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              if (paginatedState.isLoading && paginatedState.posts.isEmpty) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.emerald),
                );
              }
              if (paginatedState.error != null && paginatedState.posts.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.tr('feed_load_posts_failed'),
                            style: GoogleFonts.tajawal(
                                color: AppColors.grey700,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(paginatedState.error.toString(),
                            style: GoogleFonts.tajawal(
                                color: AppColors.grey500, fontSize: 11),
                            textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                );
              }

              final posts = paginatedState.posts;
              if (posts.isEmpty) {
                return _EmptyPosts(message: context.tr('feed_empty_posts'));
              }

              return _PostsList(
                posts: posts,
                savedIds: savedIds,
                isGuest: isGuest,
                followedMosqueIds: followedMosqueIds,
                isLoadingMore: paginatedState.isLoadingMore,
                onLoadMore: () => ref.read(paginatedPostsNotifierProvider.notifier).fetchNextPage(),
                onRefresh: () async => ref.read(paginatedPostsNotifierProvider.notifier).refresh(),
                onSave: onSave,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Followed Mosques
// ─────────────────────────────────────────────────────────────────────────────

class _FollowedTab extends ConsumerWidget {
  const _FollowedTab({
    required this.postsAsync,
    required this.savedIds,
    required this.isGuest,
    required this.followedMosqueIds,
    required this.onSave,
  });

  final AsyncValue<List<PostModel>> postsAsync;
  final Set<String> savedIds;
  final bool isGuest;
  final Set<String> followedMosqueIds;
  final Future<void> Function(PostModel, bool, bool) onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isGuest) return _FollowedGuestState();

    final followedMosquesAsync = ref.watch(followedMosquesProvider);
    final followedImamsAsync = ref.watch(followedImamsProvider);

    // If followed lists are still loading, show a spinner to avoid empty-state flickers
    if (followedMosquesAsync.isLoading || followedImamsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.emerald));
    }

    final followedMosqueIds =
        (followedMosquesAsync.asData?.value ?? []).map((m) => m.id).toSet();
    final followedImamIds = followedImamsAsync.asData?.value ?? [];

    return postsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      error: (e, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.tr('feed_load_posts_failed'),
                  style: GoogleFonts.tajawal(color: AppColors.grey700, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(e.toString(),
                  style: GoogleFonts.tajawal(color: AppColors.grey500, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      data: (allPosts) {
        // Show empty state only when neither mosques nor imams are followed
        final hasFollowed =
            followedMosqueIds.isNotEmpty || followedImamIds.isNotEmpty;
        if (!hasFollowed) {
          return _FollowedEmptyState(
              onDiscover: () => context.go('/nearby-mosques'));
        }

        // Merge posts from followed mosques AND followed imams
        final posts = allPosts.where((p) {
          final fromMosque = followedMosqueIds.contains(p.mosqueId);
          final fromImam =
              p.imamId != null && followedImamIds.contains(p.imamId);
          return fromMosque || fromImam;
        }).toList()
          // Sort newest first (already ordered, but merge may disturb order)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (posts.isEmpty) {
          return _EmptyPosts(
              message: context.tr('no_posts_followed'));
        }
        return _PostsList(
          posts: posts,
          savedIds: savedIds,
          isGuest: isGuest,
          followedMosqueIds: followedMosqueIds,
          onSave: onSave,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared posts list
// ─────────────────────────────────────────────────────────────────────────────

class _PostsList extends ConsumerWidget {
  const _PostsList({
    required this.posts,
    required this.savedIds,
    required this.isGuest,
    required this.followedMosqueIds,
    required this.onSave,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.onRefresh,
  });

  final List<PostModel> posts;
  final Set<String> savedIds;
  final bool isGuest;
  final Set<String> followedMosqueIds;
  final Future<void> Function(PostModel, bool, bool) onSave;
  final VoidCallback? onLoadMore;
  final bool isLoadingMore;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCount = posts.length + (isLoadingMore ? 1 : 0);

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 300) {
          onLoadMore?.call();
        }
        return false;
      },
      child: RefreshIndicator(
        color: AppColors.emerald,
        onRefresh: () async {
          if (onRefresh != null) {
            await onRefresh!();
          } else {
            ref.invalidate(postsStreamProvider);
          }
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 108),
          itemCount: totalCount,
          addAutomaticKeepAlives: false,
          itemBuilder: (ctx, i) {
            if (i >= posts.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
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

            final post = posts[i];
            final isSaved = savedIds.contains(post.id);
            final isFollowing = followedMosqueIds.contains(post.mosqueId);
            return RepaintBoundary(
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                isSaved: isSaved,
                isGuest: isGuest,
                isFollowing: isFollowing,
                onSave: () => onSave(post, isSaved, isGuest),
                onTap: () => context.push('/post/${post.id}', extra: post),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty states
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPosts extends StatelessWidget {
  const _EmptyPosts({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.article_outlined, size: 56, color: AppColors.grey300),
          const SizedBox(height: 12),
          Text(message,
              style: GoogleFonts.tajawal(fontSize: 15, color: AppColors.grey500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _FollowedEmptyState extends StatelessWidget {
  const _FollowedEmptyState({required this.onDiscover});
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
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                  color: AppColors.emeraldPale, shape: BoxShape.circle),
              child: const Center(
                child: Icon(Icons.mosque_rounded,
                    size: 54, color: AppColors.emerald),
              ),
            ),
            const SizedBox(height: 24),
            Text(context.tr('feed_no_followed_title'),
                style: GoogleFonts.tajawal(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal)),
            const SizedBox(height: 10),
            Text(
              context.tr('feed_no_followed_desc'),
              style: GoogleFonts.tajawal(
                  fontSize: 14, color: AppColors.grey500, height: 1.7),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: onDiscover,
              icon: const Icon(Icons.explore_rounded),
              label: Text(context.tr('explore_nearby'),
                  style: GoogleFonts.tajawal(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowedGuestState extends StatelessWidget {
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
                  color: AppColors.surfaceVariant, shape: BoxShape.circle),
              child: const Center(
                child: Icon(Icons.lock_outline_rounded,
                    size: 48, color: AppColors.grey500),
              ),
            ),
            const SizedBox(height: 20),
            Text(context.tr('member_feature_title'),
                style: GoogleFonts.tajawal(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal)),
            const SizedBox(height: 10),
            Text(
              context.tr('feed_guest_desc'),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(context.tr('create_account'),
                  style: GoogleFonts.tajawal(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text(context.tr('login_btn'),
                  style: GoogleFonts.tajawal(color: AppColors.grey500)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Post Card Widget
// ─────────────────────────────────────────────────────────────────────────────

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.isSaved,
    required this.isGuest,
    required this.isFollowing,
    required this.onSave,
    required this.onTap,
  });

  final PostModel post;
  final bool isSaved;
  final bool isGuest;
  final bool isFollowing;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final elapsed = _elapsed(context, post.createdAt);
    final isLikedAsync = ref.watch(isPostLikedProvider(post.id));
    final isLiked = isLikedAsync.asData?.value ?? false;
    final likesCount = post.likeCount;
    final commentsCount = post.commentCount;

    final mosquesMap = ref.watch(mosquesMapProvider);
    final mosque = mosquesMap[post.mosqueId];
    final fallbackMosque = mosque == null && post.mosqueId.isNotEmpty
        ? ref.watch(mosqueByIdProvider(post.mosqueId)).asData?.value
        : null;
    final effectiveMosque = mosque ?? fallbackMosque;

    final displayName = (effectiveMosque != null && effectiveMosque.name.isNotEmpty)
        ? effectiveMosque.name
        : (post.mosqueName.isNotEmpty && post.mosqueName != 'مسجد')
            ? post.mosqueName
            : (post.mosqueName.isNotEmpty ? post.mosqueName : 'مسجد');
    final displayPhoto = effectiveMosque?.photo ?? post.mosquePhoto;
    final displayVerified = effectiveMosque?.verified ?? post.verified;
    final liveImamId = effectiveMosque?.imamId ?? post.imamId;

    final imamNameAsync = liveImamId != null
        ? ref.watch(imamNameProvider(liveImamId))
        : const AsyncValue<String?>.data(null);
    final imamName = imamNameAsync.asData?.value;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPale,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.3)),
                      image: displayPhoto != null
                          ? DecorationImage(
                              image: NetworkImage(displayPhoto),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: displayPhoto == null
                        ? const Icon(Icons.mosque_rounded,
                            color: AppColors.emerald, size: 22)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              displayName,
                              style: GoogleFonts.tajawal(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emeraldDark,
                              ),
                            ),
                            if (displayVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded,
                                  color: AppColors.gold, size: 14),
                            ],
                          ],
                        ),
                        if (imamName != null && imamName.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_rounded,
                                  size: 12, color: AppColors.gold),
                              const SizedBox(width: 4),
                              Text(
                                imamName,
                                style: GoogleFonts.tajawal(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '$elapsed · ${_categoryLabel(context, post.category)}',
                          style: GoogleFonts.tajawal(
                              fontSize: 11, color: AppColors.grey500),
                        ),
                      ],
                    ),
                  ),
                  // Follow button
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _toggleFollow(context, ref, isFollowing),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                            size: 13,
                            color: isFollowing
                                ? Colors.white
                                : AppColors.grey500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isFollowing ? context.tr('following') : context.tr('follow'),
                            style: GoogleFonts.tajawal(
                              fontSize: 11,
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
            ),

            if (post.photoUrl != null && post.photoUrl!.trim().isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.zero,
                child: Image.network(
                  post.photoUrl!,
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                  cacheHeight: 500,
                  cacheWidth: 800,
                  frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                    if (wasSynchronouslyLoaded) return child;
                    return AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      child: child,
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: AppColors.grey100,
                      child: const Center(
                        child: Icon(Icons.broken_image_rounded,
                            color: AppColors.grey300, size: 40),
                      ),
                    );
                  },
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const maxLines = 3;
                  final textStyle = GoogleFonts.tajawal(
                    fontSize: 14,
                    color: AppColors.grey700,
                    height: 1.6,
                  );
                  final tp = TextPainter(
                    text: TextSpan(text: post.text, style: textStyle),
                    maxLines: maxLines,
                    textDirection: TextDirection.rtl,
                  )..layout(maxWidth: constraints.maxWidth);
                  final isOverflowing = tp.didExceedMaxLines;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.text,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                      if (isOverflowing) ...[
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: onTap,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.tr('read_more'),
                                style: GoogleFonts.tajawal(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.emerald,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 11,
                                color: AppColors.emerald,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            if (post.isEvent)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.goldPale,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_rounded,
                          size: 14, color: AppColors.gold),
                      const SizedBox(width: 5),
                      Text(
                        [post.eventDate, post.eventTime]
                            .whereType<String>()
                            .join(' · '),
                        style: GoogleFonts.tajawal(
                          fontSize: 11,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isLiked ? Colors.red : AppColors.grey500,
                    ),
                    onPressed: () => _toggleLike(context, ref),
                    tooltip: context.tr('feed_like_tooltip'),
                  ),
                  Text('$likesCount',
                      style: GoogleFonts.tajawal(
                          fontSize: 13,
                          color: AppColors.grey700,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 14),
                  const Icon(Icons.chat_bubble_outline_rounded,
                      color: AppColors.grey500, size: 20),
                  const SizedBox(width: 4),
                  Text('$commentsCount',
                      style: GoogleFonts.tajawal(
                          fontSize: 13,
                          color: AppColors.grey700,
                          fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isSaved ? AppColors.emerald : AppColors.grey500,
                    ),
                    onPressed: onSave,
                    tooltip: isSaved ? context.tr('feed_unsave_tooltip') : context.tr('feed_save_tooltip'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFollow(
      BuildContext context, WidgetRef ref, bool isFollowing) async {
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
      final mosque = ref.read(mosquesMapProvider)[post.mosqueId] ??
          ref.read(mosqueByIdProvider(post.mosqueId)).asData?.value;
      if (mosque != null) {
        await mosqueRepo.followMosque(uid, mosque);
      } else {
        await mosqueRepo.followMosqueById(uid, post.mosqueId);
      }
      if (context.mounted) {
        final targetName = mosque?.name ??
            (post.mosqueName.isNotEmpty ? post.mosqueName : 'المسجد');
        context.showSnackBar(context.tr('followed_mosque_success', args: {'{name}': targetName}));
      }
    }
  }

  Future<void> _toggleLike(BuildContext context, WidgetRef ref) async {
    if (isGuest) {
      context.showGuestUpgradeSheet();
      return;
    }
    final uid = ref.read(authStateChangesProvider).asData?.value?.uid;
    if (uid == null) return;
    final isLikedAsync = ref.read(isPostLikedProvider(post.id));
    final currentlyLiked = isLikedAsync.asData?.value ?? false;
    await ref
        .read(postRepositoryProvider)
        .toggleLikePost(uid, post.id, currentlyLiked);
  }

  String _elapsed(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return context.tr('feed_elapsed_minute', args: {'{count}': '${diff.inMinutes}'});
    if (diff.inHours < 24) return context.tr('feed_elapsed_hour', args: {'{count}': '${diff.inHours}'});
    return context.tr('feed_elapsed_day', args: {'{count}': '${diff.inDays}'});
  }

  String _categoryLabel(BuildContext context, String cat) {
    if (cat == 'دروس') return '📖 ' + context.tr('cat_lessons');
    if (cat == 'إعلانات') return '📢 ' + context.tr('cat_announcements');
    if (cat == 'أنشطة') return '🎯 ' + context.tr('cat_activities');
    return cat;
  }
}