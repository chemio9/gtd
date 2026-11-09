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

final subtaskDaoProvider = Provider((ref) => ref.watch(databaseProvider).subtaskDao);
final tagDaoProvider = Provider((ref) => ref.watch(databaseProvider).tagDao);

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

/// How the todo list groups its tasks.
enum TodoGrouping { subject, day }

final todoGroupingProvider =
    NotifierProvider<TodoGroupingNotifier, TodoGrouping>(
      TodoGroupingNotifier.new,
    );

class TodoGroupingNotifier extends Notifier<TodoGrouping> {
  @override
  TodoGrouping build() => TodoGrouping.subject;

  void set(TodoGrouping grouping) => state = grouping;
}

/// Subject tags the list is pinned to. Empty means "every subject".
///
/// `null` inside the set stands for the uncategorized group.
final todoSubjectFilterProvider = NotifierProvider<TodoSubjectFilter, Set<int?>>(
  TodoSubjectFilter.new,
);

class TodoSubjectFilter extends Notifier<Set<int?>> {
  @override
  Set<int?> build() => const {};

  void toggle(int? tagId) {
    final next = {...state};
    if (!next.remove(tagId)) next.add(tagId);
    state = next;
  }

  void clear() => state = const {};
}

/// Subject groups currently collapsed in the list.
final collapsedTodoSubjectsProvider =
    NotifierProvider<CollapsedTodoSubjects, Set<int?>>(
      CollapsedTodoSubjects.new,
    );

class CollapsedTodoSubjects extends Notifier<Set<int?>> {
  @override
  Set<int?> build() => const {};

  void toggle(int? tagId) {
    final next = {...state};
    if (!next.remove(tagId)) next.add(tagId);
    state = next;
  }
}

/// Tasks that survive the active [TodoFilter], in list order.
final filteredTodoTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(allTasksProvider).value ?? const <Task>[];
  final filter = ref.watch(todoFilterProvider);
  final today = dateOnly(DateTime.now());

  return [
    for (final task in tasks)
      if (_matchesTodoFilter(task, filter, today)) task,
  ];
});

bool _matchesTodoFilter(Task task, TodoFilter filter, DateTime today) {
  final done = task.completedAt != null;
  if (filter == TodoFilter.done) return done;
  if (done) return false;
  final due = task.dueDate == null ? null : dateOnly(task.dueDate!);
  return switch (filter) {
    TodoFilter.all => true,
    TodoFilter.today => due != null && !due.isAfter(today),
    TodoFilter.upcoming => due != null && due.isAfter(today),
    TodoFilter.anytime => due == null,
    TodoFilter.done => false,
  };
}

/// Buckets shown in the day-grouped todo list. The UI localizes the label.
enum TodoGroup { overdue, today, tomorrow, upcoming, later, anytime, completed }

/// Tasks grouped by due bucket.
final groupedTodosProvider = Provider<Map<TodoGroup, List<Task>>>((ref) {
  final tasks = ref.watch(filteredTodoTasksProvider);
  final filter = ref.watch(todoFilterProvider);
  final today = dateOnly(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));
  final groups = <TodoGroup, List<Task>>{};

  void add(TodoGroup key, Task task) =>
      groups.putIfAbsent(key, () => <Task>[]).add(task);

  for (final task in tasks) {
    if (filter == TodoFilter.done) {
      add(TodoGroup.completed, task);
      continue;
    }
    final due = task.dueDate == null ? null : dateOnly(task.dueDate!);
    switch (filter) {
      case TodoFilter.today:
        add(TodoGroup.today, task);
      case TodoFilter.upcoming:
        add(TodoGroup.upcoming, task);
      case TodoFilter.anytime:
        add(TodoGroup.anytime, task);
      case TodoFilter.all:
        if (due == null) {
          add(TodoGroup.anytime, task);
        } else if (due.isBefore(today)) {
          add(TodoGroup.overdue, task);
        } else if (due == today) {
          add(TodoGroup.today, task);
        } else if (due == tomorrow) {
          add(TodoGroup.tomorrow, task);
        } else {
          add(TodoGroup.later, task);
        }
      case TodoFilter.done:
        break;
    }
  }

  final ordered = <TodoGroup, List<Task>>{};
  for (final key in TodoGroup.values) {
    final value = groups[key];
    if (value == null || value.isEmpty) continue;
    ordered[key] = value;
  }
  return ordered;
});

