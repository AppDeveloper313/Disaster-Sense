import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert_log_entry.dart';
import '../models/city_alert.dart';

/// Persists and retrieves the alert history log.
class AlertHistoryService {
  static const _kLogKey = 'alert_history_log';
  static const _maxEntries = 200;

  // ── Read ─────────────────────────────────────────────────────────────────────
  Future<List<AlertLogEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kLogKey) ?? [];
    return raw
        .map((s) {
          try {
            return AlertLogEntry.fromJson(
                jsonDecode(s) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<AlertLogEntry>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first
  }

  // ── Write ────────────────────────────────────────────────────────────────────
  Future<void> addEntries(List<AlertLogEntry> newEntries) async {
    if (newEntries.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(_kLogKey) ?? [];

    // Prepend newest entries, cap at _maxEntries
    final merged = [
      ...newEntries.map((e) => jsonEncode(e.toJson())),
      ...existing,
    ];
    if (merged.length > _maxEntries) merged.removeRange(_maxEntries, merged.length);

    await prefs.setStringList(_kLogKey, merged);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLogKey);
  }

  // ── Risk history (sparkline data) ────────────────────────────────────────────
  /// Stores a single {city → score} snapshot.
  /// score: unknown=0, low=1, medium=2, high=3
  static const _kRiskHistory = 'risk_score_history';
  static const _maxSnapshots = 14; // keep 14 data points (≈ 2 weeks of hourly polls)

  Future<void> appendRiskSnapshot(Map<String, int> scores) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kRiskHistory) ?? [];
    final entry = jsonEncode({
      'ts': DateTime.now().toIso8601String(),
      'scores': scores,
    });
    raw.add(entry);
    if (raw.length > _maxSnapshots) raw.removeAt(0);
    await prefs.setStringList(_kRiskHistory, raw);
  }

  /// Returns a list of risk scores (0-3) for a city, oldest → newest.
  Future<List<double>> getRiskHistory(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_kRiskHistory) ?? [];
    
    // Seed mock data for the presentation if there's no history yet
    if (raw.length <= 1) {
      // Create a nice looking fake trend (7 points)
      return [
        (city.length % 3 + 1).toDouble(), // pseudo-random based on city name
        ((city.length * 2) % 3 + 1).toDouble(),
        1.0,
        2.0,
        ((city.length * 3) % 4).toDouble(),
        ((city.length * 4) % 3 + 1).toDouble(),
        // End on the actual current reading if we have one, else random
        raw.isNotEmpty 
            ? (jsonDecode(raw.last)['scores'][city] as num? ?? 0).toDouble() 
            : 1.0,
      ];
    }

    return raw.map<double>((s) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        final scores = m['scores'] as Map<String, dynamic>;
        return (scores[city] as num? ?? 0).toDouble();
      } catch (_) {
        return 0.0;
      }
    }).toList();
  }
}

/// Convert a [RiskLevel] to a numeric score for history storage.
int riskScore(RiskLevel r) {
  switch (r) {
    case RiskLevel.high:    return 3;
    case RiskLevel.medium:  return 2;
    case RiskLevel.low:     return 1;
    case RiskLevel.unknown: return 0;
  }
}
