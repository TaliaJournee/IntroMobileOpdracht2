import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/appliance.dart';
import '../widgets/date_button.dart';
import 'edit_appliance_page.dart';

class ApplianceDetailsPage extends StatefulWidget {
  final Appliance appliance;

  const ApplianceDetailsPage({super.key, required this.appliance});

  @override
  State<ApplianceDetailsPage> createState() => _ApplianceDetailsPageState();
}

class _ApplianceDetailsPageState extends State<ApplianceDetailsPage> {
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;
  bool _isRemoving = false;

  Future<void> _pickDate({required bool isStart}) async {
    final today = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
      initialDate: today,
    );

    if (selected == null) return;

    setState(() {
      if (isStart) {
        _startDate = selected;

        if (_endDate != null && _endDate!.isBefore(selected)) {
          _endDate = null;
        }
      } else {
        _endDate = selected;
      }
    });
  }

  Future<void> _reserve(Appliance appliance) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (user.uid == appliance.ownerId) {
      _showMessage('Je kan je eigen toestel niet reserveren.');
      return;
    }

    if (_startDate == null || _endDate == null) {
      _showMessage('Kies een start- en einddatum.');
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      _showMessage('De einddatum mag niet voor de startdatum liggen.');
      return;
    }

    if (_startDate!.isBefore(appliance.availableFrom) ||
        _endDate!.isAfter(appliance.availableTo)) {
      _showMessage(
        'Kies een periode binnen de beschikbaarheid van het toestel.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final existingReservations = await FirebaseFirestore.instance
          .collection('reservations')
          .where('applianceId', isEqualTo: appliance.id)
          .get();

      for (final doc in existingReservations.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';

        if (status != 'pending' && status != 'accepted') continue;

        final existingStart = (data['startDate'] as Timestamp?)?.toDate();
        final existingEnd = (data['endDate'] as Timestamp?)?.toDate();

        if (existingStart == null || existingEnd == null) continue;

        final overlaps =
            !_endDate!.isBefore(existingStart) &&
            !_startDate!.isAfter(existingEnd);

        if (overlaps) {
          _showMessage('Dit toestel is in die periode al gereserveerd.');
          setState(() => _isSaving = false);
          return;
        }
      }

      final days = _endDate!.difference(_startDate!).inDays + 1;
      final totalPrice = days * appliance.pricePerDay;

      await FirebaseFirestore.instance.collection('reservations').add({
        'applianceId': appliance.id,
        'applianceTitle': appliance.title,
        'ownerId': appliance.ownerId,
        'renterId': user.uid,
        'renterEmail': user.email ?? '',
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'status': 'pending',
        'totalPrice': totalPrice,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _showMessage(
        'Reservatie aangevraagd. De verhuurder kan ze nu accepteren.',
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      _showMessage('Reservatie mislukt: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _openEditPage(Appliance appliance) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditAppliancePage(appliance: appliance),
      ),
    );
  }

  Future<void> _confirmRemove(Appliance appliance) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.uid != appliance.ownerId) {
      _showMessage('Je mag alleen je eigen toestellen verwijderen.');
      return;
    }

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Toestel verwijderen?'),
          content: Text(
            'Ben je zeker dat je "${appliance.title}" wil verwijderen uit het aanbod?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuleren'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.delete),
              label: const Text('Verwijderen'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) return;

    setState(() => _isRemoving = true);

    try {
      await FirebaseFirestore.instance
          .collection('appliances')
          .doc(appliance.id)
          .update({
            'isActive': false,
            'removedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      _showMessage('Toestel verwijderd uit het aanbod.');
      Navigator.of(context).pop();
    } catch (error) {
      _showMessage('Verwijderen mislukt: $error');
    } finally {
      if (mounted) {
        setState(() => _isRemoving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildDeletedPage() {
    return Scaffold(
      appBar: AppBar(title: const Text('Toestel')),
      body: const Center(child: Text('Dit toestel bestaat niet meer.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final applianceRef = FirebaseFirestore.instance
        .collection('appliances')
        .doc(widget.appliance.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: applianceRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Toestel')),
            body: Center(child: Text('Fout: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.appliance.title)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data!;

        if (!doc.exists) {
          return _buildDeletedPage();
        }

        final appliance = Appliance.fromDoc(doc);

        final user = FirebaseAuth.instance.currentUser;
        final isOwner = user?.uid == appliance.ownerId;

        final days =
            _startDate != null &&
                _endDate != null &&
                !_endDate!.isBefore(_startDate!)
            ? _endDate!.difference(_startDate!).inDays + 1
            : 0;

        final total = days * appliance.pricePerDay;

        return Scaffold(
          appBar: AppBar(
            title: Text(appliance.title),
            actions: [
              if (isOwner) ...[
                IconButton(
                  tooltip: 'Bewerken',
                  onPressed: _isRemoving
                      ? null
                      : () => _openEditPage(appliance),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: 'Verwijderen',
                  onPressed: _isRemoving
                      ? null
                      : () => _confirmRemove(appliance),
                  icon: const Icon(Icons.delete),
                ),
              ],
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (appliance.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    appliance.imageUrl,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return Container(
                        height: 240,
                        color: Colors.black12,
                        alignment: Alignment.center,
                        child: const Text('Afbeelding kan niet geladen worden'),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image, size: 48),
                ),

              const SizedBox(height: 16),

              Text(
                appliance.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),

              Text('${appliance.category} • ${appliance.location}'),
              const SizedBox(height: 8),

              Text(
                '€${appliance.pricePerDay.toStringAsFixed(2)} / dag',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              Text(appliance.description),

              const SizedBox(height: 16),

              Text(
                'Beschikbaar van ${formatDate(appliance.availableFrom)} tot ${formatDate(appliance.availableTo)}',
              ),

              const Divider(height: 32),

              if (isOwner) ...[
                const Text(
                  'Dit is jouw toestel. Je kan het bewerken of verwijderen.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _isRemoving
                          ? null
                          : () => _openEditPage(appliance),
                      icon: const Icon(Icons.edit),
                      label: const Text('Bewerken'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _isRemoving
                          ? null
                          : () => _confirmRemove(appliance),
                      icon: const Icon(Icons.delete),
                      label: Text(
                        _isRemoving ? 'Verwijderen...' : 'Verwijderen',
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'Reserveren',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DateButton(
                      label: 'Startdatum',
                      value: _startDate,
                      onPressed: () => _pickDate(isStart: true),
                    ),
                    DateButton(
                      label: 'Einddatum',
                      value: _endDate,
                      onPressed: () => _pickDate(isStart: false),
                    ),
                  ],
                ),

                if (days > 0) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Totaal: $days dag(en) × €${appliance.pricePerDay.toStringAsFixed(2)} = €${total.toStringAsFixed(2)}',
                  ),
                ],

                const SizedBox(height: 16),

                FilledButton.icon(
                  onPressed: _isSaving ? null : () => _reserve(appliance),
                  icon: const Icon(Icons.event_available),
                  label: Text(_isSaving ? 'Bezig...' : 'Reservatie aanvragen'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
