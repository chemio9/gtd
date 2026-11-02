import 'package:intl/intl.dart';

/// Date helpers used across the app. Everything is local time.
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime startOfDay(DateTime value) => dateOnly(value);

DateTime endOfDay(DateTime value) =>
    dateOnly(value).add(const Duration(days: 1));

DateTime startOfWeek(DateTime value) =>
    dateOnly(value).subtract(Duration(days: value.weekday - 1));

DateTime startOfMonth(DateTime value) => DateTime(value.year, value.month);

DateTime endOfMonth(DateTime value) =>
    DateTime(value.year, value.month + 1);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool isToday(DateTime value) => isSameDay(value, DateTime.now());

bool isSameMonth(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month;

DateTime combine(DateTime day, {int hour = 0, int minute = 0}) =>
    DateTime(day.year, day.month, day.day, hour, minute);

Duration timeOfDaySinceMidnight(DateTime value) =>
    Duration(hours: value.hour, minutes: value.minute);

/// Tasks usually only have a *day*; a midnight timestamp means "no time".
bool hasTimeOfDay(DateTime value) => value.hour != 0 || value.minute != 0;

/// `Today` for date-only due dates, `Today · 09:00` when a time is set.
String formatDueLabel(DateTime value) {
  final day = friendlyDay(value);
  return hasTimeOfDay(value) ? '$day · ${formatTime(value)}' : day;
}

/// `14:30`
String formatTime(DateTime value) => DateFormat.Hm().format(value);

/// `Wed, 12 Nov`
String formatDay(DateTime value) => DateFormat('EEE, d MMM').format(value);

/// `12 Nov 2025`
String formatFullDate(DateTime value) => DateFormat('d MMM y').format(value);

/// `Nov` / `November 2025`
String formatMonthYear(DateTime value) => DateFormat('MMMM y').format(value);

/// Human friendly day label used by the todo list: `Today`, `Tomorrow`,
/// `Yesterday`, `Wed, 12 Nov` or `12 Nov 2025` when outside this year.
String friendlyDay(DateTime value) {
  final today = dateOnly(DateTime.now());
  final day = dateOnly(value);
  final diff = day.difference(today).inDays;
  return switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ when day.year == today.year => DateFormat('EEE, d MMM').format(value),
    _ => DateFormat('d MMM y').format(value),
  };
}
