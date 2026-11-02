// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'board_dao.dart';

// ignore_for_file: type=lint
mixin _$BoardDaoMixin on DatabaseAccessor<AppDatabase> {
  $BoardsTable get boards => attachedDatabase.boards;
  $BoardColumnsTable get boardColumns => attachedDatabase.boardColumns;
  $TasksTable get tasks => attachedDatabase.tasks;
  BoardDaoManager get managers => BoardDaoManager(this);
}

class BoardDaoManager {
  final _$BoardDaoMixin _db;
  BoardDaoManager(this._db);
  $$BoardsTableTableManager get boards =>
      $$BoardsTableTableManager(_db.attachedDatabase, _db.boards);
  $$BoardColumnsTableTableManager get boardColumns =>
      $$BoardColumnsTableTableManager(_db.attachedDatabase, _db.boardColumns);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db.attachedDatabase, _db.tasks);
}
