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
  });

  factory Appliance.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
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
      availableFrom: (data['availableFrom'] as Timestamp?)?.toDate() ?? DateTime.now(),
      availableTo: (data['availableTo'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }
}
