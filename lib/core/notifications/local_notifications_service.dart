import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notifications système (barre de tâches) — Android, iOS, Windows.
class LocalNotificationsService {
  LocalNotificationsService._();
  static final LocalNotificationsService instance = LocalNotificationsService._();

  static const String channelPointageId = 'pointage_reminders';
  static const String channelAlertsId = 'pointage_alerts';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) return;

    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
    } catch (_) {
      tz.setLocalLocation(tz.local);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const windowsInit = WindowsInitializationSettings(
      appName: 'My DIPS',
      appUserModelId: 'com.dips.managment',
      guid: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
        windows: windowsInit,
      ),
      onDidReceiveNotificationResponse: (_) {},
    );

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      channelPointageId,
      'Pointage',
      description: 'Rappels d\'entrée et de sortie',
      importance: Importance.high,
    ));
    await android?.createNotificationChannel(const AndroidNotificationChannel(
      channelAlertsId,
      'Alertes pointage',
      description: 'Confirmations et retards',
      importance: Importance.max,
    ));

    _initialized = true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String channelId = channelPointageId,
  }) async {
    if (!_initialized) return;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == channelAlertsId ? 'Alertes pointage' : 'Pointage',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );
    await _plugin.show(id, title, body, details);
  }

  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String channelId = channelPointageId,
  }) async {
    if (!_initialized) return;
    if (!when.isAfter(DateTime.now())) return;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelId == channelAlertsId ? 'Alertes pointage' : 'Pointage',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
      windows: const WindowsNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(when, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();
}
