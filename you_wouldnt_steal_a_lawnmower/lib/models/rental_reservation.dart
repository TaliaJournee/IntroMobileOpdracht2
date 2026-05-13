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

  final DateTime? lastMessageAt;
  final String lastMessageSenderId;
  final String lastMessageSenderEmail;
  final String lastMessageText;
  final Map<String, DateTime> chatReadAtBy;

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
    required this.lastMessageAt,
    required this.lastMessageSenderId,
    required this.lastMessageSenderEmail,
    required this.lastMessageText,
    required this.chatReadAtBy,
  });

  factory RentalReservation.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    final rawChatReadAtBy = data['chatReadAtBy'];
    final chatReadAtBy = <String, DateTime>{};

    if (rawChatReadAtBy is Map) {
      rawChatReadAtBy.forEach((key, value) {
        if (key is String && value is Timestamp) {
          chatReadAtBy[key] = value.toDate();
        }
      });
    }

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
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] as String? ?? '',
      lastMessageSenderEmail: data['lastMessageSenderEmail'] as String? ?? '',
      lastMessageText: data['lastMessageText'] as String? ?? '',
      chatReadAtBy: chatReadAtBy,
    );
  }

  bool hasUnreadMessageFor(String userId) {
    if (lastMessageAt == null) return false;
    if (lastMessageSenderId.isEmpty) return false;
    if (lastMessageSenderId == userId) return false;

    final readAt = chatReadAtBy[userId];

    if (readAt == null) return true;

    return readAt.isBefore(lastMessageAt!);
  }
}
