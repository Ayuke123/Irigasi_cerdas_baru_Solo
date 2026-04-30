import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future init() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const InitializationSettings settings = InitializationSettings(
      android: android,
    );

    await notificationsPlugin.initialize(settings);
  }

  static Future showNotification(
    String title,
    String body,
  ) async {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'irigasi_channel',
      'Irigasi Notification',
      channelDescription: 'Notifikasi sistem irigasi cerdas',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher', // 🔥 logo notif
    );

    const NotificationDetails details = NotificationDetails(
      android: android,
    );

    await notificationsPlugin.show(
      0,
      title,
      body,
      details,
    );
  }
}
