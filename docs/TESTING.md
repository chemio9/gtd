# Testing

```bash
fvm flutter analyze
fvm flutter test                       # 117 tests, ~25 s
fvm flutter test test/app_flow_test.dart --plain-name "search finds"
```

## Philosophy

- **No adb-driven end-to-end testing.** Widget tests drive the real app (real
  widgets, real navigation, real drift database) and assert on the database and
  the rendered widgets. Platform channels are faked in-process.
- **Pure logic gets unit tests.** Quick-add parsing, recurrence expansion,
  search, RRULE building and reminder time math are plain functions, so they are
  tested directly, edge case by edge case.
- **Every behavioural change ships with a test.** All 20 commits that touched
  behaviour added or extended tests in the same commit.

## Inventory (13 files)

| File | Focus | Kind |
|---|---|---|
| `app_flow_test.dart` | The app end-to-end: create/drag/complete tasks, quick add, paste list, event↔task link, reminders, subtasks/tags, search, calendar markers, settings | widget + real drift |
| `widget_test.dart` | `KanbanBoardView` contract (rendering, callbacks) | widget |
| `quick_parse_test.dart` | Title/date extraction, ISO dates, spans | unit |
| `recurrence_test.dart` | Occurrence expansion for all frequencies | unit |
| `search_test.dart` | Matcher rules, sorting, empty query | unit |
| `settings_test.dart` | Settings JSON round-trip, defaults, store persistence | unit |
| `backup_test.dart` | Export shape, round trip, replace semantics, rejects | db |
| `calendar_sync_test.dart` | Create/update/delete, mapping, RRULE, unlink | db + fake gateway |
| `device_calendar_service_test.dart` | `gtd/calendar` MethodChannel contract | mocked channel |
| `event_task_link_test.dart` | FKs/cascades, linking, v1→v4 migration, reminders column | db + raw sqlite3 |
| `task_reminder_test.dart` | `reminderTimeFor`, scheduler diffing | unit + fake gateway |
| `subtasks_tags_test.dart` | Subtask/tag CRUD, cascades, backup round trip | db |
| `l10n_test.dart` | ARB parity (en ↔ zh), non-empty values | unit |

## Patterns

### App harness with overrides

```dart
await tester.pumpWidget(ProviderScope(
  overrides: [databaseProvider.overrideWithValue(db)],
  child: const GtdApp(),
));
await tester.pumpAndSettle();
```

`db = AppDatabase.forTesting(NativeDatabase.memory())` in `setUp`, `await db.close()`
in `tearDown`. The view is pinned (`tester.view.physicalSize = Size(1400, 2200)`)
so sheets and lists fit.

### Explicit teardown for drift timers

```dart
Future<void> disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}
```

Unmounting disposes providers, drift closes query streams with a zero-duration
timer, and those pumps let it run so the framework does not report pending
timers.

### Fake gateways instead of platforms

```dart
class FakeReminderGateway implements TaskReminderGateway {
  final Map<int, DateTime> scheduled = {};
  @override
  Future<List<int>> pendingTaskReminderIds() async => scheduled.keys.toList();
  // …
}
```

Same shape for `CalendarGateway` and `SyncMappingStore`.

### Mocked MethodChannel

```dart
const channel = MethodChannel('gtd/calendar');
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(channel, (call) async { /* … */ });
```

Assert the payload the native side would receive (`calendarId`, `startMillis`,
`rrule`, …) rather than testing Kotlin.

### Platform overrides (Android-only paths)

```dart
debugDefaultTargetPlatformOverride = TargetPlatform.android;  // at test start
// … assertions …
debugDefaultTargetPlatformOverride = null;                    // before the body ends
await disposeApp(tester);
```

Reset **inside** the body: invariant checks run before `addTearDown`.

### SharedPreferences

```dart
SharedPreferences.setMockInitialValues({});
final prefs = await SharedPreferences.getInstance();
```

### Migration coverage

Build the current schema in a temp file, roll it back with raw `sqlite3`
(`ALTER TABLE … DROP COLUMN`, `DROP TABLE`, `PRAGMA user_version = 1`), reopen
with `AppDatabase`, then assert both data preservation **and** that the new
columns/tables are usable.

### Interactions that need care

| Situation | Technique |
|---|---|
| Swipe actions (`flutter_slidable`) | `tester.drag(find.text('Buy milk'), const Offset(-400, 0))`, then tap the pane label |
| Off-screen button inside a sheet | `await tester.ensureVisible(finder); await tester.tap(finder);` |
| Keyboard submit | `await tester.testTextInput.receiveAction(TextInputAction.done)` |
| Long-press rename | `await tester.longPress(find.text('Old'))` |
| Snackbar expiry | `await tester.pump(const Duration(seconds: 5)); await tester.pumpAndSettle();` |
| Dialog fields | `find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))` |
| Stable identity | widget keys: `task-completed-checkbox`, `subtask-checkbox-<id>`, `calendar-task-dot` |

## What tests deliberately do not cover

- **Kotlin side** (`CalendarSyncChannel.kt`): covered indirectly by asserting the
  channel payload; the provider interaction needs instrumentation tests.
- **Real notification delivery / permission dialogs**: verified manually on a
  device (`dumpsys alarm` shows the scheduled receiver).
- **SAF file picker**: export/import verified manually; the JSON itself is unit
  tested.
- **Web build**: no automated coverage; used only for visual inspection.

## Adding a test

1. Pure rule → add to the matching `*_test.dart` (or a new `unit` test file).
2. UI flow → extend `app_flow_test.dart`: seed through DAOs, drive widgets,
   assert both the rendered text and the database row.
3. Platform call → mock the channel or introduce a fake at the existing seam.
4. Keep the test independent: fresh in-memory DB per test, no shared settings
   store, no order dependence.
