import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gtd/settings/settings.dart';

void main() {
  group('AppSettings json', () {
    test('round trips every field', () {
      const settings = AppSettings(
        swipeStart: SwipeAction.scheduleTomorrow,
        swipeEnd: SwipeAction.scheduleToday,
        notificationsEnabled: true,
        reminderMinutes: 7 * 60 + 15,
      );
      final decoded = AppSettings.fromJson(settings.toJson());

      expect(decoded.swipeStart, SwipeAction.scheduleTomorrow);
      expect(decoded.swipeEnd, SwipeAction.scheduleToday);
      expect(decoded.notificationsEnabled, isTrue);
      expect(decoded.reminderMinutes, 7 * 60 + 15);
      expect(decoded.reminderTime, const TimeOfDay(hour: 7, minute: 15));
    });

    test('unknown values fall back to defaults', () {
      final decoded = AppSettings.fromJson({
        'swipeStart': 'somethingElse',
        'swipeEnd': null,
        'notificationsEnabled': 'yes',
        'reminderMinutes': 'late',
      });
      const defaults = AppSettings();

      expect(decoded.swipeStart, defaults.swipeStart);
      expect(decoded.swipeEnd, defaults.swipeEnd);
      expect(decoded.notificationsEnabled, defaults.notificationsEnabled);
      expect(decoded.reminderMinutes, defaults.reminderMinutes);
    });
  });

  group('SettingsController', () {
    test('persists updates through the store', () async {
      final store = MemorySettingsStore();
      final container = ProviderContainer(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      expect(container.read(settingsProvider).swipeEnd, SwipeAction.delete);

      await container
          .read(settingsProvider.notifier)
          .setSwipeEnd(SwipeAction.scheduleToday);
      await container
          .read(settingsProvider.notifier)
          .setReminderTime(const TimeOfDay(hour: 6, minute: 30));

      expect(container.read(settingsProvider).swipeEnd, SwipeAction.scheduleToday);
      expect(store.read().swipeEnd, SwipeAction.scheduleToday);
      expect(store.read().reminderMinutes, 6 * 60 + 30);
    });
  });
}
