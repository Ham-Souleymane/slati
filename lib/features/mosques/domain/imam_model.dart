import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable model for an imam document in the `imams` Firestore collection.
///
/// Existing fields are preserved as-is. New fields added for the
/// "Ask the Sheikh" feature default gracefully for legacy documents
/// that pre-date this model.
class ImamModel {
  const ImamModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.mosqueId,
    required this.status,
    required this.commentsNotify,
    required this.verificationNotify,
    required this.createdAt,
    // ── Ask the Sheikh fields (new) ───────────────────────────
    this.fields = const [],
    this.photoUrl,
    this.bio,
    this.answeredCount = 0,
    this.isVisible = true,
    this.fcmToken,
  });

  // ── Existing fields ───────────────────────────────────────────
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String mosqueId;

  /// 'pending' | 'verified'
  final String status;
  final bool commentsNotify;
  final bool verificationNotify;
  final DateTime createdAt;

  // ── New fields for Ask the Sheikh ─────────────────────────────
  /// Islamic specialization fields, e.g. ['fiqh', 'muamalat'].
  final List<String> fields;
  final String? photoUrl;
  final String? bio;
  final int answeredCount;

  /// Controls appearance in the sheikh grid. Defaults to true.
  final bool isVisible;

  /// FCM token for push notifications to the imam.
  final String? fcmToken;

  // ── Derived ──────────────────────────────────────────────────
  bool get isVerified => status == 'verified';

  // ── Firestore deserialization ─────────────────────────────────
  factory ImamModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ImamModel(
      id: doc.id,
      fullName: (d['fullName'] as String?) ?? '',
      email: (d['email'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      mosqueId: (d['mosqueId'] as String?) ?? '',
      status: (d['status'] as String?) ?? 'pending',
      commentsNotify: (d['commentsNotify'] as bool?) ?? false,
      verificationNotify: (d['verificationNotify'] as bool?) ?? false,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      // New fields — safe defaults for legacy documents
      fields: (d['fields'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      photoUrl: (d['photo'] as String?) ?? (d['photoUrl'] as String?),
      bio: d['bio'] as String?,
      answeredCount: (d['answeredCount'] as int?) ?? 0,
      isVisible: (d['isVisible'] as bool?) ?? true,
      fcmToken: d['fcmToken'] as String?,
    );
  }

  // ── Firestore serialization (full write) ──────────────────────
  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'mosqueId': mosqueId,
      'status': status,
      'commentsNotify': commentsNotify,
      'verificationNotify': verificationNotify,
      'createdAt': Timestamp.fromDate(createdAt),
      'fields': fields,
      if (photoUrl != null) 'photo': photoUrl,
      if (bio != null) 'bio': bio,
      'answeredCount': answeredCount,
      'isVisible': isVisible,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  /// Partial update map — only the new Ask the Sheikh fields.
  Map<String, dynamic> toAskFieldsUpdate() {
    return {
      'fields': fields,
      if (photoUrl != null) 'photo': photoUrl,
      if (bio != null) 'bio': bio,
      'isVisible': isVisible,
    };
  }

  ImamModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? mosqueId,
    String? status,
    bool? commentsNotify,
    bool? verificationNotify,
    List<String>? fields,
    String? photoUrl,
    String? bio,
    int? answeredCount,
    bool? isVisible,
    String? fcmToken,
  }) {
    return ImamModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      mosqueId: mosqueId ?? this.mosqueId,
      status: status ?? this.status,
      commentsNotify: commentsNotify ?? this.commentsNotify,
      verificationNotify: verificationNotify ?? this.verificationNotify,
      createdAt: createdAt,
      fields: fields ?? this.fields,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      answeredCount: answeredCount ?? this.answeredCount,
      isVisible: isVisible ?? this.isVisible,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
