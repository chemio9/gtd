import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers.dart';
import '../services/device_calendar_service.dart';
import 'database.dart';

/// Maps `events.id` (GTD) to the event id inside the device calendar.
abstract interface class SyncMappingStore {
  Map<int, int> read();
  Future<void> write(Map<int, int> mapping);
}

class MemorySyncMappingStore implements SyncMappingStore {
  MemorySyncMappingStore([Map<int, int>? initial])
    : _mapping = {...?initial};

  Map<int, int> _mapping;

  @override
  Map<int, int> read() => Map.unmodifiable(_mapping);

  @override
  Future<void> write(Map<int, int> mapping) async => _mapping = {...mapping};
}

class PrefsSyncMappingStore implements SyncMappingStore {
  PrefsSyncMappingStore(this._prefs);

  static const _key = 'calendarSync.v1';

  final SharedPreferences _prefs;

  @override
  Map<int, int> read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return {
          for (final entry in decoded.entries)
            if (int.tryParse('${entry.key}') case final key?)
              if (entry.value is num) key: (entry.value as num).toInt(),
        };
      }
    } on FormatException {
      // Ignore corrupt mapping.
    }
    return {};
  }

  @override
  Future<void> write(Map<int, int> mapping) => _prefs.setString(
    _key,
    jsonEncode({for (final entry in mapping.entries) '${entry.key}': entry.value}),
  );
}

/// Reported by [CalendarSyncService.sync].
class CalendarSyncResult {
  const CalendarSyncResult({
    this.created = 0,
    this.updated = 0,
    this.deleted = 0,
    this.failed = 0,
  });

  final int created;
  final int updated;
  final int deleted;
  final int failed;

  bool get isEmpty => created + updated + deleted == 0;

  String get summary => [
    if (created > 0) '$created created',
    if (updated > 0) '$updated updated',
    if (deleted > 0) '$deleted removed',
    if (failed > 0) '$failed failed',
    if (created + updated + deleted + failed == 0) 'nothing to sync',
  ].join(', ');
}

/// Pushes every stored event (recurring series included) into one device
/// calendar, remembering which device row belongs to which app event so repeat
/// syncs update instead of duplicating.
class CalendarSyncService {
  CalendarSyncService(this._db, this._gateway, this._mapping);

  final AppDatabase _db;
  final CalendarGateway _gateway;
  final SyncMappingStore _mapping;

  Future<CalendarSyncResult> sync({
    required int calendarId,
    required String timeZone,
  }) async {
    final events = await _db.select(_db.events).get();
    final tasks = await _db.select(_db.tasks).get();
    final taskTitles = {for (final task in tasks) task.id: task.title};
    final mapping = {..._mapping.read()};
    var created = 0;
    var updated = 0;
    var deleted = 0;
    var failed = 0;

    for (final event in events) {
      final payload = DeviceCalendarEvent(
        calendarId: calendarId,
        title: event.title,
        description: _description(
          event.notes,
          event.linkedTaskId == null ? null : taskTitles[event.linkedTaskId],
        ),
        start: event.startsAt,
        end: event.endsAt,
        allDay: event.allDay,
        timeZone: timeZone,
        rrule: buildRRule(event),
      );

      final existing = mapping[event.id];
      try {
        if (existing != null) {
          await _gateway.updateEvent(existing, payload);
          updated++;
        } else {
          final deviceId = await _gateway.insertEvent(payload);
          if (deviceId == null) {
            failed++;
          } else {
            mapping[event.id] = deviceId;
            created++;
          }
        }
      } on Object {
        failed++;
      }
    }

    // Events deleted in the app are removed from the device calendar too.
    final liveIds = events.map((event) => event.id).toSet();
    for (final staleId in mapping.keys.where((id) => !liveIds.contains(id)).toList()) {
      try {
        await _gateway.deleteEvent(mapping[staleId]!);
        mapping.remove(staleId);
        deleted++;
      } on Object {
        failed++;
      }
    }

    await _mapping.write(mapping);
    return CalendarSyncResult(
      created: created,
      updated: updated,
      deleted: deleted,
      failed: failed,
    );
  }

  /// Removes every device event this app created and forgets the mapping.
  Future<int> unlinkAll() async {
    final mapping = _mapping.read();
    var deleted = 0;
    for (final deviceEventId in mapping.values) {
      try {
        await _gateway.deleteEvent(deviceEventId);
        deleted++;
      } on Object {
        // Keep going; the mapping is cleared anyway.
      }
    }
    await _mapping.write({});
    return deleted;
  }
}

/// Merges free-text notes with the linked task, so the device calendar shows
/// what the event is about.
String? _description(String? notes, String? taskTitle) {
  final parts = [
    if (notes != null && notes.trim().isNotEmpty) notes.trim(),
    if (taskTitle != null && taskTitle.trim().isNotEmpty) 'Task: $taskTitle',
  ];
  return parts.isEmpty ? null : parts.join('\n\n');
}

/// `RRULE` string understood by Android's CalendarContract.
String? buildRRule(Event event) {
  String? until;
  final untilDate = event.recurrenceUntil;
  if (untilDate != null) {
    until =
        'UNTIL=${untilDate.year.toString().padLeft(4, '0')}'
        '${untilDate.month.toString().padLeft(2, '0')}'
        '${untilDate.day.toString().padLeft(2, '0')}T235959Z';
  }

  final parts = <String>[];
  switch (event.recurrence) {
    case RecurrenceFrequency.none:
      return null;
    case RecurrenceFrequency.daily:
      parts.add('FREQ=DAILY');
    case RecurrenceFrequency.weekly:
      parts.add('FREQ=WEEKLY');
      final codes = [...WeekdayCodeX.parse(event.byWeekday)]
        ..sort((a, b) => a.index.compareTo(b.index));
      if (codes.isNotEmpty) {
        parts.add('BYDAY=${codes.map((code) => code.name.toUpperCase()).join(',')}');
      }
    case RecurrenceFrequency.monthly:
      parts.add('FREQ=MONTHLY');
  }
  if (until != null) parts.add(until);
  return parts.join(';');
}

final syncMappingStoreProvider = Provider<SyncMappingStore>(
  (ref) => MemorySyncMappingStore(),
);

final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  return CalendarSyncService(
    ref.watch(databaseProvider),
    ref.watch(deviceCalendarServiceProvider),
    ref.watch(syncMappingStoreProvider),
  );
});
