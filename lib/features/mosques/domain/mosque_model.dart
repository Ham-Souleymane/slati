import 'package:cloud_firestore/cloud_firestore.dart';

class MosqueModel {
  const MosqueModel({
    required this.id,
    required this.name,
    required this.country,
    required this.city,
    required this.address,
    required this.geopoint,
    this.photo,
    this.contactPhone,
    this.imamId,
    required this.verified,
    this.createdAt,
    this.capacity,
  });

  final String id;
  final String name;
  final String country;
  final String city;
  final String address;
  final GeoPoint geopoint;
  final String? photo;
  final String? contactPhone;
  final String? imamId;
  final bool verified;
  final DateTime? createdAt;
  final int? capacity;

  factory MosqueModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return MosqueModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      country: data['country'] as String? ?? '',
      city: data['city'] as String? ?? '',
      address: data['address'] as String? ?? '',
      geopoint: data['geopoint'] as GeoPoint? ?? const GeoPoint(0, 0),
      photo: data['photo'] as String?,
      contactPhone: data['contactPhone'] as String?,
      imamId: data['imamId'] as String?,
      verified: data['verified'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      capacity: data['capacity'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'country': country,
      'city': city,
      'address': address,
      'geopoint': geopoint,
      if (photo != null) 'photo': photo,
      if (contactPhone != null) 'contactPhone': contactPhone,
      if (imamId != null) 'imamId': imamId,
      'verified': verified,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (capacity != null) 'capacity': capacity,
    };
  }
}
