import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/post_model.dart';
import '../domain/comment_model.dart';

class PostRepository {
  PostRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection('posts');

  // ── Feed reads ───────────────────────────────────────────────

  /// Watches all posts in descending order of creation.
  /// Optionally filtered by category.
  Stream<List<PostModel>> watchPosts({String? category}) {
    if (category != null && category != 'الكل' && category != 'قريب مني') {
      return _posts
          .where('category', isEqualTo: category)
          .snapshots()
          .map((snap) {
        final list =
            snap.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    }
    return _posts.orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    });
  }

  // ── Saved posts subcollection ─────────────────────────────────

  /// Watches the set of saved post IDs for a given user.
  Stream<Set<String>> watchSavedPostIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toSet());
  }

  /// Watches the fully hydrated list of saved posts.
  Stream<List<PostModel>> watchSavedPosts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    });
  }

  /// Saves a post to the user's `savedPosts` subcollection.
  /// Stores a copy of the post for instant offline-capable viewing.
  Future<void> savePost(String userId, PostModel post) async {
    final docRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(post.id);

    final data = post.toFirestore();
    data['savedAt'] = FieldValue.serverTimestamp();

    await docRef.set(data);
  }

  /// Removes a post from the user's `savedPosts` subcollection.
  Future<void> unsavePost(String userId, String postId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('savedPosts')
        .doc(postId)
        .delete();
  }

  // ── Likes & Comments ──────────────────────────────────────────

  /// Toggles the like status of a post by the current user.
  /// Writes or deletes posts/{postId}/likes/{userId}.
  Future<void> toggleLikePost(String userId, String postId, bool currentlyLiked) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);

    if (currentlyLiked) {
      await likeRef.delete();
      try {
        await postRef.update({'likeCount': FieldValue.increment(-1)});
      } catch (e) {
        debugPrint('[PostRepository] Failed to decrement likeCount: $e');
      }
    } else {
      await likeRef.set({
        'likedAt': FieldValue.serverTimestamp(),
      });
      try {
        await postRef.update({'likeCount': FieldValue.increment(1)});
      } catch (e) {
        debugPrint('[PostRepository] Failed to increment likeCount: $e');
      }
    }
  }

  /// Streams whether the user liked the post.
  Stream<bool> watchIsPostLiked(String userId, String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Streams comments for a post ordered by createdAt ascending.
  Stream<List<CommentModel>> watchComments(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => CommentModel.fromFirestore(doc)).toList());
  }

  /// Adds a comment under posts/{postId}/comments/{commentId}.
  Future<void> addComment(
    String postId,
    String userId,
    String userName,
    String? userPhotoUrl,
    String text,
  ) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final commentsRef = postRef.collection('comments');
    
    await commentsRef.add({
      'userId': userId,
      'userName': userName,
      if (userPhotoUrl != null) 'userPhotoUrl': userPhotoUrl,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await postRef.update({'commentCount': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('[PostRepository] Failed to increment commentCount: $e');
    }
  }

  /// Streams the actual number of likes in the subcollection.
  Stream<int> watchLikeCount(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Streams the actual number of comments in the subcollection.
  Stream<int> watchCommentCount(String postId) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Watches a single post by ID.
  Stream<PostModel> watchPost(String postId) {
    return _posts.doc(postId).snapshots().map((doc) => PostModel.fromFirestore(doc));
  }

  /// Watches the Imam's name. First checks mock names, then looks up users/{imamId}.
  Stream<String?> watchImamName(String imamId) {
    const mockNames = {
      'imam_1': 'الشيخ د. محمد العتيبي',
      'imam_2': 'الشيخ عبد الرحمن السديس',
      'imam_3': 'الشيخ علي الحذيفي',
      'imam_4': 'الشيخ ماهر المعيقلي',
    };
    if (mockNames.containsKey(imamId)) {
      return Stream.value(mockNames[imamId]);
    }
    return _firestore
        .collection('users')
        .doc(imamId)
        .snapshots()
        .map((snap) => snap.data()?['fullName'] as String?);
  }

  // ── Mock seeding ──────────────────────────────────────────────

  /// Seeds community posts near the user coordinates if the collection is empty.
  Future<void> seedMockPostsIfEmpty(double lat, double lng) async {
    final snap = await _posts.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    final now = DateTime.now();

    final mockData = [
      {
        'mosqueId': 'mosque_1',
        'imamId': 'imam_1',
        'mosqueName': 'مسجد الروضة الكبير',
        'verified': true,
        'category': 'دروس',
        'text': 'نهنئكم بحلول العام الهجري الجديد، وندعوكم لحضور الدرس الأسبوعي بعنوان "سيرة المصطفى ﷺ وعبر الهجرة" بعد صلاة المغرب لفضيلة الشيخ د. محمد العتيبي.',
        'hoursOffset': 2,
        'lat': lat + 0.005,
        'lng': lng + 0.005,
        'eventDate': 'الخميس القادم',
        'eventTime': 'بعد المغرب مباشرة',
        'eventLocation': 'قاعة المحاضرات الرئيسية',
      },
      {
        'mosqueId': 'mosque_2',
        'imamId': 'imam_2',
        'mosqueName': 'جامع التقوى',
        'verified': true,
        'category': 'أنشطة',
        'text': 'يسر إدارة المسجد الإعلان عن بدء التسجيل في دورة التجويد المكثفة لحفظ ومراجعة جزء عمّ للناشئين. تبدأ الحلقات يوم السبت القادم بعد صلاة العصر.',
        'hoursOffset': 5,
        'lat': lat - 0.008,
        'lng': lng + 0.006,
        'eventDate': 'السبت القادم',
        'eventTime': '4:30 مساءً',
        'eventLocation': 'حلقات التحفيظ بالمسجد',
      },
      {
        'mosqueId': 'mosque_3',
        'imamId': 'imam_3',
        'mosqueName': 'مسجد قباء الجديد',
        'verified': true,
        'category': 'إعلانات',
        'text': 'تقام صلاة الاستسقاء يوم غدٍ الخميس بعد شروق الشمس بربع ساعة في مصلى العيد المفتوح خلف المسجد. نسأل الله أن يغيث البلاد والعباد.',
        'hoursOffset': 10,
        'lat': lat + 0.003,
        'lng': lng - 0.007,
        'eventDate': 'غداً الخميس',
        'eventTime': '6:15 صباحاً',
        'eventLocation': 'مصلى العيد الخلفي',
      },
      {
        'mosqueId': 'mosque_4',
        'imamId': 'imam_4',
        'mosqueName': 'جامع السلام',
        'verified': true,
        'category': 'دروس',
        'text': 'تذكير بالدرس الشهري في فقه العبادات (أحكام الطهارة والصلاة) يلقيه إمام المسجد الشيخ عبدالرحمن الرميح اليوم بعد صلاة العشاء.',
        'hoursOffset': 24,
        'lat': lat - 0.004,
        'lng': lng - 0.003,
        'eventDate': 'اليوم',
        'eventTime': 'بعد العشاء',
        'eventLocation': 'محراب المسجد',
      },
    ];

    for (var i = 0; i < mockData.length; i++) {
      final docRef = _posts.doc();
      final item = mockData[i];
      final post = PostModel(
        id: docRef.id,
        mosqueId: item['mosqueId'] as String,
        imamId: item['imamId'] as String?,
        mosqueName: item['mosqueName'] as String,
        verified: item['verified'] as bool,
        category: item['category'] as String,
        text: item['text'] as String,
        createdAt: now.subtract(Duration(hours: item['hoursOffset'] as int)),
        eventDate: item['eventDate'] as String?,
        eventTime: item['eventTime'] as String?,
        eventLocation: item['eventLocation'] as String?,
        latitude: item['lat'] as double?,
        longitude: item['lng'] as double?,
      );
      batch.set(docRef, post.toFirestore());
    }

    await batch.commit();
    debugPrint('[PostRepository] Seeded mock community posts');
  }

  /// Fetches a paginated batch of posts using Firestore cursors.
  Future<PaginatedPostsResult> fetchPostsPaginated({
    String? category,
    DocumentSnapshot<Map<String, dynamic>>? startAfterDoc,
    int pageSize = 15,
  }) async {
    Query<Map<String, dynamic>> query = _posts.orderBy('createdAt', descending: true);
    if (category != null &&
        category != 'all' &&
        category != 'الكل' &&
        category != 'nearby' &&
        category != 'قريب مني') {
      final dbCat = {
        'lessons': 'دروس',
        'announcements': 'إعلانات',
        'activities': 'أنشطة',
      }[category] ?? category;
      query = query.where('category', isEqualTo: dbCat);
    }
    if (startAfterDoc != null) {
      query = query.startAfterDocument(startAfterDoc);
    }
    query = query.limit(pageSize);

    final snap = await query.get();
    final posts = snap.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
    final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
    final hasMore = snap.docs.length >= pageSize;

    return PaginatedPostsResult(
      posts: posts,
      lastDocument: lastDoc,
      hasMore: hasMore,
    );
  }

  /// Watches all posts published by a specific mosque.
  Stream<List<PostModel>> watchMosquePosts(String mosqueId) {
    return _posts
        .where('mosqueId', isEqualTo: mosqueId)
        .snapshots()
        .map((snap) {
      final list =
          snap.docs.map((doc) => PostModel.fromFirestore(doc)).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}

// ── Paginated Models & Notifier ───────────────────────────────────────────────

class PaginatedPostsResult {
  final List<PostModel> posts;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const PaginatedPostsResult({
    required this.posts,
    this.lastDocument,
    required this.hasMore,
  });
}

class PaginatedPostsState {
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  const PaginatedPostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.lastDocument,
  });

  PaginatedPostsState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
  }) {
    return PaginatedPostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }
}

class PaginatedPostsNotifier extends Notifier<PaginatedPostsState> {
  String? _category;

  @override
  PaginatedPostsState build() {
    Future.microtask(() => fetchInitial());
    return const PaginatedPostsState(isLoading: true);
  }

  void setCategory(String? category) {
    if (_category != category) {
      _category = category;
      fetchInitial();
    }
  }

  Future<void> fetchInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(postRepositoryProvider);
      final result = await repo.fetchPostsPaginated(category: _category);
      state = PaginatedPostsState(
        posts: result.posts,
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
        isLoading: false,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> fetchNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final repo = ref.read(postRepositoryProvider);
      final result = await repo.fetchPostsPaginated(
        category: _category,
        startAfterDoc: state.lastDocument,
      );
      state = state.copyWith(
        posts: [...state.posts, ...result.posts],
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  Future<void> refresh() async {
    return fetchInitial();
  }
}

final paginatedPostsNotifierProvider =
    NotifierProvider<PaginatedPostsNotifier, PaginatedPostsState>(
  PaginatedPostsNotifier.new,
);

// ── Providers ─────────────────────────────────────────────────────────────────

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(firestoreProvider));
});

