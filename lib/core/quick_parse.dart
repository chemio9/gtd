import 'date_x.dart';

/// Result of parsing a one-line "quick add" input.
class QuickAddResult {
  const QuickAddResult({
    required this.title,
    required this.dueDate,
    required this.matchedDateToken,
    required this.matchedTimeToken,
  });

  final String title;
  final DateTime? dueDate;

  /// True when the input contained a day token (today/tomorrow/…).
  final bool matchedDateToken;

  /// True when the input contained a time token (`at 9`, `14:30`).
  final bool matchedTimeToken;
}

/// Extracts a due date from a free-form line like `Buy milk tomorrow 9am`.
///
/// Supported tokens (case-insensitive, removed from the resulting title):
/// * `today`, `tomorrow`, `tonight` (today 20:00)
/// * `next week`, `next month`
/// * `in 3 days`, `+3d`
/// * weekday names: `mon`, `monday`, `tue`, `wed`, `thu`, `fri`, `sat`, `sun`
/// * times: `at 9`, `at 09:30`, `9am`, `7:15pm`, `at 14:00`
///
/// [fallbackDue] is used when the input has no day token at all.
QuickAddResult parseQuickAdd(
  String input, {
  DateTime? now,
  DateTime? fallbackDue,
}) {
  final reference = now ?? DateTime.now();
  final today = dateOnly(reference);
  var text = ' ${input.trim()} ';
  DateTime? day;
  DateTime? time;
  var matchedDate = false;
  var matchedTime = false;

  // --- time first, so "tomorrow 9am" keeps both parts ---------------------
  final timeMatch = _timePattern.firstMatch(text);
  if (timeMatch != null) {
    final hour = _parseHour(timeMatch);
    if (hour != null) {
      time = DateTime(
        0,
        1,
        1,
        hour,
        int.tryParse(timeMatch.namedGroup('minute') ?? '') ?? 0,
      );
      matchedTime = true;
      text = text.replaceRange(timeMatch.start, timeMatch.end, ' ');
    }
  }

  if (time == null) {
    final bareTime = _bareTimePattern.firstMatch(text);
    if (bareTime != null) {
      final hour = _parseHour(bareTime);
      if (hour != null) {
        time = DateTime(
          0,
          1,
          1,
          hour,
          int.tryParse(bareTime.namedGroup('minute') ?? '') ?? 0,
        );
        matchedTime = true;
        text = text.replaceRange(bareTime.start, bareTime.end, ' ');
      }
    }
  }

  // --- relative keywords --------------------------------------------------
  for (final entry in _keywordOffsets.entries) {
    final match = RegExp(
      '\\b${entry.key}\\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) continue;
    day = today.add(Duration(days: entry.value));
    matchedDate = true;
    text = text.replaceRange(match.start, match.end, ' ');
    break;
  }

  // --- "in 3 days" / "+3d" ------------------------------------------------
  if (day == null) {
    final offset = _offsetPattern.firstMatch(text);
    if (offset != null) {
      final days = int.tryParse(offset.group(1) ?? offset.group(2) ?? '');
      if (days != null) {
        day = today.add(Duration(days: days));
        matchedDate = true;
        text = text.replaceRange(offset.start, offset.end, ' ');
      }
    }
  }

  // --- weekday names ------------------------------------------------------
  if (day == null) {
    final weekday = _weekdayPattern.firstMatch(text);
    if (weekday != null) {
      final target = _weekdayNumbers[weekday.namedGroup('day')!.toLowerCase()];
      if (target != null) {
        final delta = (target - reference.weekday) % 7;
        day = today.add(Duration(days: delta));
        matchedDate = true;
        text = text.replaceRange(weekday.start, weekday.end, ' ');
      }
    }
  }

  DateTime? due;
  if (day != null || time != null) {
    final base = day ?? (fallbackDue != null ? dateOnly(fallbackDue) : today);
    due = DateTime(
      base.year,
      base.month,
      base.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
  } else if (fallbackDue != null) {
    due = fallbackDue;
  }

  final title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return QuickAddResult(
    title: title,
    dueDate: due,
    matchedDateToken: matchedDate,
    matchedTimeToken: matchedTime,
  );
}

int? _parseHour(RegExpMatch match) {
  var hour = int.tryParse(match.namedGroup('hour') ?? '');
  if (hour == null) return null;
  final suffix = match.groupNames.contains('suffix')
      ? (match.namedGroup('suffix') ?? '').toLowerCase()
      : '';
  if (suffix == 'pm' && hour < 12) hour += 12;
  if (suffix == 'am' && hour == 12) hour = 0;
  if (hour > 23) return null;
  return hour;
}

final _timePattern = RegExp(
  r'(?:\bat\s+)?\b(?<hour>\d{1,2})(?::(?<minute>\d{2}))?\s*(?<suffix>am|pm)\b',
  caseSensitive: false,
);

final _bareTimePattern = RegExp(
  r'(?:\bat\s+)(?<hour>\d{1,2})(?::(?<minute>\d{2}))?\b',
  caseSensitive: false,
);

final _offsetPattern = RegExp(
  r'(?:\bin\s+(\d{1,3})\s+days?|\+(\d{1,3})d\b)',
  caseSensitive: false,
);

final _weekdayPattern = RegExp(
  r'\b(?<day>mon|monday|tue|tues|tuesday|wed|weds|wednesday|thu|thur|thurs|thursday|fri|friday|sat|saturday|sun|sunday)\b',
  caseSensitive: false,
);

const _keywordOffsets = <String, int>{
  'today': 0,
  'tonight': 0,
  'tomorrow': 1,
  'next week': 7,
  'next month': 30,
};

const _weekdayNumbers = <String, int>{
  'mon': DateTime.monday,
  'monday': DateTime.monday,
  'tue': DateTime.tuesday,
  'tues': DateTime.tuesday,
  'tuesday': DateTime.tuesday,
  'wed': DateTime.wednesday,
  'weds': DateTime.wednesday,
  'wednesday': DateTime.wednesday,
  'thu': DateTime.thursday,
  'thur': DateTime.thursday,
  'thurs': DateTime.thursday,
  'thursday': DateTime.thursday,
  'fri': DateTime.friday,
  'friday': DateTime.friday,
  'sat': DateTime.saturday,
  'saturday': DateTime.saturday,
  'sun': DateTime.sunday,
  'sunday': DateTime.sunday,
};
