import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import '../constants/categories.dart';
import '../models/appliance.dart';
import '../widgets/date_button.dart';

class EditAppliancePage extends StatefulWidget {
  final Appliance appliance;

  const EditAppliancePage({super.key, required this.appliance});

  @override
  State<EditAppliancePage> createState() => _EditAppliancePageState();
}

class _EditAppliancePageState extends State<EditAppliancePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _locationService = const LocationService();

  late String _category;
  late DateTime _availableFrom;
  late DateTime _availableTo;

  bool _isSaving = false;
  GeoPoint? _selectedGeoPoint;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();

    _titleController.text = widget.appliance.title;
    _descriptionController.text = widget.appliance.description;
    _locationController.text = widget.appliance.location;
    _priceController.text = widget.appliance.pricePerDay.toStringAsFixed(2);
    _imageUrlController.text = widget.appliance.imageUrl;

    if (widget.appliance.latitude != null &&
        widget.appliance.longitude != null) {
      _selectedGeoPoint = GeoPoint(
        widget.appliance.latitude!,
        widget.appliance.longitude!,
      );
    }

    _category = applianceCategories.contains(widget.appliance.category)
        ? widget.appliance.category
        : applianceCategories.first;

    _availableFrom = widget.appliance.availableFrom;
    _availableTo = widget.appliance.availableTo;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  DateTime _safeInitialDate(DateTime preferred) {
    final today = DateTime.now();
    final firstDate = DateTime(today.year, today.month, today.day);
    final lastDate = DateTime(today.year + 2);

    if (preferred.isBefore(firstDate)) return firstDate;
    if (preferred.isAfter(lastDate)) return lastDate;

    return preferred;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 2),
      initialDate: _safeInitialDate(isStart ? _availableFrom : _availableTo),
    );

    if (selected == null) return;

    setState(() {
      if (isStart) {
        _availableFrom = selected;

        if (_availableTo.isBefore(selected)) {
          _availableTo = selected;
        }
      } else {
        _availableTo = selected;
      }
    });
  }

  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return true;

    final uri = Uri.tryParse(url);

    if (uri == null) return false;

    final hasValidScheme = uri.scheme == 'http' || uri.scheme == 'https';
    final hasHost = uri.host.isNotEmpty;

    return hasValidScheme && hasHost;
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      final position = await _locationService.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _selectedGeoPoint = GeoPoint(position.latitude, position.longitude);
      });

      _showMessage('Locatie gekozen. Je kan de marker nog verplaatsen.');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  void _setLocationFromMap(LatLng position) {
    setState(() {
      _selectedGeoPoint = GeoPoint(position.latitude, position.longitude);
    });
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Je moet ingelogd zijn.');
      return;
    }

    if (user.uid != widget.appliance.ownerId) {
      _showMessage('Je mag alleen je eigen toestellen aanpassen.');
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final priceText = _priceController.text.trim().replaceAll(',', '.');
    final price = double.tryParse(priceText);
    final imageUrl = _imageUrlController.text.trim();

    if (title.isEmpty ||
        description.isEmpty ||
        location.isEmpty ||
        price == null) {
      _showMessage('Vul titel, beschrijving, locatie en een geldige prijs in.');
      return;
    }

    if (price <= 0) {
      _showMessage('De prijs moet groter zijn dan 0.');
      return;
    }

    if (_selectedGeoPoint == null) {
      _showMessage('Kies ook de exacte locatie van het toestel.');
      return;
    }

    if (_availableTo.isBefore(_availableFrom)) {
      _showMessage('De einddatum mag niet voor de begindatum liggen.');
      return;
    }

    if (!_isValidImageUrl(imageUrl)) {
      _showMessage(
        'Geef een geldige afbeeldings-URL in, bijvoorbeeld https://...',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final geoFirePoint = GeoFirePoint(_selectedGeoPoint!);

      await FirebaseFirestore.instance
          .collection('appliances')
          .doc(widget.appliance.id)
          .update({
            'title': title,
            'description': description,
            'category': _category,
            'location': location,
            'locationLower': location.toLowerCase(),
            'geo': geoFirePoint.data,
            'pricePerDay': price,
            'imageUrl': imageUrl,
            'availableFrom': Timestamp.fromDate(_availableFrom),
            'availableTo': Timestamp.fromDate(_availableTo),
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      _showMessage('Toestel aangepast.');
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage('Aanpassen mislukt: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildLocationPicker() {
    final selectedGeoPoint = _selectedGeoPoint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _isGettingLocation ? null : _useCurrentLocation,
          icon: const Icon(Icons.my_location),
          label: Text(
            _isGettingLocation
                ? 'Locatie ophalen...'
                : 'Gebruik mijn huidige locatie',
          ),
        ),
        const SizedBox(height: 8),

        if (selectedGeoPoint == null)
          Container(
            height: 140,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Dit toestel heeft nog geen exacte kaartlocatie. Kies je huidige locatie en verplaats de marker indien nodig.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          Text(
            'Gekozen locatie: ${selectedGeoPoint.latitude.toStringAsFixed(5)}, ${selectedGeoPoint.longitude.toStringAsFixed(5)}',
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: GoogleMap(
                key: ValueKey(
                  '${selectedGeoPoint.latitude}-${selectedGeoPoint.longitude}',
                ),
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    selectedGeoPoint.latitude,
                    selectedGeoPoint.longitude,
                  ),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('appliance-location'),
                    position: LatLng(
                      selectedGeoPoint.latitude,
                      selectedGeoPoint.longitude,
                    ),
                    infoWindow: const InfoWindow(title: 'Locatie toestel'),
                  ),
                },
                onTap: _setLocationFromMap,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tik op de kaart om de marker te verplaatsen.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrlController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Toestel bewerken')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Naam toestel',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Beschrijving',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'Categorie',
                border: OutlineInputBorder(),
              ),
              items: applianceCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _category = value);
                }
              },
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Locatie',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            _buildLocationPicker(),

            const SizedBox(height: 12),

            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Prijs per dag',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DateButton(
                  label: 'Beschikbaar vanaf',
                  value: _availableFrom,
                  onPressed: () => _pickDate(isStart: true),
                ),
                DateButton(
                  label: 'Beschikbaar tot',
                  value: _availableTo,
                  onPressed: () => _pickDate(isStart: false),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _imageUrlController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Afbeeldings-URL',
                hintText: 'https://voorbeeld.com/grasmaaier.jpg',
                border: OutlineInputBorder(),
              ),
            ),

            if (imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      height: 180,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Text('Afbeelding kan niet geladen worden'),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon: const Icon(Icons.save),
              label: Text(_isSaving ? 'Opslaan...' : 'Wijzigingen opslaan'),
            ),
          ],
        ),
      ),
    );
  }
}
