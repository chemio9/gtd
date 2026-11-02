import 'package:drift/drift.dart' show Value;

import '../data/database.dart';
import 'date_x.dart';

/// A single visible instance of an [Event] (recurring events produce many).
class EventOccurrence {
  const EventOccurrence({
    required this.event,
    required this.start,
    required this.end,
  });

  /// The stored row. For recurring events this is the series template.
  final Event event;
  final DateTime start;
  final DateTime end;

  bool get isRecurring => event.recurrence != RecurrenceFrequency.none;

  bool get spansMultipleDays => !isSameDay(start, end);

  bool overlaps(DateTime rangeStart, DateTime rangeEnd) =>
      start.isBefore(rangeEnd) && end.isAfter(rangeStart);
}

/// Expands [event] into occurrences that intersect `[rangeStart, rangeEnd)`.
///
/// Only reads, never writes: expanding a weekly event for a month shows every
/// instance without storing one row per occurrence.
List<EventOccurrence> expandEvent(
  Event event,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final occurrences = <EventOccurrence>[];
  final duration = event.endsAt.difference(event.startsAt);
  final until = event.recurrenceUntil;

  void add(DateTime start) {
    final end = start.add(duration);
    if (!(start.isBefore(rangeEnd) && end.isAfter(rangeStart))) return;
    if (until != null && dateOnly(start).isAfter(dateOnly(until))) return;
    occurrences.add(EventOccurrence(event: event, start: start, end: end));
  }

  switch (event.recurrence) {
    case RecurrenceFrequency.none:
      add(event.startsAt);

    case RecurrenceFrequency.daily:
      final first = _firstDayNotBefore(event.startsAt, rangeStart);
      var day = first;
      var guard = 0;
      while (day.isBefore(rangeEnd) && guard++ < 1000) {
        add(_atTimeOf(day, event.startsAt));
        day = day.add(const Duration(days: 1));
      }

    case RecurrenceFrequency.weekly:
      final codes = WeekdayCodeX.parse(event.byWeekday);
      final weekdays = codes.isEmpty
          ? {event.startsAt.weekday}
          : codes.map((c) => c.weekday).toSet();
      var day = _firstDayNotBefore(event.startsAt, rangeStart);
      var guard = 0;
      while (day.isBefore(rangeEnd) && guard++ < 1000) {
        if (weekdays.contains(day.weekday)) add(_atTimeOf(day, event.startsAt));
        day = day.add(const Duration(days: 1));
      }

    case RecurrenceFrequency.monthly:
      var cursor = DateTime(
        event.startsAt.year,
        event.startsAt.month,
        _clampedDay(event.startsAt),
        event.startsAt.hour,
        event.startsAt.minute,
      );
      var guard = 0;
      while (cursor.isBefore(rangeEnd) && guard++ < 400) {
        add(cursor);
        final nextMonth = DateTime(cursor.year, cursor.month + 1);
        cursor = DateTime(
          nextMonth.year,
          nextMonth.month,
          _clampedDay(event.startsAt, month: nextMonth.month, year: nextMonth.year),
          event.startsAt.hour,
          event.startsAt.minute,
        );
      }
  }

  occurrences.sort((a, b) => a.start.compareTo(b.start));
  return occurrences;
}

DateTime _firstDayNotBefore(DateTime startsAt, DateTime rangeStart) {
  final startDay = dateOnly(startsAt);
  final rangeDay = dateOnly(rangeStart);
  return rangeDay.isAfter(startDay) ? rangeDay : startDay;
}

DateTime _atTimeOf(DateTime day, DateTime template) => DateTime(
  day.year,
  day.month,
  day.day,
  template.hour,
  template.minute,
);

int _clampedDay(DateTime value, {int? month, int? year}) {
  final y = year ?? value.year;
  final m = month ?? value.month;
  final lastDay = DateTime(y, m + 1, 0).day;
  return value.day > lastDay ? lastDay : value.day;
}

/// Expands many events and buckets them by day (`dateOnly`).
Map<DateTime, List<EventOccurrence>> bucketByDay(
  Iterable<Event> events,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final buckets = <DateTime, List<EventOccurrence>>{};
  for (final event in events) {
    for (final occurrence in expandEvent(event, rangeStart, rangeEnd)) {
      var day = dateOnly(occurrence.start);
      final lastDay = dateOnly(
        occurrence.end.isAfter(occurrence.start)
            ? occurrence.end.subtract(const Duration(seconds: 1))
            : occurrence.start,
      );
      while (!day.isAfter(lastDay)) {
        buckets.putIfAbsent(day, () => []).add(occurrence);
        day = day.add(const Duration(days: 1));
      }
    }
  }
  for (final list in buckets.values) {
    list.sort((a, b) => a.start.compareTo(b.start));
  }
  return buckets;
}

/// Small helper for building an `EventsCompanion` from UI input.
EventsCompanion eventCompanion({
  String? title,
  String? notes,
  DateTime? startsAt,
  DateTime? endsAt,
  bool? allDay,
  RecurrenceFrequency? recurrence,
  Iterable<WeekdayCode>? byWeekday,
  DateTime? recurrenceUntil,
  bool clearRecurrenceUntil = false,
}) {
  return EventsCompanion(
    title: title == null ? const Value.absent() : Value(title),
    notes: notes == null ? const Value.absent() : Value(notes),
    startsAt: startsAt == null ? const Value.absent() : Value(startsAt),
    endsAt: endsAt == null ? const Value.absent() : Value(endsAt),
    allDay: allDay == null ? const Value.absent() : Value(allDay),
    recurrence:
        recurrence == null ? const Value.absent() : Value(recurrence),
    byWeekday: byWeekday == null
        ? const Value.absent()
        : Value(WeekdayCodeX.serialize(byWeekday)),
    recurrenceUntil: clearRecurrenceUntil
        ? const Value(null)
        : recurrenceUntil == null
        ? const Value.absent()
        : Value(recurrenceUntil),
  );
}
