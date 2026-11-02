import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../data/daos/board_dao.dart';
import '../data/daos/event_dao.dart';
import '../data/daos/task_dao.dart';
import 'tables.dart';

export 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Boards, BoardColumns, Tasks, Events],
  daos: [BoardDao, TaskDao, EventDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Used by tests with an in-memory executor.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seed();
    },
    onUpgrade: (m, from, to) async {
      // v2: events can be linked to a task.
      if (from < 2) {
        await m.addColumn(events, events.linkedTaskId);
      }
      // v3: per-task reminders (minutes before the due time).
      if (from < 3) {
        await m.addColumn(tasks, tasks.reminderMinutesBefore);
      }
    },
    beforeOpen: (details) async {
      // SQLite disables foreign keys per connection; without this the
      // board -> column -> task cascades and the event -> task link would
      // silently do nothing.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _seed() async {
    final boardId = await into(boards).insert(
      BoardsCompanion.insert(name: 'Personal', position: const Value(0)),
    );
    const columns = ['To do', 'In progress', 'Done'];
    for (var i = 0; i < columns.length; i++) {
      await into(boardColumns).insert(
        BoardColumnsCompanion.insert(
          boardId: boardId,
          title: columns[i],
          position: Value(i),
          isDone: Value(i == columns.length - 1),
        ),
      );
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'gtd',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  }
}
