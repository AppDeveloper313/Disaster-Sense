import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/city_alert.dart';
import '../models/earthquake_alert.dart';
import '../models/heatwave_alert.dart';
import '../models/weather_data.dart';

class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8000';
    }
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<FloodRiskResponse> getFloodRisk() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'cache_flood_risk';
    try {
      final response = await http
          .get(_uri('/api/flood-risk'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        return FloodRiskResponse.fromJson(json.decode(response.body));
      } else {
        throw ApiException(
          'Failed to fetch flood risk: ${response.statusCode}',
        );
      }
    } catch (e) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        return FloodRiskResponse.fromJson(json.decode(cachedData));
      }
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<EarthquakeRiskResponse> getEarthquakeRisk() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'cache_earthquake_risk';
    try {
      final response = await http
          .get(_uri('/api/earthquake-risk'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        return EarthquakeRiskResponse.fromJson(json.decode(response.body));
      } else {
        throw ApiException(
          'Failed to fetch earthquake risk: ${response.statusCode}',
        );
      }
    } catch (e) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        return EarthquakeRiskResponse.fromJson(json.decode(cachedData));
      }
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<FloodRiskResponse> getFloodAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'cache_flood_alerts';
    try {
      final response = await http
          .get(_uri('/api/flood-risk/alerts-only'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        final data = json.decode(response.body);
        return _parseFloodAlerts(data);
      } else {
        throw ApiException(
          'Failed to fetch flood alerts: ${response.statusCode}',
        );
      }
    } catch (e) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final data = json.decode(cachedData);
        return _parseFloodAlerts(data);
      }
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  FloodRiskResponse _parseFloodAlerts(Map<String, dynamic> data) {
    return FloodRiskResponse(
      timestamp: data['timestamp'] ?? '',
      citiesAnalyzed: data['total_cities_checked'] ?? 0,
      alerts:
          (data['alerts'] as List<dynamic>?)
              ?.map((e) => CityAlert.fromJson(e))
              .toList() ??
          [],
      errors:
          (data['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Future<EarthquakeRiskResponse> getEarthquakeAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'cache_earthquake_alerts';
    try {
      final response = await http
          .get(_uri('/api/earthquake-risk/alerts-only'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        final data = json.decode(response.body);
        return _parseEarthquakeAlerts(data);
      } else {
        throw ApiException(
          'Failed to fetch earthquake alerts: ${response.statusCode}',
        );
      }
    } catch (e) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        final data = json.decode(cachedData);
        return _parseEarthquakeAlerts(data);
      }
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  EarthquakeRiskResponse _parseEarthquakeAlerts(Map<String, dynamic> data) {
    return EarthquakeRiskResponse(
      timestamp: data['timestamp'] ?? '',
      totalQuakesFound: data['total_quakes_found'] ?? 0,
      citiesAnalyzed: data['total_cities_checked'] ?? 0,
      alerts:
          (data['alerts'] as List<dynamic>?)
              ?.map((e) => EarthquakeAlert.fromJson(e))
              .toList() ??
          [],
      errors:
          (data['errors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Future<WeatherData?> getWeather(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cache_weather_${city.toLowerCase()}';
    try {
      final response = await http
          .get(_uri('/api/weather/${Uri.encodeComponent(city)}'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        return WeatherData.fromJson(json.decode(response.body));
      }
      return null;
    } catch (_) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        return WeatherData.fromJson(json.decode(cachedData));
      }
      return null;
    }
  }

  Future<HeatwaveRiskResponse> getHeatwaveRisk() async {
    final prefs = await SharedPreferences.getInstance();
    const cacheKey = 'cache_heatwave_risk';
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/heatwave-risk'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        prefs.setString(cacheKey, response.body);
        return HeatwaveRiskResponse.fromJson(json.decode(response.body));
      } else {
        throw ApiException('Failed to fetch heatwave risk: ${response.statusCode}');
      }
    } catch (e) {
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        return HeatwaveRiskResponse.fromJson(json.decode(cachedData));
      }
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<String?> getCityAiSummary(String city) async {
    try {
      final response = await http.post(
        _uri('/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': 'Provide a concise disaster risk assessment summary for $city based on current data. Explain any active warnings or anomalies without generic fluff.',
          'city': city,
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['response'] as String;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching AI summary: $e');
      return null;
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
