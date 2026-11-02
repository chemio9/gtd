import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A calendar account installed on the device.
@immutable
class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    required this.account,
    required this.isWritable,
    required this.isPrimary,
  });

  final int id;
  final String name;
  final String account;
  final bool isWritable;
  final bool isPrimary;

  factory DeviceCalendarInfo.fromMap(Map<Object?, Object?> map) {
    return DeviceCalendarInfo(
      id: (map['id'] as num).toInt(),
      name: map['name'] as String? ?? 'Calendar',
      account: map['account'] as String? ?? '',
      isWritable: map['isWritable'] as bool? ?? false,
      isPrimary: map['isPrimary'] as bool? ?? false,
    );
  }
}

/// Everything needed to write one GTD event into the device calendar.
@immutable
class DeviceCalendarEvent {
  const DeviceCalendarEvent({
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.timeZone,
    this.description,
    this.rrule,
  });

  final int calendarId;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final String timeZone;
  final String? description;
  final String? rrule;

  bool get isRecurring => rrule != null && rrule!.isNotEmpty;

  Map<String, Object?> toMap({int? deviceEventId}) {
    // All-day events must be anchored to UTC midnight, end exclusive.
    final startMillis = allDay
        ? DateTime.utc(start.year, start.month, start.day)
              .millisecondsSinceEpoch
        : start.millisecondsSinceEpoch;
    final endMillis = allDay
        ? DateTime.utc(
            end.year,
            end.month,
            end.day,
          ).add(const Duration(days: 1)).millisecondsSinceEpoch
        : end.millisecondsSinceEpoch;

    return {
      'deviceEventId': ?deviceEventId,
      'calendarId': calendarId,
      'title': title,
      'description': description,
      'startMillis': startMillis,
      'endMillis': endMillis,
      'allDay': allDay,
      'timeZone': timeZone,
      'rrule': rrule,
    };
  }
}

/// Gateway used by the sync service. The real implementation talks to the
/// Android `CalendarContract` provider over a MethodChannel; tests use a fake.
abstract interface class CalendarGateway {
  Future<int?> insertEvent(DeviceCalendarEvent event);
  Future<void> updateEvent(int deviceEventId, DeviceCalendarEvent event);
  Future<void> deleteEvent(int deviceEventId);
}

class DeviceCalendarService implements CalendarGateway {
  DeviceCalendarService([MethodChannel? channel])
    : _channel = channel ?? const MethodChannel('gtd/calendar');

  final MethodChannel _channel;

  /// Calendar sync is implemented for Android only.
  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> hasPermission() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('hasPermission') ?? false;
  }

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('requestPermission') ?? false;
  }

  Future<List<DeviceCalendarInfo>> calendars() async {
    if (!isSupported) return const [];
    final raw = await _channel.invokeListMethod<Object?>('listCalendars');
    return [
      for (final entry in raw ?? const <Object?>[])
        if (entry is Map)
          DeviceCalendarInfo.fromMap(entry.cast<Object?, Object?>()),
    ];
  }

  Future<int?> createLocalCalendar(String name) async {
    if (!isSupported) return null;
    return await _channel.invokeMethod<int>('createLocalCalendar', {
      'name': name,
    });
  }

  @override
  Future<int?> insertEvent(DeviceCalendarEvent event) async {
    if (!isSupported) return null;
    return await _channel.invokeMethod<int>('insertEvent', event.toMap());
  }

  @override
  Future<void> updateEvent(int deviceEventId, DeviceCalendarEvent event) async {
    if (!isSupported) return;
    // The calendar cannot change for an existing device event.
    final payload = event.toMap(deviceEventId: deviceEventId)
      ..remove('calendarId');
    await _channel.invokeMethod<bool>('updateEvent', payload);
  }

  @override
  Future<void> deleteEvent(int deviceEventId) async {
    if (!isSupported) return;
    await _channel.invokeMethod<bool>('deleteEvent', {
      'deviceEventId': deviceEventId,
    });
  }
}

final deviceCalendarServiceProvider = Provider<DeviceCalendarService>(
  (ref) => DeviceCalendarService(),
);
