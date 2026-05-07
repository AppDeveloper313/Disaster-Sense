import 'city_alert.dart';

/// A single entry in the persistent alert history log.
class AlertLogEntry {
  final String city;
  final String type; // 'flood' | 'earthquake'
  final RiskLevel riskLevel;
  final String message;
  final DateTime timestamp;

  AlertLogEntry({
    required this.city,
    required this.type,
    required this.riskLevel,
    required this.message,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'city': city,
        'type': type,
        'riskLevel': riskLevel.name,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AlertLogEntry.fromJson(Map<String, dynamic> json) => AlertLogEntry(
        city: json['city'] as String,
        type: json['type'] as String,
        riskLevel: RiskLevel.values.firstWhere(
          (e) => e.name == json['riskLevel'],
          orElse: () => RiskLevel.unknown,
        ),
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
