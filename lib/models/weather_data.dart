import 'package:flutter/material.dart';

class DailyForecast {
  final String date;
  final double? tempMaxC;
  final double? tempMinC;
  final double? precipitationMm;
  final String condition;
  final String conditionIcon;

  DailyForecast({
    required this.date,
    this.tempMaxC,
    this.tempMinC,
    this.precipitationMm,
    required this.condition,
    required this.conditionIcon,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: json['date'] ?? '',
      tempMaxC: (json['temp_max_c'] as num?)?.toDouble(),
      tempMinC: (json['temp_min_c'] as num?)?.toDouble(),
      precipitationMm: (json['precipitation_mm'] as num?)?.toDouble(),
      condition: json['condition'] ?? '',
      conditionIcon: json['condition_icon'] ?? '',
    );
  }
}

class AirQuality {
  final double? pm25;
  final int? usAqi;
  final String category;
  final String colorHex;

  AirQuality({
    this.pm25,
    this.usAqi,
    required this.category,
    required this.colorHex,
  });

  factory AirQuality.fromJson(Map<String, dynamic> json) {
    return AirQuality(
      pm25: (json['pm2_5'] as num?)?.toDouble(),
      usAqi: json['us_aqi'] as int?,
      category: json['category'] ?? 'Unknown',
      colorHex: json['color'] ?? '#9E9E9E',
    );
  }

  Color get color {
    try {
      final hex = colorHex.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
}

class WeatherData {
  final String city;
  final String timestamp;
  final double? temperatureC;
  final double? feelsLikeC;
  final int? humidityPct;
  final double? windSpeedKmh;
  final String condition;
  final String conditionIcon;
  final AirQuality? airQuality;
  final List<DailyForecast> forecast;

  WeatherData({
    required this.city,
    required this.timestamp,
    this.temperatureC,
    this.feelsLikeC,
    this.humidityPct,
    this.windSpeedKmh,
    required this.condition,
    required this.conditionIcon,
    this.airQuality,
    this.forecast = const [],
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      city: json['city'] ?? '',
      timestamp: json['timestamp'] ?? '',
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      feelsLikeC: (json['feels_like_c'] as num?)?.toDouble(),
      humidityPct: json['humidity_pct'] as int?,
      windSpeedKmh: (json['wind_speed_kmh'] as num?)?.toDouble(),
      condition: json['condition'] ?? 'Unknown',
      conditionIcon: json['condition_icon'] ?? '🌡️',
      airQuality: json['air_quality'] != null
          ? AirQuality.fromJson(json['air_quality'])
          : null,
      forecast: (json['forecast'] as List<dynamic>?)
              ?.map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
