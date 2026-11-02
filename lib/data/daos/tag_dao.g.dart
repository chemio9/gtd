// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_dao.dart';

// ignore_for_file: type=lint
mixin _$TagDaoMixin on DatabaseAccessor<AppDatabase> {
  $TagsTable get tags => attachedDatabase.tags;
  $BoardsTable get boards => attachedDatabase.boards;
  $BoardColumnsTable get boardColumns => attachedDatabase.boardColumns;
  $TasksTable get tasks => attachedDatabase.tasks;
  $TaskTagsTable get taskTags => attachedDatabase.taskTags;
  TagDaoManager get managers => TagDaoManager(this);
}

class TagDaoManager {
  final _$TagDaoMixin _db;
  TagDaoManager(this._db);
  $$TagsTableTableManager get tags =>
      $$TagsTableTableManager(_db.attachedDatabase, _db.tags);
  $$BoardsTableTableManager get boards =>
      $$BoardsTableTableManager(_db.attachedDatabase, _db.boards);
  $$BoardColumnsTableTableManager get boardColumns =>
      $$BoardColumnsTableTableManager(_db.attachedDatabase, _db.boardColumns);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$TaskTagsTableTableManager get taskTags =>
      $$TaskTagsTableTableManager(_db.attachedDatabase, _db.taskTags);
}
