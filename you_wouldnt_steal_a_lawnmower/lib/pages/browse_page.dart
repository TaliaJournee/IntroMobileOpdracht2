import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../constants/categories.dart';
import '../models/appliance.dart';
import '../services/location_service.dart';
import '../widgets/appliance_card.dart';
import 'appliance_details_page.dart';

class BrowsePage extends StatefulWidget {
  const BrowsePage({super.key});

  @override
  State<BrowsePage> createState() => _BrowsePageState();
}

class _BrowsePageState extends State<BrowsePage> {
  final _locationController = TextEditingController();
  final _locationService = const LocationService();

  String _selectedCategory = 'Alle';
  GeoPoint? _searchCenter;
  double _radiusKm = 10;
  bool _isGettingLocation = false;

  final List<double> _radiusOptions = const [1, 5, 10, 25, 50, 100];

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  CollectionReference<Map<String, dynamic>> get _appliancesCollection {
    return FirebaseFirestore.instance.collection('appliances');
  }

  Future<void> _useMyLocationForSearch() async {
    setState(() => _isGettingLocation = true);

    try {
      final position = await _locationService.getCurrentPosition();

      if (!mounted) return;

      setState(() {
        _searchCenter = GeoPoint(position.latitude, position.longitude);
      });
    } catch (error) {
      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() => _isGettingLocation = false);
      }
    }
  }

  void _clearDistanceFilter() {
    setState(() {
      _searchCenter = null;
    });
  }

  GeoPoint _geopointFrom(Map<String, dynamic> data) {
    final geo = data['geo'];

    if (geo is Map && geo['geopoint'] is GeoPoint) {
      return geo['geopoint'] as GeoPoint;
    }

    throw StateError('Document has no valid geo.geopoint field.');
  }

  GeoPoint? _geoPointOf(Appliance appliance) {
    if (appliance.latitude == null || appliance.longitude == null) {
      return null;
    }

    return GeoPoint(appliance.latitude!, appliance.longitude!);
  }

  Stream<List<Appliance>> _applianceStream() {
    final searchCenter = _searchCenter;

    if (searchCenter == null) {
      return _appliancesCollection
          .where('isActive', isEqualTo: true)
          .snapshots()
          .map((snapshot) {
            final appliances = snapshot.docs.map(Appliance.fromDoc).toList();
            return _filterAndSortAppliances(appliances);
          });
    }

    final geoCollection = GeoCollectionReference<Map<String, dynamic>>(
      _appliancesCollection,
    );

    return geoCollection
        .subscribeWithin(
          center: GeoFirePoint(searchCenter),
          radiusInKm: _radiusKm,
          field: 'geo',
          geopointFrom: _geopointFrom,
          strictMode: true,
        )
        .map((docs) {
          final appliances = docs
              .map(Appliance.fromDoc)
              .where((appliance) {
                return appliance.isActive && _geoPointOf(appliance) != null;
              })
              .map((appliance) {
                final appliancePoint = _geoPointOf(appliance)!;

                final distanceInKm = _distanceInKm(
                  from: searchCenter,
                  to: appliancePoint,
                );

                return appliance.copyWith(distanceInKm: distanceInKm);
              })
              .toList();

          return _filterAndSortAppliances(appliances);
        });
  }

  List<Appliance> _filterAndSortAppliances(List<Appliance> appliances) {
    final locationFilter = _locationController.text.trim().toLowerCase();

    final filtered = appliances.where((appliance) {
      final categoryMatches =
          _selectedCategory == 'Alle' ||
          appliance.category == _selectedCategory;

      final locationMatches =
          locationFilter.isEmpty ||
          appliance.location.toLowerCase().contains(locationFilter);

      return categoryMatches && locationMatches;
    }).toList();

    if (_searchCenter != null) {
      filtered.sort((a, b) {
        final aDistance = a.distanceInKm ?? double.infinity;
        final bDistance = b.distanceInKm ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });
    } else {
      filtered.sort((a, b) => b.availableFrom.compareTo(a.availableFrom));
    }

    return filtered;
  }

  double _distanceInKm({required GeoPoint from, required GeoPoint to}) {
    const earthRadiusKm = 6371.0;

    final lat1 = _degreesToRadians(from.latitude);
    final lon1 = _degreesToRadians(from.longitude);
    final lat2 = _degreesToRadians(to.latitude);
    final lon2 = _degreesToRadians(to.longitude);

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  Set<Marker> _buildMarkers(List<Appliance> appliances) {
    final searchCenter = _searchCenter;

    return {
      if (searchCenter != null)
        Marker(
          markerId: const MarkerId('search-center'),
          position: LatLng(searchCenter.latitude, searchCenter.longitude),
          infoWindow: const InfoWindow(title: 'Jouw locatie'),
        ),
      ...appliances.map((appliance) {
        final appliancePoint = _geoPointOf(appliance)!;

        return Marker(
          markerId: MarkerId(appliance.id),
          position: LatLng(appliancePoint.latitude, appliancePoint.longitude),
          infoWindow: InfoWindow(
            title: appliance.title,
            snippet: '€${appliance.pricePerDay.toStringAsFixed(2)} / dag',
          ),
          onTap: () => _openDetails(appliance),
        );
      }),
    };
  }

  double _mapZoomForRadius() {
    if (_radiusKm <= 1) return 14;
    if (_radiusKm <= 5) return 12;
    if (_radiusKm <= 10) return 11;
    if (_radiusKm <= 25) return 10;
    if (_radiusKm <= 50) return 9;
    return 8;
  }

  void _openDetails(Appliance appliance) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ApplianceDetailsPage(appliance: appliance),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFilters() {
    final isDistanceFilterActive = _searchCenter != null;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Zoek op locatienaam, bv. Antwerpen',
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
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedCategory = value);
              }
            },
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<double>(
                  initialValue: _radiusKm,
                  decoration: const InputDecoration(
                    labelText: 'Afstand',
                    border: OutlineInputBorder(),
                  ),
                  items: _radiusOptions
                      .map(
                        (radius) => DropdownMenuItem(
                          value: radius,
                          child: Text('${radius.round()} km'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _radiusKm = value);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _isGettingLocation ? null : _useMyLocationForSearch,
                icon: const Icon(Icons.my_location),
                label: Text(_isGettingLocation ? 'Zoeken...' : 'In de buurt'),
              ),
            ],
          ),

          if (isDistanceFilterActive) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _clearDistanceFilter,
                icon: const Icon(Icons.close),
                label: const Text('Afstandsfilter uitzetten'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMap(List<Appliance> appliances) {
    final searchCenter = _searchCenter;

    if (searchCenter == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          child: GoogleMap(
            key: ValueKey(
              '${searchCenter.latitude}-${searchCenter.longitude}-$_radiusKm',
            ),
            initialCameraPosition: CameraPosition(
              target: LatLng(searchCenter.latitude, searchCenter.longitude),
              zoom: _mapZoomForRadius(),
            ),
            markers: _buildMarkers(appliances),
            circles: {
              Circle(
                circleId: const CircleId('search-radius'),
                center: LatLng(searchCenter.latitude, searchCenter.longitude),
                radius: _radiusKm * 1000,
                fillColor: Colors.black12,
                strokeColor: Colors.black26,
                strokeWidth: 1,
              ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(List<Appliance> appliances) {
    return Column(
      children: [
        _buildMap(appliances),
        const Expanded(child: Center(child: Text('Geen toestellen gevonden.'))),
      ],
    );
  }

  Widget _buildApplianceList(List<Appliance> appliances) {
    return Column(
      children: [
        _buildMap(appliances),
        Expanded(
          child: ListView.builder(
            itemCount: appliances.length,
            itemBuilder: (context, index) {
              final appliance = appliances[index];

              return ApplianceCard(
                appliance: appliance,
                onTap: () => _openDetails(appliance),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: StreamBuilder<List<Appliance>>(
            stream: _applianceStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Fout: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final appliances = snapshot.data!;

              if (appliances.isEmpty) {
                return _buildEmptyState(appliances);
              }

              return _buildApplianceList(appliances);
            },
          ),
        ),
      ],
    );
  }
}
