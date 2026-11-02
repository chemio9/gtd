import 'package:drift/drift.dart';

/// Priority of a task. Stored as its index in the database.
enum TaskPriority { low, medium, high, urgent }

extension TaskPriorityX on TaskPriority {
  String get label => switch (this) {
    TaskPriority.low => 'Low',
    TaskPriority.medium => 'Medium',
    TaskPriority.high => 'High',
    TaskPriority.urgent => 'Urgent',
  };

  int get weight => index;
}

/// How often an event repeats.
enum RecurrenceFrequency { none, daily, weekly, monthly }

/// Weekday codes used in [Events.byWeekday] (`mo,we,fr`).
enum WeekdayCode { mo, tu, we, th, fr, sa, su }

extension WeekdayCodeX on WeekdayCode {
  /// `DateTime.weekday` for this code (monday == 1).
  int get weekday => index + 1;

  String get short => switch (this) {
    WeekdayCode.mo => 'Mon',
    WeekdayCode.tu => 'Tue',
    WeekdayCode.we => 'Wed',
    WeekdayCode.th => 'Thu',
    WeekdayCode.fr => 'Fri',
    WeekdayCode.sa => 'Sat',
    WeekdayCode.su => 'Sun',
  };

  static WeekdayCode fromWeekday(int weekday) => WeekdayCode.values[weekday - 1];

  static List<WeekdayCode> parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    final codes = <WeekdayCode>[];
    for (final part in raw.split(',')) {
      final name = part.trim().toLowerCase();
      for (final code in WeekdayCode.values) {
        if (code.name == name) codes.add(code);
      }
    }
    return codes;
  }

  static String? serialize(Iterable<WeekdayCode> codes) {
    final sorted = codes.toSet().toList()..sort((a, b) => a.index - b.index);
    if (sorted.isEmpty) return null;
    return sorted.map((c) => c.name).join(',');
  }
}

class Boards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 64)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('BoardColumn')
class BoardColumns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get boardId =>
      integer().references(Boards, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 64)();
  IntColumn get position => integer().withDefault(const Constant(0))();

  /// Tasks dropped here are marked as completed.
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
}

@DataClassName('Task')
class Tasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get boardId => integer()
      .nullable()
      .references(Boards, #id, onDelete: KeyAction.cascade)();
  IntColumn get columnId => integer()
      .nullable()
      .references(BoardColumns, #id, onDelete: KeyAction.setNull)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Minutes before the due time to fire a reminder; null = no reminder.
  IntColumn get reminderMinutesBefore => integer().nullable()();
  IntColumn get priority =>
      intEnum<TaskPriority>().withDefault(const Constant(1))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

@DataClassName('Event')
class Events extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get notes => text().nullable()();

  /// Optional task this event belongs to (meeting about a task, deadline…).
  IntColumn get linkedTaskId => integer()
      .nullable()
      .references(Tasks, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get startsAt => dateTime()();
  DateTimeColumn get endsAt => dateTime()();
  BoolColumn get allDay => boolean().withDefault(const Constant(false))();
  TextColumn get recurrence =>
      textEnum<RecurrenceFrequency>().withDefault(const Constant('none'))();

  /// Comma separated weekday codes, only used for weekly recurrence.
  TextColumn get byWeekday => text().nullable()();
  DateTimeColumn get recurrenceUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// One level of checkable steps inside a task.
@DataClassName('Subtask')
class Subtasks extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  BoolColumn get isDone => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Global tag, reusable across boards.
@DataClassName('Tag')
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// ARGB colour used for the chip.
  IntColumn get color => integer().withDefault(const Constant(0xFF4F46E5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {name},
  ];
}

@DataClassName('TaskTag')
class TaskTags extends Table {
  IntColumn get taskId =>
      integer().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}
