import 'package:flutter/material.dart';
import '../models/city_alert.dart';
import '../providers/disaster_provider.dart';
import 'risk_badge.dart';

class CityCard extends StatelessWidget {
  final String cityName;
  final CityData? data;
  final VoidCallback onTap;

  const CityCard({
    super.key,
    required this.cityName,
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final floodRisk = data?.floodAlert?.riskLevel ?? RiskLevel.unknown;
    final quakeRisk = data?.earthquakeAlert?.riskLevel ?? RiskLevel.unknown;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: data?.overallRisk.color.withAlpha(100) ?? Colors.grey.withAlpha(50),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      cityName,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  RiskBadge(
                    riskLevel: floodRisk,
                    label: 'Flood',
                    compact: true,
                  ),
                  RiskBadge(
                    riskLevel: quakeRisk,
                    label: 'Earthquake',
                    compact: true,
                  ),
                ],
              ),
              if (data?.floodAlert != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.water_drop,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${data!.floodAlert!.rainfall3dayMm.toStringAsFixed(1)} mm (3-day)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
