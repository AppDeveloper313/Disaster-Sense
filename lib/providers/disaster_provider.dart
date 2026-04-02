import 'package:flutter/material.dart';
import '../models/city_alert.dart';
import '../models/earthquake_alert.dart';
import '../services/api_service.dart';

class CityData {
  final CityAlert? floodAlert;
  final EarthquakeAlert? earthquakeAlert;

  CityData({this.floodAlert, this.earthquakeAlert});

  RiskLevel get overallRisk {
    final floodRisk = floodAlert?.riskLevel ?? RiskLevel.unknown;
    final quakeRisk = earthquakeAlert?.riskLevel ?? RiskLevel.unknown;

    if (floodRisk == RiskLevel.high || quakeRisk == RiskLevel.high) {
      return RiskLevel.high;
    }
    if (floodRisk == RiskLevel.medium || quakeRisk == RiskLevel.medium) {
      return RiskLevel.medium;
    }
    if (floodRisk == RiskLevel.low || quakeRisk == RiskLevel.low) {
      return RiskLevel.low;
    }
    return RiskLevel.unknown;
  }
}

class DisasterProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  String? _error;
  String? _lastUpdated;

  Map<String, CityData> _cityData = {};
  List<CityAlert> _floodAlerts = [];
  List<EarthquakeAlert> _earthquakeAlerts = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastUpdated => _lastUpdated;
  Map<String, CityData> get cityData => _cityData;
  List<CityAlert> get floodAlerts => _floodAlerts;
  List<EarthquakeAlert> get earthquakeAlerts => _earthquakeAlerts;

  List<String> get cities =>
      ['Karachi', 'Lahore', 'Peshawar', 'Quetta', 'Sukkur'];

  CityData? getCityData(String city) => _cityData[city];

  Future<void> fetchAllData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getFloodRisk(),
        _apiService.getEarthquakeRisk(),
      ]);

      final floodResponse = results[0] as FloodRiskResponse;
      final earthquakeResponse = results[1] as EarthquakeRiskResponse;

      _cityData = {};

      for (final city in cities) {
        final floodAlert = floodResponse.alerts
            .where((a) => a.city.toLowerCase() == city.toLowerCase())
            .firstOrNull;

        final quakeAlert = earthquakeResponse.alerts
            .where((a) => a.city.toLowerCase() == city.toLowerCase())
            .firstOrNull;

        _cityData[city] = CityData(
          floodAlert: floodAlert,
          earthquakeAlert: quakeAlert,
        );
      }

      _lastUpdated = floodResponse.timestamp;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchAlerts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getFloodAlerts(),
        _apiService.getEarthquakeAlerts(),
      ]);

      final floodResponse = results[0] as FloodRiskResponse;
      final earthquakeResponse = results[1] as EarthquakeRiskResponse;

      _floodAlerts = floodResponse.alerts;
      _earthquakeAlerts = earthquakeResponse.alerts;
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait([
      fetchAllData(),
      fetchAlerts(),
    ]);
  }
}
