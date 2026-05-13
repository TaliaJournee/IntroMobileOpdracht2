import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/location_service.dart';
import '../constants/categories.dart';
import '../widgets/date_button.dart';

class AddAppliancePage extends StatefulWidget {
  const AddAppliancePage({super.key});

  @override
  State<AddAppliancePage> createState() => _AddAppliancePageState();
}

class _AddAppliancePageState extends State<AddAppliancePage> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();

  final _locationService = const LocationService();

  String _category = applianceCategories.first;
  DateTime? _availableFrom;
  DateTime? _availableTo;
  bool _isSaving = false;
  GeoPoint? _selectedGeoPoint;
  bool _isGettingLocation = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

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
        _availableFrom = selected;

        if (_availableTo != null && _availableTo!.isBefore(selected)) {
          _availableTo = null;
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

  Future<void> _saveAppliance() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final priceText = _priceController.text.trim().replaceAll(',', '.');
    final price = double.tryParse(priceText);
    final imageUrl = _imageUrlController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Je moet ingelogd zijn om een toestel toe te voegen.');
      return;
    }

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

    if (_availableFrom == null || _availableTo == null) {
      _showMessage('Kies een beschikbaarheidsperiode.');
      return;
    }

    if (_availableTo!.isBefore(_availableFrom!)) {
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

      await FirebaseFirestore.instance.collection('appliances').add({
        'ownerId': user.uid,
        'ownerEmail': user.email ?? '',
        'title': title,
        'description': description,
        'category': _category,
        'location': location,
        'locationLower': location.toLowerCase(),
        'geo': geoFirePoint.data,
        'pricePerDay': price,
        'imageUrl': imageUrl,
        'availableFrom': Timestamp.fromDate(_availableFrom!),
        'availableTo': Timestamp.fromDate(_availableTo!),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _titleController.clear();
      _descriptionController.clear();
      _locationController.clear();
      _priceController.clear();
      _imageUrlController.clear();

      setState(() {
        _category = applianceCategories.first;
        _availableFrom = null;
        _availableTo = null;
        _selectedGeoPoint = null;
      });

      _showMessage('Toestel toegevoegd.');
    } catch (error) {
      _showMessage('Opslaan mislukt: $error');
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
                'Kies eerst je huidige locatie.\n'
                'Daarna kan je op de kaart tikken of de marker slepen naar de exacte plaats van het toestel.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          Text(
            'Gekozen locatie: '
            '${selectedGeoPoint.latitude.toStringAsFixed(5)}, '
            '${selectedGeoPoint.longitude.toStringAsFixed(5)}',
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
                    draggable: true,
                    onDragEnd: _setLocationFromMap,
                  ),
                },
                onTap: _setLocationFromMap,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tik op de kaart of sleep de marker om de locatie te verplaatsen.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrlController.text.trim();

    return SingleChildScrollView(
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
                  (category) => DropdownMenuItem<String>(
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
              labelText: 'Locatie, bv. Antwerpen',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _buildLocationPicker(),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            onPressed: _isSaving ? null : _saveAppliance,
            icon: const Icon(Icons.save),
            label: Text(_isSaving ? 'Opslaan...' : 'Toestel opslaan'),
          ),
        ],
      ),
    );
  }
}
