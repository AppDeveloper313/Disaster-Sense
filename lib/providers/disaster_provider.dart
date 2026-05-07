import 'package:flutter/foundation.dart';
import '../models/city_alert.dart';
import '../models/earthquake_alert.dart';
import '../models/heatwave_alert.dart';
import '../models/alert_log_entry.dart';
import '../services/api_service.dart';
import '../services/alert_history_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Import notification service only on non-web
import '../services/notification_service.dart'
    if (dart.library.html) '../services/notification_service_stub.dart';

class CityData {
  final CityAlert? floodAlert;
  final EarthquakeAlert? earthquakeAlert;
  final HeatwaveAlert? heatwaveAlert;

  CityData({this.floodAlert, this.earthquakeAlert, this.heatwaveAlert});

  RiskLevel get overallRisk {
    final floodRisk = floodAlert?.riskLevel ?? RiskLevel.unknown;
    final quakeRisk = earthquakeAlert?.riskLevel ?? RiskLevel.unknown;
    final heatRisk = heatwaveAlert?.riskLevel ?? RiskLevel.unknown;

    if (floodRisk == RiskLevel.high || quakeRisk == RiskLevel.high || heatRisk == RiskLevel.high) {
      return RiskLevel.high;
    }
    if (floodRisk == RiskLevel.medium || quakeRisk == RiskLevel.medium || heatRisk == RiskLevel.medium) {
      return RiskLevel.medium;
    }
    if (floodRisk == RiskLevel.low || quakeRisk == RiskLevel.low || heatRisk == RiskLevel.low) {
      return RiskLevel.low;
    }
    return RiskLevel.unknown;
  }
}

class DisasterProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AlertHistoryService _historyService = AlertHistoryService();

  bool _isLoading = false;
  String? _error;
  String? _lastUpdated;
  Map<String, CityData> _cityData = {};
  List<CityAlert> _floodAlerts = [];
  List<EarthquakeAlert> _earthquakeAlerts = [];
  List<HeatwaveAlert> _heatwaveAlerts = [];
  String? _currentCity;
  Position? _currentPosition;

  // Alert log (newest first) — loaded from SharedPreferences on demand
  List<AlertLogEntry> _alertLog = [];
  bool _logLoaded = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastUpdated => _lastUpdated;
  Map<String, CityData> get cityData => _cityData;
  List<CityAlert> get floodAlerts => _floodAlerts;
  List<EarthquakeAlert> get earthquakeAlerts => _earthquakeAlerts;
  List<HeatwaveAlert> get heatwaveAlerts => _heatwaveAlerts;
  String? get currentCity => _currentCity;
  Position? get currentPosition => _currentPosition;
  List<AlertLogEntry> get alertLog => _alertLog;

  final List<String> _cities = [
    'Karachi', 'Lahore', 'Peshawar', 'Quetta', 'Sukkur'
  ];
  List<String> get cities => _cities;

  CityData? getCityData(String city) => _cityData[city];

  // ── Fetch all data ───────────────────────────────────────────────────────────
  Future<void> fetchAllData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _determinePosition();

      final results = await Future.wait([
        _apiService.getFloodRisk(),
        _apiService.getEarthquakeRisk(),
        _apiService.getHeatwaveRisk(),
      ]);

      final floodResponse = results[0] as FloodRiskResponse;
      final earthquakeResponse = results[1] as EarthquakeRiskResponse;
      final heatwaveResponse = results[2] as HeatwaveRiskResponse;

      final previous = Map<String, CityData>.from(_cityData);
      _cityData = {};

      for (final city in cities) {
        final floodAlert = floodResponse.alerts
            .where((a) => a.city.toLowerCase() == city.toLowerCase())
            .firstOrNull;
        final quakeAlert = earthquakeResponse.alerts
            .where((a) => a.city.toLowerCase() == city.toLowerCase())
            .firstOrNull;
        final heatAlert = heatwaveResponse.alerts
            .where((a) => a.city.toLowerCase() == city.toLowerCase())
            .firstOrNull;

        _cityData[city] = CityData(
          floodAlert: floodAlert,
          earthquakeAlert: quakeAlert,
          heatwaveAlert: heatAlert,
        );
      }

      _lastUpdated = floodResponse.timestamp;
      _error = null;

      // ── Post-fetch side-effects ─────────────────────────────────────────────
      await Future.wait([
        _logAndNotifyAlerts(previous),
        _persistRiskSnapshot(),
      ]);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Log new alerts & fire notifications ─────────────────────────────────────
  Future<void> _logAndNotifyAlerts(Map<String, CityData> previous) async {
    final newEntries = <AlertLogEntry>[];

    for (final city in cities) {
      final data = _cityData[city];
      if (data == null) continue;

      final prevData = previous[city];

      // ── Flood ──────────────────────────────────────────────────────────────
      final fRisk = data.floodAlert?.riskLevel ?? RiskLevel.unknown;
      final prevFRisk = prevData?.floodAlert?.riskLevel ?? RiskLevel.unknown;
      if (fRisk != prevFRisk || prevData == null) {
        final msg = data.floodAlert?.forecastSummary ??
            '${fRisk.label} flood risk detected.';
        newEntries.add(AlertLogEntry(
          city: city,
          type: 'flood',
          riskLevel: fRisk,
          message: msg,
          timestamp: DateTime.now(),
        ));

        // Notify on escalation to HIGH or MEDIUM
        if ((fRisk == RiskLevel.high || fRisk == RiskLevel.medium) &&
            fRisk != prevFRisk) {
          final emoji = fRisk == RiskLevel.high ? '🚨' : '⚠️';
          final body = '${data.floodAlert?.forecastSummary ?? ''} ${data.floodAlert?.recommendation ?? ''}'.trim();
          await _fireNotification(
            city: city,
            type: 'flood',
            title: '$emoji ${fRisk.label} Flood Risk – $city',
            body: body.isNotEmpty ? body : '${fRisk.label} flood risk detected in $city.',
          );
        }
      }

      // ── Earthquake ─────────────────────────────────────────────────────────
      final qRisk = data.earthquakeAlert?.riskLevel ?? RiskLevel.unknown;
      final prevQRisk =
          prevData?.earthquakeAlert?.riskLevel ?? RiskLevel.unknown;
      if (qRisk != prevQRisk || prevData == null) {
        final msg = data.earthquakeAlert?.recommendation ??
            '${qRisk.label} earthquake risk detected.';
        newEntries.add(AlertLogEntry(
          city: city,
          type: 'earthquake',
          riskLevel: qRisk,
          message: msg,
          timestamp: DateTime.now(),
        ));

        if ((qRisk == RiskLevel.high || qRisk == RiskLevel.medium) &&
            qRisk != prevQRisk) {
          final emoji = qRisk == RiskLevel.high ? '🚨' : '⚠️';
          final magInfo = data.earthquakeAlert?.earthquake != null
              ? 'M${data.earthquakeAlert!.earthquake!.magnitude.toStringAsFixed(1)} detected. '
              : '';
          final body = '$magInfo${data.earthquakeAlert?.recommendation ?? ''}'.trim();
          await _fireNotification(
            city: city,
            type: 'earthquake',
            title: '$emoji ${qRisk.label} Earthquake Risk – $city',
            body: body.isNotEmpty ? body : '${qRisk.label} earthquake risk detected in $city.',
          );
        }
      }

      // ── Heatwave ───────────────────────────────────────────────────────────
      final hRisk = data.heatwaveAlert?.riskLevel ?? RiskLevel.unknown;
      final prevHRisk =
          prevData?.heatwaveAlert?.riskLevel ?? RiskLevel.unknown;
      if (hRisk != prevHRisk || prevData == null) {
        final msg = data.heatwaveAlert?.forecastSummary ??
            '${hRisk.label} heatwave risk detected.';
        newEntries.add(AlertLogEntry(
          city: city,
          type: 'heatwave',
          riskLevel: hRisk,
          message: msg,
          timestamp: DateTime.now(),
        ));

        if ((hRisk == RiskLevel.high || hRisk == RiskLevel.medium) &&
            hRisk != prevHRisk) {
          final emoji = hRisk == RiskLevel.high ? '🔥' : '🌡️';
          final tempInfo = data.heatwaveAlert != null
              ? 'Max temp: ${data.heatwaveAlert!.maxTemperature.toStringAsFixed(0)}°C. '
              : '';
          final body = '$tempInfo${data.heatwaveAlert?.recommendation ?? ''}'.trim();
          await _fireNotification(
            city: city,
            type: 'heatwave',
            title: '$emoji ${hRisk.label} Heatwave Risk – $city',
            body: body.isNotEmpty ? body : '${hRisk.label} heatwave risk detected in $city.',
          );
        }
      }
    }

    if (newEntries.isNotEmpty) {
      await _historyService.addEntries(newEntries);
      // Prepend to in-memory list (avoid full reload)
      _alertLog = [...newEntries, ..._alertLog];
      // Cap in-memory list
      if (_alertLog.length > 200) _alertLog = _alertLog.sublist(0, 200);
    }
  }

  /// Fire a push notification (non-web only).
  Future<void> _fireNotification({
    required String city,
    required String type,
    required String title,
    required String body,
  }) async {
    if (!kIsWeb) {
      try {
        await NotificationService().showRiskAlert(
          id: NotificationService.notificationId(city, type),
          title: title,
          body: body,
          payload: 'city:$city:$type',
          disasterType: type,
        );
      } catch (_) {}
    }
  }

  // ── Save risk score snapshot for sparklines ──────────────────────────────────
  Future<void> _persistRiskSnapshot() async {
    final scores = <String, int>{};
    for (final city in cities) {
      scores[city] = riskScore(_cityData[city]?.overallRisk ?? RiskLevel.unknown);
    }
    await _historyService.appendRiskSnapshot(scores);
  }

  // ── Load alert log (called by AlertHistoryScreen) ────────────────────────────
  Future<void> loadAlertLog() async {
    if (_logLoaded) return;
    _alertLog = await _historyService.loadAll();
    _logLoaded = true;
    notifyListeners();
  }

  Future<void> refreshAlertLog() async {
    _alertLog = await _historyService.loadAll();
    notifyListeners();
  }

  Future<void> clearAlertLog() async {
    await _historyService.clearAll();
    _alertLog = [];
    notifyListeners();
  }

  // ── Risk sparkline data ──────────────────────────────────────────────────────
  Future<List<double>> getRiskHistory(String city) =>
      _historyService.getRiskHistory(city);

  // ── Fetch alerts tab data ────────────────────────────────────────────────────
  Future<void> fetchAlerts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _apiService.getFloodRisk(), // the alerts-only logic is basically similar
        _apiService.getEarthquakeAlerts(),
        _apiService.getHeatwaveRisk(), // Since there isn't an alerts-only endpoint for heatwave yet, fetch full
      ]);

      final floodResponse = results[0] as FloodRiskResponse;
      final earthquakeResponse = results[1] as EarthquakeRiskResponse;
      final heatwaveResponse = results[2] as HeatwaveRiskResponse;

      _floodAlerts = floodResponse.alerts.where((a) => a.riskLevel == RiskLevel.high || a.riskLevel == RiskLevel.medium).toList();
      _earthquakeAlerts = earthquakeResponse.alerts;
      _heatwaveAlerts = heatwaveResponse.alerts.where((a) => a.riskLevel == RiskLevel.high || a.riskLevel == RiskLevel.medium).toList();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await Future.wait([fetchAllData(), fetchAlerts()]);
  }

  // ── Location ─────────────────────────────────────────────────────────────────
  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.low),
      );
      _currentPosition = position;

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final city = placemarks.first.locality ??
            placemarks.first.subAdministrativeArea;
        if (city != null && city.isNotEmpty) {
          final matched = _cities.firstWhere(
            (c) => c.toLowerCase() == city.toLowerCase(),
            orElse: () => city,
          );
          _currentCity = matched;
          if (!_cities.contains(_currentCity)) {
            _cities.add(_currentCity!);
          }
        }
      }
    } catch (_) {}
  }
}
