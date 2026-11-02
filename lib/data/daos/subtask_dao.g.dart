// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtask_dao.dart';

// ignore_for_file: type=lint
mixin _$SubtaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $BoardsTable get boards => attachedDatabase.boards;
  $BoardColumnsTable get boardColumns => attachedDatabase.boardColumns;
  $TasksTable get tasks => attachedDatabase.tasks;
  $SubtasksTable get subtasks => attachedDatabase.subtasks;
  SubtaskDaoManager get managers => SubtaskDaoManager(this);
}

class SubtaskDaoManager {
  final _$SubtaskDaoMixin _db;
  SubtaskDaoManager(this._db);
  $$BoardsTableTableManager get boards =>
      $$BoardsTableTableManager(_db.attachedDatabase, _db.boards);
  $$BoardColumnsTableTableManager get boardColumns =>
      $$BoardColumnsTableTableManager(_db.attachedDatabase, _db.boardColumns);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
  $$SubtasksTableTableManager get subtasks =>
      $$SubtasksTableTableManager(_db.attachedDatabase, _db.subtasks);
}
