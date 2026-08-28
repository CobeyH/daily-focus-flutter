import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Wraps [FlutterLocalNotificationsPlugin] for scheduling a single
/// "task complete" notification at an exact wall-clock time.
class NotificationService {
  static const _channelId = 'task_complete';
  static const _channelName = 'Task Complete';
  static const _channelDescription =
      'Alerts you when a timed task has finished.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Must be called once before any notifications are scheduled.
  Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name.identifier));
    } catch (e) {
      debugPrint('Failed to resolve timezone, defaulting to UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings: settings);

    // Request notification permission (required on Android 13+).
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Whether exact alarms are currently permitted.
  ///
  /// On Android 14+ this is false until the user grants the
  /// `SCHEDULE_EXACT_ALARM` permission. On older Android versions (or before
  /// targeting Android 14) it is always true.
  Future<bool> canScheduleExact() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return (await android.canScheduleExactNotifications()) ?? true;
  }

  /// Prompts the user (via the system settings screen) to allow exact alarms.
  /// Returns whether the permission was granted.
  Future<bool> requestExactAlarmPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true;
    return (await android.requestExactAlarmsPermission()) ?? false;
  }

  /// Schedules a notification to fire exactly at [when] (a UTC instant).
  ///
  /// [notificationId] must be unique per scheduled notification. Returns the
  /// assigned id so callers can cancel it.
  Future<int> scheduleTaskComplete({
    required int notificationId,
    required String taskName,
    required DateTime when,
  }) async {
    await init();
    // On Android 14+ exact alarms require the user to grant
    // SCHEDULE_EXACT_ALARM. If not granted, fall back to an inexact alarm so
    // scheduling still succeeds (the notification may be slightly delayed).
    final canExact = await canScheduleExact();
    final mode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Task complete 🎉',
      body: '$taskName — you did it!',
      scheduledDate: tz.TZDateTime.from(when, tz.local),
      androidScheduleMode: mode,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
    return notificationId;
  }

  Future<void> cancel(int notificationId) async {
    await init();
    await _plugin.cancel(id: notificationId);
  }

  /// Shows an immediate notification (e.g. if a timer elapsed while the app
  /// was killed and we detect it on resume).
  Future<void> showTaskComplete({
    required int notificationId,
    required String taskName,
  }) async {
    await init();
    await _plugin.show(
      id: notificationId,
      title: 'Task complete 🎉',
      body: '$taskName — you did it!',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }
}
