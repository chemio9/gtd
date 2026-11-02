import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a horizontal swipe on a todo row does.
enum SwipeAction { toggleComplete, scheduleToday, scheduleTomorrow, delete }

extension SwipeActionX on SwipeAction {
  String get label => switch (this) {
    SwipeAction.toggleComplete => 'Complete / reopen',
    SwipeAction.scheduleToday => 'Schedule for today',
    SwipeAction.scheduleTomorrow => 'Schedule for tomorrow',
    SwipeAction.delete => 'Delete',
  };

  /// Compact label for the swipe pane.
  String get shortLabel => switch (this) {
    SwipeAction.toggleComplete => 'Done',
    SwipeAction.scheduleToday => 'Today',
    SwipeAction.scheduleTomorrow => 'Tomorrow',
    SwipeAction.delete => 'Delete',
  };

  IconData get icon => switch (this) {
    SwipeAction.toggleComplete => Icons.check_circle_outline,
    SwipeAction.scheduleToday => Icons.today_outlined,
    SwipeAction.scheduleTomorrow => Icons.event_outlined,
    SwipeAction.delete => Icons.delete_outline,
  };

  /// Destructive actions get the error colour in the swipe pane.
  bool get isDestructive => this == SwipeAction.delete;

  static SwipeAction parse(Object? value, SwipeAction fallback) {
    for (final action in SwipeAction.values) {
      if (action.name == value) return action;
    }
    return fallback;
  }
}

/// User preferences. Persisted as JSON under a single key so the schema can
/// grow without touching one preference key per field.
@immutable
class AppSettings {
  const AppSettings({
    this.swipeStart = SwipeAction.toggleComplete,
    this.swipeEnd = SwipeAction.delete,
    this.notificationsEnabled = false,
    this.reminderMinutes = 8 * 60,
    this.deviceCalendarId,
    this.deviceCalendarName,
    this.lastCalendarSyncAt,
  });

  /// Swipe from the leading edge (to the right).
  final SwipeAction swipeStart;

  /// Swipe from the trailing edge (to the left).
  final SwipeAction swipeEnd;

  final bool notificationsEnabled;

  /// Daily reminder, minutes since midnight.
  final int reminderMinutes;

  /// Device calendar the GTD events are mirrored into.
  final int? deviceCalendarId;
  final String? deviceCalendarName;
  final DateTime? lastCalendarSyncAt;

  TimeOfDay get reminderTime =>
      TimeOfDay(hour: reminderMinutes ~/ 60, minute: reminderMinutes % 60);

  bool get hasDeviceCalendar => deviceCalendarId != null;

  AppSettings copyWith({
    SwipeAction? swipeStart,
    SwipeAction? swipeEnd,
    bool? notificationsEnabled,
    int? reminderMinutes,
    int? deviceCalendarId,
    String? deviceCalendarName,
    DateTime? lastCalendarSyncAt,
    bool clearDeviceCalendar = false,
    bool clearLastSync = false,
  }) {
    return AppSettings(
      swipeStart: swipeStart ?? this.swipeStart,
      swipeEnd: swipeEnd ?? this.swipeEnd,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      deviceCalendarId: clearDeviceCalendar
          ? null
          : deviceCalendarId ?? this.deviceCalendarId,
      deviceCalendarName: clearDeviceCalendar
          ? null
          : deviceCalendarName ?? this.deviceCalendarName,
      lastCalendarSyncAt: clearLastSync
          ? null
          : lastCalendarSyncAt ?? this.lastCalendarSyncAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'swipeStart': swipeStart.name,
    'swipeEnd': swipeEnd.name,
    'notificationsEnabled': notificationsEnabled,
    'reminderMinutes': reminderMinutes,
    'deviceCalendarId': deviceCalendarId,
    'deviceCalendarName': deviceCalendarName,
    'lastCalendarSyncAt': lastCalendarSyncAt?.toIso8601String(),
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    const defaults = AppSettings();
    return AppSettings(
      swipeStart: SwipeActionX.parse(json['swipeStart'], defaults.swipeStart),
      swipeEnd: SwipeActionX.parse(json['swipeEnd'], defaults.swipeEnd),
      notificationsEnabled: json['notificationsEnabled'] is bool
          ? json['notificationsEnabled'] as bool
          : defaults.notificationsEnabled,
      reminderMinutes: json['reminderMinutes'] is num
          ? (json['reminderMinutes'] as num).toInt()
          : defaults.reminderMinutes,
      deviceCalendarId: json['deviceCalendarId'] is num
          ? (json['deviceCalendarId'] as num).toInt()
          : null,
      deviceCalendarName: json['deviceCalendarName'] is String
          ? json['deviceCalendarName'] as String
          : null,
      lastCalendarSyncAt: json['lastCalendarSyncAt'] is String
          ? DateTime.tryParse(json['lastCalendarSyncAt'] as String)
          : null,
    );
  }
}

/// Storage seam so tests (and the web preview) never need platform channels.
abstract interface class SettingsStore {
  AppSettings read();
  Future<void> write(AppSettings settings);
}

/// Default store: keeps settings for the lifetime of the process.
class MemorySettingsStore implements SettingsStore {
  MemorySettingsStore([this._value = const AppSettings()]);

  AppSettings _value;

  @override
  AppSettings read() => _value;

  @override
  Future<void> write(AppSettings settings) async => _value = settings;
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  static const _key = 'settings.v1';

  final SharedPreferences _prefs;

  @override
  AppSettings read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return AppSettings.fromJson(decoded);
    } on FormatException {
      // Corrupted preferences fall back to defaults.
    }
    return const AppSettings();
  }

  @override
  Future<void> write(AppSettings settings) {
    return _prefs.setString(_key, jsonEncode(settings.toJson()));
  }
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => MemorySettingsStore(),
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsStoreProvider).read();

  Future<void> save(AppSettings next) async {
    state = next;
    await ref.read(settingsStoreProvider).write(next);
  }

  Future<void> setSwipeStart(SwipeAction action) =>
      save(state.copyWith(swipeStart: action));

  Future<void> setSwipeEnd(SwipeAction action) =>
      save(state.copyWith(swipeEnd: action));

  Future<void> setNotificationsEnabled(bool enabled) =>
      save(state.copyWith(notificationsEnabled: enabled));

  Future<void> setReminderTime(TimeOfDay time) =>
      save(state.copyWith(reminderMinutes: time.hour * 60 + time.minute));

  Future<void> setDeviceCalendar(int? id, String? name) => save(
    state.copyWith(
      deviceCalendarId: id,
      deviceCalendarName: name,
      clearDeviceCalendar: id == null,
    ),
  );

  Future<void> markCalendarSynced(DateTime at) =>
      save(state.copyWith(lastCalendarSyncAt: at));
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);
