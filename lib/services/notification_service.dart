import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    final androidImpl = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.requestNotificationsPermission();
    await androidImpl?.requestExactAlarmsPermission();

    _initialized = true;
  }

  int _notificationIdForKey(String key) => key.hashCode & 0x7FFFFFFF;

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    required DateTime scheduledAt,
    bool isPrivate = false,
  }) async {
    await initialize();
    if (scheduledAt.isBefore(DateTime.now())) return;

    final id = _notificationIdForKey(taskId);
    final tzDate = tz.TZDateTime.from(scheduledAt, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'personal_space_reminders',
      'Task & Note Reminders',
      channelDescription: 'Scheduled reminders from PERSONAL SPACE',
      importance: Importance.high,
      priority: Priority.high,
      visibility: NotificationVisibility.private,
    );

    // Never expose private content through ordinary notifications
    final bodyText =
        isPrivate ? 'You have a private reminder scheduled.' : taskTitle;

    await _plugin.zonedSchedule(
      id,
      'PERSONAL SPACE Reminder',
      bodyText,
      tzDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelReminder(String taskId) async {
    await initialize();
    await _plugin.cancel(_notificationIdForKey(taskId));
  }
}
