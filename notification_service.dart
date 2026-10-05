import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await plugin.initialize(settings);

    final androidImpl = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidImpl?.requestNotificationsPermission();
  }

  Future<void> lowBalance(double balance, double threshold) async {
    const details = AndroidNotificationDetails(
      'mizani_finance',
      'اسم الميزانية',
      channelDescription: 'تنبيهات الميزانية والرصيد',
      importance: Importance.high,
      priority: Priority.high,
    );

    await plugin.show(
      1001,
      'تنبيه اسم الميزانية',
      'رصيدك ${balance.toStringAsFixed(3)} ر.ع، وهو أقل من حد التنبيه ${threshold.toStringAsFixed(3)} ر.ع.',
      const NotificationDetails(android: details),
    );
  }
}