import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/data/calendar_sync.dart';
import 'package:gtd/data/database.dart';
import 'package:gtd/services/device_calendar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeCalendarGateway implements CalendarGateway {
  int nextId = 100;
  final Map<int, DeviceCalendarEvent> events = {};
  int inserts = 0;
  int updates = 0;
  int deletes = 0;
  bool failInserts = false;

  @override
  Future<int?> insertEvent(DeviceCalendarEvent event) async {
    inserts++;
    if (failInserts) return null;
    final id = nextId++;
    events[id] = event;
    return id;
  }

  @override
  Future<void> updateEvent(int deviceEventId, DeviceCalendarEvent event) async {
    updates++;
    events[deviceEventId] = event;
  }

  @override
  Future<void> deleteEvent(int deviceEventId) async {
    deletes++;
    events.remove(deviceEventId);
  }
}

void main() {
  late AppDatabase db;
  late FakeCalendarGateway gateway;
  late MemorySyncMappingStore mapping;
  late CalendarSyncService sync;
  const calendarId = 42;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    gateway = FakeCalendarGateway();
    mapping = MemorySyncMappingStore();
    sync = CalendarSyncService(db, gateway, mapping);
  });

  tearDown(() => db.close());

  Future<int> addEvent({
    String title = 'Team sync',
    String? notes,
    DateTime? start,
    DateTime? end,
    bool allDay = false,
    RecurrenceFrequency recurrence = RecurrenceFrequency.none,
    String? byWeekday,
    DateTime? until,
  }) {
    return db.eventDao.createEvent(
      EventsCompanion.insert(
        title: title,
        notes: Value(notes),
        startsAt: start ?? DateTime(2026, 11, 3, 9),
        endsAt: end ?? DateTime(2026, 11, 3, 10),
        allDay: Value(allDay),
        recurrence: Value(recurrence),
        byWeekday: Value(byWeekday),
        recurrenceUntil: Value(until),
      ),
    );
  }

  Future<CalendarSyncResult> runSync() =>
      sync.sync(calendarId: calendarId, timeZone: 'Europe/Berlin');

  test('first sync creates every event and records the mapping', () async {
    await addEvent(title: 'Standup');
    await addEvent(
      title: 'Design review',
      start: DateTime(2026, 11, 4, 14),
      end: DateTime(2026, 11, 4, 15, 30),
    );

    final result = await runSync();

    expect(result.created, 2);
    expect(result.updated, 0);
    expect(gateway.events, hasLength(2));
    expect(mapping.read(), hasLength(2));
    expect(
      gateway.events.values.map((e) => e.title),
      containsAll(['Standup', 'Design review']),
    );
    // The payload carries the chosen calendar and timezone.
    expect(gateway.events.values.every((e) => e.calendarId == calendarId), isTrue);
    expect(gateway.events.values.every((e) => e.timeZone == 'Europe/Berlin'), isTrue);
  });

  test('second sync updates instead of duplicating', () async {
    final id = await addEvent(title: 'Standup');
    await runSync();
    expect(gateway.inserts, 1);

    await db.eventDao.updateEvent(
      id,
      const EventsCompanion(title: Value('Daily standup')),
    );
    final result = await runSync();

    expect(result.updated, 1);
    expect(result.created, 0);
    expect(gateway.inserts, 1);
    expect(gateway.events.values.single.title, 'Daily standup');
  });

  test('events deleted in the app are deleted from the device', () async {
    final keep = await addEvent(title: 'Keep me');
    final drop = await addEvent(title: 'Drop me');
    await runSync();
    expect(gateway.events, hasLength(2));

    await db.eventDao.deleteEvent(drop);
    final result = await runSync();

    expect(result.deleted, 1);
    expect(gateway.deletes, 1);
    expect(gateway.events, hasLength(1));
    expect(mapping.read().keys, [keep]);
  });

  test('all-day events are stored as UTC midnight and flagged', () async {
    await addEvent(
      title: 'Holiday',
      allDay: true,
      start: DateTime(2026, 11, 3, 9),
      end: DateTime(2026, 11, 3, 10),
    );

    await runSync();

    final payload = gateway.events.values.single;
    expect(payload.allDay, isTrue);
    final map = payload.toMap();
    expect(
      map['startMillis'],
      DateTime.utc(2026, 11, 3).millisecondsSinceEpoch,
    );
    // All-day end is exclusive: next UTC midnight.
    expect(
      map['endMillis'],
      DateTime.utc(2026, 11, 4).millisecondsSinceEpoch,
    );
  });

  test('recurring events carry an RRULE', () async {
    await addEvent(
      title: 'Weekly review',
      recurrence: RecurrenceFrequency.weekly,
      byWeekday: 'mo,we',
      until: DateTime(2026, 12, 31),
    );

    await runSync();

    expect(
      gateway.events.values.single.rrule,
      'FREQ=WEEKLY;BYDAY=MO,WE;UNTIL=20261231T235959Z',
    );
  });

  test('failed inserts are reported and not mapped', () async {
    await addEvent();
    gateway.failInserts = true;

    final result = await runSync();

    expect(result.failed, 1);
    expect(result.created, 0);
    expect(mapping.read(), isEmpty);
  });

  test('unlinkAll removes device copies and forgets the mapping', () async {
    await addEvent(title: 'A');
    await addEvent(title: 'B');
    await runSync();

    final removed = await sync.unlinkAll();

    expect(removed, 2);
    expect(gateway.events, isEmpty);
    expect(mapping.read(), isEmpty);
  });

  test('prefs mapping store round trips and survives bad data', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PrefsSyncMappingStore(prefs);

    expect(store.read(), isEmpty);
    await store.write({3: 900, 4: 901});
    expect(store.read(), {3: 900, 4: 901});

    await prefs.setString('calendarSync.v1', 'not json');
    expect(store.read(), isEmpty);
  });

  group('buildRRule', () {
    Event event({
      required RecurrenceFrequency recurrence,
      String? byWeekday,
      DateTime? until,
    }) {
      return Event(
        id: 1,
        title: 'x',
        startsAt: DateTime(2026, 11, 2, 9),
        endsAt: DateTime(2026, 11, 2, 10),
        allDay: false,
        recurrence: recurrence,
        byWeekday: byWeekday,
        recurrenceUntil: until,
        createdAt: DateTime(2026, 11, 2),
      );
    }

    test('one-off events have no rule', () {
      expect(buildRRule(event(recurrence: RecurrenceFrequency.none)), isNull);
    });

    test('daily without end date', () {
      expect(
        buildRRule(event(recurrence: RecurrenceFrequency.daily)),
        'FREQ=DAILY',
      );
    });

    test('weekly with weekdays is sorted and upper cased', () {
      expect(
        buildRRule(
          event(recurrence: RecurrenceFrequency.weekly, byWeekday: 'we,mo'),
        ),
        'FREQ=WEEKLY;BYDAY=MO,WE',
      );
    });

    test('monthly with until date', () {
      expect(
        buildRRule(
          event(
            recurrence: RecurrenceFrequency.monthly,
            until: DateTime(2027, 1, 5),
          ),
        ),
        'FREQ=MONTHLY;UNTIL=20270105T235959Z',
      );
    });
  });
}
