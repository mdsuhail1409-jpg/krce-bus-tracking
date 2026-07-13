import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'krce_alerts',
        'KRCE Alerts',
        channelDescription: 'Bus tracking alerts and notifications',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.show(id, title, body, details);
  }

  static Future<void> showGpsNotification() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'krce_gps',
        'GPS Broadcasting',
        channelDescription: 'Background GPS location service',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
      ),
    );
    await _plugin.show(
        101, 'KRCE Bus Tracking', 'Broadcasting your location live...', details);
  }

  static Future<void> cancelGpsNotification() async {
    await _plugin.cancel(101);
  }
}
