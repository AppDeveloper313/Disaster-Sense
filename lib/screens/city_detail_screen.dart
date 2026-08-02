import 'package:flutter/material.dart';
import 'dart:ui';
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
  String? _aiSummary;
  bool _aiSummaryLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWeather();
    _loadAiSummary();
  }

  Future<void> _loadAiSummary() async {
    if (!mounted) return;
    setState(() => _aiSummaryLoading = true);
    final summary = await ApiService().getCityAiSummary(widget.cityName);
    if (mounted) {
      setState(() {
        _aiSummary = summary;
        _aiSummaryLoading = false;
      });
    }
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

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(widget.cityName, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  _weatherLoading = true;
                  _aiSummaryLoading = true;
                });
                _loadWeather();
                _loadAiSummary();
              },
            ),
          ],
        ),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                  left: 16,
                  right: 16,
                  bottom: 16,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildWeatherCard(context),
                    const SizedBox(height: 16),
                    _buildRiskSummaryCard(context, floodAlert, quakeAlert, heatAlert),
                  ]),
                ),
              ),
              SliverAppBar(
                pinned: true,
                primary: false,
                automaticallyImplyLeading: false,
                toolbarHeight: 0,
                backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
                bottom: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 24),
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5), width: 1.5),
                  ),
                  splashBorderRadius: BorderRadius.circular(30),
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  tabs: const [
                    Tab(text: 'AI Prediction'),
                    Tab(text: 'Specific Risks'),
                    Tab(text: 'Forecasts & AQI'),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              // Tab 1: AI Prediction
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAiPredictionCard(context),
                ],
              ),
              // Tab 2: Specific Risks
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (floodAlert != null) ...[
                    _buildFloodCard(context, floodAlert),
                    const SizedBox(height: 16),
                  ],
                  if (quakeAlert != null) ...[
                    _buildQuakeCard(context, quakeAlert),
                    const SizedBox(height: 16),
                  ],
                  if (heatAlert != null) ...[
                    _buildHeatCard(context, heatAlert),
                    const SizedBox(height: 16),
                  ],
                  if (floodAlert == null && quakeAlert == null && heatAlert == null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          "No specific disaster risks active.",
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              // Tab 3: Forecasts
              ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_weather?.forecast.isNotEmpty == true) ...[
                    _GlassCard(
                      child: ForecastSparkline(
                        forecast: _weather!.forecast,
                        label: '7-Day Temperature Forecast',
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_weather?.airQuality != null) ...[
                    _buildAirQualityCard(context, _weather!.airQuality!),
                    const SizedBox(height: 16),
                  ],
                  if (floodAlert?.timestamp != null || quakeAlert?.timestamp != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Last updated: ${_formatTimestamp(floodAlert?.timestamp ?? quakeAlert?.timestamp ?? '')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskSummaryCard(BuildContext context, CityAlert? floodAlert, EarthquakeAlert? quakeAlert, HeatwaveAlert? heatAlert) {
    final theme = Theme.of(context);
    final overallRisk = widget.data?.overallRisk ?? RiskLevel.unknown;
    Color glowColor;
    switch (overallRisk) {
      case RiskLevel.high: glowColor = Colors.redAccent; break;
      case RiskLevel.medium: glowColor = Colors.orangeAccent; break;
      case RiskLevel.low: glowColor = Colors.greenAccent; break;
      case RiskLevel.unknown: glowColor = theme.colorScheme.primary; break;
    }

    return _GlassCard(
      glowColor: glowColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_outlined, color: glowColor),
              const SizedBox(width: 8),
              Text(
                'Risk Assessment',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
    );
  }

  Widget _buildAiPredictionCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_aiSummaryLoading) {
      return _GlassCard(
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
            ),
            const SizedBox(width: 16),
            Text('DisasterSense AI is analyzing...', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    if (_aiSummary == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primaryContainer.withValues(alpha: 0.5),
                  cs.surface.withValues(alpha: 0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: cs.primary.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome, color: cs.primary, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'AI Prediction',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _aiSummary!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherCard(BuildContext context) {
    final theme = Theme.of(context);

    if (_weatherLoading) {
      return _GlassCard(
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
      );
    }

    if (_weather == null) {
      return _GlassCard(
        child: Row(
          children: [
            Icon(Icons.cloud_off, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text('Weather data unavailable', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    final w = _weather!;
    return _GlassCard(
      glowColor: theme.colorScheme.tertiary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(w.conditionIcon, style: const TextStyle(fontSize: 64)),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.temperatureC != null ? '${w.temperatureC!.toStringAsFixed(1)}°C' : '--°C',
                      style: theme.textTheme.displayMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      w.condition,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _weatherMetric(context, Icons.thermostat, 'Feels Like', w.feelsLikeC != null ? '${w.feelsLikeC!.toStringAsFixed(1)}°C' : '--'),
              _weatherMetric(context, Icons.water_drop, 'Humidity', w.humidityPct != null ? '${w.humidityPct}%' : '--'),
              _weatherMetric(context, Icons.air, 'Wind', w.windSpeedKmh != null ? '${w.windSpeedKmh!.toStringAsFixed(0)} km/h' : '--'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weatherMetric(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Column(
      children: [
        Icon(icon, color: onSurface.withValues(alpha: 0.7), size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  Widget _buildAirQualityCard(BuildContext context, AirQuality aqi) {
    final theme = Theme.of(context);
    return _GlassCard(
      glowColor: aqi.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.air, color: aqi.color, size: 24),
              const SizedBox(width: 8),
              Text(
                'Air Quality',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: aqi.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: aqi.color.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      aqi.usAqi != null ? '${aqi.usAqi}' : '--',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: aqi.color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'AQI',
                      style: theme.textTheme.labelMedium?.copyWith(color: aqi.color, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      aqi.category,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: aqi.color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (aqi.pm25 != null) ...[
                      const SizedBox(height: 8),
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
    );
  }

  Widget _buildFloodCard(BuildContext context, CityAlert floodAlert) {
    final theme = Theme.of(context);
    return _GlassCard(
      glowColor: floodAlert.riskLevel.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop, color: floodAlert.riskLevel.color),
              const SizedBox(width: 8),
              Text(
                'Flood Risk Details',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(context, 'Cumulative Rainfall (3-day)', '${floodAlert.rainfall3dayMm.toStringAsFixed(1)} mm', Icons.water),
          const SizedBox(height: 16),
          Text('Forecast Summary', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            floodAlert.forecastSummary.isNotEmpty ? floodAlert.forecastSummary : 'No forecast available',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          _buildRecommendationBox(context, floodAlert.recommendation, floodAlert.riskLevel.color),
        ],
      ),
    );
  }

  Widget _buildQuakeCard(BuildContext context, EarthquakeAlert quakeAlert) {
    final theme = Theme.of(context);
    return _GlassCard(
      glowColor: quakeAlert.riskLevel.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.landslide, color: quakeAlert.riskLevel.color),
              const SizedBox(width: 8),
              Text(
                'Earthquake Risk Details',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (quakeAlert.earthquake != null) ...[
            _buildInfoRow(context, 'Magnitude', 'M${quakeAlert.earthquake!.magnitude.toStringAsFixed(1)}', Icons.show_chart),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Depth', '${quakeAlert.earthquake!.depthKm.toStringAsFixed(1)} km', Icons.arrow_downward),
            const SizedBox(height: 8),
            _buildInfoRow(context, 'Distance', '${quakeAlert.distanceKm.toStringAsFixed(0)} km', Icons.place),
            const SizedBox(height: 16),
            Text('Location', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(quakeAlert.earthquake!.locationDescription, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ] else ...[
            const Text('No significant seismic activity detected.'),
          ],
          const SizedBox(height: 16),
          _buildRecommendationBox(context, quakeAlert.recommendation, quakeAlert.riskLevel.color),
        ],
      ),
    );
  }

  Widget _buildHeatCard(BuildContext context, HeatwaveAlert alert) {
    final theme = Theme.of(context);
    return _GlassCard(
      glowColor: alert.riskLevel.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_fire_department, color: alert.riskLevel.color),
              const SizedBox(width: 8),
              Text(
                'Heatwave Warning',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(alert.forecastSummary, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 16),
          _buildRecommendationBox(context, alert.recommendation, alert.riskLevel.color),
        ],
      ),
    );
  }

  Widget _buildRecommendationBox(BuildContext context, String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
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

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? glowColor;

  const _GlassCard({required this.child, this.glowColor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = glowColor ?? cs.primary;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
