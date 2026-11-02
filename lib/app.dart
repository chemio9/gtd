import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings/settings.dart';
import 'ui/board/board_page.dart';
import 'ui/calendar/calendar_page.dart';
import 'ui/todos/todos_page.dart';

class GtdApp extends StatelessWidget {
  const GtdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GTD',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
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

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
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
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban),
            label: 'Board',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Todos',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
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
Widget buildApp({SettingsStore? settingsStore}) {
  return ProviderScope(
    overrides: [
      if (settingsStore != null)
        settingsStoreProvider.overrideWithValue(settingsStore),
    ],
    child: const GtdApp(),
  );
}
