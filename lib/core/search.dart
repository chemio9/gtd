import '../data/database.dart';

/// Result bucket of the global search.
class SearchResults {
  const SearchResults({
    this.tasks = const [],
    this.events = const [],
    this.matchedSubtasks = const {},
  });

  final List<Task> tasks;
  final List<Event> events;

  /// `taskId -> matching subtask titles`, used to explain why a task matched.
  final Map<int, List<String>> matchedSubtasks;

  bool get isEmpty => tasks.isEmpty && events.isEmpty;

  int get total => tasks.length + events.length;
}

/// Case-insensitive substring search across tasks (title, notes, subtask and
/// tag names) and events (title, notes).
///
/// Pure so it can be unit tested without the database; the UI feeds it the
/// providers it already watches.
SearchResults runSearch({
  required String query,
  required Iterable<Task> tasks,
  required Iterable<Event> events,
  required Iterable<Subtask> subtasks,
  Map<int, List<Tag>> tagsByTask = const {},
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return const SearchResults();

  final subtasksByTask = <int, List<Subtask>>{};
  for (final subtask in subtasks) {
    subtasksByTask.putIfAbsent(subtask.taskId, () => []).add(subtask);
  }

  bool matches(String? value) =>
      value != null && value.toLowerCase().contains(needle);

  final matchedTasks = <Task>[];
  final matchedSubtasks = <int, List<String>>{};

  for (final task in tasks) {
    final subtaskTitles = [
      for (final subtask in subtasksByTask[task.id] ?? const <Subtask>[])
        if (matches(subtask.title)) subtask.title,
    ];
    final tagNames = [
      for (final tag in tagsByTask[task.id] ?? const <Tag>[]) tag.name,
    ];

    final hit =
        matches(task.title) ||
        matches(task.notes) ||
        subtaskTitles.isNotEmpty ||
        tagNames.any(matches);

    if (!hit) continue;
    matchedTasks.add(task);
    if (subtaskTitles.isNotEmpty) {
      matchedSubtasks[task.id] = subtaskTitles;
    }
  }

  final matchedEvents = [
    for (final event in events)
      if (matches(event.title) || matches(event.notes)) event,
  ];

  matchedTasks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  matchedEvents.sort((a, b) => a.startsAt.compareTo(b.startsAt));

  return SearchResults(
    tasks: matchedTasks,
    events: matchedEvents,
    matchedSubtasks: matchedSubtasks,
  );
}
