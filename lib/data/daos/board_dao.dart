import 'package:drift/drift.dart';

import '../database.dart';

part 'board_dao.g.dart';

@DriftAccessor(tables: [Boards, BoardColumns, Tasks])
class BoardDao extends DatabaseAccessor<AppDatabase> with _$BoardDaoMixin {
  BoardDao(super.db);

  Stream<List<Board>> watchBoards() {
    return (select(boards)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<Board?> boardById(int id) {
    return (select(boards)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Board?> firstBoard() {
    return (select(boards)
          ..orderBy([(t) => OrderingTerm.asc(t.position)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> createBoard(String name, {bool withDefaultColumns = true}) async {
    return transaction(() async {
      final maxPosition = await _maxBoardPosition();
      final id = await into(boards).insert(
        BoardsCompanion.insert(
          name: name,
          position: Value(maxPosition + 1),
        ),
      );
      if (withDefaultColumns) {
        for (final (index, title) in _defaultColumns.indexed) {
          await addColumn(
            boardId: id,
            title: title,
            isDone: index == _defaultColumns.length - 1,
          );
        }
      }
      return id;
    });
  }

  static const _defaultColumns = ['To do', 'In progress', 'Done'];

  Future<void> renameBoard(int id, String name) {
    return (update(boards)..where((t) => t.id.equals(id)))
        .write(BoardsCompanion(name: Value(name)));
  }

  Future<void> deleteBoard(int id) {
    return (delete(boards)..where((t) => t.id.equals(id))).go();
  }

  Future<int> _maxBoardPosition() async {
    final row = await (selectOnly(boards)
          ..addColumns([boards.position.max()]))
        .getSingle();
    return row.read(boards.position.max()) ?? -1;
  }

  // ---------------------------------------------------------------- columns

  Stream<List<BoardColumn>> watchColumns(int boardId) {
    return (select(boardColumns)
          ..where((t) => t.boardId.equals(boardId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch();
  }

  Future<List<BoardColumn>> columnsOf(int boardId) {
    return (select(boardColumns)
          ..where((t) => t.boardId.equals(boardId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
  }

  Future<BoardColumn?> firstColumn(int boardId) {
    return (select(boardColumns)
          ..where((t) => t.boardId.equals(boardId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> addColumn({
    required int boardId,
    required String title,
    bool isDone = false,
  }) async {
    final row = await (selectOnly(boardColumns)
          ..addColumns([boardColumns.position.max()])
          ..where(boardColumns.boardId.equals(boardId)))
        .getSingle();
    final next = (row.read(boardColumns.position.max()) ?? -1) + 1;
    return into(boardColumns).insert(
      BoardColumnsCompanion.insert(
        boardId: boardId,
        title: title,
        position: Value(next),
        isDone: Value(isDone),
      ),
    );
  }

  Future<void> renameColumn(int id, String title) {
    return (update(boardColumns)..where((t) => t.id.equals(id)))
        .write(BoardColumnsCompanion(title: Value(title)));
  }

  Future<void> setColumnDone(int id, bool isDone) {
    return (update(boardColumns)..where((t) => t.id.equals(id)))
        .write(BoardColumnsCompanion(isDone: Value(isDone)));
  }

  /// Deletes a column and moves its tasks to the first remaining column.
  Future<void> deleteColumn(int id) async {
    await transaction(() async {
      final column = await (select(boardColumns)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (column == null) return;

      final remaining = (await columnsOf(column.boardId))
          .where((c) => c.id != id)
          .toList();
      final fallback = remaining.isEmpty ? null : remaining.first;

      final fallbackIsDone = fallback?.isDone ?? false;
      await (update(tasks)..where((t) => t.columnId.equals(id))).write(
        TasksCompanion(
          columnId: Value(fallback?.id),
          completedAt: Value(fallbackIsDone ? DateTime.now() : null),
        ),
      );
      await (delete(boardColumns)..where((t) => t.id.equals(id))).go();
      if (fallback != null) {
        await _renumberTasks(fallback.id);
      }
    });
  }

  Future<void> reorderColumns(int boardId, List<int> orderedIds) async {
    await transaction(() async {
      final rows = await columnsOf(boardId);
      if (rows.length != orderedIds.length) return;
      for (final (index, id) in orderedIds.indexed) {
        await (update(boardColumns)..where((t) => t.id.equals(id)))
            .write(BoardColumnsCompanion(position: Value(index)));
      }
    });
  }

  Future<void> _renumberTasks(int columnId) async {
    final rows = await (select(tasks)
          ..where((t) => t.columnId.equals(columnId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    for (final (index, task) in rows.indexed) {
      if (task.position == index) continue;
      await (update(tasks)..where((t) => t.id.equals(task.id)))
          .write(TasksCompanion(position: Value(index)));
    }
  }
}
