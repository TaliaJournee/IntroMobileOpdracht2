import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/rental_reservation.dart';
import '../widgets/date_button.dart';

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isFinished(RentalReservation reservation) {
    final today = _dateOnly(DateTime.now());
    final endDate = _dateOnly(reservation.endDate);

    return endDate.isBefore(today);
  }

  bool _needsReturnConfirmation(RentalReservation reservation) {
    return reservation.status == 'accepted' && _isFinished(reservation);
  }

  Future<void> _setStatus(
    BuildContext context,
    String reservationId,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reservatie bijgewerkt naar $status.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Bijwerken mislukt: $error')));
      }
    }
  }

  Future<void> _confirmReturned(
    BuildContext context,
    RentalReservation reservation,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Teruggave bevestigen?'),
          content: Text(
            'Bevestig je dat "${reservation.applianceTitle}" is teruggebracht door ${reservation.renterEmail}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuleren'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('Bevestigen'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservation.id)
          .update({
            'status': 'returned',
            'returnedConfirmedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Teruggave bevestigd.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Teruggave bevestigen mislukt: $error')),
        );
      }
    }
  }

  String _statusLabel(RentalReservation reservation) {
    if (reservation.status == 'pending') return 'In afwachting';

    if (reservation.status == 'accepted') {
      if (_isFinished(reservation)) {
        return 'Afgelopen, wacht op teruggave';
      }

      return 'Geaccepteerd';
    }

    if (reservation.status == 'rejected') return 'Geweigerd';
    if (reservation.status == 'cancelled') return 'Geannuleerd';
    if (reservation.status == 'returned') return 'Teruggebracht';

    return reservation.status;
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

        final reservations =
            snapshot.data!.docs.map(RentalReservation.fromDoc).toList()
              ..sort((a, b) {
                if (a.status == 'pending' && b.status != 'pending') return -1;
                if (a.status != 'pending' && b.status == 'pending') return 1;

                final aNeedsReturn = _needsReturnConfirmation(a);
                final bNeedsReturn = _needsReturnConfirmation(b);

                if (aNeedsReturn && !bNeedsReturn) return -1;
                if (!aNeedsReturn && bNeedsReturn) return 1;

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
            final needsReturnConfirmation = _needsReturnConfirmation(
              reservation,
            );

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
                    Text(
                      '${formatDate(reservation.startDate)} - ${formatDate(reservation.endDate)}',
                    ),
                    Text('Status: ${_statusLabel(reservation)}'),
                    Text(
                      'Totaal: €${reservation.totalPrice.toStringAsFixed(2)}',
                    ),

                    if (reservation.status == 'pending') ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: () =>
                                _setStatus(context, reservation.id, 'accepted'),
                            icon: const Icon(Icons.check),
                            label: const Text('Accepteren'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _setStatus(context, reservation.id, 'rejected'),
                            icon: const Icon(Icons.close),
                            label: const Text('Weigeren'),
                          ),
                        ],
                      ),
                    ],

                    if (needsReturnConfirmation) ...[
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _confirmReturned(context, reservation),
                        icon: const Icon(Icons.assignment_turned_in),
                        label: const Text('Teruggave bevestigen'),
                      ),
                    ],

                    if (reservation.status == 'returned') ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Teruggave is bevestigd.',
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
