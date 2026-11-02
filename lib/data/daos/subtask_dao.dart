import 'package:drift/drift.dart';

import '../database.dart';

part 'subtask_dao.g.dart';

@DriftAccessor(tables: [Subtasks])
class SubtaskDao extends DatabaseAccessor<AppDatabase> with _$SubtaskDaoMixin {
  SubtaskDao(super.db);

  Stream<List<Subtask>> watchForTask(int taskId) {
    return (select(subtasks)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Stream<List<Subtask>> watchAll() => select(subtasks).watch();

  Future<int> add({required int taskId, required String title}) async {
    final row = await (selectOnly(subtasks)
          ..addColumns([subtasks.position.max()])
          ..where(subtasks.taskId.equals(taskId)))
        .getSingle();
    final next = (row.read(subtasks.position.max()) ?? -1) + 1;
    return into(subtasks).insert(
      SubtasksCompanion.insert(
        taskId: taskId,
        title: title,
        position: Value(next),
      ),
    );
  }

  Future<void> setDone(int id, bool done) {
    return (update(subtasks)..where((t) => t.id.equals(id)))
        .write(SubtasksCompanion(isDone: Value(done)));
  }

  Future<void> rename(int id, String title) {
    return (update(subtasks)..where((t) => t.id.equals(id)))
        .write(SubtasksCompanion(title: Value(title)));
  }

  Future<void> deleteSubtask(int id) {
    return (delete(subtasks)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteForTask(int taskId) {
    return (delete(subtasks)..where((t) => t.taskId.equals(taskId))).go();
  }
}
