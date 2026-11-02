import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/data/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> addTask({String title = 'Prepare deck'}) async {
    final board = await db.boardDao.firstBoard();
    final column = await db.boardDao.firstColumn(board!.id);
    return db.taskDao.createTask(
      title: title,
      boardId: board.id,
      columnId: column!.id,
    );
  }

  Future<int> addEvent({String title = 'Design review'}) {
    return db.eventDao.createEvent(
      EventsCompanion.insert(
        title: title,
        startsAt: DateTime(2026, 11, 3, 14),
        endsAt: DateTime(2026, 11, 3, 15),
      ),
    );
  }

  test('foreign keys are enforced for every connection', () async {
    final pragma = await db.customSelect('PRAGMA foreign_keys').getSingle();
    expect(pragma.data['foreign_keys'], 1);
  });

  test('deleting a board cascades to its columns and tasks', () async {
    await addTask();
    final board = await db.boardDao.firstBoard();

    await db.boardDao.deleteBoard(board!.id);

    expect(await db.select(db.boards).get(), isEmpty);
    expect(await db.select(db.boardColumns).get(), isEmpty);
    expect(await db.select(db.tasks).get(), isEmpty);
  });

  test('linking an event to a task is readable from both sides', () async {
    final taskId = await addTask();
    final eventId = await addEvent();

    await db.eventDao.linkTask(eventId, taskId);

    final event = await db.eventDao.eventById(eventId);
    expect(event!.linkedTaskId, taskId);

    final forTask = await db.eventDao.watchEventsForTask(taskId).first;
    expect(forTask.map((e) => e.id), [eventId]);
  });

  test('unlinking clears the reference', () async {
    final taskId = await addTask();
    final eventId = await addEvent();
    await db.eventDao.linkTask(eventId, taskId);

    await db.eventDao.linkTask(eventId, null);

    expect((await db.eventDao.eventById(eventId))!.linkedTaskId, isNull);
  });

  test('deleting a task unlinks its events instead of deleting them', () async {
    final taskId = await addTask();
    final eventId = await addEvent();
    await db.eventDao.linkTask(eventId, taskId);

    await db.taskDao.deleteTask(taskId);

    final event = await db.eventDao.eventById(eventId);
    expect(event, isNotNull);
    expect(event!.linkedTaskId, isNull);
  });

  test('schema v1 databases are upgraded in place', () async {
    final directory = await Directory.systemTemp.createTemp('gtd-migration');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/gtd.sqlite');

    // Build the current schema, then roll it back to look like v1.
    final current = AppDatabase.forTesting(NativeDatabase(file));
    await current.eventDao.createEvent(
      EventsCompanion.insert(
        title: 'Team sync',
        startsAt: DateTime(2026, 11, 3, 9),
        endsAt: DateTime(2026, 11, 3, 10),
      ),
    );
    await current.close();

    final raw = sqlite.sqlite3.open(file.path);
    raw.execute('ALTER TABLE events DROP COLUMN linked_task_id');
    raw.execute('PRAGMA user_version = 1');
    raw.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);

    final events = await upgraded.select(upgraded.events).get();
    expect(events, hasLength(1));
    expect(events.single.title, 'Team sync');
    expect(events.single.linkedTaskId, isNull);

    final version = await upgraded
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data['user_version'], 2);

    // The new column is usable after the upgrade.
    final taskId = await upgraded.taskDao.createTask(title: 'After upgrade');
    await upgraded.eventDao.linkTask(events.single.id, taskId);
    expect(
      (await upgraded.eventDao.eventById(events.single.id))!.linkedTaskId,
      taskId,
    );
  });
}
