import 'package:flutter/material.dart';
import '../models/city_alert.dart';
import '../providers/disaster_provider.dart';
import '../widgets/risk_badge.dart';

class CityDetailScreen extends StatelessWidget {
  final String cityName;
  final CityData? data;

  const CityDetailScreen({
    super.key,
    required this.cityName,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final floodAlert = data?.floodAlert;
    final quakeAlert = data?.earthquakeAlert;

    return Scaffold(
      appBar: AppBar(
        title: Text(cityName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Risk Badges Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Risk Assessment',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        RiskBadge(
                          riskLevel: floodAlert?.riskLevel ?? RiskLevel.unknown,
                          label: 'Flood',
                        ),
                        RiskBadge(
                          riskLevel: quakeAlert?.riskLevel ?? RiskLevel.unknown,
                          label: 'Earthquake',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Flood Information
            if (floodAlert != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.water_drop, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Flood Risk Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      _buildInfoRow(
                        context,
                        'Cumulative Rainfall (3-day)',
                        '${floodAlert.rainfall3dayMm.toStringAsFixed(1)} mm',
                        Icons.water,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Forecast Summary',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        floodAlert.forecastSummary.isNotEmpty
                            ? floodAlert.forecastSummary
                            : 'No forecast available',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: floodAlert.riskLevel.color.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: floodAlert.riskLevel.color.withAlpha(50),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: floodAlert.riskLevel.color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                floodAlert.recommendation.isNotEmpty
                                    ? floodAlert.recommendation
                                    : 'No recommendation available',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Earthquake Information
            if (quakeAlert != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.landslide, color: theme.colorScheme.secondary),
                          const SizedBox(width: 8),
                          Text(
                            'Earthquake Risk Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (quakeAlert.earthquake != null) ...[
                        _buildInfoRow(
                          context,
                          'Magnitude',
                          'M${quakeAlert.earthquake!.magnitude.toStringAsFixed(1)}',
                          Icons.show_chart,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          context,
                          'Depth',
                          '${quakeAlert.earthquake!.depthKm.toStringAsFixed(1)} km',
                          Icons.arrow_downward,
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          context,
                          'Distance from City',
                          '${quakeAlert.distanceKm.toStringAsFixed(0)} km',
                          Icons.place,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Location',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quakeAlert.earthquake!.locationDescription,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ] else ...[
                        const Text('No significant seismic activity detected.'),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: quakeAlert.riskLevel.color.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: quakeAlert.riskLevel.color.withAlpha(50),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: quakeAlert.riskLevel.color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                quakeAlert.recommendation,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Last Updated
            if (floodAlert?.timestamp != null || quakeAlert?.timestamp != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Last updated: ${_formatTimestamp(floodAlert?.timestamp ?? quakeAlert?.timestamp ?? '')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final local = dt.toLocal();
      return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}
