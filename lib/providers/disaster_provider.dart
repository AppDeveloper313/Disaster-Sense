import 'dart:math';
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

/// A monitored city sorted by distance from the user.
class NearbyCity {
  final String name;
  final double distanceKm;
  final double lat;
  final double lon;

  NearbyCity({
    required this.name,
    required this.distanceKm,
    required this.lat,
    required this.lon,
  });
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
  List<NearbyCity> _nearestCities = [];

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
  List<NearbyCity> get nearestCities => _nearestCities;
  List<AlertLogEntry> get alertLog => _alertLog;

  // Coordinates for all monitored cities (lat, lon)
  static const Map<String, List<double>> cityCoords = {
    // ── Sindh ────────────────────────────────────────────
    'Karachi':         [24.8607, 67.0011],
    'Hyderabad':       [25.3960, 68.3578],
    'Sukkur':          [27.7052, 68.8574],
    'Larkana':         [27.5570, 68.2141],
    'Nawabshah':       [26.2483, 68.4100],
    'Mirpur Khas':     [25.5276, 69.0159],
    'Khairpur':        [27.5295, 68.7592],
    'Jacobabad':       [28.2769, 68.4514],
    'Dadu':            [26.7319, 67.7752],
    'Badin':           [24.6561, 68.8372],
    'Thatta':          [24.7461, 67.9236],
    'Tando Adam':      [25.7646, 68.6618],
    // ── Punjab ───────────────────────────────────────────
    'Lahore':          [31.5497, 74.3436],
    'Faisalabad':      [31.4504, 73.1350],
    'Rawalpindi':      [33.5651, 73.0169],
    'Multan':          [30.1575, 71.6836],
    'Gujranwala':      [32.1877, 74.1945],
    'Sialkot':         [32.4945, 74.5229],
    'Bahawalpur':      [29.3956, 71.6836],
    'Sargodha':        [32.0836, 72.6711],
    'Jhang':           [31.2681, 72.3181],
    'Sheikhupura':     [31.7167, 73.9850],
    'Rahim Yar Khan':  [28.4202, 70.2952],
    'Gujrat':          [32.5742, 74.0789],
    'Sahiwal':         [30.6682, 73.1114],
    'Kasur':           [31.1176, 74.4508],
    'Okara':           [30.8138, 73.4534],
    'Jhelum':          [32.9425, 73.7257],
    'Khanewal':        [30.3018, 71.9321],
    'Muzaffargarh':    [30.0734, 71.1936],
    'Dera Ghazi Khan': [30.0489, 70.6455],
    'Mianwali':        [32.5839, 71.5370],
    'Chakwal':         [32.9328, 72.8556],
    'Attock':          [33.7667, 72.3597],
    'Chiniot':         [31.7200, 72.9789],
    'Vehari':          [30.0450, 72.3489],
    'Lodhran':         [29.5339, 71.6333],
    'Sadiqabad':       [28.3091, 70.1327],
    'Bhakkar':         [31.6082, 71.0648],
    'Layyah':          [30.9693, 70.9428],
    'Nankana Sahib':   [31.4500, 73.7083],
    // ── Khyber Pakhtunkhwa ───────────────────────────────
    'Peshawar':        [34.0151, 71.5249],
    'Mardan':          [34.1986, 72.0404],
    'Mingora':         [34.7717, 72.3600],
    'Abbottabad':      [34.1463, 73.2117],
    'Kohat':           [33.5869, 71.4414],
    'Dera Ismail Khan':[31.8626, 70.9019],
    'Nowshera':        [34.0153, 71.9747],
    'Swabi':           [34.1200, 72.4700],
    'Mansehra':        [34.3300, 73.2000],
    'Haripur':         [33.9942, 72.9331],
    'Bannu':           [32.9888, 70.6044],
    'Chitral':         [35.8518, 71.7864],
    'Hangu':           [33.5311, 71.0572],
    // ── Balochistan ──────────────────────────────────────
    'Quetta':          [30.1798, 66.9750],
    'Turbat':          [26.0028, 63.0472],
    'Gwadar':          [25.1216, 62.3254],
    'Hub':             [25.0500, 66.8875],
    'Zhob':            [31.3515, 69.4493],
    'Khuzdar':         [27.8000, 66.6100],
    'Chaman':          [30.9210, 66.4597],
    'Noshki':          [29.5530, 66.0130],
    'Sibi':            [29.5430, 67.8770],
    // ── Islamabad Capital Territory ──────────────────────
    'Islamabad':       [33.6844, 73.0479],
    // ── Gilgit-Baltistan ─────────────────────────────────
    'Gilgit':          [35.9208, 74.3144],
    'Skardu':          [35.2972, 75.6308],
    // ── Azad Jammu & Kashmir ─────────────────────────────
    'Muzaffarabad':    [34.3700, 73.4711],
    'Mirpur':          [33.1484, 73.7514],
  };

  // Core cities shown in the default list view
  static const List<String> _coreCities = [
    'Karachi', 'Lahore', 'Peshawar', 'Quetta', 'Sukkur',
  ];

  final List<String> _cities = [..._coreCities];

  /// Core cities (shown by default in the main list).
  List<String> get cities => _cities;

  /// All monitored cities (used for search + nearest-city calculation).
  List<String> get allCities => cityCoords.keys.toList();

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

      for (final city in allCities) {
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

    for (final city in allCities) {
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
    for (final city in allCities) {
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

      // Compute nearest 3 cities by Haversine distance
      _nearestCities = _computeNearestCities(position.latitude, position.longitude, count: 3);

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

  /// Haversine distance in km between two lat/lng points.
  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  /// Returns the [count] nearest monitored cities sorted by distance.
  List<NearbyCity> _computeNearestCities(double userLat, double userLon, {int count = 3}) {
    final entries = cityCoords.entries.map((e) {
      final d = _haversineKm(userLat, userLon, e.value[0], e.value[1]);
      return NearbyCity(name: e.key, distanceKm: d, lat: e.value[0], lon: e.value[1]);
    }).toList();
    entries.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return entries.take(count).toList();
  }
}
