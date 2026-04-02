import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/city_alert.dart';
import '../models/earthquake_alert.dart';

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
    try {
      final response = await http
          .get(_uri('/api/flood-risk'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return FloodRiskResponse.fromJson(json.decode(response.body));
      } else {
        throw ApiException(
          'Failed to fetch flood risk: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<EarthquakeRiskResponse> getEarthquakeRisk() async {
    try {
      final response = await http
          .get(_uri('/api/earthquake-risk'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return EarthquakeRiskResponse.fromJson(json.decode(response.body));
      } else {
        throw ApiException(
          'Failed to fetch earthquake risk: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<FloodRiskResponse> getFloodAlerts() async {
    try {
      final response = await http
          .get(_uri('/api/flood-risk/alerts-only'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
      } else {
        throw ApiException(
          'Failed to fetch flood alerts: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }

  Future<EarthquakeRiskResponse> getEarthquakeAlerts() async {
    try {
      final response = await http
          .get(_uri('/api/earthquake-risk/alerts-only'))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
      } else {
        throw ApiException(
          'Failed to fetch earthquake alerts: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Network error: $e');
    }
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}
