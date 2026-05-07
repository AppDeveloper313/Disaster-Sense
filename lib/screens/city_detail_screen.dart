import 'package:flutter/material.dart';
import '../models/city_alert.dart';
import '../models/earthquake_alert.dart';
import '../models/heatwave_alert.dart';
import '../models/weather_data.dart';
import '../providers/disaster_provider.dart';
import '../services/api_service.dart';
import '../widgets/risk_badge.dart';
import '../widgets/forecast_sparkline.dart';

class CityDetailScreen extends StatefulWidget {
  final String cityName;
  final CityData? data;

  const CityDetailScreen({
    super.key,
    required this.cityName,
    required this.data,
  });

  @override
  State<CityDetailScreen> createState() => _CityDetailScreenState();
}

class _CityDetailScreenState extends State<CityDetailScreen> {
  WeatherData? _weather;
  bool _weatherLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    final weather = await ApiService().getWeather(widget.cityName);
    if (mounted) {
      setState(() {
        _weather = weather;
        _weatherLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final floodAlert = widget.data?.floodAlert;
    final quakeAlert = widget.data?.earthquakeAlert;
    final heatAlert = widget.data?.heatwaveAlert;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cityName),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _weatherLoading = true);
              _loadWeather();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Current Weather ───────────────────────────────────────────
            _buildWeatherCard(context),
            const SizedBox(height: 16),

            // ── Risk Summary ──────────────────────────────────────────────
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
                        RiskBadge(
                          riskLevel: heatAlert?.riskLevel ?? RiskLevel.unknown,
                          label: 'Heatwave',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Precipitation Forecast Sparkline ───────────────────────────
            if (_weather?.forecast.isNotEmpty == true) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ForecastSparkline(
                    forecast: _weather!.forecast,
                    label: '7-Day Temperature Forecast',
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // ── Flood Information ─────────────────────────────────────────
            if (floodAlert != null) ...[
              _buildFloodCard(context, floodAlert),
              const SizedBox(height: 16),
            ],

            // ── Earthquake Information ────────────────────────────────────
            if (quakeAlert != null) ...[
              _buildQuakeCard(context, quakeAlert),
              const SizedBox(height: 16),
            ],

            // ── Heatwave Information ──────────────────────────────────────
            if (heatAlert != null) ...[
              _buildHeatCard(context, heatAlert),
              const SizedBox(height: 16),
            ],

            // ── Air Quality ───────────────────────────────────────────────
            if (_weather?.airQuality != null)
              _buildAirQualityCard(context, _weather!.airQuality!),

            // ── Last Updated ──────────────────────────────────────────────
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

  // ── Weather Card ───────────────────────────────────────────────────────────
  Widget _buildWeatherCard(BuildContext context) {
    final theme = Theme.of(context);

    if (_weatherLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 16),
              Text('Loading weather…', style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_weather == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text('Weather data unavailable',
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    final w = _weather!;
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.conditionIcon, style: const TextStyle(fontSize: 52)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        w.temperatureC != null
                            ? '${w.temperatureC!.toStringAsFixed(1)}°C'
                            : '--°C',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        w.condition,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _weatherMetric(
                  context,
                  Icons.thermostat,
                  'Feels Like',
                  w.feelsLikeC != null
                      ? '${w.feelsLikeC!.toStringAsFixed(1)}°C'
                      : '--',
                ),
                _weatherMetric(
                  context,
                  Icons.water_drop,
                  'Humidity',
                  w.humidityPct != null ? '${w.humidityPct}%' : '--',
                ),
                _weatherMetric(
                  context,
                  Icons.air,
                  'Wind',
                  w.windSpeedKmh != null
                      ? '${w.windSpeedKmh!.toStringAsFixed(0)} km/h'
                      : '--',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _weatherMetric(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final onContainer = theme.colorScheme.onPrimaryContainer;
    return Column(
      children: [
        Icon(icon, color: onContainer.withValues(alpha: 0.7), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: onContainer,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall
              ?.copyWith(color: onContainer.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  // ── Air Quality Card ───────────────────────────────────────────────────────
  Widget _buildAirQualityCard(BuildContext context, AirQuality aqi) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.air, color: aqi.color),
                const SizedBox(width: 8),
                Text(
                  'Air Quality',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                // AQI gauge chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: aqi.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: aqi.color),
                  ),
                  child: Column(
                    children: [
                      Text(
                        aqi.usAqi != null ? '${aqi.usAqi}' : '--',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: aqi.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'AQI',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: aqi.color),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aqi.category,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: aqi.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (aqi.pm25 != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'PM2.5: ${aqi.pm25!.toStringAsFixed(1)} µg/m³',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Flood Card ─────────────────────────────────────────────────────────────
  Widget _buildFloodCard(BuildContext context, CityAlert floodAlert) {
    final theme = Theme.of(context);
    return Card(
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
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
            Text('Forecast Summary', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              floodAlert.forecastSummary.isNotEmpty
                  ? floodAlert.forecastSummary
                  : 'No forecast available',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildRecommendationBox(
              context,
              floodAlert.recommendation,
              floodAlert.riskLevel.color,
            ),
          ],
        ),
      ),
    );
  }

  // ── Earthquake Card ────────────────────────────────────────────────────────
  Widget _buildQuakeCard(BuildContext context, EarthquakeAlert quakeAlert) {
    final theme = Theme.of(context);
    return Card(
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
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
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
              Text('Location', style: theme.textTheme.labelLarge),
              const SizedBox(height: 4),
              Text(quakeAlert.earthquake!.locationDescription,
                  style: theme.textTheme.bodyMedium),
            ] else ...[
              const Text('No significant seismic activity detected.'),
            ],
            const SizedBox(height: 16),
            _buildRecommendationBox(
              context,
              quakeAlert.recommendation,
              quakeAlert.riskLevel.color,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildRecommendationBox(
      BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text.isNotEmpty ? text : 'No recommendation available',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, String label, String value, IconData icon) {
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
          style:
              theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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

  Widget _buildHeatCard(BuildContext context, HeatwaveAlert alert) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Card(
      color: alert.alertTriggered
          ? cs.errorContainer.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department,
                  color: alert.alertTriggered ? cs.error : cs.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Heatwave Warning',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: alert.alertTriggered ? cs.error : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alert.forecastSummary,
              style: theme.textTheme.bodyMedium,
            ),
            if (alert.recommendation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        alert.recommendation,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
