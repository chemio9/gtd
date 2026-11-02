import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/date_x.dart';
import '../../data/calendar_sync.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';
import '../../services/device_calendar_service.dart';
import '../../services/time_zone_service.dart';
import '../../services/notification_service.dart';
import '../../settings/settings.dart';

/// App version, read from the platform bundle (falls back when unavailable,
/// e.g. in widget tests).
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.isEmpty ? '' : '+${info.buildNumber}';
    return '${info.version}$build';
  } on Object {
    return 'dev';
  }
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final version = ref.watch(appVersionProvider);
    final notificationsAvailable =
        !kIsWeb && ref.read(notificationServiceProvider).isSupported;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionHeader(context.l10n.settingsSwipe),
          _SwipeActionTile(
            title: context.l10n.settingsSwipeRight,
            subtitle: context.l10n.settingsSwipeRightHint,
            value: settings.swipeStart,
            onChanged: notifier.setSwipeStart,
          ),
          _SwipeActionTile(
            title: context.l10n.settingsSwipeLeft,
            value: settings.swipeEnd,
            onChanged: notifier.setSwipeEnd,
          ),
          const Divider(height: 24),
          _SectionHeader(context.l10n.settingsReminders),
          SwitchListTile(
            title: Text(context.l10n.settingsDailyReminder),
            subtitle: Text(
              notificationsAvailable
                  ? context.l10n.settingsDailyReminderHint
                  : context.l10n.settingsNotificationsUnsupported,
            ),
            value: settings.notificationsEnabled && notificationsAvailable,
            onChanged: notificationsAvailable
                ? (value) => _toggleNotifications(context, ref, value)
                : null,
          ),
          ListTile(
            enabled: settings.notificationsEnabled && notificationsAvailable,
            leading: const Icon(Icons.schedule_outlined),
            title: Text(context.l10n.settingsReminderTime),
            trailing: Text(
              formatTime(
                DateTime(2000, 1, 1, settings.reminderTime.hour,
                    settings.reminderTime.minute),
              ),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            onTap: () => _pickReminderTime(context, ref, settings.reminderTime),
          ),
          const Divider(height: 24),
          _SectionHeader(context.l10n.settingsCalendarSync),
          ..._calendarSyncSection(context, ref, settings, notifier),
          const Divider(height: 24),
          _SectionHeader(context.l10n.settingsBackup),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: Text(context.l10n.settingsExport),
            subtitle: Text(context.l10n.settingsExportHint),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(context.l10n.settingsImport),
            subtitle: Text(context.l10n.settingsImportHint),
            onTap: () => _import(context, ref),
          ),
          const Divider(height: 24),
          _SectionHeader(context.l10n.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.settingsVersion),
            trailing: Text(
              version.value ??
                  (version.isLoading ? '…' : 'unknown'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(context.l10n.settingsLicenses),
            subtitle: Text(context.l10n.settingsLicensesHint),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'GTD',
              applicationVersion: version.value ?? '',
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _calendarSyncSection(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SettingsController notifier,
  ) {
    final service = ref.read(deviceCalendarServiceProvider);
    if (!service.isSupported) {
      return [
        ListTile(
          enabled: false,
          leading: const Icon(Icons.calendar_month_outlined),
          title: Text(context.l10n.settingsDeviceCalendar),
          subtitle: Text(context.l10n.settingsOnlyAndroid),
        ),
      ];
    }

    final lastSync = settings.lastCalendarSyncAt;
    return [
      ListTile(
        leading: const Icon(Icons.calendar_month_outlined),
        title: Text(context.l10n.settingsDeviceCalendar),
        subtitle: Text(
          settings.deviceCalendarName ??
              context.l10n.settingsDeviceCalendarHint,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pickDeviceCalendar(context, ref, notifier),
      ),
      ListTile(
        enabled: settings.hasDeviceCalendar,
        leading: const Icon(Icons.sync),
        title: Text(context.l10n.settingsSyncNow),
        subtitle: Text(
          lastSync == null
              ? context.l10n.settingsNotSyncedYet
              : context.l10n.settingsLastSynced(
                  DateFormat('d MMM, HH:mm').format(lastSync),
                ),
        ),
        onTap: () => _syncCalendar(context, ref, settings, notifier),
      ),
      ListTile(
        enabled: settings.hasDeviceCalendar,
        leading: const Icon(Icons.playlist_remove),
        title: Text(context.l10n.settingsRemoveSynced),
        subtitle: Text(context.l10n.settingsRemoveSyncedHint),
        onTap: () => _unlinkCalendar(context, ref, notifier),
      ),
    ];
  }

  Future<void> _pickDeviceCalendar(
    BuildContext context,
    WidgetRef ref,
    SettingsController notifier,
  ) async {
    final service = ref.read(deviceCalendarServiceProvider);
    try {
      var granted = await service.hasPermission();
      if (!granted) granted = await service.requestPermission();
      if (!granted) {
        if (context.mounted) _snack(context, context.l10n.settingsCalendarPermissionDenied);
        return;
      }

      var calendars = (await service.calendars())
          .where((calendar) => calendar.isWritable)
          .toList();

      if (calendars.isEmpty) {
        if (!context.mounted) return;
        final create = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.settingsNoWritableCalendar),
            content: Text(context.l10n.settingsNoWritableCalendarBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.create),
              ),
            ],
          ),
        );
        if (create != true) return;
        final id = await service.createLocalCalendar('GTD');
        if (id == null) {
          if (context.mounted) _snack(context, context.l10n.settingsCouldNotCreateCalendar);
          return;
        }
        calendars = (await service.calendars())
            .where((calendar) => calendar.isWritable)
            .toList();
      }

      if (!context.mounted) return;
      final selected = await showModalBottomSheet<DeviceCalendarInfo>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final calendar in calendars)
                ListTile(
                  leading: Icon(
                    calendar.id == ref.read(settingsProvider).deviceCalendarId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                  ),
                  title: Text(calendar.name),
                  subtitle: calendar.account.isEmpty
                      ? null
                      : Text(calendar.account),
                  onTap: () => Navigator.pop(context, calendar),
                ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      await notifier.setDeviceCalendar(selected.id, selected.name);
    } on Object catch (error) {
      if (context.mounted) _snack(context, context.l10n.settingsCalendarError('$error'));
    }
  }

  Future<void> _syncCalendar(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    SettingsController notifier,
  ) async {
    final calendarId = settings.deviceCalendarId;
    if (calendarId == null) return;

    final service = ref.read(deviceCalendarServiceProvider);
    try {
      var granted = await service.hasPermission();
      if (!granted) granted = await service.requestPermission();
      if (!granted) {
        if (context.mounted) _snack(context, context.l10n.settingsCalendarPermissionDenied);
        return;
      }

      final timeZone = await ref
          .read(timeZoneServiceProvider)
          .localZoneName();

      final result = await ref
          .read(calendarSyncServiceProvider)
          .sync(calendarId: calendarId, timeZone: timeZone);
      await notifier.markCalendarSynced(DateTime.now());
      if (context.mounted) _snack(context, context.l10n.settingsCalendarSynced(result.summary));
    } on Object catch (error) {
      if (context.mounted) _snack(context, context.l10n.settingsSyncFailed('$error'));
    }
  }

  Future<void> _unlinkCalendar(
    BuildContext context,
    WidgetRef ref,
    SettingsController notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settingsRemoveSyncedQuestion),
        content: Text(context.l10n.settingsRemoveSyncedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final removed = await ref.read(calendarSyncServiceProvider).unlinkAll();
      await notifier.markCalendarSynced(DateTime.now());
      if (context.mounted) _snack(context, context.l10n.settingsRemovedEvents(removed));
    } on Object catch (error) {
      if (context.mounted) _snack(context, context.l10n.settingsCouldNotRemove('$error'));
    }
  }

  Future<void> _toggleNotifications(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final service = ref.read(notificationServiceProvider);
    final notifier = ref.read(settingsProvider.notifier);

    if (!enabled) {
      await notifier.setNotificationsEnabled(false);
      await service.cancelDailyReminder();
      return;
    }

    try {
      final granted = await service.requestPermission();
      if (!granted) {
        if (context.mounted) {
          _snack(context, context.l10n.settingsNotificationDenied);
        }
        return;
      }
      await notifier.setNotificationsEnabled(true);
      await service.scheduleDailyReminder(ref.read(settingsProvider).reminderTime);
      if (context.mounted) {
        _snack(context, context.l10n.settingsDailyReminderEnabled);
      }
    } on Object catch (error) {
      await notifier.setNotificationsEnabled(false);
      if (context.mounted) {
        _snack(context, context.l10n.settingsCouldNotEnable('$error'));
      }
    }
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDay current,
  ) async {
    final time = await showTimePicker(context: context, initialTime: current);
    if (time == null) return;

    final notifier = ref.read(settingsProvider.notifier);
    await notifier.setReminderTime(time);
    if (ref.read(settingsProvider).notificationsEnabled) {
      try {
        await ref
            .read(notificationServiceProvider)
            .scheduleDailyReminder(time);
      } on Object catch (error) {
        if (context.mounted) {
          _snack(context, context.l10n.settingsCouldNotReschedule('$error'));
        }
      }
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    try {
      final backup = await ref.read(backupServiceProvider).export();
      final json = const JsonEncoder.withIndent('  ').convert(backup);
      final stamp = DateFormat('yyyyMMdd-Hm').format(DateTime.now());
      final target = await FilePicker.saveFile(
        fileName: 'gtd-backup-$stamp.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        dialogTitle: l10n.settingsExportDialogTitle,
      );
      if (context.mounted) {
        _snack(
          context,
          target == null
              ? l10n.settingsBackupNotSaved
              : l10n.settingsBackupSaved,
        );
      }
    } on Object catch (error) {
      if (context.mounted) _snack(context, context.l10n.settingsExportFailed('$error'));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final Uint8List bytes;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        dialogTitle: context.l10n.settingsImportDialogTitle,
      );
      if (files.isEmpty) return;
      bytes = await files.first.readAsBytes();
    } on Object catch (error) {
      if (context.mounted) _snack(context, context.l10n.settingsCouldNotOpenFile('$error'));
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.settingsReplaceAllQuestion),
        content: Text(context.l10n.settingsReplaceAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.settingsImport),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await ref
          .read(backupServiceProvider)
          .importJson(utf8.decode(bytes));
      ref.read(selectedBoardIdProvider.notifier).select(null);
      if (context.mounted) {
        _snack(context, context.l10n.settingsImported(result.summary));
      }
    } on FormatException catch (error) {
      if (context.mounted) _snack(context, error.message);
    } on Object catch (error) {
      if (context.mounted) _snack(context, context.l10n.settingsImportFailed('$error'));
    }
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          letterSpacing: .8,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SwipeActionTile extends StatelessWidget {
  const _SwipeActionTile({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final SwipeAction value;
  final ValueChanged<SwipeAction> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(value.icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value.label, style: theme.textTheme.bodyMedium),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () async {
        final selected = await showModalBottomSheet<SwipeAction>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: RadioGroup<SwipeAction>(
              groupValue: value,
              onChanged: (choice) => Navigator.pop(context, choice),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in SwipeAction.values)
                    RadioListTile<SwipeAction>(
                      value: action,
                      title: Text(action.label),
                      secondary: Icon(action.icon),
                    ),
                ],
              ),
            ),
          ),
        );
        if (selected != null) onChanged(selected);
      },
    );
  }
}
