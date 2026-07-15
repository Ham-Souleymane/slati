import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../domain/user_model.dart';

/// Repository for reading and writing worshipper profiles in `users/{uid}`.
class UserRepository {
  UserRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // ── Create / upsert ──────────────────────────────────────────
  /// Creates (or overwrites) the user document.
  /// Only writes to `users/{uid}` — never touches `imams` or `mosques`.
  Future<void> createUserDoc({
    required String uid,
    required String fullName,
    required bool isGuest,
    String? phone,
    String? email,
    String? city,
    String? photoUrl,
    String? fcmToken,
  }) async {
    final doc = UserModel(
      id: uid,
      fullName: fullName,
      phone: phone,
      email: email,
      city: city,
      photoUrl: photoUrl,
      fcmToken: fcmToken,
      isGuest: isGuest,
      createdAt: DateTime.now(),
    );
    await _users.doc(uid).set(doc.toFirestore());
  }

  /// Updates specific fields on an existing user doc (merge-safe).
  Future<void> updateUserDoc(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).set(fields, SetOptions(merge: true));
  }

  // ── Read ─────────────────────────────────────────────────────
  /// Returns a live stream of the user's profile, or null if not yet created.
  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserModel.fromFirestore(snap);
    });
  }

  Future<UserModel?> getUser(String uid) async {
    final snap = await _users.doc(uid).get();
    if (!snap.exists) return null;
    return UserModel.fromFirestore(snap);
  }
}

// ── Providers ────────────────────────────────────────────────
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(firestoreProvider));
});

/// Streams the current signed-in user's worshipper profile.
/// Returns null when signed out or when the user doc doesn't exist yet.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value(null);
  return ref.watch(userRepositoryProvider).watchUser(user.uid);
});
