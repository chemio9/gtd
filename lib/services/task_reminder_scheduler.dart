import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import 'notification_service.dart';

/// Notification id space reserved for task reminders (`base + task.id`).
const taskReminderIdBase = 5000;

/// When the reminder for [task] should fire, or `null` when it should not.
///
/// Date-only due dates (midnight) are treated as "that day, 09:00" so
/// "3 hours before" still lands somewhere sensible.
DateTime? reminderTimeFor(Task task, {DateTime? now}) {
  final due = task.dueDate;
  final offset = task.reminderMinutesBefore;
  if (due == null || offset == null) return null;
  if (task.completedAt != null) return null;

  final hasTime = due.hour != 0 || due.minute != 0;
  final base = hasTime
      ? due
      : DateTime(due.year, due.month, due.day, 9);
  final fireAt = base.subtract(Duration(minutes: offset));
  if (now != null && !fireAt.isAfter(now)) return null;
  return fireAt;
}

/// Scheduling seam so the logic is testable without platform channels.
abstract interface class TaskReminderGateway {
  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  });

  Future<void> cancelTaskReminder(int id);

  /// Ids of task reminders currently pending in the OS.
  Future<List<int>> pendingTaskReminderIds();
}

class TaskReminderSyncResult {
  const TaskReminderSyncResult({
    this.scheduled = 0,
    this.cancelled = 0,
    this.skipped = 0,
  });

  final int scheduled;
  final int cancelled;
  final int skipped;
}

/// Keeps device notifications in sync with the stored tasks.
///
/// Runs on every task change: cancels the previously scheduled task reminders
/// and schedules the ones that are still in the future.
class TaskReminderScheduler {
  TaskReminderScheduler(this._gateway, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final TaskReminderGateway _gateway;
  final DateTime Function() _clock;

  Future<TaskReminderSyncResult> syncAll(Iterable<Task> tasks) async {
    final pending = await _gateway.pendingTaskReminderIds();
    var cancelled = 0;
    for (final id in pending) {
      await _gateway.cancelTaskReminder(id);
      cancelled++;
    }

    final now = _clock();
    var scheduled = 0;
    var skipped = 0;
    for (final task in tasks) {
      final when = reminderTimeFor(task, now: now);
      if (when == null) {
        skipped++;
        continue;
      }
      await _gateway.scheduleTaskReminder(
        id: taskReminderIdBase + task.id,
        title: task.title,
        body: task.title,
        when: when,
      );
      scheduled++;
    }
    return TaskReminderSyncResult(
      scheduled: scheduled,
      cancelled: cancelled,
      skipped: skipped,
    );
  }
}

final taskReminderGatewayProvider = Provider<TaskReminderGateway>(
  (ref) => ref.watch(notificationServiceProvider),
);

final taskReminderSchedulerProvider = Provider<TaskReminderScheduler>(
  (ref) => TaskReminderScheduler(ref.watch(taskReminderGatewayProvider)),
);
