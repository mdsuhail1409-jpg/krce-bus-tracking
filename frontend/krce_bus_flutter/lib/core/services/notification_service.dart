import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Request notification permission for Android 13+ (POST_NOTIFICATIONS)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
    bool playAudioFeedback = true,
  }) async {
    if (playAudioFeedback) {
      // Play audible alert feedback on device speaker and trigger haptic pulse
      try {
        await SystemSound.play(SystemSoundType.alert);
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'krce_alerts_v2',
        'KRCE Bus Audio Alerts',
        channelDescription: 'Real-time bus arrival proximity and emergency audio alerts',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
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
