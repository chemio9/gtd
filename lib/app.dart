import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/calendar_sync.dart';
import 'l10n/l10n.dart';
import 'providers.dart';
import 'services/task_reminder_scheduler.dart';
import 'settings/settings.dart';
import 'ui/board/board_page.dart';
import 'ui/calendar/calendar_page.dart';
import 'ui/todos/todos_page.dart';

class GtdApp extends StatelessWidget {
  const GtdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      builder: (context, child) {
        // Keep intl date formatting in the same language as the UI.
        Intl.defaultLocale = Localizations.localeOf(context).toLanguageTag();
        return child ?? const SizedBox.shrink();
      },
      home: const HomeShell(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4F46E5),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        isDense: true,
      ),
      visualDensity: VisualDensity.standard,
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReminders());
  }

  /// Mirrors task reminders into the OS notification scheduler. Failures are
  /// swallowed: a missing plugin (tests, unsupported platform) must never
  /// break the UI.
  Future<void> _syncReminders() async {
    try {
      final settings = ref.read(settingsProvider);
      final scheduler = ref.read(taskReminderSchedulerProvider);
      if (!settings.notificationsEnabled) {
        await scheduler.syncAll(const []);
        return;
      }
      final tasks = ref.read(allTasksProvider).value;
      if (tasks == null) return;
      await scheduler.syncAll(tasks);
    } on Object {
      // Notifications are best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(allTasksProvider, (_, _) => _syncReminders());
    ref.listen(settingsProvider, (_, _) => _syncReminders());
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          BoardPage(),
          TodosPage(),
          CalendarPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.view_kanban_outlined),
            selectedIcon: const Icon(Icons.view_kanban),
            label: context.l10n.navBoard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.checklist_outlined),
            selectedIcon: const Icon(Icons.checklist),
            label: context.l10n.navTodos,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: context.l10n.navCalendar,
          ),
        ],
      ),
    );
  }
}

/// Convenience wrapper so `main.dart` stays tiny.
///
/// [settingsStore] is overridden with the SharedPreferences-backed store in
/// `main()`; tests keep the in-memory default.
Widget buildApp({
  SettingsStore? settingsStore,
  SyncMappingStore? syncMappingStore,
}) {
  return ProviderScope(
    overrides: [
      if (settingsStore != null)
        settingsStoreProvider.overrideWithValue(settingsStore),
      if (syncMappingStore != null)
        syncMappingStoreProvider.overrideWithValue(syncMappingStore),
    ],
    child: const GtdApp(),
  );
}
