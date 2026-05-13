import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/rental_reservation.dart';
import '../widgets/date_button.dart';
import 'reservation_chat_page.dart';

class MyReservationsPage extends StatelessWidget {
  const MyReservationsPage({super.key});

  bool _canChat(RentalReservation reservation) {
    return reservation.status == 'accepted';
  }

  Future<void> _cancelReservation(
    BuildContext context,
    String reservationId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservatie geannuleerd.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Annuleren mislukt: $error')));
      }
    }
  }

  void _openChat(BuildContext context, RentalReservation reservation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReservationChatPage(reservation: reservation),
      ),
    );
  }

  String _statusLabel(String status) {
    if (status == 'pending') return 'In afwachting';
    if (status == 'accepted') return 'Geaccepteerd';
    if (status == 'rejected') return 'Geweigerd';
    if (status == 'cancelled') return 'Geannuleerd';
    if (status == 'returned') return 'Teruggebracht';

    return status;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('renterId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Fout: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reservations =
            snapshot.data!.docs.map(RentalReservation.fromDoc).toList()
              ..sort((a, b) => b.startDate.compareTo(a.startDate));

        if (reservations.isEmpty) {
          return const Center(child: Text('Je hebt nog geen reserveringen.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index];
            final canChat = _canChat(reservation);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reservation.applianceTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${formatDate(reservation.startDate)} - ${formatDate(reservation.endDate)}',
                    ),
                    Text('Status: ${_statusLabel(reservation.status)}'),
                    Text(
                      'Totaal: €${reservation.totalPrice.toStringAsFixed(2)}',
                    ),

                    if (reservation.status == 'pending') ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _cancelReservation(context, reservation.id),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Annuleren'),
                      ),
                    ],

                    if (canChat) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openChat(context, reservation),
                        icon: const Icon(Icons.chat),
                        label: const Text('Berichten'),
                      ),
                    ],

                    if (reservation.status == 'returned') ...[
                      const SizedBox(height: 8),
                      const Text(
                        'De teruggave is bevestigd door de verhuurder.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
