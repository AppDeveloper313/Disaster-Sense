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
  final Map<String, LatLng> _cityCoordinates = {
    'Karachi': const LatLng(24.8607, 67.0011),
    'Lahore': const LatLng(31.5497, 74.3436),
    'Peshawar': const LatLng(34.0151, 71.5249),
    'Quetta': const LatLng(30.1798, 66.9750),
    'Sukkur': const LatLng(27.7138, 68.8673),
  };

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

  @override
  Widget build(BuildContext context) {
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

          for (final city in provider.cities) {
            final data = provider.getCityData(city);
            LatLng? coordinates = _cityCoordinates[city];
            
            if (coordinates == null && city == provider.currentCity && provider.currentPosition != null) {
              coordinates = LatLng(provider.currentPosition!.latitude, provider.currentPosition!.longitude);
            }

            if (data != null && coordinates != null) {
              final (color, iconData) = _getMarkerStyle(data);
              
              markers.add(
                Marker(
                  width: 80.0,
                  height: 80.0,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          child: Text(
                            city == provider.currentCity ? '$city (You)' : city,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Icon(
                          iconData,
                          color: color,
                          size: 40.0,
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
              ? LatLng(provider.currentPosition!.latitude, provider.currentPosition!.longitude)
              : const LatLng(30.3753, 69.3451);
          final zoom = provider.currentPosition != null ? 7.0 : 5.0;

          return FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: zoom,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.disaster_sense',
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }
}
