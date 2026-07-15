import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  const PostModel({
    required this.id,
    required this.mosqueId,
    required this.mosqueName,
    this.mosquePhoto,
    required this.verified,
    required this.text,
    this.photoUrl,
    required this.category,
    required this.createdAt,
    this.eventDate,
    this.eventTime,
    this.eventLocation,
    this.latitude,
    this.longitude,
    this.likeCount = 0,
    this.commentCount = 0,
    this.imamId,
  });

  final String id;
  final String mosqueId;
  final String mosqueName;
  final String? mosquePhoto;
  final bool verified;
  final String text;
  final String? photoUrl;
  final String category; // 'دروس', 'إعلانات', 'أنشطة' etc.
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final String? imamId;

  // Optional event details
  final String? eventDate;
  final String? eventTime;
  final String? eventLocation;

  // Coordinates of the mosque (for distance filtering client-side)
  final double? latitude;
  final double? longitude;

  bool get isEvent =>
      eventDate != null || eventTime != null || eventLocation != null;

  factory PostModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final mediaUrls = d['mediaUrls'] as List<dynamic>?;
    final fallbackPhotoUrl = (mediaUrls != null && mediaUrls.isNotEmpty)
        ? mediaUrls.first?.toString()
        : null;

    // Safe helper: returns null if the value is not a String (e.g. it's a Timestamp).
    String? _str(String key) {
      final v = d[key];
      if (v == null) return null;
      if (v is String) return v;
      // If a Timestamp was accidentally stored in a string field, convert it.
      if (v is Timestamp) return v.toDate().toIso8601String();
      return v.toString();
    }

    // Safe DateTime: handles both Timestamp and ISO-8601 String.
    DateTime _date(String key) {
      final v = d[key];
      if (v is Timestamp) return v.toDate();
      if (v is String) {
        return DateTime.tryParse(v) ?? DateTime.now();
      }
      return DateTime.now();
    }

    return PostModel(
      id: doc.id,
      mosqueId: _str('mosqueId') ?? '',
      mosqueName: _str('mosqueName') ?? 'مسجد',
      mosquePhoto: _str('mosquePhoto'),
      verified: d['verified'] as bool? ?? false,
      text: _str('text') ?? '',
      photoUrl: _str('photoUrl') ?? fallbackPhotoUrl,
      category: _str('category') ?? 'إعلانات',
      createdAt: _date('createdAt'),
      eventDate: _str('eventDate'),
      eventTime: _str('eventTime'),
      eventLocation: _str('eventLocation'),
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      likeCount: d['likeCount'] as int? ?? 0,
      commentCount: d['commentCount'] as int? ?? 0,
      imamId: _str('imamId'),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'mosqueId': mosqueId,
      'mosqueName': mosqueName,
      if (mosquePhoto != null) 'mosquePhoto': mosquePhoto,
      'verified': verified,
      'text': text,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (photoUrl != null) 'mediaUrls': [photoUrl],
      'category': category,
      'createdAt': Timestamp.fromDate(createdAt),
      if (eventDate != null) 'eventDate': eventDate,
      if (eventTime != null) 'eventTime': eventTime,
      if (eventLocation != null) 'eventLocation': eventLocation,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'likeCount': likeCount,
      'commentCount': commentCount,
      if (imamId != null) 'imamId': imamId,
    };
  }
}
