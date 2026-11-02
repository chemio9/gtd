import 'package:drift/drift.dart';

import '../database.dart';

part 'event_dao.g.dart';

@DriftAccessor(tables: [Events])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  Stream<List<Event>> watchAllEvents() {
    return (select(events)..orderBy([(t) => OrderingTerm.asc(t.startsAt)]))
        .watch();
  }

  /// Events that can produce an occurrence inside `[from, to)`.
  ///
  /// Recurring events are returned regardless of age (their expansion is
  /// bounded by `recurrenceUntil`), so the caller can expand them for the
  /// requested window only.
  Stream<List<Event>> watchEventsBetween(DateTime from, DateTime to) {
    return (select(events)
          ..where(
            (t) =>
                (t.startsAt.isSmallerThanValue(to) &
                    t.recurrence.equalsValue(RecurrenceFrequency.none) &
                    t.endsAt.isBiggerOrEqualValue(from)) |
                (t.recurrence.equalsValue(RecurrenceFrequency.none).not() &
                    (t.recurrenceUntil.isNull() |
                        t.recurrenceUntil.isBiggerOrEqualValue(from))),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.startsAt)]))
        .watch();
  }

  /// Events linked to [taskId], ordered by start.
  Stream<List<Event>> watchEventsForTask(int taskId) {
    return (select(events)
          ..where((t) => t.linkedTaskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.asc(t.startsAt)]))
        .watch();
  }

  Future<Event?> eventById(int id) {
    return (select(events)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<int> createEvent(EventsCompanion entry) {
    return into(events).insert(entry);
  }

  Future<void> updateEvent(int id, EventsCompanion changes) {
    return (update(events)..where((t) => t.id.equals(id))).write(changes);
  }

  /// Links an event to a task, or clears the link when [taskId] is null.
  Future<void> linkTask(int eventId, int? taskId) {
    return (update(events)..where((t) => t.id.equals(eventId)))
        .write(EventsCompanion(linkedTaskId: Value(taskId)));
  }

  Future<void> deleteEvent(int id) {
    return (delete(events)..where((t) => t.id.equals(id))).go();
  }
}
