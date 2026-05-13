import 'package:cloud_firestore/cloud_firestore.dart';

class Appliance {
  final String id;
  final String ownerId;
  final String ownerEmail;
  final String title;
  final String description;
  final String category;
  final String location;
  final String imageUrl;
  final double pricePerDay;
  final DateTime availableFrom;
  final DateTime availableTo;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final double? distanceInKm;

  Appliance({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.title,
    required this.description,
    required this.category,
    required this.location,
    required this.imageUrl,
    required this.pricePerDay,
    required this.availableFrom,
    required this.availableTo,
    required this.isActive,
    this.latitude,
    this.longitude,
    this.distanceInKm,
  });

  factory Appliance.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    final geo = data['geo'];
    final GeoPoint? geoPoint = geo is Map ? geo['geopoint'] as GeoPoint? : null;

    return Appliance(
      id: doc.id,
      ownerId: data['ownerId'] as String? ?? '',
      ownerEmail: data['ownerEmail'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? '',
      location: data['location'] as String? ?? '',
      imageUrl: data['imageUrl'] as String? ?? '',
      pricePerDay: (data['pricePerDay'] as num?)?.toDouble() ?? 0,
      availableFrom:
          (data['availableFrom'] as Timestamp?)?.toDate() ?? DateTime.now(),
      availableTo:
          (data['availableTo'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
      latitude: geoPoint?.latitude,
      longitude: geoPoint?.longitude,
    );
  }

  Appliance copyWith({
    String? id,
    String? ownerId,
    String? ownerEmail,
    String? title,
    String? description,
    String? category,
    String? location,
    String? imageUrl,
    double? pricePerDay,
    DateTime? availableFrom,
    DateTime? availableTo,
    bool? isActive,
    double? latitude,
    double? longitude,
    double? distanceInKm,
  }) {
    return Appliance(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
      isActive: isActive ?? this.isActive,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceInKm: distanceInKm ?? this.distanceInKm,
    );
  }
}
