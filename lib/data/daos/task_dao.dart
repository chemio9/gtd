import 'package:drift/drift.dart';

import '../database.dart';

part 'task_dao.g.dart';

@DriftAccessor(tables: [Tasks, BoardColumns, Boards])
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  TaskDao(super.db);

  Stream<List<Task>> watchBoardTasks(int boardId) {
    return (select(tasks)
          ..where((t) => t.boardId.equals(boardId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.columnId),
            (t) => OrderingTerm.asc(t.position),
          ]))
        .watch();
  }

  Stream<List<Task>> watchAllTasks() {
    return (select(tasks)..orderBy([
      (t) => OrderingTerm.asc(t.completedAt),
      (t) => OrderingTerm.asc(t.dueDate),
      (t) => OrderingTerm.desc(t.priority),
      (t) => OrderingTerm.desc(t.createdAt),
    ])).watch();
  }

  /// Tasks with a due date inside `[from, to)`.
  Stream<List<Task>> watchTasksDueBetween(DateTime from, DateTime to) {
    return (select(tasks)
          ..where(
            (t) =>
                t.dueDate.isBiggerOrEqualValue(from) &
                t.dueDate.isSmallerThanValue(to),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .watch();
  }

  Future<Task?> taskById(int id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> createTask({
    required String title,
    String? notes,
    int? boardId,
    int? columnId,
    DateTime? dueDate,
    int? reminderMinutesBefore,
    TaskPriority priority = TaskPriority.medium,
    int? position,
  }) async {
    // A task without a column would be invisible on the board, so fall back to
    // the first column of the board.
    var resolvedColumnId = columnId;
    if (resolvedColumnId == null && boardId != null) {
      final first = await (select(boardColumns)
            ..where((t) => t.boardId.equals(boardId))
            ..orderBy([(t) => OrderingTerm.asc(t.position)])
            ..limit(1))
          .getSingleOrNull();
      resolvedColumnId = first?.id;
    }

    final resolvedPosition = position ??
        await _nextPosition(columnId: resolvedColumnId, boardId: boardId);
    return into(tasks).insert(
      TasksCompanion.insert(
        title: title,
        notes: Value(notes),
        boardId: Value(boardId),
        columnId: Value(resolvedColumnId),
        dueDate: Value(dueDate),
        reminderMinutesBefore: Value(reminderMinutesBefore),
        priority: Value(priority),
        position: Value(resolvedPosition),
      ),
    );
  }

  Future<int> _nextPosition({int? columnId, int? boardId}) async {
    final query = selectOnly(tasks)..addColumns([tasks.position.max()]);
    if (columnId != null) {
      query.where(tasks.columnId.equals(columnId));
    } else if (boardId != null) {
      query.where(tasks.boardId.equals(boardId) & tasks.columnId.isNull());
    }
    final row = await query.getSingle();
    return (row.read(tasks.position.max()) ?? -1) + 1;
  }

  Future<void> updateTask(int id, TasksCompanion changes) {
    return (update(tasks)..where((t) => t.id.equals(id))).write(
      changes.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> deleteTask(int id) {
    return (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

  /// Sets (or clears) the due date of several tasks at once.
  ///
  /// Clearing the date also clears the reminder, mirroring the editor.
  Future<void> setDueDates(Iterable<int> ids, DateTime? due) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    final now = DateTime.now();
    await transaction(() async {
      for (final id in list) {
        await (update(tasks)..where((t) => t.id.equals(id))).write(
          TasksCompanion(
            dueDate: Value(due),
            reminderMinutesBefore:
                due == null ? const Value(null) : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
      }
    });
  }

  /// Completes (or reopens) several tasks, honouring each task's done column.
  /// Tasks that already match [completed] are left untouched.
  Future<void> setCompletedMany(
    Iterable<Task> tasks, {
    required bool completed,
  }) async {
    final pending = [
      for (final task in tasks)
        if ((task.completedAt != null) != completed) task,
    ];
    if (pending.isEmpty) return;
    await transaction(() async {
      for (final task in pending) {
        await setCompleted(task, completed: completed);
      }
    });
  }

  Future<void> deleteTasks(Iterable<int> ids) async {
    final list = ids.toList();
    if (list.isEmpty) return;
    await (delete(tasks)..where((t) => t.id.isIn(list))).go();
  }

  Future<void> setCompleted(Task task, {required bool completed}) async {
    if (completed) {
      // Move the task into the board's done column when there is one.
      final columnId = task.columnId;
      if (columnId != null) {
        final column = await (select(boardColumns)
              ..where((t) => t.id.equals(columnId)))
            .getSingleOrNull();
        if (column == null || !column.isDone) {
          final done = await _doneColumnFor(task.boardId);
          if (done != null) {
            await (update(tasks)..where((t) => t.id.equals(task.id))).write(
              TasksCompanion(
                columnId: Value(done.id),
                position: Value(await _nextPosition(columnId: done.id)),
                completedAt: Value(DateTime.now()),
                updatedAt: Value(DateTime.now()),
              ),
            );
            return;
          }
        }
      }
      await (update(tasks)..where((t) => t.id.equals(task.id))).write(
        TasksCompanion(
          completedAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    // Un-completing: send the task back to the first non-done column.
    final firstColumn = await _firstOpenColumnFor(task.boardId);
    await (update(tasks)..where((t) => t.id.equals(task.id))).write(
      TasksCompanion(
        completedAt: const Value(null),
        columnId: Value(firstColumn?.id ?? task.columnId),
        position: Value(
          await _nextPosition(columnId: firstColumn?.id ?? task.columnId),
        ),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<BoardColumn?> _doneColumnFor(int? boardId) async {
    if (boardId == null) return null;
    return (select(boardColumns)
          ..where((t) => t.boardId.equals(boardId) & t.isDone.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.position)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<BoardColumn?> _firstOpenColumnFor(int? boardId) async {
    if (boardId == null) return null;
    return (select(boardColumns)
          ..where((t) => t.boardId.equals(boardId) & t.isDone.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.position)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// Moves [taskId] to [toColumnId] and rewrites the positions of both the
  /// source and the target column.
  ///
  /// [targetOrderedIds] must contain every task id of the target column in the
  /// desired order, including the moved task.
  Future<void> moveTask({
    required int taskId,
    required int fromColumnId,
    required int toColumnId,
    required List<int> targetOrderedIds,
  }) async {
    await transaction(() async {
      final targetColumn = await (select(boardColumns)
            ..where((t) => t.id.equals(toColumnId)))
          .getSingleOrNull();
      final isDone = targetColumn?.isDone ?? false;

      await (update(tasks)..where((t) => t.id.equals(taskId))).write(
        TasksCompanion(
          columnId: Value(toColumnId),
          completedAt: Value(isDone ? DateTime.now() : null),
          updatedAt: Value(DateTime.now()),
        ),
      );

      for (final (index, id) in targetOrderedIds.indexed) {
        await (update(tasks)..where((t) => t.id.equals(id)))
            .write(TasksCompanion(position: Value(index)));
      }

      if (fromColumnId != toColumnId) {
        final remaining =
            await (select(tasks)
                  ..where((t) => t.columnId.equals(fromColumnId))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get();
        for (final (index, task) in remaining.indexed) {
          if (task.position == index) continue;
          await (update(tasks)..where((t) => t.id.equals(task.id)))
              .write(TasksCompanion(position: Value(index)));
        }
      }
    });
  }
}
