import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/data/database.dart';
import 'package:gtd/services/task_reminder_scheduler.dart';

Task task({
  int id = 1,
  String title = 'Ship v1',
  DateTime? due,
  int? reminder,
  DateTime? completedAt,
}) {
  return Task(
    id: id,
    title: title,
    dueDate: due,
    reminderMinutesBefore: reminder,
    completedAt: completedAt,
    priority: TaskPriority.medium,
    position: 0,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
}

class FakeReminderGateway implements TaskReminderGateway {
  final Map<int, DateTime> scheduled = {};
  final Set<int> pending = {};
  int cancels = 0;

  @override
  Future<void> scheduleTaskReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
  }) async {
    scheduled[id] = when;
    pending.add(id);
  }

  @override
  Future<void> cancelTaskReminder(int id) async {
    cancels++;
    pending.remove(id);
    scheduled.remove(id);
  }

  @override
  Future<List<int>> pendingTaskReminderIds() async => pending.toList();
}

void main() {
  final now = DateTime(2026, 11, 2, 10);

  group('reminderTimeFor', () {
    test('no reminder or no due date means nothing to schedule', () {
      expect(reminderTimeFor(task(due: now), now: now), isNull);
      expect(reminderTimeFor(task(reminder: 60), now: now), isNull);
    });

    test('subtracts the offset from the due time', () {
      final t = task(due: DateTime(2026, 11, 2, 18), reminder: 180);
      expect(reminderTimeFor(t, now: now), DateTime(2026, 11, 2, 15));
    });

    test('offset zero fires at the due time', () {
      final t = task(due: DateTime(2026, 11, 2, 18), reminder: 0);
      expect(reminderTimeFor(t, now: now), DateTime(2026, 11, 2, 18));
    });

    test('date-only due dates anchor at 09:00', () {
      final t = task(due: DateTime(2026, 11, 3), reminder: 60);
      expect(reminderTimeFor(t, now: now), DateTime(2026, 11, 3, 8));
    });

    test('completed tasks and past moments are skipped', () {
      expect(
        reminderTimeFor(
          task(due: DateTime(2026, 11, 2, 18), reminder: 60, completedAt: now),
          now: now,
        ),
        isNull,
      );
      expect(
        reminderTimeFor(
          task(due: DateTime(2026, 11, 2, 9), reminder: 180),
          now: now,
        ),
        isNull,
      );
    });
  });

  group('TaskReminderScheduler', () {
    test('schedules future reminders and skips the rest', () async {
      final gateway = FakeReminderGateway();
      final scheduler = TaskReminderScheduler(gateway, clock: () => now);

      final result = await scheduler.syncAll([
        task(id: 1, due: DateTime(2026, 11, 2, 18), reminder: 60),
        task(id: 2, due: DateTime(2026, 11, 2, 11), reminder: 180),
        task(id: 3),
      ]);

      expect(result.scheduled, 1);
      expect(result.skipped, 2);
      expect(gateway.scheduled[taskReminderIdBase + 1], DateTime(2026, 11, 2, 17));
    });

    test('clears previously scheduled reminders before rescheduling', () async {
      final gateway = FakeReminderGateway();
      final scheduler = TaskReminderScheduler(gateway, clock: () => now);

      await scheduler.syncAll([
        task(id: 1, due: DateTime(2026, 11, 2, 18), reminder: 60),
      ]);
      expect(gateway.pending, {taskReminderIdBase + 1});

      final result = await scheduler.syncAll([]);

      expect(result.cancelled, 1);
      expect(gateway.pending, isEmpty);
    });

    test('id space never collides with the daily reminder', () async {
      final gateway = FakeReminderGateway();
      final scheduler = TaskReminderScheduler(gateway, clock: () => now);

      await scheduler.syncAll([
        task(id: 7, due: DateTime(2026, 11, 2, 18), reminder: 0),
      ]);

      expect(gateway.scheduled.keys.single, greaterThan(1001));
    });
  });
}
