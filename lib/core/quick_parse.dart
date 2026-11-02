import 'date_x.dart';

/// Result of parsing a one-line "quick add" input.
class QuickAddResult {
  const QuickAddResult({
    required this.title,
    required this.dueDate,
    required this.matchedDateToken,
    required this.matchedTimeToken,
    this.spans = const [],
  });

  final String title;
  final DateTime? dueDate;

  /// True when the input contained a day token (today/tomorrow/2026-11-03/…).
  final bool matchedDateToken;

  /// True when the input contained a time token (`at 9`, `14:30`, `9am`).
  final bool matchedTimeToken;

  /// Character ranges of the recognised tokens inside the original input.
  /// Used to highlight them in the text field.
  final List<(int, int)> spans;

  bool get hasTokens => spans.isNotEmpty;
}

/// Extracts a due date from a free-form line like `a conference 2026-11-03 9:45`.
///
/// Supported tokens (case-insensitive, removed from the resulting title):
/// * absolute dates: `2026-11-03`, `2026/11/3`, `2026-11-03T09:45`
/// * relative days: `today`, `tomorrow`, `tonight` (today 20:00)
/// * `next week`, `next month`, `in 3 days`, `+3d`
/// * weekday names: `mon`, `monday`, `tue`, `wed`, `thu`, `fri`, `sat`, `sun`
/// * times: `9:45`, `at 9`, `at 09:30`, `9am`, `7:15pm`, `at 14:00`
///
/// [fallbackDue] is used when the input has no day token at all.
QuickAddResult parseQuickAdd(
  String input, {
  DateTime? now,
  DateTime? fallbackDue,
}) {
  final reference = now ?? DateTime.now();
  final today = dateOnly(reference);
  var text = input;
  final spans = <(int, int)>[];

  // Blanking a token with spaces (instead of deleting it) keeps every later
  // match offset valid, so the reported spans point into the original input.
  void consume(int start, int end) {
    spans.add((start, end));
    text = text.replaceRange(start, end, ' ' * (end - start));
  }

  DateTime? day;
  DateTime? time;
  var matchedDate = false;
  var matchedTime = false;

  // --- 1. absolute date, optionally with a time ---------------------------
  final dateTimeMatch = _isoDateTimePattern.firstMatch(text);
  if (dateTimeMatch != null) {
    final date = _dateFromParts(dateTimeMatch);
    if (date != null) {
      day = date;
      final hour = int.parse(dateTimeMatch[4]!);
      final minute = int.parse(dateTimeMatch[5]!);
      if (hour < 24 && minute < 60) {
        time = DateTime(0, 1, 1, hour, minute);
        matchedTime = true;
      }
      matchedDate = true;
      consume(dateTimeMatch.start, dateTimeMatch.end);
    }
  }

  if (day == null) {
    final isoDate = _isoDatePattern.firstMatch(text);
    if (isoDate != null) {
      final date = _dateFromParts(isoDate);
      if (date != null) {
        day = date;
        matchedDate = true;
        consume(isoDate.start, isoDate.end);
      }
    }
  }

  // --- 2. time, so "tomorrow 9am" keeps both parts ------------------------
  if (time == null) {
    final clock = _amPmPattern.firstMatch(text);
    if (clock != null) {
      final hour = _parseAmPmHour(clock);
      if (hour != null) {
        time = DateTime(0, 1, 1, hour, int.parse(clock[2] ?? '0'));
        matchedTime = true;
        consume(clock.start, clock.end);
      }
    }
  }

  if (time == null) {
    final colonTime = _colonTimePattern.firstMatch(text);
    if (colonTime != null) {
      final hour = int.parse(colonTime[1]!);
      final minute = int.parse(colonTime[2]!);
      if (hour < 24 && minute < 60) {
        time = DateTime(0, 1, 1, hour, minute);
        matchedTime = true;
        consume(colonTime.start, colonTime.end);
      }
    }
  }

  if (time == null) {
    final atHour = _atHourPattern.firstMatch(text);
    if (atHour != null) {
      final hour = int.parse(atHour[1]!);
      if (hour < 24) {
        time = DateTime(0, 1, 1, hour);
        matchedTime = true;
        consume(atHour.start, atHour.end);
      }
    }
  }

  // --- 3. relative keywords ----------------------------------------------
  if (day == null) {
    for (final entry in _keywordOffsets.entries) {
      final match = RegExp(
        '\\b${entry.key}\\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) continue;
      day = today.add(Duration(days: entry.value));
      matchedDate = true;
      consume(match.start, match.end);
      break;
    }
  }

  // --- 4. "in 3 days" / "+3d" ---------------------------------------------
  if (day == null) {
    final offset = _offsetPattern.firstMatch(text);
    if (offset != null) {
      final days = int.tryParse(offset.group(1) ?? offset.group(2) ?? '');
      if (days != null) {
        day = today.add(Duration(days: days));
        matchedDate = true;
        consume(offset.start, offset.end);
      }
    }
  }

  // --- 5. weekday names ---------------------------------------------------
  if (day == null) {
    final weekday = _weekdayPattern.firstMatch(text);
    if (weekday != null) {
      final target = _weekdayNumbers[weekday.namedGroup('day')!.toLowerCase()];
      if (target != null) {
        final delta = (target - reference.weekday) % 7;
        day = today.add(Duration(days: delta));
        matchedDate = true;
        consume(weekday.start, weekday.end);
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

  spans.sort((a, b) => a.$1.compareTo(b.$1));
  final title = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return QuickAddResult(
    title: title,
    dueDate: due,
    matchedDateToken: matchedDate,
    matchedTimeToken: matchedTime,
    spans: spans,
  );
}

/// `2026-11-03`, `2026/11/3` — groups: 1=year 2=month 3=day.
DateTime? _dateFromParts(RegExpMatch match) {
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  // Rejects impossible days such as 2026-02-31.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

int? _parseAmPmHour(RegExpMatch match) {
  var hour = int.tryParse(match[1] ?? '');
  if (hour == null || hour > 12) return null;
  final suffix = (match[3] ?? '').toLowerCase();
  if (suffix == 'pm' && hour < 12) hour += 12;
  if (suffix == 'am' && hour == 12) hour = 0;
  return hour;
}

/// `2026-11-03T09:45` / `2026-11-03 09:45`
final _isoDateTimePattern = RegExp(
  r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})[Tt ](\d{1,2}):(\d{2})\b',
  caseSensitive: false,
);

/// `2026-11-03` / `2026/11/3`
final _isoDatePattern = RegExp(
  r'\b(\d{4})[-/](\d{1,2})[-/](\d{1,2})\b',
  caseSensitive: false,
);

/// `9:45am` / `7:15 pm` / `at 9:30am` — 1=hour 2=minute 3=suffix.
final _amPmPattern = RegExp(
  r'(?:\bat\s+)?\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
  caseSensitive: false,
);

/// `9:45`, `at 09:30` — 2=hour 3=minute.
final _colonTimePattern = RegExp(
  r'(?:\bat\s+)?\b(\d{1,2}):(\d{2})\b',
  caseSensitive: false,
);

/// `at 9` — 2=hour.
final _atHourPattern = RegExp(r'\bat\s+(\d{1,2})\b', caseSensitive: false);

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
