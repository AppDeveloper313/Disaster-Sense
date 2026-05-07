/// Web stub — flutter_local_notifications is not supported on web.
/// The real implementation is in notification_service.dart.

void Function(String? payload)? onNotificationTapped;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  Future<void> initialize() async {}
  Future<void> requestPermissions() async {}

  Future<void> showRiskAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
    String disasterType = 'general',
  }) async {}

  static int notificationId(String city, String type) {
    return '${city.toLowerCase()}_$type'.hashCode.abs() % 100000;
  }
}
