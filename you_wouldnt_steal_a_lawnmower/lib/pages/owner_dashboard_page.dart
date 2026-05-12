import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/rental_reservation.dart';
import '../widgets/date_button.dart';

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

  Future<void> _setStatus(
    BuildContext context,
    String reservationId,
    String status,
  ) async {
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .update({'status': status});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reservatie bijgewerkt naar $status.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('ownerId', isEqualTo: uid)
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
          ..sort((a, b) {
            if (a.status == 'pending' && b.status != 'pending') return -1;
            if (a.status != 'pending' && b.status == 'pending') return 1;
            return b.startDate.compareTo(a.startDate);
          });

        if (reservations.isEmpty) {
          return const Center(
            child: Text('Nog geen aanvragen voor jouw toestellen.'),
          );
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
                    Text('Huurder: ${reservation.renterEmail}'),
                    Text('${formatDate(reservation.startDate)} - ${formatDate(reservation.endDate)}'),
                    Text('Status: ${reservation.status}'),
                    Text('Totaal: €${reservation.totalPrice.toStringAsFixed(2)}'),
                    if (reservation.status == 'pending') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _setStatus(context, reservation.id, 'accepted'),
                            icon: const Icon(Icons.check),
                            label: const Text('Accepteren'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _setStatus(context, reservation.id, 'rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text('Weigeren'),
                          ),
                        ],
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
