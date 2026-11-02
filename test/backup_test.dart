import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/data/backup.dart';
import 'package:gtd/data/database.dart';

void main() {
  late AppDatabase source;

  setUp(() {
    source = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => source.close());

  Future<AppDatabase> seed() async {
    final board = await source.boardDao.firstBoard();
    final columns = await source.boardDao.columnsOf(board!.id);
    final taskId = await source.taskDao.createTask(
      title: 'Ship v1',
      notes: 'with notes',
      boardId: board.id,
      columnId: columns[1].id,
      dueDate: DateTime(2026, 11, 3, 9, 45),
      priority: TaskPriority.high,
    );
    await source.taskDao.setCompleted(
      (await source.taskDao.taskById(taskId))!,
      completed: true,
    );
    await source.eventDao.createEvent(
      EventsCompanion.insert(
        title: 'Team sync',
        startsAt: DateTime(2026, 11, 2, 9),
        endsAt: DateTime(2026, 11, 2, 10),
        recurrence: const Value(RecurrenceFrequency.weekly),
        byWeekday: const Value('mo,we'),
        recurrenceUntil: Value(DateTime(2026, 12, 31)),
      ),
    );
    return source;
  }

  test('export contains every table with the current schema version', () async {
    await seed();
    final backup = await BackupService(source).export();

    expect(backup['app'], BackupService.appTag);
    expect(backup['version'], BackupService.formatVersion);
    expect(backup['boards'], hasLength(1));
    expect(backup['columns'], hasLength(3));
    expect(backup['tasks'], hasLength(1));
    expect(backup['events'], hasLength(1));
  });

  test('export/import round trip keeps ids, dates and relationships', () async {
    await seed();
    final json = jsonEncode(await BackupService(source).export());

    final target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(target.close);

    final result = await BackupService(target).importJson(json);
    expect(result.boards, 1);
    expect(result.tasks, 1);
    expect(result.events, 1);

    final tasks = await target.select(target.tasks).get();
    expect(tasks, hasLength(1));
    final task = tasks.single;
    expect(task.title, 'Ship v1');
    expect(task.notes, 'with notes');
    expect(task.priority, TaskPriority.high);
    expect(task.dueDate, DateTime(2026, 11, 3, 9, 45));
    expect(task.completedAt, isNotNull);

    // The task still points at the imported column of the imported board.
    // Completing it moved it to the board's "done" column before export.
    final board = await target.boardDao.firstBoard();
    final columns = await target.boardDao.columnsOf(board!.id);
    expect(columns, hasLength(3));
    expect(task.boardId, board.id);
    expect(task.columnId, columns.last.id);
    expect(columns.last.isDone, isTrue);

    final events = await target.select(target.events).get();
    expect(events.single.title, 'Team sync');
    expect(events.single.recurrence, RecurrenceFrequency.weekly);
    expect(events.single.byWeekday, 'mo,we');
    expect(events.single.recurrenceUntil, DateTime(2026, 12, 31));
  });

  test('import replaces existing content', () async {
    final json = jsonEncode(await BackupService(await seed()).export());

    final target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(target.close);
    await target.boardDao.createBoard('Old board');
    await target.taskDao.createTask(title: 'Old task');

    await BackupService(target).importJson(json);

    final tasks = await target.select(target.tasks).get();
    expect(tasks.map((t) => t.title), ['Ship v1']);
    final boards = await target.select(target.boards).get();
    expect(boards.map((b) => b.name), ['Personal']);
  });

  test('rejects files that are not GTD backups', () async {
    final service = BackupService(source);
    expect(
      () => service.importJson('{"app":"other","version":1}'),
      throwsFormatException,
    );
    expect(() => service.importJson('not json'), throwsFormatException);
    expect(
      () => service.importJson('{"app":"gtd","version":99}'),
      throwsFormatException,
    );
  });
}
