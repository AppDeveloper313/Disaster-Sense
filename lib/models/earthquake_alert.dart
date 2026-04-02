import 'city_alert.dart';

class EarthquakeInfo {
  final String id;
  final double magnitude;
  final double depthKm;
  final double latitude;
  final double longitude;
  final String locationDescription;
  final String quakeTime;

  EarthquakeInfo({
    required this.id,
    required this.magnitude,
    required this.depthKm,
    required this.latitude,
    required this.longitude,
    required this.locationDescription,
    required this.quakeTime,
  });

  factory EarthquakeInfo.fromJson(Map<String, dynamic> json) {
    return EarthquakeInfo(
      id: json['id'] ?? '',
      magnitude: (json['magnitude'] ?? 0).toDouble(),
      depthKm: (json['depth_km'] ?? 0).toDouble(),
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      locationDescription: json['location_description'] ?? '',
      quakeTime: json['quake_time'] ?? '',
    );
  }
}

class EarthquakeAlert {
  final String city;
  final RiskLevel riskLevel;
  final bool alertTriggered;
  final double distanceKm;
  final String recommendation;
  final EarthquakeInfo? earthquake;
  final String? timestamp;

  EarthquakeAlert({
    required this.city,
    required this.riskLevel,
    required this.alertTriggered,
    required this.distanceKm,
    required this.recommendation,
    this.earthquake,
    this.timestamp,
  });

  factory EarthquakeAlert.fromJson(Map<String, dynamic> json) {
    return EarthquakeAlert(
      city: json['city'] ?? '',
      riskLevel: parseRiskLevel(json['risk_level']),
      alertTriggered: json['alert_triggered'] ?? false,
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      recommendation: json['recommendation'] ?? '',
      earthquake: json['earthquake'] != null
          ? EarthquakeInfo.fromJson(json['earthquake'])
          : null,
      timestamp: json['timestamp'],
    );
  }
}

class EarthquakeRiskResponse {
  final String timestamp;
  final int totalQuakesFound;
  final int citiesAnalyzed;
  final List<EarthquakeAlert> alerts;
  final List<String> errors;

  EarthquakeRiskResponse({
    required this.timestamp,
    required this.totalQuakesFound,
    required this.citiesAnalyzed,
    required this.alerts,
    required this.errors,
  });

  factory EarthquakeRiskResponse.fromJson(Map<String, dynamic> json) {
    return EarthquakeRiskResponse(
      timestamp: json['timestamp'] ?? '',
      totalQuakesFound: json['total_quakes_found'] ?? 0,
      citiesAnalyzed: json['cities_analyzed'] ?? 0,
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((e) => EarthquakeAlert.fromJson(e))
              .toList() ??
          [],
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
