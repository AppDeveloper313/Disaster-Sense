import 'package:flutter/material.dart';

enum RiskLevel { low, medium, high, unknown }

extension RiskLevelExtension on RiskLevel {
  Color get color {
    switch (this) {
      case RiskLevel.low:
        return Colors.green;
      case RiskLevel.medium:
        return Colors.amber;
      case RiskLevel.high:
        return Colors.red;
      case RiskLevel.unknown:
        return Colors.grey;
    }
  }

  String get label {
    switch (this) {
      case RiskLevel.low:
        return 'Low';
      case RiskLevel.medium:
        return 'Medium';
      case RiskLevel.high:
        return 'High';
      case RiskLevel.unknown:
        return 'Unknown';
    }
  }

  IconData get icon {
    switch (this) {
      case RiskLevel.low:
        return Icons.check_circle;
      case RiskLevel.medium:
        return Icons.warning;
      case RiskLevel.high:
        return Icons.error;
      case RiskLevel.unknown:
        return Icons.help;
    }
  }
}

RiskLevel parseRiskLevel(String? value) {
  switch (value?.toLowerCase()) {
    case 'low':
      return RiskLevel.low;
    case 'medium':
      return RiskLevel.medium;
    case 'high':
      return RiskLevel.high;
    default:
      return RiskLevel.unknown;
  }
}

class CityAlert {
  final String city;
  final RiskLevel riskLevel;
  final double rainfall3dayMm;
  final bool alertTriggered;
  final String forecastSummary;
  final String recommendation;
  final String? timestamp;

  CityAlert({
    required this.city,
    required this.riskLevel,
    required this.rainfall3dayMm,
    required this.alertTriggered,
    required this.forecastSummary,
    required this.recommendation,
    this.timestamp,
  });

  factory CityAlert.fromJson(Map<String, dynamic> json) {
    return CityAlert(
      city: json['city'] ?? '',
      riskLevel: parseRiskLevel(json['risk_level']),
      rainfall3dayMm: (json['cumulative_rainfall_3day_mm'] ?? 0).toDouble(),
      alertTriggered: json['alert_triggered'] ?? false,
      forecastSummary: json['forecast_summary'] ?? '',
      recommendation: json['recommendation'] ?? '',
      timestamp: json['timestamp'],
    );
  }
}

class FloodRiskResponse {
  final String timestamp;
  final int citiesAnalyzed;
  final List<CityAlert> alerts;
  final List<String> errors;

  FloodRiskResponse({
    required this.timestamp,
    required this.citiesAnalyzed,
    required this.alerts,
    required this.errors,
  });

  factory FloodRiskResponse.fromJson(Map<String, dynamic> json) {
    return FloodRiskResponse(
      timestamp: json['timestamp'] ?? '',
      citiesAnalyzed: json['cities_analyzed'] ?? 0,
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((e) => CityAlert.fromJson(e))
              .toList() ??
          [],
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
