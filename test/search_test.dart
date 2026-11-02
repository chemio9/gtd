import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/core/search.dart';
import 'package:gtd/data/database.dart';

Task task(int id, String title, {String? notes, DateTime? completedAt}) {
  return Task(
    id: id,
    title: title,
    notes: notes,
    completedAt: completedAt,
    priority: TaskPriority.medium,
    position: 0,
    createdAt: DateTime(2026, 11, 1),
    updatedAt: DateTime(2026, 11, 1),
  );
}

Event event(int id, String title, {String? notes}) {
  return Event(
    id: id,
    title: title,
    notes: notes,
    startsAt: DateTime(2026, 11, 3, 9),
    endsAt: DateTime(2026, 11, 3, 10),
    allDay: false,
    recurrence: RecurrenceFrequency.none,
    createdAt: DateTime(2026, 11, 1),
  );
}

Subtask subtask(int id, int taskId, String title) {
  return Subtask(
    id: id,
    taskId: taskId,
    title: title,
    isDone: false,
    position: 0,
    createdAt: DateTime(2026, 11, 1),
  );
}

Tag tag(int id, String name) {
  return Tag(
    id: id,
    name: name,
    color: 0xFF4F46E5,
    createdAt: DateTime(2026, 11, 1),
  );
}

void main() {
  final tasks = [
    task(1, 'Prepare deck', notes: 'for the board meeting'),
    task(2, 'Buy milk'),
    task(3, 'Old task', completedAt: DateTime(2026, 11, 2)),
  ];
  final events = [
    event(1, 'Design review', notes: 'bring the deck'),
    event(2, 'Lunch'),
  ];
  final subtasks = [subtask(1, 1, 'Outline slides')];
  final tagsByTask = {2: [tag(1, 'groceries')]};

  SearchResults search(String query) => runSearch(
    query: query,
    tasks: tasks,
    events: events,
    subtasks: subtasks,
    tagsByTask: tagsByTask,
  );

  test('empty query returns nothing', () {
    expect(search('   ').isEmpty, isTrue);
  });

  test('matches task titles case-insensitively', () {
    expect(search('DECK').tasks.map((t) => t.id), [1]);
    expect(search('milk').tasks.map((t) => t.title), ['Buy milk']);
  });

  test('matches notes, subtasks and tags', () {
    expect(search('board meeting').tasks.single.id, 1);
    expect(search('outline').tasks.single.id, 1);
    expect(search('outline').matchedSubtasks[1], ['Outline slides']);
    expect(search('groceries').tasks.single.id, 2);
  });

  test('matches events by title and notes', () {
    expect(search('review').events.single.id, 1);
    expect(search('bring').events.single.id, 1);
  });

  test('completed tasks are still searchable', () {
    expect(search('old task').tasks.single.id, 3);
  });

  test('no hits yields an empty result', () {
    final result = search('zzzz');
    expect(result.isEmpty, isTrue);
    expect(result.total, 0);
  });

  test('results are sorted by title and start time', () {
    final result = search('e');
    expect(
      result.tasks.map((t) => t.title.toLowerCase()),
      orderedEquals(
        result.tasks.map((t) => t.title.toLowerCase()).toList()..sort(),
      ),
    );
  });
}
