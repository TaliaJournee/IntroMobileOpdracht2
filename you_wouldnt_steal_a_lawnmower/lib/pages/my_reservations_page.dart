import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/rental_reservation.dart';
import '../widgets/date_button.dart';

class MyReservationsPage extends StatelessWidget {
  const MyReservationsPage({super.key});

  Future<void> _cancelReservation(BuildContext context, String reservationId) async {
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .update({'status': 'cancelled'});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservatie geannuleerd.')),
      );
    }
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

        final reservations = snapshot.data!.docs
            .map(RentalReservation.fromDoc)
            .toList()
          ..sort((a, b) => b.startDate.compareTo(a.startDate));

        if (reservations.isEmpty) {
          return const Center(child: Text('Je hebt nog geen reserveringen.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index];
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
                    Text('${formatDate(reservation.startDate)} - ${formatDate(reservation.endDate)}'),
                    Text('Status: ${reservation.status}'),
                    Text('Totaal: €${reservation.totalPrice.toStringAsFixed(2)}'),
                    if (reservation.status == 'pending') ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _cancelReservation(context, reservation.id),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Annuleren'),
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
