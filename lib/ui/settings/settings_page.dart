import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/date_x.dart';
import '../../providers.dart';
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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionHeader('Swipe actions'),
          _SwipeActionTile(
            title: 'Swipe right',
            subtitle: 'On a task in the Todos list',
            value: settings.swipeStart,
            onChanged: notifier.setSwipeStart,
          ),
          _SwipeActionTile(
            title: 'Swipe left',
            value: settings.swipeEnd,
            onChanged: notifier.setSwipeEnd,
          ),
          const Divider(height: 24),
          const _SectionHeader('Reminders'),
          SwitchListTile(
            title: const Text('Daily reminder'),
            subtitle: Text(
              notificationsAvailable
                  ? 'A notification at your chosen time'
                  : 'Not available in the browser build',
            ),
            value: settings.notificationsEnabled && notificationsAvailable,
            onChanged: notificationsAvailable
                ? (value) => _toggleNotifications(context, ref, value)
                : null,
          ),
          ListTile(
            enabled: settings.notificationsEnabled && notificationsAvailable,
            leading: const Icon(Icons.schedule_outlined),
            title: const Text('Reminder time'),
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
          const _SectionHeader('Backup'),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Export'),
            subtitle: const Text('Save boards, tasks and events as JSON'),
            onTap: () => _export(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Import'),
            subtitle: const Text('Replace everything with a backup file'),
            onTap: () => _import(context, ref),
          ),
          const Divider(height: 24),
          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: Text(
              version.value ??
                  (version.isLoading ? '…' : 'unknown'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Licenses'),
            subtitle: const Text('Open source packages used by GTD'),
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
          _snack(context, 'Notification permission denied');
        }
        return;
      }
      await notifier.setNotificationsEnabled(true);
      await service.scheduleDailyReminder(ref.read(settingsProvider).reminderTime);
      if (context.mounted) {
        _snack(context, 'Daily reminder enabled');
      }
    } on Object catch (error) {
      await notifier.setNotificationsEnabled(false);
      if (context.mounted) {
        _snack(context, 'Could not enable notifications: $error');
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
          _snack(context, 'Could not reschedule reminder: $error');
        }
      }
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final backup = await ref.read(backupServiceProvider).export();
      final json = const JsonEncoder.withIndent('  ').convert(backup);
      final stamp = DateFormat('yyyyMMdd-Hm').format(DateTime.now());
      final target = await FilePicker.saveFile(
        fileName: 'gtd-backup-$stamp.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        dialogTitle: 'Export GTD backup',
      );
      if (context.mounted) {
        _snack(
          context,
          target == null ? 'Backup not saved' : 'Backup saved',
        );
      }
    } on Object catch (error) {
      if (context.mounted) _snack(context, 'Export failed: $error');
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final Uint8List bytes;
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        dialogTitle: 'Import GTD backup',
      );
      if (files.isEmpty) return;
      bytes = await files.first.readAsBytes();
    } on Object catch (error) {
      if (context.mounted) _snack(context, 'Could not open file: $error');
      return;
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Importing a backup deletes the boards, tasks and events that are '
          'currently stored on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Import'),
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
        _snack(context, 'Imported ${result.summary}');
      }
    } on FormatException catch (error) {
      if (context.mounted) _snack(context, error.message);
    } on Object catch (error) {
      if (context.mounted) _snack(context, 'Import failed: $error');
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
