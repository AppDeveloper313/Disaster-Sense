import 'city_alert.dart';

class HeatwaveAlert {
  final String city;
  final RiskLevel riskLevel;
  final double maxTemperature;
  final String forecastSummary;
  final bool alertTriggered;
  final String recommendation;

  HeatwaveAlert({
    required this.city,
    required this.riskLevel,
    required this.maxTemperature,
    required this.forecastSummary,
    required this.alertTriggered,
    required this.recommendation,
  });

  factory HeatwaveAlert.fromJson(Map<String, dynamic> json) {
    return HeatwaveAlert(
      city: json['city'] ?? '',
      riskLevel: parseRiskLevel(json['risk_level']),
      maxTemperature: (json['max_temperature'] ?? 0).toDouble(),
      forecastSummary: json['forecast_summary'] ?? '',
      alertTriggered: json['alert_triggered'] ?? false,
      recommendation: json['recommendation'] ?? '',
    );
  }
}

class HeatwaveRiskResponse {
  final String timestamp;
  final int citiesAnalyzed;
  final List<HeatwaveAlert> alerts;
  final List<String> errors;

  HeatwaveRiskResponse({
    required this.timestamp,
    required this.citiesAnalyzed,
    required this.alerts,
    required this.errors,
  });

  factory HeatwaveRiskResponse.fromJson(Map<String, dynamic> json) {
    return HeatwaveRiskResponse(
      timestamp: json['timestamp'] ?? '',
      citiesAnalyzed: json['cities_analyzed'] ?? 0,
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((e) => HeatwaveAlert.fromJson(e))
              .toList() ??
          [],
      errors: (json['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