/// Tasks grouped by subject tag.
///
/// A task carrying several tags appears once per tag. Tasks without any tag
/// land in the `null` group, which always renders last.
final subjectTodosProvider = Provider<Map<int?, List<Task>>>((ref) {
  final tasks = ref.watch(filteredTodoTasksProvider);
  final byTask = ref.watch(taskTagsProvider);
  final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
  final filter = ref.watch(todoSubjectFilterProvider);
  final tagById = {for (final tag in tags) tag.id: tag};

  final groups = <int?, List<Task>>{};
  for (final task in tasks) {
    final subjects = byTask[task.id] ?? const <Tag>[];
    if (subjects.isEmpty) {
      groups.putIfAbsent(null, () => <Task>[]).add(task);
      continue;
    }
    for (final subject in subjects) {
      groups.putIfAbsent(subject.id, () => <Task>[]).add(task);
    }
  }

  // Alphabetical subjects first, then the uncategorized bucket.
  final subjectIds = groups.keys.whereType<int>().toList()
    ..sort(
      (a, b) => (tagById[a]?.name ?? '').compareTo(tagById[b]?.name ?? ''),
    );
  final ordered = <int?, List<Task>>{};
  for (final id in subjectIds) {
    if (filter.isNotEmpty && !filter.contains(id)) continue;
    ordered[id] = groups[id]!;
  }
  if (filter.isEmpty || filter.contains(null)) {
    final uncategorized = groups[null];
    if (uncategorized != null) ordered[null] = uncategorized;
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

/// ---------------------------------------------------------------- subtasks
final allSubtasksProvider = StreamProvider<List<Subtask>>((ref) {
  return ref.watch(subtaskDaoProvider).watchAll();
});

final subtasksForTaskProvider = StreamProvider.family<List<Subtask>, int>((
  ref,
  taskId,
) {
  return ref.watch(subtaskDaoProvider).watchForTask(taskId);
});

/// `taskId -> subtasks`, ordered, used to render the tree in the list.
final subtasksByTaskProvider = Provider<Map<int, List<Subtask>>>((ref) {
  final subtasks = [...?ref.watch(allSubtasksProvider).value];
  subtasks.sort((a, b) {
    final byPosition = a.position.compareTo(b.position);
    return byPosition != 0 ? byPosition : a.id.compareTo(b.id);
  });
  final byTask = <int, List<Subtask>>{};
  for (final subtask in subtasks) {
    byTask.putIfAbsent(subtask.taskId, () => <Subtask>[]).add(subtask);
  }
  return byTask;
});

/// `taskId -> (done, total)` used to badge task rows.
final subtaskProgressProvider = Provider<Map<int, ({int done, int total})>>((
  ref,
) {
  final subtasks = ref.watch(allSubtasksProvider).value ?? const <Subtask>[];
  final progress = <int, ({int done, int total})>{};
  for (final subtask in subtasks) {
    final current = progress[subtask.taskId] ?? (done: 0, total: 0);
    progress[subtask.taskId] = (
      done: current.done + (subtask.isDone ? 1 : 0),
      total: current.total + 1,
    );
  }
  return progress;
});

/// -------------------------------------------------------------------- tags
final tagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(tagDaoProvider).watchAll();
});

final tagsForTaskProvider = StreamProvider.family<List<Tag>, int>((
  ref,
  taskId,
) {
  return ref.watch(tagDaoProvider).watchForTask(taskId);
});

/// `taskId -> tags`, used to decorate task lists in one place.
final taskTagsProvider = Provider<Map<int, List<Tag>>>((ref) {
  final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
  final links = ref.watch(_taskTagLinksProvider).value ?? const <TaskTag>[];
  final byId = {for (final tag in tags) tag.id: tag};
  final byTask = <int, List<Tag>>{};
  for (final link in links) {
    final tag = byId[link.tagId];
    if (tag == null) continue;
    byTask.putIfAbsent(link.taskId, () => <Tag>[]).add(tag);
  }
  return byTask;
});

final _taskTagLinksProvider = StreamProvider<List<TaskTag>>((ref) {
  return ref.watch(tagDaoProvider).watchAllLinks();
});

/// Every stored event row (series, not occurrences).
final allEventsProvider = StreamProvider<List<Event>>((ref) {
  return ref.watch(eventDaoProvider).watchAllEvents();
});

/// Events linked to one task, newest window not applied (series rows).
final eventsForTaskProvider = StreamProvider.family<List<Event>, int>((
  ref,
  taskId,
) {
  return ref.watch(eventDaoProvider).watchEventsForTask(taskId);
});

/// `taskId -> linked event rows`, used to mark tasks in lists.
final linkedEventsByTaskProvider = Provider<Map<int, List<Event>>>((ref) {
  final events = ref.watch(allEventsProvider).value ?? const <Event>[];
  final byTask = <int, List<Event>>{};
  for (final event in events) {
    final taskId = event.linkedTaskId;
    if (taskId == null) continue;
    byTask.putIfAbsent(taskId, () => <Event>[]).add(event);
  }
  return byTask;
});

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
