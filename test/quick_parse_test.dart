import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/core/date_x.dart';
import 'package:gtd/core/quick_parse.dart';

void main() {
  // Monday, 12 January 2026, 10:00.
  final now = DateTime(2026, 1, 12, 10);

  QuickAddResult parse(String input, {DateTime? fallback}) =>
      parseQuickAdd(input, now: now, fallbackDue: fallback);

  group('quick add parsing', () {
    test('plain text keeps the title and uses the fallback date', () {
      final result = parse('Buy milk', fallback: DateTime(2026, 1, 12));
      expect(result.title, 'Buy milk');
      expect(result.dueDate, DateTime(2026, 1, 12));
      expect(result.matchedDateToken, isFalse);
    });

    test('plain text without fallback has no due date', () {
      final result = parse('Buy milk');
      expect(result.title, 'Buy milk');
      expect(result.dueDate, isNull);
    });

    test('today / tomorrow strip the token from the title', () {
      expect(parse('Call mom tomorrow').title, 'Call mom');
      expect(parse('Call mom tomorrow').dueDate, DateTime(2026, 1, 13));

      expect(parse('today standup notes').title, 'standup notes');
      expect(parse('today standup notes').dueDate, DateTime(2026, 1, 12));
    });

    test('next week and offsets', () {
      expect(parse('Plan sprint next week').dueDate, DateTime(2026, 1, 19));
      expect(parse('Plan sprint next week').title, 'Plan sprint');
      expect(parse('Water plants in 3 days').dueDate, DateTime(2026, 1, 15));
      expect(parse('Water plants in 3 days').title, 'Water plants');
      expect(parse('Water plants +3d').dueDate, DateTime(2026, 1, 15));
    });

    test('weekday names resolve to the next occurrence', () {
      // 12 Jan 2026 is a Monday.
      expect(parse('Gym fri').dueDate, DateTime(2026, 1, 16));
      expect(parse('Gym friday').title, 'Gym');
      expect(parse('Gym mon').dueDate, DateTime(2026, 1, 12));
      expect(parse('Gym sun').dueDate, DateTime(2026, 1, 18));
    });

    test('time tokens combine with day tokens', () {
      final result = parse('Standup tomorrow at 9:30am');
      expect(result.title, 'Standup');
      expect(result.dueDate, DateTime(2026, 1, 13, 9, 30));
      expect(result.matchedTimeToken, isTrue);

      expect(parse('Review at 14:00').dueDate, DateTime(2026, 1, 12, 14));
      expect(parse('Review 7pm').dueDate, DateTime(2026, 1, 12, 19));
      expect(parse('Review 12am').dueDate, DateTime(2026, 1, 12, 0));
      expect(parse('Review 12pm').dueDate, DateTime(2026, 1, 12, 12));
    });

    test('date-only results are stored at midnight', () {
      final result = parse('Buy milk tomorrow');
      expect(hasTimeOfDay(result.dueDate!), isFalse);
      expect(hasTimeOfDay(parse('Buy milk at 9am').dueDate!), isTrue);
    });

    test('tokens are case insensitive and keep the rest intact', () {
      final result = parse('  Pay   TOMORROW   rent  ');
      expect(result.title, 'Pay rent');
      expect(result.dueDate, DateTime(2026, 1, 13));
    });

    test('a line with only a date token yields an empty title', () {
      final result = parse('tomorrow');
      expect(result.title, isEmpty);
      expect(result.dueDate, DateTime(2026, 1, 13));
    });
  });
}
