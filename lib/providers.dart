import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/backup.dart';
import 'data/database.dart';
import 'core/date_x.dart';
import 'core/recurrence.dart';

/// ---------------------------------------------------------------------------
/// Database & DAOs
/// ---------------------------------------------------------------------------
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final boardDaoProvider = Provider((ref) => ref.watch(databaseProvider).boardDao);
final taskDaoProvider = Provider((ref) => ref.watch(databaseProvider).taskDao);
final eventDaoProvider = Provider((ref) => ref.watch(databaseProvider).eventDao);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(ref.watch(databaseProvider)),
);

/// ---------------------------------------------------------------------------
/// Boards
/// ---------------------------------------------------------------------------
final boardsProvider = StreamProvider<List<Board>>((ref) {
  return ref.watch(boardDaoProvider).watchBoards();
});

/// Board currently selected in the board tab (falls back to the first board).
class SelectedBoardId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final selectedBoardIdProvider =
    NotifierProvider<SelectedBoardId, int?>(SelectedBoardId.new);

final activeBoardProvider = Provider<Board?>((ref) {
  final boards = ref.watch(boardsProvider).value ?? const <Board>[];
  if (boards.isEmpty) return null;
  final id = ref.watch(selectedBoardIdProvider);
  for (final board in boards) {
    if (board.id == id) return board;
  }
  return boards.first;
});

final boardColumnsProvider =
    StreamProvider.family<List<BoardColumn>, int>((ref, boardId) {
      return ref.watch(boardDaoProvider).watchColumns(boardId);
    });

final boardTasksProvider =
    StreamProvider.family<List<Task>, int>((ref, boardId) {
      return ref.watch(taskDaoProvider).watchBoardTasks(boardId);
    });

/// ---------------------------------------------------------------------------
/// Tasks
/// ---------------------------------------------------------------------------
final allTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskDaoProvider).watchAllTasks();
});

final tasksDueBetweenProvider =
    StreamProvider.family<List<Task>, (DateTime, DateTime)>((ref, range) {
      return ref
          .watch(taskDaoProvider)
          .watchTasksDueBetween(range.$1, range.$2);
    });

enum TodoFilter { all, today, upcoming, anytime, done }

final todoFilterProvider = NotifierProvider<TodoFilterNotifier, TodoFilter>(
  TodoFilterNotifier.new,
);

class TodoFilterNotifier extends Notifier<TodoFilter> {
  @override
  TodoFilter build() => TodoFilter.all;

  void set(TodoFilter filter) => state = filter;
}

/// Tasks grouped by the bucket shown in the todo list.
final groupedTodosProvider = Provider<Map<String, List<Task>>>((ref) {
  final tasks = ref.watch(allTasksProvider).value ?? const <Task>[];
  final filter = ref.watch(todoFilterProvider);
  final today = dateOnly(DateTime.now());
  final groups = <String, List<Task>>{};

  void add(String key, Task task) =>
      groups.putIfAbsent(key, () => <Task>[]).add(task);

  for (final task in tasks) {
    final done = task.completedAt != null;
    if (filter == TodoFilter.done) {
      if (done) add('Completed', task);
      continue;
    }
    if (done) continue;
    final due = task.dueDate == null ? null : dateOnly(task.dueDate!);
    switch (filter) {
      case TodoFilter.today:
        if (due != null && !due.isAfter(today)) add('Today', task);
      case TodoFilter.upcoming:
        if (due != null && due.isAfter(today)) add('Upcoming', task);
      case TodoFilter.anytime:
        if (due == null) add('Anytime', task);
      case TodoFilter.all:
        if (due == null) {
          add('Anytime', task);
        } else if (due.isBefore(today)) {
          add('Overdue', task);
        } else if (due == today) {
          add('Today', task);
        } else if (due == today.add(const Duration(days: 1))) {
          add('Tomorrow', task);
        } else {
          add('Later', task);
        }
      case TodoFilter.done:
        break;
    }
  }

  const order = ['Overdue', 'Today', 'Tomorrow', 'Upcoming', 'Later', 'Anytime', 'Completed'];
  final ordered = <String, List<Task>>{};
  for (final key in order) {
    final value = groups[key];
    if (value == null || value.isEmpty) continue;
    ordered[key] = value;
  }
  return ordered;
});

/// ---------------------------------------------------------------------------
/// Calendar
/// ---------------------------------------------------------------------------
final calendarFocusedDayProvider =
    NotifierProvider<CalendarFocusedDay, DateTime>(CalendarFocusedDay.new);

class CalendarFocusedDay extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void set(DateTime day) => state = dateOnly(day);
}

/// Events (series rows) that may appear in the given month window.
final eventsInRangeProvider =
    StreamProvider.family<List<Event>, (DateTime, DateTime)>((ref, range) {
      return ref.watch(eventDaoProvider).watchEventsBetween(range.$1, range.$2);
    });

/// Expanded occurrences for a month window, bucketed by day.
final occurrencesByDayProvider =
    Provider.family<Map<DateTime, List<EventOccurrence>>, (DateTime, DateTime)>((
      ref,
      range,
    ) {
      final events = ref.watch(eventsInRangeProvider(range)).value ?? const [];
      return bucketByDay(events, range.$1, range.$2);
    });
