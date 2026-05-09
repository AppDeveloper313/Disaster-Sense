warning: in the working copy of 'lib/providers/disaster_provider.dart', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'lib/screens/home_screen.dart', LF will be replaced by CRLF the next time Git touches it
warning: in the working copy of 'lib/screens/map_screen.dart', LF will be replaced by CRLF the next time Git touches it
[1mdiff --git a/backend/config.py b/backend/config.py[m
[1mindex 005df76..7f26092 100644[m
[1m--- a/backend/config.py[m
[1m+++ b/backend/config.py[m
[36m@@ -5,11 +5,81 @@[m [mfrom typing import Dict, Tuple[m
 [m
 # Priority cities in Pakistan with coordinates (latitude, longitude)[m
 PAKISTAN_CITIES: Dict[str, Tuple[float, float]] = {[m
[31m-    "Karachi": (24.8607, 67.0011),[m
[31m-    "Lahore": (31.5497, 74.3436),[m
[31m-    "Peshawar": (34.0151, 71.5249),[m
[31m-    "Quetta": (30.1798, 66.9750),[m
[31m-    "Sukkur": (27.7052, 68.8574),[m
[32m+[m[32m    # ── Sindh ──────────────────────────────────────────────[m
[32m+[m[32m    "Karachi":        (24.8607, 67.0011),[m
[32m+[m[32m    "Hyderabad":      (25.3960, 68.3578),[m
[32m+[m[32m    "Sukkur":         (27.7052, 68.8574),[m
[32m+[m[32m    "Larkana":        (27.5570, 68.2141),[m
[32m+[m[32m    "Nawabshah":      (26.2483, 68.4100),[m
[32m+[m[32m    "Mirpur Khas":    (25.5276, 69.0159),[m
[32m+[m[32m    "Khairpur":       (27.5295, 68.7592),[m
[32m+[m[32m    "Jacobabad":      (28.2769, 68.4514),[m
[32m+[m[32m    "Dadu":           (26.7319, 67.7752),[m
[32m+[m[32m    "Badin":          (24.6561, 68.8372),[m
[32m+[m[32m    "Thatta":         (24.7461, 67.9236),[m
[32m+[m[32m    "Tando Adam":     (25.7646, 68.6618),[m
[32m+[m[32m    # ── Punjab ─────────────────────────────────────────────[m
[32m+[m[32m    "Lahore":         (31.5497, 74.3436),[m
[32m+[m[32m    "Faisalabad":     (31.4504, 73.1350),[m
[32m+[m[32m    "Rawalpindi":     (33.5651, 73.0169),[m
[32m+[m[32m    "Multan":         (30.1575, 71.6836),[m
[32m+[m[32m    "Gujranwala":     (32.1877, 74.1945),[m
[32m+[m[32m    "Sialkot":        (32.4945, 74.5229),[m
[32m+[m[32m    "Bahawalpur":     (29.3956, 71.6836),[m
[32m+[m[32m    "Sargodha":       (32.0836, 72.6711),[m
[32m+[m[32m    "Jhang":          (31.2681, 72.3181),[m
[32m+[m[32m    "Sheikhupura":    (31.7167, 73.9850),[m
[32m+[m[32m    "Rahim Yar Khan": (28.4202, 70.2952),[m
[32m+[m[32m    "Gujrat":         (32.5742, 74.0789),[m
[32m+[m[32m    "Sahiwal":        (30.6682, 73.1114),[m
[32m+[m[32m    "Kasur":          (31.1176, 74.4508),[m
[32m+[m[32m    "Okara":          (30.8138, 73.4534),[m
[32m+[m[32m    "Jhelum":         (32.9425, 73.7257),[m
[32m+[m[32m    "Khanewal":       (30.3018, 71.9321),[m
[32m+[m[32m    "Muzaffargarh":   (30.0734, 71.1936),[m
[32m+[m[32m    "Dera Ghazi Khan":(30.0489, 70.6455),[m
[32m+[m[32m    "Mianwali":       (32.5839, 71.5370),[m
[32m+[m[32m    "Chakwal":        (32.9328, 72.8556),[m
[32m+[m[32m    "Attock":         (33.7667, 72.3597),[m
[32m+[m[32m    "Chiniot":        (31.7200, 72.9789),[m
[32m+[m[32m    "Vehari":         (30.0450, 72.3489),[m
[32m+[m[32m    "Lodhran":        (29.5339, 71.6333),[m
[32m+[m[32m    "Sadiqabad":      (28.3091, 70.1327),[m
[32m+[m[32m    "Bhakkar":        (31.6082, 71.0648),[m
[32m+[m[32m    "Layyah":         (30.9693, 70.9428),[m
[32m+[m[32m    "Nankana Sahib":  (31.4500, 73.7083),[m
[32m+[m[32m    # ── Khyber Pakhtunkhwa ─────────────────────────────────[m
[32m+[m[32m    "Peshawar":       (34.0151, 71.5249),[m
[32m+[m[32m    "Mardan":         (34.1986, 72.0404),[m
[32m+[m[32m    "Mingora":        (34.7717, 72.3600),[m
[32m+[m[32m    "Abbottabad":     (34.1463, 73.2117),[m
[32m+[m[32m    "Kohat":          (33.5869, 71.4414),[m
[32m+[m[32m    "Dera Ismail Khan":(31.8626, 70.9019),[m
[32m+[m[32m    "Nowshera":       (34.0153, 71.9747),[m
[32m+[m[32m    "Swabi":          (34.1200, 72.4700),[m
[32m+[m[32m    "Mansehra":       (34.3300, 73.2000),[m
[32m+[m[32m    "Haripur":        (33.9942, 72.9331),[m
[32m+[m[32m    "Bannu":          (32.9888, 70.6044),[m
[32m+[m[32m    "Chitral":        (35.8518, 71.7864),[m
[32m+[m[32m    "Hangu":          (33.5311, 71.0572),[m
[32m+[m[32m    # ── Balochistan ────────────────────────────────────────[m
[32m+[m[32m    "Quetta":         (30.1798, 66.9750),[m
[32m+[m[32m    "Turbat":         (26.0028, 63.0472),[m
[32m+[m[32m    "Gwadar":         (25.1216, 62.3254),[m
[32m+[m[32m    "Hub":            (25.0500, 66.8875),[m
[32m+[m[32m    "Zhob":           (31.3515, 69.4493),[m
[32m+[m[32m    "Khuzdar":        (27.8000, 66.6100),[m
[32m+[m[32m    "Chaman":         (30.9210, 66.4597),[m
[32m+[m[32m    "Noshki":         (29.5530, 66.0130),[m
[32m+[m[32m    "Sibi":           (29.5430, 67.8770),[m
[32m+[m[32m    # ── Islamabad Capital Territory ────────────────────────[m
[32m+[m[32m    "Islamabad":      (33.6844, 73.0479),[m
[32m+[m[32m    # ── Gilgit-Baltistan ───────────────────────────────────[m
[32m+[m[32m    "Gilgit":         (35.9208, 74.3144),[m
[32m+[m[32m    "Skardu":         (35.2972, 75.6308),[m
[32m+[m[32m    # ── Azad Jammu & Kashmir ───────────────────────────────[m
[32m+[m[32m    "Muzaffarabad":   (34.3700, 73.4711),[m
[32m+[m[32m    "Mirpur":         (33.1484, 73.7514),[m
 }[m
 [m
 # Open-Meteo API endpoints[m
[1mdiff --git a/backend/main.py b/backend/main.py[m
[1mindex 993a129..9a66bf1 100644[m
[1m--- a/backend/main.py[m
[1m+++ b/backend/main.py[m
[36m@@ -39,7 +39,7 @@[m [mfetcher = DisasterSenseDataFetcher()[m
 earthquake_fetcher = EarthquakeSenseDataFetcher()[m
 heatwave_fetcher = HeatwaveDataFetcher()[m
 [m
[31m-VALID_CITIES = ["karachi", "lahore", "peshawar", "quetta", "sukkur"][m
[32m+[m[32mVALID_CITIES = [name.lower() for name in PAKISTAN_CITIES.keys()][m[41m[m
 [m
 [m
 @app.on_event("startup")[m
[36m@@ -176,15 +176,8 @@[m [mdef list_cities():[m
             "name": name,[m
             "latitude": coords[0],[m
             "longitude": coords[1],[m
[31m-            "risk_type": risk_type,[m
         }[m
[31m-        for name, coords, risk_type in [[m
[31m-            ("Karachi", PAKISTAN_CITIES["Karachi"], "cyclone, heatwave"),[m
[31m-            ("Lahore", PAKISTAN_CITIES["Lahore"], "heatwave, smog"),[m
[31m-            ("Peshawar", PAKISTAN_CITIES["Peshawar"], "flash floods"),[m
[31m-            ("Quetta", PAKISTAN_CITIES["Quetta"], "earthquake"),[m
[31m-            ("Sukkur", PAKISTAN_CITIES["Sukkur"], "monsoon flooding"),[m
[31m-        ][m
[32m+[m[32m        for name, coords in PAKISTAN_CITIES.items()[m[41m[m
     ][m
     return {[m
         "count": len(cities),[m
[1mdiff --git a/lib/providers/disaster_provider.dart b/lib/providers/disaster_provider.dart[m
[1mindex 2579c5a..a79f667 100644[m
[1m--- a/lib/providers/disaster_provider.dart[m
[1m+++ b/lib/providers/disaster_provider.dart[m
[36m@@ -1,3 +1,4 @@[m
[32m+[m[32mimport 'dart:math';[m
 import 'package:flutter/foundation.dart';[m
 import '../models/city_alert.dart';[m
 import '../models/earthquake_alert.dart';[m
[36m@@ -37,6 +38,21 @@[m [mclass CityData {[m
   }[m
 }[m
 [m
[32m+[m[32m/// A monitored city sorted by distance from the user.[m
[32m+[m[32mclass NearbyCity {[m
[32m+[m[32m  final String name;[m
[32m+[m[32m  final double distanceKm;[m
[32m+[m[32m  final double lat;[m
[32m+[m[32m  final double lon;[m
[32m+[m
[32m+[m[32m  NearbyCity({[m
[32m+[m[32m    required this.name,[m
[32m+[m[32m    required this.distanceKm,[m
[32m+[m[32m    required this.lat,[m
[32m+[m[32m    required this.lon,[m
[32m+[m[32m  });[m
[32m+[m[32m}[m
[32m+[m
 class DisasterProvider extends ChangeNotifier {[m
   final ApiService _apiService = ApiService();[m
   final AlertHistoryService _historyService = AlertHistoryService();[m
[36m@@ -50,6 +66,7 @@[m [mclass DisasterProvider extends ChangeNotifier {[m
   List<HeatwaveAlert> _heatwaveAlerts = [];[m
   String? _currentCity;[m
   Position? _currentPosition;[m
[32m+[m[32m  List<NearbyCity> _nearestCities = [];[m
 [m
   // Alert log (newest first) — loaded from SharedPreferences on demand[m
   List<AlertLogEntry> _alertLog = [];[m
[36m@@ -64,13 +81,101 @@[m [mclass DisasterProvider extends ChangeNotifier {[m
   List<HeatwaveAlert> get heatwaveAlerts => _heatwaveAlerts;[m
   String? get currentCity => _currentCity;[m
   Position? get currentPosition => _currentPosition;[m
[32m+[m[32m  List<NearbyCity> get nearestCities => _nearestCities;[m
   List<AlertLogEntry> get alertLog => _alertLog;[m
 [m
[31m-  final List<String> _cities = [[m
[31m-    'Karachi', 'Lahore', 'Peshawar', 'Quetta', 'Sukkur'[m
[32m+[m[32m  // Coordinates for all monitored cities (lat, lon)[m
[32m+[m[32m  static const Map<String, List<double>> cityCoords = {[m
[32m+[m[32m    // ── Sindh ────────────────────────────────────────────[m
[32m+[m[32m    'Karachi':         [24.8607, 67.0011],[m
[32m+[m[32m    'Hyderabad':       [25.3960, 68.3578],[m
[32m+[m[32m    'Sukkur':          [27.7052, 68.8574],[m
[32m+[m[32m    'Larkana':         [27.5570, 68.2141],[m
[32m+[m[32m    'Nawabshah':       [26.2483, 68.4100],[m
[32m+[m[32m    'Mirpur Khas':     [25.5276, 69.0159],[m
[32m+[m[32m    'Khairpur':        [27.5295, 68.7592],[m
[32m+[m[32m    'Jacobabad':       [28.2769, 68.4514],[m
[32m+[m[32m    'Dadu':            [26.7319, 67.7752],[m
[32m+[m[32m    'Badin':           [24.6561, 68.8372],[m
[32m+[m[32m    'Thatta':          [24.7461, 67.9236],[m
[32m+[m[32m    'Tando Adam':      [25.7646, 68.6618],[m
[32m+[m[32m    // ── Punjab ───────────────────────────────────────────[m
[32m+[m[32m    'Lahore':          [31.5497, 74.3436],[m
[32m+[m[32m    'Faisalabad':      [31.4504, 73.1350],[m
[32m+[m[32m    'Rawalpindi':      [33.5651, 73.0169],[m
[32m+[m[32m    'Multan':          [30.1575, 71.6836],[m
[32m+[m[32m    'Gujranwala':      [32.1877, 74.1945],[m
[32m+[m[32m    'Sialkot':         [32.4945, 74.5229],[m
[32m+[m[32m    'Bahawalpur':      [29.3956, 71.6836],[m
[32m+[m[32m    'Sargodha':        [32.0836, 72.6711],[m
[32m+[m[32m    'Jhang':           [31.2681, 72.3181],[m
[32m+[m[32m    'Sheikhupura':     [31.7167, 73.9850],[m
[32m+[m[32m    'Rahim Yar Khan':  [28.4202, 70.2952],[m
[32m+[m[32m    'Gujrat':          [32.5742, 74.0789],[m
[32m+[m[32m    'Sahiwal':         [30.6682, 73.1114],[m
[32m+[m[32m    'Kasur':           [31.1176, 74.4508],[m
[32m+[m[32m    'Okara':           [30.8138, 73.4534],[m
[32m+[m[32m    'Jhelum':          [32.9425, 73.7257],[m
[32m+[m[32m    'Khanewal':        [30.3018, 71.9321],[m
[32m+[m[32m    'Muzaffargarh':    [30.0734, 71.1936],[m
[32m+[m[32m    'Dera Ghazi Khan': [30.0489, 70.6455],[m
[32m+[m[32m    'Mianwali':        [32.5839, 71.5370],[m
[32m+[m[32m    'Chakwal':         [32.9328, 72.8556],[m
[32m+[m[32m    'Attock':          [33.7667, 72.3597],[m
[32m+[m[32m    'Chiniot':         [31.7200, 72.9789],[m
[32m+[m[32m    'Vehari':          [30.0450, 72.3489],[m
[32m+[m[32m    'Lodhran':         [29.5339, 71.6333],[m
[32m+[m[32m    'Sadiqabad':       [28.3091, 70.1327],[m
[32m+[m[32m    'Bhakkar':         [31.6082, 71.0648],[m
[32m+[m[32m    'Layyah':          [30.9693, 70.9428],[m
[32m+[m[32m    'Nankana Sahib':   [31.4500, 73.7083],[m
[32m+[m[32m    // ── Khyber Pakhtunkhwa ───────────────────────────────[m
[32m+[m[32m    'Peshawar':        [34.0151, 71.5249],[m
[32m+[m[32m    'Mardan':          [34.1986, 72.0404],[m
[32m+[m[32m    'Mingora':         [34.7717, 72.3600],[m
[32m+[m[32m    'Abbottabad':      [34.1463, 73.2117],[m
[32m+[m[32m    'Kohat':           [33.5869, 71.4414],[m
[32m+[m[32m    'Dera Ismail Khan':[31.8626, 70.9019],[m
[32m+[m[32m    'Nowshera':        [34.0153, 71.9747],[m
[32m+[m[32m    'Swabi':           [34.1200, 72.4700],[m
[32m+[m[32m    'Mansehra':        [34.3300, 73.2000],[m
[32m+[m[32m    'Haripur':         [33.9942, 72.9331],[m
[32m+[m[32m    'Bannu':           [32.9888, 70.6044],[m
[32m+[m[32m    'Chitral':         [35.8518, 71.7864],[m
[32m+[m[32m    'Hangu':           [33.5311, 71.0572],[m
[32m+[m[32m    // ── Balochistan ──────────────────────────────────────[m
[32m+[m[32m    'Quetta':          [30.1798, 66.9750],[m
[32m+[m[32m    'Turbat':          [26.0028, 63.0472],[m
[32m+[m[32m    'Gwadar':          [25.1216, 62.3254],[m
[32m+[m[32m    'Hub':             [25.0500, 66.8875],[m
[32m+[m[32m    'Zhob':            [31.3515, 69.4493],[m
[32m+[m[32m    'Khuzdar':         [27.8000, 66.6100],[m
[32m+[m[32m    'Chaman':          [30.9210, 66.4597],[m
[32m+[m[32m    'Noshki':          [29.5530, 66.0130],[m
[32m+[m[32m    'Sibi':            [29.5430, 67.8770],[m
[32m+[m[32m    // ── Islamabad Capital Territory ──────────────────────[m
[32m+[m[32m    'Islamabad':       [33.6844, 73.0479],[m
[32m+[m[32m    // ── Gilgit-Baltistan ─────────────────────────────────[m
[32m+[m[32m    'Gilgit':          [35.9208, 74.3144],[m
[32m+[m[32m    'Skardu':          [35.2972, 75.6308],[m
[32m+[m[32m    // ── Azad Jammu & Kashmir ─────────────────────────────[m
[32m+[m[32m    'Muzaffarabad':    [34.3700, 73.4711],[m
[32m+[m[32m    'Mirpur':          [33.1484, 73.7514],[m
[32m+[m[32m  };[m
[32m+[m
[32m+[m[32m  // Core cities shown in the default list view[m
[32m+[m[32m  static const List<String> _coreCities = [[m
[32m+[m[32m    'Karachi', 'Lahore', 'Peshawar', 'Quetta', 'Sukkur',[m
   ];[m
[32m+[m
[32m+[m[32m  final List<String> _cities = [..._coreCities];[m
[32m+[m
[32m+[m[32m  /// Core cities (shown by default in the main list).[m
   List<String> get cities => _cities;[m
 [m
[32m+[m[32m  /// All monitored cities (used for search + nearest-city calculation).[m
[32m+[m[32m  List<String> get allCities => cityCoords.keys.toList();[m
[32m+[m
   CityData? getCityData(String city) => _cityData[city];[m
 [m
   // ── Fetch all data ───────────────────────────────────────────────────────────[m
[36m@@ -95,7 +200,7 @@[m [mclass DisasterProvider extends ChangeNotifier {[m
       final previous = Map<String, CityData>.from(_cityData);[m
       _cityData = {};[m
 [m
[31m-      for (final city in cities) {[m
[32m+[m[32m      for (final city in allCities) {[m
         final floodAlert = floodResponse.alerts[m
             .where((a) => a.city.toLowerCase() == city.toLowerCase())[m
             .firstOrNull;[m
[36m@@ -133,7 +238,7 @@[m [mclass DisasterProvider extends ChangeNotifier {[m
   Future<void> _logAndNotifyAlerts(Map<String, CityData> previous) async {[m
     final newEntries = <AlertLogEntry>[];[m
 [m
[31m-    for (final city in cities) {[m
[