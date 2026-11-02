import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'task_reminder_scheduler.dart';

/// Thin wrapper around `flutter_local_notifications` for the daily reminder.
///
/// Scheduled notifications need a platform scheduler, so the browser build
/// reports [isSupported] == false and the settings UI disables the switch.
class NotificationService implements TaskReminderGateway {
  NotificationService();

  static const _reminderId = 1001;
  static const _channelId = 'daily_reminder';
  static const _taskChannelId = 'task_reminders';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  bool get isSupported => !kIsWeb;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } on Object {
      // Unknown zone: keep the UTC default rather than crashing.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Asks the platform for permission, returning whether it was granted.
  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await _ensureInitialized();

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        final darwin = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await darwin?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            false;
      default:
        return true;
    }
  }

  Future<void> scheduleDailyReminder(TimeOfDay time) async {
    await _ensureInitialized();
    await _plugin.cancel(id: _reminderId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: _reminderId,
      title: 'Your day in GTD',
      body: 'Check today\'s tasks and events.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Daily reminder',
          channelDescription: 'Daily nudge to review your day',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // ------------------------------------------------------------ task reminders

  @override
  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    if (!isSupported) return;
    await _ensureInitialized();

    final moment = tz.TZDateTime.from(when, tz.local);
    if (!moment.isAfter(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: moment,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _taskChannelId,
          'Task reminders',
          channelDescription: 'Reminders for tasks with a due date',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelTaskReminder(int id) async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: id);
  }

  @override
  Future<List<int>> pendingTaskReminderIds() async {
    if (!isSupported) return const [];
    await _ensureInitialized();
    final pending = await _plugin.pendingNotificationRequests();
    return [
      for (final request in pending)
        if (request.id >= taskReminderIdBase) request.id,
    ];
  }

  Future<void> cancelDailyReminder() async {
    if (!isSupported) return;
    await _ensureInitialized();
    await _plugin.cancel(id: _reminderId);
  }
}

/// Provider indirection so tests never touch platform channels.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
