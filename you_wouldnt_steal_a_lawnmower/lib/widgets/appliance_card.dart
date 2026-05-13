import 'package:flutter/material.dart';

import '../models/appliance.dart';
import 'date_button.dart';

class ApplianceCard extends StatelessWidget {
  final Appliance appliance;
  final VoidCallback onTap;

  const ApplianceCard({
    super.key,
    required this.appliance,
    required this.onTap,
  });

  String _formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()} m van jou';
    }

    if (distanceInKm < 10) {
      return '${distanceInKm.toStringAsFixed(1)} km van jou';
    }

    return '${distanceInKm.round()} km van jou';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (appliance.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    appliance.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                )
              else
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image, size: 40),
                ),
              const SizedBox(height: 12),
              Text(
                appliance.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('${appliance.category} • ${appliance.location}'),
              if (appliance.distanceInKm != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatDistance(appliance.distanceInKm!),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                '€${appliance.pricePerDay.toStringAsFixed(2)} / dag',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Beschikbaar: ${formatDate(appliance.availableFrom)} - ${formatDate(appliance.availableTo)}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
