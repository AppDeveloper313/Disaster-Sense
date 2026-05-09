import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/disaster_provider.dart';
import '../models/city_alert.dart';
import 'city_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  /// Build LatLng map from the provider's canonical city coordinates.
  Map<String, LatLng> get _cityCoordinates {
    return DisasterProvider.cityCoords.map(
      (name, coords) => MapEntry(name, LatLng(coords[0], coords[1])),
    );
  }

  (Color, IconData) _getMarkerStyle(CityData data) {
    // 1. Check for High risks first
    if (data.heatwaveAlert?.riskLevel == RiskLevel.high) {
      return (Colors.red, Icons.local_fire_department);
    }
    if (data.earthquakeAlert?.riskLevel == RiskLevel.high) {
      return (Colors.brown, Icons.broken_image);
    }
    if (data.floodAlert?.riskLevel == RiskLevel.high) {
      return (Colors.blue, Icons.water_drop);
    }

    // 2. Check for Medium risks
    if (data.heatwaveAlert?.riskLevel == RiskLevel.medium) {
      return (Colors.orange, Icons.local_fire_department);
    }
    if (data.earthquakeAlert?.riskLevel == RiskLevel.medium) {
      return (Colors.deepPurple, Icons.broken_image);
    }
    if (data.floodAlert?.riskLevel == RiskLevel.medium) {
      return (Colors.lightBlue, Icons.water_drop);
    }

    // 3. Low risk default
    return (Colors.green, Icons.location_on);
  }

  String _formatDistance(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<DisasterProvider>().fetchAllData(),
          ),
        ],
      ),
      body: Consumer<DisasterProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.cityData.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final markers = <Marker>[];
          final polylines = <Polyline>[];
          final nearbyNames = provider.nearestCities.map((c) => c.name).toSet();

          // ── User location marker ────────────────────────────────────────
          LatLng? userLatLng;
          if (provider.currentPosition != null) {
            userLatLng = LatLng(
              provider.currentPosition!.latitude,
              provider.currentPosition!.longitude,
            );

            markers.add(
              Marker(
                width: 90.0,
                height: 60.0,
                point: userLatLng,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_pin_circle,
                              size: 12, color: cs.primary),
                          const SizedBox(width: 2),
                          Text(
                            'You',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Pulsing blue dot
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primary.withValues(alpha: 0.25),
                      ),
                      alignment: Alignment.center,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cs.primary,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ── City markers ────────────────────────────────────────────────
          for (final city in provider.allCities) {
            final data = provider.getCityData(city);
            LatLng? coordinates = _cityCoordinates[city];

            // For user's current city not in the predefined list, use GPS coords
            if (coordinates == null &&
                city == provider.currentCity &&
                provider.currentPosition != null) {
              coordinates = LatLng(provider.currentPosition!.latitude,
                  provider.currentPosition!.longitude);
            }

            if (data != null && coordinates != null) {
              final (color, iconData) = _getMarkerStyle(data);
              final isNearby = nearbyNames.contains(city);
              final nearbyIndex = provider.nearestCities
                  .indexWhere((c) => c.name == city);

              // ── Draw line from user to nearby city ────────────────────
              if (isNearby && userLatLng != null) {
                polylines.add(
                  Polyline(
                    points: [userLatLng, coordinates],
                    strokeWidth: nearbyIndex == 0 ? 2.5 : 1.5,
                    color: nearbyIndex == 0
                        ? cs.primary.withValues(alpha: 0.7)
                        : cs.onSurfaceVariant.withValues(alpha: 0.35),
                    pattern: StrokePattern.dashed(segments: [8, 4]),
                  ),
                );
              }

              markers.add(
                Marker(
                  width: isNearby ? 160.0 : 140.0,
                  height: isNearby ? 95.0 : 80.0,
                  point: coordinates,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CityDetailScreen(
                            cityName: city,
                            data: data,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // City name label
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isNearby
                                ? cs.primaryContainer
                                : theme.cardColor,
                            borderRadius: BorderRadius.circular(6),
                            border: isNearby
                                ? Border.all(
                                    color: cs.primary.withValues(alpha: 0.5),
                                    width: 1)
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Rank badge for nearby cities
                              if (isNearby && nearbyIndex >= 0) ...[
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: nearbyIndex == 0
                                        ? cs.primary
                                        : cs.onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${nearbyIndex + 1}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: nearbyIndex == 0
                                          ? cs.onPrimary
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                city,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isNearby
                                      ? cs.onPrimaryContainer
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Distance label for nearby cities
                        if (isNearby && nearbyIndex >= 0) ...[
                          const SizedBox(height: 1),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDistance(
                                  provider.nearestCities[nearbyIndex]
                                      .distanceKm),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],

                        // Disaster icon
                        Icon(
                          iconData,
                          color: color,
                          size: isNearby ? 36.0 : 32.0,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          }

          // Center roughly on Pakistan or user's location
          final center = provider.currentPosition != null
              ? LatLng(provider.currentPosition!.latitude,
                  provider.currentPosition!.longitude)
              : const LatLng(30.3753, 69.3451);
          final zoom = provider.currentPosition != null ? 7.0 : 5.0;

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: zoom,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.disaster_sense',
                  ),
                  PolylineLayer(polylines: polylines),
                  MarkerLayer(markers: markers),
                ],
              ),

              // ── Nearest-cities legend overlay ─────────────────────────────
              if (provider.nearestCities.isNotEmpty)
                Positioned(
                  bottom: 16,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.near_me, size: 14, color: cs.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Nearest Cities',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(provider.nearestCities.length, (i) {
                          final nc = provider.nearestCities[i];
                          final data = provider.getCityData(nc.name);
                          final risk =
                              data?.overallRisk ?? RiskLevel.unknown;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: GestureDetector(
                              onTap: data == null
                                  ? null
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CityDetailScreen(
                                            cityName: nc.name,
                                            data: data,
                                          ),
                                        ),
                                      ),
                              child: Row(
                                children: [
                                  // Rank
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: i == 0
                                          ? cs.primary
                                          : cs.onSurfaceVariant
                                              .withValues(alpha: 0.15),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${i + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: i == 0
                                            ? cs.onPrimary
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Name
                                  Expanded(
                                    child: Text(
                                      nc.name,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  // Distance
                                  Text(
                                    _formatDistance(nc.distanceKm),
                                    style:
                                        theme.textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Risk dot
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: risk.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