/// Watches the live stream of posts, optionally filtered by category.
final postsStreamProvider =
    StreamProvider.family<List<PostModel>, String?>((ref, category) {
  return ref.watch(postRepositoryProvider).watchPosts(category: category);
});

/// Watches saved post IDs for the currently logged-in user.
final savedPostIdsProvider = StreamProvider<Set<String>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value(const {});
  return ref.watch(postRepositoryProvider).watchSavedPostIds(user.uid);
});

/// Watches all saved posts for the currently logged-in user.
final savedPostsStreamProvider = StreamProvider<List<PostModel>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value(const []);
  return ref.watch(postRepositoryProvider).watchSavedPosts(user.uid);
});

/// Streams whether the current user liked the post.
final isPostLikedProvider =
    StreamProvider.family<bool, String>((ref, postId) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value(false);
  return ref.watch(postRepositoryProvider).watchIsPostLiked(user.uid, postId);
});

/// Streams all comments for a given post.
final postCommentsProvider =
    StreamProvider.family<List<CommentModel>, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchComments(postId);
});

/// Streams a single post by ID.
final postStreamProvider =
    StreamProvider.family<PostModel, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchPost(postId);
});

/// Streams the actual number of likes in the subcollection.
final postLikesCountProvider =
    StreamProvider.family<int, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchLikeCount(postId);
});

/// Streams the actual number of comments in the subcollection.
final postCommentsCountProvider =
    StreamProvider.family<int, String>((ref, postId) {
  return ref.watch(postRepositoryProvider).watchCommentCount(postId);
});

/// Streams the Imam's name from their user ID.
final imamNameProvider =
    StreamProvider.family<String?, String>((ref, imamId) {
  return ref.watch(postRepositoryProvider).watchImamName(imamId);
});

/// Streams all posts published by a specific mosque.
final mosquePostsStreamProvider =
    StreamProvider.family<List<PostModel>, String>((ref, mosqueId) {
  return ref.watch(postRepositoryProvider).watchMosquePosts(mosqueId);
});
