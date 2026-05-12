import 'package:cloud_firestore/cloud_firestore.dart';

class RentalReservation {
  final String id;
  final String applianceId;
  final String applianceTitle;
  final String ownerId;
  final String renterId;
  final String renterEmail;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final double totalPrice;

  RentalReservation({
    required this.id,
    required this.applianceId,
    required this.applianceTitle,
    required this.ownerId,
    required this.renterId,
    required this.renterEmail,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.totalPrice,
  });

  factory RentalReservation.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RentalReservation(
      id: doc.id,
      applianceId: data['applianceId'] as String? ?? '',
      applianceTitle: data['applianceTitle'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      renterId: data['renterId'] as String? ?? '',
      renterEmail: data['renterEmail'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'pending',
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0,
    );
  }
}
