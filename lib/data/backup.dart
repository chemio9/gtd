import 'dart:convert';

import 'package:drift/drift.dart';

import 'database.dart';

/// Result of restoring a backup file.
class BackupImportResult {
  const BackupImportResult({
    required this.boards,
    required this.columns,
    required this.tasks,
    required this.events,
  });

  final int boards;
  final int columns;
  final int tasks;
  final int events;

  int get total => boards + columns + tasks + events;

  String get summary =>
      '$boards board(s), $columns column(s), $tasks task(s), $events event(s)';
}

/// JSON import/export of the whole database.
///
/// Rows keep their original ids so relationships (task → column → board) and
/// any future references survive a round trip.
class BackupService {
  BackupService(this._db);

  /// Bump when the JSON shape changes; imports refuse other versions.
  static const formatVersion = 1;
  static const appTag = 'gtd';

  final AppDatabase _db;

  Future<Map<String, dynamic>> export() async {
    final boards = await _db.select(_db.boards).get();
    final columns = await _db.select(_db.boardColumns).get();
    final tasks = await _db.select(_db.tasks).get();
    final events = await _db.select(_db.events).get();

    return {
      'app': appTag,
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'boards': [
        for (final board in boards)
          {
            'id': board.id,
            'name': board.name,
            'position': board.position,
            'createdAt': board.createdAt.toIso8601String(),
          },
      ],
      'columns': [
        for (final column in columns)
          {
            'id': column.id,
            'boardId': column.boardId,
            'title': column.title,
            'position': column.position,
            'isDone': column.isDone,
          },
      ],
      'tasks': [
        for (final task in tasks)
          {
            'id': task.id,
            'boardId': task.boardId,
            'columnId': task.columnId,
            'title': task.title,
            'notes': task.notes,
            'dueDate': task.dueDate?.toIso8601String(),
            'priority': task.priority.index,
            'position': task.position,
            'completedAt': task.completedAt?.toIso8601String(),
            'createdAt': task.createdAt.toIso8601String(),
            'updatedAt': task.updatedAt.toIso8601String(),
          },
      ],
      'events': [
        for (final event in events)
          {
            'id': event.id,
            'title': event.title,
            'notes': event.notes,
            'startsAt': event.startsAt.toIso8601String(),
            'endsAt': event.endsAt.toIso8601String(),
            'allDay': event.allDay,
            'recurrence': event.recurrence.name,
            'byWeekday': event.byWeekday,
            'recurrenceUntil': event.recurrenceUntil?.toIso8601String(),
            'createdAt': event.createdAt.toIso8601String(),
          },
      ],
    };
  }

  /// Restores [raw] into the database. With [replace] the current content is
  /// deleted first, otherwise rows are merged by id.
  Future<BackupImportResult> importJson(
    String raw, {
    bool replace = true,
  }) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Not a GTD backup file');
    }
    if (decoded['app'] != appTag) {
      throw const FormatException('Not a GTD backup file');
    }
    final version = (decoded['version'] as num?)?.toInt();
    if (version != formatVersion) {
      throw FormatException('Unsupported backup version: $version');
    }

    final boards = _list(decoded['boards']);
    final columns = _list(decoded['columns']);
    final tasks = _list(decoded['tasks']);
    final events = _list(decoded['events']);

    await _db.transaction(() async {
      if (replace) {
        await _db.delete(_db.events).go();
        await _db.delete(_db.tasks).go();
        await _db.delete(_db.boardColumns).go();
        await _db.delete(_db.boards).go();
      }

      for (final json in boards) {
        await _db
            .into(_db.boards)
            .insert(
              BoardsCompanion(
                id: Value(_int(json['id'])),
                name: Value(_string(json['name'], 'Board')),
                position: Value(_int(json['position'])),
                createdAt: Value(_date(json['createdAt']) ?? DateTime.now()),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      for (final json in columns) {
        await _db
            .into(_db.boardColumns)
            .insert(
              BoardColumnsCompanion(
                id: Value(_int(json['id'])),
                boardId: Value(_int(json['boardId'])),
                title: Value(_string(json['title'], 'Column')),
                position: Value(_int(json['position'])),
                isDone: Value(json['isDone'] as bool? ?? false),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      for (final json in tasks) {
        final priorityIndex = _int(json['priority']);
        await _db
            .into(_db.tasks)
            .insert(
              TasksCompanion(
                id: Value(_int(json['id'])),
                boardId: Value(_nullableInt(json['boardId'])),
                columnId: Value(_nullableInt(json['columnId'])),
                title: Value(_string(json['title'], 'Task')),
                notes: Value(json['notes'] as String?),
                dueDate: Value(_date(json['dueDate'])),
                priority: Value(
                  priorityIndex >= 0 && priorityIndex < TaskPriority.values.length
                      ? TaskPriority.values[priorityIndex]
                      : TaskPriority.medium,
                ),
                position: Value(_int(json['position'])),
                completedAt: Value(_date(json['completedAt'])),
                createdAt: Value(_date(json['createdAt']) ?? DateTime.now()),
                updatedAt: Value(_date(json['updatedAt']) ?? DateTime.now()),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
      for (final json in events) {
        await _db
            .into(_db.events)
            .insert(
              EventsCompanion(
                id: Value(_int(json['id'])),
                title: Value(_string(json['title'], 'Event')),
                notes: Value(json['notes'] as String?),
                startsAt: Value(_date(json['startsAt']) ?? DateTime.now()),
                endsAt: Value(_date(json['endsAt']) ?? DateTime.now()),
                allDay: Value(json['allDay'] as bool? ?? false),
                recurrence: Value(
                  RecurrenceFrequency.values.firstWhere(
                    (value) => value.name == json['recurrence'],
                    orElse: () => RecurrenceFrequency.none,
                  ),
                ),
                byWeekday: Value(json['byWeekday'] as String?),
                recurrenceUntil: Value(_date(json['recurrenceUntil'])),
                createdAt: Value(_date(json['createdAt']) ?? DateTime.now()),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }
    });

    return BackupImportResult(
      boards: boards.length,
      columns: columns.length,
      tasks: tasks.length,
      events: events.length,
    );
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is Map) entry.cast<String, dynamic>(),
    ];
  }

  static int _int(Object? value) => (value as num?)?.toInt() ?? 0;

  static int? _nullableInt(Object? value) => (value as num?)?.toInt();

  static String _string(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value : fallback;

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
