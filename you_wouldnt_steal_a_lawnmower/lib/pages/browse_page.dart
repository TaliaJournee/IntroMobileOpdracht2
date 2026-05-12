import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../constants/categories.dart';
import '../models/appliance.dart';
import '../widgets/appliance_card.dart';
import 'appliance_details_page.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final _locationController = TextEditingController();
  String _selectedCategory = 'Alle';

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Zoek op locatie, bv. Antwerpen',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categorie',
                  border: OutlineInputBorder(),
                ),
                items: ['Alle', ...applianceCategories]
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('appliances')
                .where('isActive', isEqualTo: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Fout: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final locationFilter = _locationController.text.trim().toLowerCase();
              final appliances = snapshot.data!.docs
                  .map(Appliance.fromDoc)
                  .where((appliance) {
                    final categoryMatches = _selectedCategory == 'Alle' ||
                        appliance.category == _selectedCategory;
                    final locationMatches = locationFilter.isEmpty ||
                        appliance.location.toLowerCase().contains(locationFilter);
                    return categoryMatches && locationMatches;
                  })
                  .toList()
                ..sort((a, b) => b.availableFrom.compareTo(a.availableFrom));

              if (appliances.isEmpty) {
                return const Center(
                  child: Text('Geen toestellen gevonden.'),
                );
              }

              return ListView.builder(
                itemCount: appliances.length,
                itemBuilder: (context, index) {
                  final appliance = appliances[index];
                  return ApplianceCard(
                    appliance: appliance,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ApplianceDetailsPage(appliance: appliance),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
