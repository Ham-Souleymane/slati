import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable model representing a worshipper's Firestore profile.
class UserModel {
  const UserModel({
    required this.id,
    required this.fullName,
    required this.isGuest,
    required this.createdAt,
    this.phone,
    this.email,
    this.city,
    this.photoUrl,
    this.fcmToken,
  });

  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? city;
  final String? photoUrl;
  final String? fcmToken;
  final bool isGuest;
  final DateTime createdAt;

  // ── Firestore serialization ──────────────────────────────────
  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return UserModel(
      id: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      phone: d['phone'] as String?,
      email: d['email'] as String?,
      city: d['city'] as String?,
      photoUrl: d['photoUrl'] as String?,
      fcmToken: d['fcmToken'] as String?,
      isGuest: (d['isGuest'] as bool?) ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (city != null) 'city': city,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (fcmToken != null) 'fcmToken': fcmToken,
      'isGuest': isGuest,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserModel copyWith({
    String? fullName,
    String? phone,
    String? email,
    String? city,
    String? photoUrl,
    String? fcmToken,
    bool? isGuest,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      city: city ?? this.city,
      photoUrl: photoUrl ?? this.photoUrl,
      fcmToken: fcmToken ?? this.fcmToken,
      isGuest: isGuest ?? this.isGuest,
      createdAt: createdAt,
    );
  }
}
