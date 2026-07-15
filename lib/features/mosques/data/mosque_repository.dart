import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/mosque_model.dart';
import '../domain/mosque_prayer_times_model.dart';

class MosqueRepository {
  MosqueRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _mosques =>
      _firestore.collection('mosques');

  // ── Mosque reads ──────────────────────────────────────────────

  /// Watch all mosques (read-only).
  Stream<List<MosqueModel>> watchAllMosques() {
    return _mosques.snapshots().map(
          (snap) => snap.docs.map(MosqueModel.fromFirestore).toList(),
        );
  }

  /// Fetch all mosques once.
  Future<List<MosqueModel>> getAllMosques() async {
    final snap = await _mosques.get();
    return snap.docs.map(MosqueModel.fromFirestore).toList();
  }

  /// Watch a single mosque by ID.
  Stream<MosqueModel?> watchMosque(String mosqueId) {
    return _mosques.doc(mosqueId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return MosqueModel.fromFirestore(doc);
    });
  }

  /// Fetch a single mosque by ID.
  Future<MosqueModel?> getOneMosque(String mosqueId) async {
    final doc = await _mosques.doc(mosqueId).get();
    if (!doc.exists) return null;
    return MosqueModel.fromFirestore(doc);
  }

  // ── Prayer Times subcollection ────────────────────────────────

  /// Watches `mosques/{mosqueId}/prayerTimes/{date}` for live updates.
  /// [date] is 'yyyy-MM-dd'. Emits null when no Firestore document exists.
  Stream<MosquePrayerTimes?> watchMosquePrayerTimes(
    String mosqueId,
    String date,
  ) {
    return _mosques
        .doc(mosqueId)
        .collection('prayerTimes')
        .doc(date)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      return MosquePrayerTimes.fromFirestore(snap, mosqueId);
    });
  }

  /// One-shot fetch of mosque prayer times for a given date.
  Future<MosquePrayerTimes?> getMosquePrayerTimes(
    String mosqueId,
    String date,
  ) async {
    final doc = await _mosques
        .doc(mosqueId)
        .collection('prayerTimes')
        .doc(date)
        .get();
    if (!doc.exists) return null;
    return MosquePrayerTimes.fromFirestore(doc, mosqueId);
  }

  // ── Mock seeding ──────────────────────────────────────────────

  /// Seeds 4 mock mosques near [lat]/[lng] if the collection is empty.
  Future<void> seedMockMosquesIfEmpty(double lat, double lng) async {
    final snap = await _mosques.limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _firestore.batch();
    final mockData = [
      {
        'id': 'mosque_1',
        'name': 'مسجد الروضة الكبير',
        'address': 'حي الروضة، الشارع العام',
        'lat': lat + 0.005,
        'lng': lng + 0.005,
        'capacity': 1200,
        'contactPhone': '+966500000001',
        'verified': true,
        'imamId': 'imam_1',
      },
      {
        'id': 'mosque_2',
        'name': 'جامع التقوى',
        'address': 'حي الياسمين، طريق الملك عبدالعزيز',
        'lat': lat - 0.008,
        'lng': lng + 0.006,
        'capacity': 800,
        'contactPhone': '+966500000002',
        'verified': true,
        'imamId': 'imam_2',
      },
      {
        'id': 'mosque_3',
        'name': 'مسجد قباء الجديد',
        'address': 'المنطقة المركزية',
        'lat': lat + 0.003,
        'lng': lng - 0.007,
        'capacity': 1500,
        'contactPhone': '+966500000003',
        'verified': true,
        'imamId': 'imam_3',
      },
      {
        'id': 'mosque_4',
        'name': 'جامع السلام',
        'address': 'حي السلام، الشارع التجاري',
        'lat': lat - 0.004,
        'lng': lng - 0.003,
        'capacity': 600,
        'contactPhone': '+966500000004',
        'verified': true,
        'imamId': 'imam_4',
      },
    ];

    for (final item in mockData) {
      final docRef = _mosques.doc(item['id'] as String);
      final mosque = MosqueModel(
        id: docRef.id,
        name: item['name'] as String,
        country: 'المملكة العربية السعودية',
        city: 'المدينة',
        address: item['address'] as String,
        geopoint: GeoPoint(item['lat'] as double, item['lng'] as double),
        verified: item['verified'] as bool,
        capacity: item['capacity'] as int,
        contactPhone: item['contactPhone'] as String,
        imamId: item['imamId'] as String?,
        createdAt: DateTime.now(),
      );
      batch.set(docRef, mosque.toFirestore());
    }

    await batch.commit();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final mosqueRepositoryProvider = Provider<MosqueRepository>((ref) {
  return MosqueRepository(ref.watch(firestoreProvider));
});

/// Stream of all mosques from Firestore.
final mosquesStreamProvider = StreamProvider<List<MosqueModel>>((ref) {
  return ref.watch(mosqueRepositoryProvider).watchAllMosques();
});

/// Stream of a single mosque by ID.
final mosqueProvider =
    StreamProvider.family<MosqueModel?, String>((ref, mosqueId) {
  return ref.watch(mosqueRepositoryProvider).watchMosque(mosqueId);
});

/// Today's date as 'yyyy-MM-dd'.
String todayDateString() {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Stream of a mosque's official prayer times for today.
final mosqueTodayPrayerTimesProvider =
    StreamProvider.family<MosquePrayerTimes?, String>((ref, mosqueId) {
  return ref
      .watch(mosqueRepositoryProvider)
      .watchMosquePrayerTimes(mosqueId, todayDateString());
});

// ── Extensions: follow/save mosque ────────────────────────────────────────────

extension FollowMosqueExtension on MosqueRepository {
  CollectionReference<Map<String, dynamic>> _followedRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('followedMosques');

  /// Writes a snapshot of [mosque] under `users/{userId}/followedMosques/{mosqueId}`
  /// and a follower entry under `mosques/{mosqueId}/followers/{userId}` in a batch.
  Future<void> followMosque(String userId, MosqueModel mosque) async {
    final batch = _firestore.batch();
    
    final userFollowRef = _followedRef(userId).doc(mosque.id);
    final mosqueFollowerRef = _firestore
        .collection('mosques')
        .doc(mosque.id)
        .collection('followers')
        .doc(userId);

    batch.set(userFollowRef, {
      'name': mosque.name,
      'address': mosque.address,
      'verified': mosque.verified,
      if (mosque.photo != null) 'photo': mosque.photo,
      'latitude': mosque.geopoint.latitude,
      'longitude': mosque.geopoint.longitude,
      'followedAt': FieldValue.serverTimestamp(),
    });

    batch.set(mosqueFollowerRef, {
      'userId': userId,
      'followedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Deletes `users/{userId}/followedMosques/{mosqueId}` and
  /// `mosques/{mosqueId}/followers/{userId}` in a batch.
  Future<void> unfollowMosque(String userId, String mosqueId) async {
    final batch = _firestore.batch();

    final userFollowRef = _followedRef(userId).doc(mosqueId);
    final mosqueFollowerRef = _firestore
        .collection('mosques')
        .doc(mosqueId)
        .collection('followers')
        .doc(userId);

    batch.delete(userFollowRef);
    batch.delete(mosqueFollowerRef);

    await batch.commit();
  }

  /// Follows a mosque by ID only — fetches the mosque document first,
  /// then delegates to [followMosque]. Used when only the mosqueId is known.
  Future<void> followMosqueById(String userId, String mosqueId) async {
    final doc = await _firestore.collection('mosques').doc(mosqueId).get();
    if (!doc.exists) return;
    final mosque = MosqueModel.fromFirestore(doc);
    await followMosque(userId, mosque);
  }

  /// Streams all followed mosques for a user as full [MosqueModel] objects

  /// (reconstructed from stored snapshot data).
  Stream<List<MosqueModel>> watchFollowedMosques(String userId) {
    return _followedRef(userId)
        .orderBy('followedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = doc.data();
              return MosqueModel(
                id: doc.id,
                name: d['name'] as String? ?? '',
                country: '',
                city: '',
                address: d['address'] as String? ?? '',
                geopoint: GeoPoint(
                  (d['latitude'] as num?)?.toDouble() ?? 0,
                  (d['longitude'] as num?)?.toDouble() ?? 0,
                ),
                photo: d['photo'] as String?,
                verified: d['verified'] as bool? ?? false,
              );
            }).toList());
  }

  /// Streams a bool indicating whether [userId] is following [mosqueId].
  Stream<bool> watchIsFollowing(String userId, String mosqueId) {
    return _followedRef(userId)
        .doc(mosqueId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Follow an imam. Writes to both imams/{imamId}/followers/{userId}
  /// and users/{userId}/followedImams/{imamId}.
  Future<void> followImam(String userId, String imamId) async {
    final batch = _firestore.batch();
    
    final imamFollowerRef = _firestore
        .collection('imams')
        .doc(imamId)
        .collection('followers')
        .doc(userId);
    
    final userImamRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('followedImams')
        .doc(imamId);
        
    batch.set(imamFollowerRef, {
      'userId': userId,
      'followedAt': FieldValue.serverTimestamp(),
    });
    
    batch.set(userImamRef, {
      'imamId': imamId,
      'followedAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();
  }

  /// Unfollow an imam. Deletes from both collections.
  Future<void> unfollowImam(String userId, String imamId) async {
    final batch = _firestore.batch();
    
    final imamFollowerRef = _firestore
        .collection('imams')
        .doc(imamId)
        .collection('followers')
        .doc(userId);
    
    final userImamRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('followedImams')
        .doc(imamId);
        
    batch.delete(imamFollowerRef);
    batch.delete(userImamRef);
    
    await batch.commit();
  }

  /// Watches whether the user is following a specific imam.
  Stream<bool> watchIsFollowingImam(String userId, String imamId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followedImams')
        .doc(imamId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// Watches the list of followed imam IDs for a given user.
  Stream<List<String>> watchFollowedImamIds(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('followedImams')
        .orderBy('followedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => doc.id).toList());
  }
}

/// Streams all followed mosques for the currently signed-in user.
final followedMosquesProvider = StreamProvider<List<MosqueModel>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(mosqueRepositoryProvider).watchFollowedMosques(user.uid);
});

/// Streams whether the current user is following [mosqueId].
final isFollowingProvider =
    StreamProvider.family<bool, String>((ref, mosqueId) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value(false);
  return ref
      .watch(mosqueRepositoryProvider)
      .watchIsFollowing(user.uid, mosqueId);
});

/// Streams whether the current user is following [imamId].
final isFollowingImamProvider =
    StreamProvider.family<bool, String>((ref, imamId) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value(false);
  return ref
      .watch(mosqueRepositoryProvider)
      .watchIsFollowingImam(user.uid, imamId);
});

/// Streams all followed imam IDs for the current user.
final followedImamsProvider = StreamProvider<List<String>>((ref) {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.asData?.value;
  if (user == null) return Stream.value([]);
  return ref.watch(mosqueRepositoryProvider).watchFollowedImamIds(user.uid);
});

/// Streams a single mosque by ID (used to enrich post cards with live mosque data).
final mosqueByIdProvider =
    StreamProvider.family<MosqueModel?, String>((ref, mosqueId) {
  if (mosqueId.isEmpty) return Stream.value(null);
  return ref.watch(mosqueRepositoryProvider).watchMosque(mosqueId);
});
