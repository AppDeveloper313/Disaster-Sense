import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Global callback for when a notification is tapped.
/// Set this from main.dart to navigate to the relevant screen.
void Function(String? payload)? onNotificationTapped;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = true;
  }

  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (onNotificationTapped != null && payload != null) {
      onNotificationTapped!(payload);
    }
  }

  Future<void> requestPermissions() async {
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Show a disaster risk alert notification.
  ///
  /// [disasterType] is one of 'flood', 'earthquake', 'heatwave', 'general'.
  /// [id] should be unique per city+type combination to avoid overwriting.
  Future<void> showRiskAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
    String disasterType = 'general',
  }) async {
    final channelConfig = _channelFor(disasterType);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      channelConfig.id,
      channelConfig.name,
      channelDescription: channelConfig.description,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'DisasterSense Alert',
      color: channelConfig.color,
      groupKey: 'disaster_sense_alerts',
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformDetails,
      payload: payload,
    );
  }

  /// Generate a unique, stable notification ID for a city+type combo.
  static int notificationId(String city, String type) {
    return '${city.toLowerCase()}_$type'.hashCode.abs() % 100000;
  }
}

// ── Channel configuration ─────────────────────────────────────────────────────

class _ChannelConfig {
  final String id;
  final String name;
  final String description;
  final Color color;

  const _ChannelConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
  });
}

_ChannelConfig _channelFor(String disasterType) {
  switch (disasterType) {
    case 'flood':
      return const _ChannelConfig(
        id: 'disaster_flood_channel',
        name: 'Flood Alerts',
        description: 'Notifications for flood risk alerts.',
        color: Color(0xFF1976D2), // Blue
      );
    case 'earthquake':
      return const _ChannelConfig(
        id: 'disaster_earthquake_channel',
        name: 'Earthquake Alerts',
        description: 'Notifications for earthquake risk alerts.',
        color: Color(0xFFE65100), // Deep Orange
      );
    case 'heatwave':
      return const _ChannelConfig(
        id: 'disaster_heatwave_channel',
        name: 'Heatwave Alerts',
        description: 'Notifications for heatwave risk alerts.',
        color: Color(0xFFF44336), // Red
      );
    default:
      return const _ChannelConfig(
        id: 'disaster_alerts_channel',
        name: 'Disaster Alerts',
        description: 'General disaster risk notifications.',
        color: Color(0xFFF44336), // Red
      );
  }
}
