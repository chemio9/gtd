import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/services/device_calendar_service.dart';

/// Verifies the Dart side of the `gtd/calendar` MethodChannel contract without
/// a device: payload shape, parsing and platform support.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('gtd/calendar');
  final calls = <MethodCall>[];
  late DeviceCalendarService service;

  void mockChannel(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call);
          return handler(call);
        });
  }

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    service = DeviceCalendarService(channel);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('support', () {
    test('is supported on Android', () {
      expect(service.isSupported, isTrue);
    });

    test('is not supported on desktop and never hits the channel', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      mockChannel((_) async => null);

      expect(service.isSupported, isFalse);
      expect(await service.hasPermission(), isFalse);
      expect(await service.calendars(), isEmpty);
      expect(await service.insertEvent(_event()), isNull);
      expect(calls, isEmpty);
    });
  });

  group('permissions', () {
    test('forwards the native answer', () async {
      mockChannel((call) async => call.method == 'requestPermission');

      expect(await service.hasPermission(), isFalse);
      expect(await service.requestPermission(), isTrue);
      expect(calls.map((c) => c.method), ['hasPermission', 'requestPermission']);
    });
  });

  group('calendars', () {
    test('parses id, name, account and writable flags', () async {
      mockChannel(
        (_) async => [
          {
            'id': 1,
            'name': 'Personal',
            'account': 'me@example.com',
            'isWritable': true,
            'isPrimary': true,
          },
          {
            'id': 2,
            'name': 'Holidays',
            'account': 'me@example.com',
            'isWritable': false,
            'isPrimary': false,
          },
        ],
      );

      final calendars = await service.calendars();

      expect(calendars, hasLength(2));
      expect(calendars.first.id, 1);
      expect(calendars.first.name, 'Personal');
      expect(calendars.first.account, 'me@example.com');
      expect(calendars.first.isWritable, isTrue);
      expect(calendars.first.isPrimary, isTrue);
      expect(calendars[1].isWritable, isFalse);
    });

    test('creates a local calendar with the requested name', () async {
      mockChannel((call) async {
        expect(call.method, 'createLocalCalendar');
        expect(call.arguments, {'name': 'GTD'});
        return 7;
      });

      expect(await service.createLocalCalendar('GTD'), 7);
    });
  });

  group('events', () {
    test('insert sends the calendar id and epoch millis', () async {
      mockChannel((call) async {
        expect(call.method, 'insertEvent');
        final args = (call.arguments as Map).cast<String, Object?>();
        expect(args['calendarId'], 42);
        expect(args['title'], 'Team sync');
        expect(args['description'], 'weekly');
        expect(args['allDay'], isFalse);
        expect(args['timeZone'], 'Europe/Berlin');
        expect(args['startMillis'], DateTime(2026, 11, 3, 9).millisecondsSinceEpoch);
        expect(args['endMillis'], DateTime(2026, 11, 3, 9, 30).millisecondsSinceEpoch);
        expect(args.containsKey('deviceEventId'), isFalse);
        return 1234;
      });

      final id = await service.insertEvent(_event());
      expect(id, 1234);
    });

    test('all-day events snap to UTC midnight with an exclusive end', () async {
      mockChannel((call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        expect(args['allDay'], isTrue);
        expect(args['startMillis'], DateTime.utc(2026, 11, 3).millisecondsSinceEpoch);
        expect(args['endMillis'], DateTime.utc(2026, 11, 4).millisecondsSinceEpoch);
        return 1;
      });

      await service.insertEvent(
        _event(
          start: DateTime(2026, 11, 3, 9),
          end: DateTime(2026, 11, 3, 10),
          allDay: true,
        ),
      );
    });

    test('recurring events carry the rrule', () async {
      mockChannel((call) async {
        final args = (call.arguments as Map).cast<String, Object?>();
        expect(args['rrule'], 'FREQ=WEEKLY;BYDAY=MO,WE');
        return 1;
      });

      await service.insertEvent(_event(rrule: 'FREQ=WEEKLY;BYDAY=MO,WE'));
    });

    test('update includes the device event id and no calendar id', () async {
      mockChannel((call) async {
        expect(call.method, 'updateEvent');
        final args = (call.arguments as Map).cast<String, Object?>();
        expect(args['deviceEventId'], 99);
        expect(args.containsKey('calendarId'), isFalse);
        return true;
      });

      await service.updateEvent(99, _event());
    });

    test('delete sends only the device event id', () async {
      mockChannel((call) async {
        expect(call.method, 'deleteEvent');
        expect(call.arguments, {'deviceEventId': 99});
        return true;
      });

      await service.deleteEvent(99);
    });
  });
}

DeviceCalendarEvent _event({
  DateTime? start,
  DateTime? end,
  bool allDay = false,
  String? rrule,
}) {
  return DeviceCalendarEvent(
    calendarId: 42,
    title: 'Team sync',
    description: 'weekly',
    start: start ?? DateTime(2026, 11, 3, 9),
    end: end ?? DateTime(2026, 11, 3, 9, 30),
    allDay: allDay,
    timeZone: 'Europe/Berlin',
    rrule: rrule,
  );
}
