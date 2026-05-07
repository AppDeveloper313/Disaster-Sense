import 'dart:async';
import 'package:workmanager/workmanager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'notification_service.dart';
import '../models/city_alert.dart';
import '../models/earthquake_alert.dart';
import '../models/heatwave_alert.dart';

/// SharedPreferences key prefix for tracking which alerts have already
/// been notified so we don't spam the user on every periodic check.
const _kNotifiedPrefix = 'bg_notified_';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();

      final prefs = await SharedPreferences.getInstance();

      // ── Determine user's current city ──────────────────────────────────────
      String? userCity;
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            Position position = await Geolocator.getCurrentPosition(
              locationSettings:
                  const LocationSettings(accuracy: LocationAccuracy.low),
            );

            List<Placemark> placemarks = await placemarkFromCoordinates(
              position.latitude,
              position.longitude,
            );

            if (placemarks.isNotEmpty) {
              final placemark = placemarks.first;
              userCity =
                  placemark.locality ?? placemark.subAdministrativeArea;
            }
          }
        }
      } catch (_) {
        // Location unavailable — still check all cities
      }

      // ── Fetch all risk data ────────────────────────────────────────────────
      final apiService = ApiService();

      final results = await Future.wait([
        apiService.getFloodRisk(),
        apiService.getEarthquakeRisk(),
        apiService.getHeatwaveRisk(),
      ]);

      final floodResponse = results[0] as FloodRiskResponse;
      final earthquakeResponse = results[1] as EarthquakeRiskResponse;
      final heatwaveResponse = results[2] as HeatwaveRiskResponse;

      // ── Check flood alerts ─────────────────────────────────────────────────
      for (final alert in floodResponse.alerts) {
        if (alert.riskLevel == RiskLevel.high ||
            alert.riskLevel == RiskLevel.medium) {
          final key = '${_kNotifiedPrefix}flood_${alert.city.toLowerCase()}_${alert.riskLevel.name}';
          final alreadyNotified = prefs.getBool(key) ?? false;

          if (!alreadyNotified) {
            final isUserCity =
                userCity != null &&
                alert.city.toLowerCase() == userCity.toLowerCase();

            final emoji = alert.riskLevel == RiskLevel.high ? '🚨' : '⚠️';
            final title =
                '$emoji ${alert.riskLevel.label} Flood Risk: ${alert.city}';
            final body = isUserCity
                ? 'Your area has ${alert.riskLevel.label.toLowerCase()} flood risk. ${alert.forecastSummary} ${alert.recommendation}'
                : '${alert.forecastSummary} ${alert.recommendation}';

            await notificationService.showRiskAlert(
              id: NotificationService.notificationId(alert.city, 'flood'),
              title: title,
              body: body.trim(),
              payload: 'city:${alert.city}:flood',
              disasterType: 'flood',
            );

            await prefs.setBool(key, true);
          }
        } else {
          // Clear notified flag when risk drops so user gets re-notified if it rises again
          await prefs.remove(
              '${_kNotifiedPrefix}flood_${alert.city.toLowerCase()}_high');
          await prefs.remove(
              '${_kNotifiedPrefix}flood_${alert.city.toLowerCase()}_medium');
        }
      }

      // ── Check earthquake alerts ────────────────────────────────────────────
      for (final alert in earthquakeResponse.alerts) {
        if (alert.riskLevel == RiskLevel.high ||
            alert.riskLevel == RiskLevel.medium) {
          final key = '${_kNotifiedPrefix}earthquake_${alert.city.toLowerCase()}_${alert.riskLevel.name}';
          final alreadyNotified = prefs.getBool(key) ?? false;

          if (!alreadyNotified) {
            final isUserCity =
                userCity != null &&
                alert.city.toLowerCase() == userCity.toLowerCase();

            final emoji = alert.riskLevel == RiskLevel.high ? '🚨' : '⚠️';
            final magInfo = alert.earthquake != null
                ? 'M${alert.earthquake!.magnitude.toStringAsFixed(1)} detected ${alert.distanceKm.toStringAsFixed(0)}km away. '
                : '';
            final title =
                '$emoji ${alert.riskLevel.label} Earthquake Risk: ${alert.city}';
            final body = isUserCity
                ? 'Your area has ${alert.riskLevel.label.toLowerCase()} earthquake risk. $magInfo${alert.recommendation}'
                : '$magInfo${alert.recommendation}';

            await notificationService.showRiskAlert(
              id: NotificationService.notificationId(alert.city, 'earthquake'),
              title: title,
              body: body.trim(),
              payload: 'city:${alert.city}:earthquake',
              disasterType: 'earthquake',
            );

            await prefs.setBool(key, true);
          }
        } else {
          await prefs.remove(
              '${_kNotifiedPrefix}earthquake_${alert.city.toLowerCase()}_high');
          await prefs.remove(
              '${_kNotifiedPrefix}earthquake_${alert.city.toLowerCase()}_medium');
        }
      }

      // ── Check heatwave alerts ──────────────────────────────────────────────
      for (final alert in heatwaveResponse.alerts) {
        if (alert.riskLevel == RiskLevel.high ||
            alert.riskLevel == RiskLevel.medium) {
          final key = '${_kNotifiedPrefix}heatwave_${alert.city.toLowerCase()}_${alert.riskLevel.name}';
          final alreadyNotified = prefs.getBool(key) ?? false;

          if (!alreadyNotified) {
            final isUserCity =
                userCity != null &&
                alert.city.toLowerCase() == userCity.toLowerCase();

            final emoji = alert.riskLevel == RiskLevel.high ? '🔥' : '🌡️';
            final tempInfo =
                'Max temp: ${alert.maxTemperature.toStringAsFixed(0)}°C. ';
            final title =
                '$emoji ${alert.riskLevel.label} Heatwave Risk: ${alert.city}';
            final body = isUserCity
                ? 'Your area has ${alert.riskLevel.label.toLowerCase()} heatwave risk. $tempInfo${alert.recommendation}'
                : '$tempInfo${alert.recommendation}';

            await notificationService.showRiskAlert(
              id: NotificationService.notificationId(alert.city, 'heatwave'),
              title: title,
              body: body.trim(),
              payload: 'city:${alert.city}:heatwave',
              disasterType: 'heatwave',
            );

            await prefs.setBool(key, true);
          }
        } else {
          await prefs.remove(
              '${_kNotifiedPrefix}heatwave_${alert.city.toLowerCase()}_high');
          await prefs.remove(
              '${_kNotifiedPrefix}heatwave_${alert.city.toLowerCase()}_medium');
        }
      }
    } catch (err) {
      // Background task failed — will retry on next schedule
    }
    return Future.value(true);
  });
}

class BackgroundService {
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
  }

  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      "disaster-sense-periodic-task",
      "checkDisasterRisk",
      frequency: const Duration(minutes: 15),
      initialDelay: const Duration(seconds: 30),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
  }

  /// Force an immediate one-shot check (e.g. when user manually refreshes).
  static Future<void> triggerImmediateCheck() async {
    await Workmanager().registerOneOffTask(
      "disaster-sense-immediate-check",
      "checkDisasterRisk",
      initialDelay: Duration.zero,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
  }

  /// Clear all previously notified flags so future checks re-send notifications.
  static Future<void> resetNotifiedFlags() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_kNotifiedPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
