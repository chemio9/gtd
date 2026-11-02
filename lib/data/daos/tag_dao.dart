import 'package:drift/drift.dart';

import '../database.dart';

part 'tag_dao.g.dart';

@DriftAccessor(tables: [Tags, TaskTags, Tasks])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  TagDao(super.db);

  Stream<List<Tag>> watchAll() {
    return (select(tags)..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Stream<List<Tag>> watchForTask(int taskId) {
    final query = select(tags).join([
      innerJoin(taskTags, taskTags.tagId.equalsExp(tags.id)),
    ])..where(taskTags.taskId.equals(taskId));
    query.orderBy([OrderingTerm.asc(tags.name)]);
    return query.watch().map((rows) => rows.map((row) => row.readTable(tags)).toList());
  }

  /// Flat `taskId -> tagId` rows, used to decorate task lists.
  Stream<List<TaskTag>> watchAllLinks() => select(taskTags).watch();

  Future<Tag?> byName(String name) {
    return (select(tags)..where((t) => t.name.equals(name))).getSingleOrNull();
  }

  Future<int> create(String name, {int color = 0xFF4F46E5}) async {
    final existing = await byName(name);
    if (existing != null) return existing.id;
    return into(tags).insert(
      TagsCompanion.insert(name: name, color: Value(color)),
    );
  }

  Future<void> deleteTag(int id) {
    return (delete(tags)..where((t) => t.id.equals(id))).go();
  }

  Future<void> attach(int taskId, int tagId) async {
    await into(taskTags).insertOnConflictUpdate(
      TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
    );
  }

  Future<void> detach(int taskId, int tagId) {
    return (delete(taskTags)
          ..where((t) => t.taskId.equals(taskId) & t.tagId.equals(tagId)))
        .go();
  }

  /// Replaces the tag set of a task.
  Future<void> setForTask(int taskId, Iterable<int> tagIds) async {
    await transaction(() async {
      await (delete(taskTags)..where((t) => t.taskId.equals(taskId))).go();
      for (final tagId in tagIds.toSet()) {
        await into(taskTags).insert(
          TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
        );
      }
    });
  }
}
