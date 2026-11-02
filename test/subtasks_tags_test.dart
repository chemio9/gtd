import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/data/backup.dart';
import 'package:gtd/data/database.dart';

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

  group('subtasks', () {
    test('are listed in position order and can be checked', () async {
      final taskId = await addTask();
      final first = await db.subtaskDao.add(taskId: taskId, title: 'Outline');
      await db.subtaskDao.add(taskId: taskId, title: 'Slides');

      await db.subtaskDao.setDone(first, true);

      final subtasks = await db.subtaskDao.watchForTask(taskId).first;
      expect(subtasks.map((s) => s.title), ['Outline', 'Slides']);
      expect(subtasks.first.isDone, isTrue);
      expect(subtasks.last.isDone, isFalse);
    });

    test('are removed with their task', () async {
      final taskId = await addTask();
      await db.subtaskDao.add(taskId: taskId, title: 'Step');

      await db.taskDao.deleteTask(taskId);

      expect(await db.select(db.subtasks).get(), isEmpty);
    });

    test('can be deleted individually', () async {
      final taskId = await addTask();
      final id = await db.subtaskDao.add(taskId: taskId, title: 'Step');

      await db.subtaskDao.deleteSubtask(id);

      expect(await db.select(db.subtasks).get(), isEmpty);
    });
  });

  group('tags', () {
    test('create is idempotent by name', () async {
      final first = await db.tagDao.create('work');
      final second = await db.tagDao.create('work');

      expect(second, first);
      expect(await db.select(db.tags).get(), hasLength(1));
    });

    test('attach and detach per task', () async {
      final taskId = await addTask();
      final work = await db.tagDao.create('work', color: 0xFF00FF00);
      final home = await db.tagDao.create('home');

      await db.tagDao
          .setForTask(taskId, [work, home]);
      expect(
        (await db.tagDao.watchForTask(taskId).first).map((t) => t.name),
        ['home', 'work'],
      );

      await db.tagDao.detach(taskId, work);
      expect(
        (await db.tagDao.watchForTask(taskId).first).map((t) => t.name),
        ['home'],
      );
    });

    test('setForTask replaces the whole set', () async {
      final taskId = await addTask();
      final a = await db.tagDao.create('a');
      final b = await db.tagDao.create('b');

      await db.tagDao.setForTask(taskId, [a, b]);
      await db.tagDao.setForTask(taskId, [b]);

      expect((await db.tagDao.watchForTask(taskId).first).single.id, b);
      expect(await db.select(db.taskTags).get(), hasLength(1));
    });

    test('links disappear when the task or the tag goes away', () async {
      final taskId = await addTask();
      final tag = await db.tagDao.create('temp');
      await db.tagDao.setForTask(taskId, [tag]);
      await db.tagDao.deleteTag(tag);
      expect(await db.select(db.taskTags).get(), isEmpty);

      final other = await db.tagDao.create('other');
      await db.tagDao.setForTask(taskId, [other]);
      await db.taskDao.deleteTask(taskId);
      expect(await db.select(db.taskTags).get(), isEmpty);
    });
  });

  test('backup round-trips subtasks, tags and links', () async {
    final taskId = await addTask();
    await db.subtaskDao.add(taskId: taskId, title: 'Outline');
    final tag = await db.tagDao.create('work', color: 0xFF123456);
    await db.tagDao.setForTask(taskId, [tag]);

    final json = jsonEncode(await BackupService(db).export());
    final target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(target.close);

    final result = await BackupService(target).importJson(json);

    expect(result.subtasks, 1);
    expect(result.tags, 1);
    final subtasks = await target.select(target.subtasks).get();
    expect(subtasks.single.title, 'Outline');
    expect(subtasks.single.taskId, taskId);
    final tags = await target.select(target.tags).get();
    expect(tags.single.name, 'work');
    expect(tags.single.color, 0xFF123456);
    expect(
      (await target.tagDao.watchForTask(taskId).first).single.id,
      tags.single.id,
    );
  });
}
