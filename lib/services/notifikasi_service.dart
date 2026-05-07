import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future init() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: android);

    await notificationsPlugin.initialize(settings);

    final androidPlugin =
        notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // 🔥 REQUEST PERMISSION (ANDROID 13+)
    await androidPlugin?.requestNotificationsPermission();

    // 🔥 BUAT CHANNEL MANUAL (INI KUNCI UTAMA)
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'irigasi_channel',
        'Irigasi Notification',
        description: 'Notifikasi sistem irigasi cerdas',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );
  }

  /// 🔔 SHOW NOTIFICATION (SUARA + GETAR + POPUP)
  static Future showNotification(String title, String body) async {
    final AndroidNotificationDetails android = AndroidNotificationDetails(
      'irigasi_channel',
      'Irigasi Notification',
      channelDescription: 'Notifikasi sistem irigasi cerdas',

      importance: Importance.max,
      priority: Priority.high,

      playSound: true,
      enableVibration: true,

      fullScreenIntent: true, // 🔥 biar muncul di atas (heads-up)
    );

    final NotificationDetails details = NotificationDetails(android: android);

    final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await notificationsPlugin.show(
      id,
      title,
      body,
      details,
    );
  }
}
