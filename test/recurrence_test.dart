import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/core/recurrence.dart';
import 'package:gtd/data/database.dart';

Event event({
  required DateTime start,
  required DateTime end,
  RecurrenceFrequency recurrence = RecurrenceFrequency.none,
  String? byWeekday,
  DateTime? until,
}) {
  return Event(
    id: 1,
    title: 'Standup',
    startsAt: start,
    endsAt: end,
    allDay: false,
    recurrence: recurrence,
    byWeekday: byWeekday,
    recurrenceUntil: until,
    createdAt: start,
  );
}

void main() {
  group('recurrence expansion', () {
    test('non recurring event appears once inside the window', () {
      final single = event(
        start: DateTime(2025, 3, 12, 9),
        end: DateTime(2025, 3, 12, 10),
      );
      final occurrences = expandEvent(
        single,
        DateTime(2025, 3, 1),
        DateTime(2025, 4, 1),
      );
      expect(occurrences, hasLength(1));
      expect(occurrences.single.start, DateTime(2025, 3, 12, 9));
    });

    test('non recurring event outside the window is ignored', () {
      final single = event(
        start: DateTime(2025, 5, 12, 9),
        end: DateTime(2025, 5, 12, 10),
      );
      expect(
        expandEvent(single, DateTime(2025, 3, 1), DateTime(2025, 4, 1)),
        isEmpty,
      );
    });

    test('daily recurrence fills the window and respects until', () {
      final daily = event(
        start: DateTime(2025, 3, 1, 8),
        end: DateTime(2025, 3, 1, 9),
        recurrence: RecurrenceFrequency.daily,
        until: DateTime(2025, 3, 5),
      );
      final occurrences = expandEvent(
        daily,
        DateTime(2025, 3, 1),
        DateTime(2025, 4, 1),
      );
      expect(occurrences, hasLength(5));
      expect(occurrences.last.start, DateTime(2025, 3, 5, 8));
    });

    test('weekly recurrence only lands on selected weekdays', () {
      // 2025-03-03 is a Monday.
      final weekly = event(
        start: DateTime(2025, 3, 3, 9),
        end: DateTime(2025, 3, 3, 10),
        recurrence: RecurrenceFrequency.weekly,
        byWeekday: 'mo,we',
      );
      final occurrences = expandEvent(
        weekly,
        DateTime(2025, 3, 1),
        DateTime(2025, 3, 15),
      );
      expect(
        occurrences.map((o) => o.start.weekday).toSet(),
        {DateTime.monday, DateTime.wednesday},
      );
      expect(occurrences.first.start, DateTime(2025, 3, 3, 9));
    });

    test('monthly recurrence keeps day of month and clamps short months', () {
      final monthly = event(
        start: DateTime(2025, 1, 31, 12),
        end: DateTime(2025, 1, 31, 13),
        recurrence: RecurrenceFrequency.monthly,
      );
      final occurrences = expandEvent(
        monthly,
        DateTime(2025, 1, 1),
        DateTime(2025, 4, 1),
      );
      expect(occurrences.map((o) => o.start.day), [31, 28, 31]);
    });

    test('multi day events are bucketed on every covered day', () {
      final trip = event(
        start: DateTime(2025, 3, 10, 9),
        end: DateTime(2025, 3, 12, 18),
      );
      final buckets = bucketByDay(
        [trip],
        DateTime(2025, 3, 1),
        DateTime(2025, 4, 1),
      );
      expect(buckets.keys, hasLength(3));
      expect(buckets[DateTime(2025, 3, 12)], hasLength(1));
    });
  });
}
