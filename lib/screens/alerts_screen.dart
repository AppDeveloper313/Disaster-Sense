import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/city_alert.dart';
import '../models/earthquake_alert.dart';
import '../providers/disaster_provider.dart';
import '../widgets/risk_badge.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DisasterProvider>().fetchAlerts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.notification_important),
            SizedBox(width: 8),
            Text('Active Alerts'),
          ],
        ),
        centerTitle: false,
      ),
      body: Consumer<DisasterProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading &&
              provider.floodAlerts.isEmpty &&
              provider.earthquakeAlerts.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null &&
              provider.floodAlerts.isEmpty &&
              provider.earthquakeAlerts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load alerts',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(provider.error!),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => provider.fetchAlerts(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final hasFloodAlerts = provider.floodAlerts.isNotEmpty;
          final hasQuakeAlerts = provider.earthquakeAlerts.isNotEmpty;

          if (!hasFloodAlerts && !hasQuakeAlerts) {
            return RefreshIndicator(
              onRefresh: () => provider.fetchAlerts(),
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 80,
                            color: Colors.green,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Active Alerts',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All cities are at low risk level',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchAlerts(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Flood Alerts Section
                if (hasFloodAlerts) ...[
                  _buildSectionHeader(
                    context,
                    'Flood Alerts',
                    Icons.water_drop,
                    Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  ...provider.floodAlerts.map(
                    (alert) => _buildFloodAlertCard(context, alert),
                  ),
                  const SizedBox(height: 24),
                ],

                // Earthquake Alerts Section
                if (hasQuakeAlerts) ...[
                  _buildSectionHeader(
                    context,
                    'Earthquake Alerts',
                    Icons.landslide,
                    Colors.orange,
                  ),
                  const SizedBox(height: 8),
                  ...provider.earthquakeAlerts.map(
                    (alert) => _buildQuakeAlertCard(context, alert),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFloodAlertCard(BuildContext context, CityAlert alert) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: alert.riskLevel.color.withAlpha(100), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  alert.city,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                RiskBadge(
                  riskLevel: alert.riskLevel,
                  label: 'Flood',
                  compact: true,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.water, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  '${alert.rainfall3dayMm.toStringAsFixed(1)} mm rainfall (3-day)',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              alert.recommendation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuakeAlertCard(BuildContext context, EarthquakeAlert alert) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: alert.riskLevel.color.withAlpha(100), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  alert.city,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                RiskBadge(
                  riskLevel: alert.riskLevel,
                  label: 'Earthquake',
                  compact: true,
                ),
              ],
            ),
            if (alert.earthquake != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.show_chart,
                    size: 16,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'M${alert.earthquake!.magnitude.toStringAsFixed(1)} at ${alert.distanceKm.toStringAsFixed(0)} km',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                alert.earthquake!.locationDescription,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              alert.recommendation,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
