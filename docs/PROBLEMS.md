# Problems encountered — and how they were solved

A journal of real failures hit while building this app: symptom → root cause →
fix → what to remember. Most were caught by tests, a few by the Android build.

---

## Data & schema

### 1. Deleting a board left orphan columns and tasks

- **Symptom:** `board_dao.deleteBoard()` removed the board; its columns and tasks
  stayed in the database and reappeared in odd ways.
- **Root cause:** SQLite disables foreign keys **per connection**. Drift never
  turns them on by default, so `ON DELETE CASCADE` was decorative.
- **Fix:** `MigrationStrategy.beforeOpen` runs `PRAGMA foreign_keys = ON`, with a
  regression test asserting `PRAGMA foreign_keys == 1` and the cascade.
- **Remember:** every new connection (including test executors) needs the
  pragma; cascade tests are cheap and catch silent data loss.

### 2. Tasks created from the app bar were invisible on the board

- **Symptom:** creating a task from the "New task" action added a row that no
  board column showed.
- **Root cause:** the editor only sent a `columnId` when opened from a column;
  otherwise the task was saved with `column_id = NULL`.
- **Fix:** `TaskDao.createTask` falls back to the board's first column (and the
  editor resolves the effective column before saving).
- **Remember:** a nullable FK that the UI assumes is non-null is a bug waiting to
  happen; put the invariant in the DAO.

### 3. Enum columns failed codegen with `clientDefault`

- **Symptom:** `intEnum<TaskPriority>().clientDefault(() => …)` generated code
  that returned the enum where an `int` was expected.
- **Root cause:** `clientDefault` operates on the **SQL** type, not the Dart type;
  converted columns need `withDefault`.
- **Fix:** `intEnum<TaskPriority>().withDefault(const Constant(1))` (and the
  `textEnum` equivalent for recurrence).
- **Remember:** for converted columns, `withDefault` for SQL-level defaults,
  `clientDefault` only with the raw type.

### 4. Migration test could not express "an old database"

- **Symptom:** testing the v1 → v4 upgrade needed a v1 database, but there is
  only one schema definition.
- **Fix:** build the *current* schema in a temp SQLite file, then roll it back
  with raw SQL (`ALTER TABLE … DROP COLUMN`, `DROP TABLE`), set
  `PRAGMA user_version = 1`, close, and reopen with `AppDatabase`. Drift runs
  `onUpgrade` on first use.
- **Remember:** dropping tables must happen before dropping columns to keep FK
  dependencies happy, and the test then asserts the new tables/columns are
  usable, not just present.

### 5. `int autoincrement` ids are a sync blocker

- **Symptom:** not a bug today, but a design dead end found while evaluating
  account sync.
- **Cause:** every table uses autoincrement ints; two devices generate the same
  ids, and hard deletes leave no tombstone.
- **Decision:** documented as a precondition for any future sync (UUID ids,
  tombstones, `events.updated_at`) rather than half-implementing it.

---

## Flutter widgets & UX

### 6. "A TextEditingController was used after being disposed"

- **Symptom:** creating a board/column crashed right after the dialog closed.
- **Cause:** the dialog's controller was disposed immediately after
  `showDialog` returned, while the dialog was still animating out and rebuilding.
- **Fix:** replaced three ad-hoc dialogs with `showTextPrompt`, a StatefulWidget
  that owns and disposes its own controller.
- **Remember:** never dispose a controller owned by a widget you don't own; let
  the widget's state do it.

### 7. The undo snackbar never disappeared

- **Symptom:** after adding or deleting a task, the snackbar stayed forever.
- **Cause:** `SnackBar` sets `persist = persist ?? action != null`
  (`snack_bar.dart`), so **any** snackbar with an action is persistent.
- **Fix:** `persist: false` on the delete-undo snackbar (4 s), and the add flow
  shows no snackbar at all — undo is now reserved for deletions.
- **Remember:** Material 3 semantic defaults can be surprising; set them
  explicitly when they matter.

### 8. Pushing a route crashed with "multiple heroes share the same tag"

- **Symptom:** opening Settings from the Todos tab threw a hero-tag assertion.
- **Cause:** the shell keeps three pages alive in an `IndexedStack`, so three
  FABs with the default hero tag existed in the same navigator subtree.
- **Fix:** explicit `heroTag: 'todos-fab'` / `'calendar-fab'`.
- **Remember:** `IndexedStack` + FABs = always give hero tags.

### 9. Dragging a card down within its own column landed one slot off

- **Symptom:** dropping a card onto the next card inserted it after that card.
- **Cause:** the drop index was computed against the list **including** the
  dragged card, so removing it shifted everything by one.
- **Fix:** when the source column matches, decrement the target index if the
  dragged index is below it; the board also skips no-op moves.
- **Remember:** index math during drag & drop must account for the dragged item
  still being in the list.

### 10. `Draggable`/`DragTarget` generic bounds

- **Symptom:** `KanbanBoardView<T>` failed to compile with `T` unbounded.
- **Cause:** Flutter's `Draggable<T extends Object>` (and `DragTarget`).
- **Fix:** bound the component and its models: `KanbanBoardView<T extends Object>`,
  `KanbanColumn<T extends Object>`, `KanbanMove<T extends Object>`.
- **Remember:** mirror Flutter's generic bounds in your own generic widgets.

### 11. A picker sheet was taller than the screen

- **Symptom:** in tests the tag picker's "Save" button was off-screen and could
  not be tapped; on device it sat under the keyboard.
- **Cause:** `showModalBottomSheet(isScrollControlled: true)` with a `Column`
  whose `Flexible(ListView)` had no height ceiling.
- **Fix:** wrap the sheet in
  `ConstrainedBox(maxHeight: MediaQuery.sizeOf(context).height * .8)` and keep
  the action row outside the scrollable.
- **Remember:** sheets that can grow must cap their height explicitly.

### 12. Multi-line paste collapsed into one task

- **Symptom:** pasting a list into the quick-add field produced a single joined
  title.
- **Cause:** the field is single-line; the platform strips newlines before the
  callback sees them, so splitting on `\n` was too late.
- **Fix:** replaced implicit paste handling with an explicit **Paste list** menu
  action that reads the clipboard, splits lines, strips bullets and parses each
  line, with a count snackbar (no undo). The submit path still splits
  defensively.
- **Remember:** you cannot intercept paste semantics in a single-line field;
  make the action explicit.

### 13. Quick-add ISO dates had two parser bugs

- **Symptom:** `+3d` never matched, and the bare-clock branch threw
  "Not a capture group name: suffix".
- **Cause:** `\b` before `+` is not a word boundary (both sides non-word), and
  `_parseHour` read a `suffix` group that the bare-clock regex does not define.
- **Fix:** restructured the offset pattern (`(?:in\s+(\d+)…|\+(\d+)d\b)`) and
  made `_parseHour` check `match.groupNames.contains('suffix')`.
- **Also:** `RegExpMatch.group('name')` does not exist in Dart — use
  `namedGroup('name')`.
- **Remember:** regex boundaries around punctuation are a trap; feature-detect
  named groups.

### 14. Task editor had a `Completed` switch, list had a checkbox

- **Symptom:** inconsistent affordances for the same concept.
- **Fix:** removed the `SwitchListTile`; existing tasks get a round checkbox in
  front of the title (`ValueKey('task-completed-checkbox')`), same save path.
- **Remember:** completion is a checkbox concept everywhere else — keep it one
  control.

### 15. Subtasks were truncated and not editable

- **Symptom:** long subtask titles were ellipsized at two lines; there was no way
  to change a subtask's text.
- **Fix:** dropped `maxLines/overflow` (the row wraps and keeps `\n`, connector
  top-aligned), and added renaming via the editor row, a pencil button, and
  long-press in the todo list, using a multi-line `showTextPrompt(maxLines: 3)`.
- **Remember:** any inline list is a place where users will want to edit, not
  just toggle.

---

## Platform & tooling

### 16. `device_calendar` could not be built at all

- **Symptom:** adding the popular calendar plugin pulled in an ancient Android
  module (AGP 3.4.2, `jcenter()`, no `namespace`, compileSdk 29) and would not
  build with AGP 9.
- **Fix:** dropped the dependency and implemented `gtd/calendar` as a small
  MethodChannel over `CalendarContract` (278 lines of Kotlin), which also gave
  control over `RRULE`, `DURATION` and all-day semantics.
- **Remember:** check a plugin's `android/build.gradle` before adopting it; a
  small channel is often cheaper than fighting a stale plugin.

### 17. `file_picker` 13 changed its API

- **Symptom:** `FilePicker.platform.pickFiles(withData: true)` and
  `FilePickerResult` no longer existed, and `file_saver` was unnecessary.
- **Fix:** `FilePicker.pickFiles(...)` now returns `List<PlatformFile>`; read via
  `await files.first.readAsBytes()`, and export with `FilePicker.saveFile(...)`.
  Removed `file_saver`.
- **Remember:** read the installed version's API, not the blog post.

### 18. Kotlin compile error `Operator '==' cannot be applied to 'Long' and 'Int'`

- **Symptom:** release build failed in `CalendarSyncChannel.durationString`.
- **Cause:** `(endMillis - startMillis) / 60_000` is `Long`; comparing it to `0`
  is a type error in Kotlin.
- **Fix:** `minutes > 0L || hours == 0L`.
- **Remember:** Kotlin does not widen `Long`/`Int` silently in comparisons.

### 19. Timezone lookup hung widget tests

- **Symptom:** the calendar-sync widget test ran for minutes and then failed with
  pending work; the sync never completed.
- **Cause:** `FlutterTimezone.getLocalTimezone()` is a platform call that never
  resolves under `flutter_test` (no plugin), and it was awaited directly.
- **Fix:** `TimeZoneService` — a `Provider` seam with a 2 s timeout and `'UTC'`
  fallback; tests override it with a fixed value.
- **Remember:** never await a plugin directly in a code path a widget test can
  reach; wrap it.

### 20. Gradle/AGP version dance during `flutter run`

- **Symptom:** one `flutter run` failed with "Minimum supported Gradle version is
  9.6.0. Current version is 9.3.1", while `flutter build apk` succeeded minutes
  earlier.
- **Cause:** the Flutter tool temporarily migrates the wrapper/AGP
  (`gradle-9.8.2-bin`, AGP 9.5.0) for the build and a stale 9.3.1 distribution
  was picked up mid-migration; the repo ended unchanged.
- **Fix:** re-running the same command after the migration completed worked;
  `flutter build apk --debug` remains the reliable smoke test.
- **Remember:** when Gradle complains about versions, check
  `android/gradle/wrapper/gradle-wrapper.properties` and
  `~/.gradle/wrapper/dists` before editing anything.

### 21. Changing the application id changed the install identity

- **Symptom:** after renaming `io.github.chemio9.gtd.gtd` → `io.github.chemio9.gtd`,
  the device kept both apps.
- **Cause:** the package id is the install identity, not a label.
- **Fix (documented):** export/import moves the data; the manifest activity
  resolves against `namespace`, so both `namespace` and the Kotlin package had to
  move together.
- **Remember:** decide the app id before the first release; verify with
  `aapt2 dump packagename`.

---

## Tests & i18n

### 22. Drift's deferred timers failed widget tests

- **Symptom:** "Pending timers" failure at the end of every widget test using the
  real database.
- **Cause:** drift schedules a zero-duration timer when a query stream is closed
  during provider disposal (unmount at test end).
- **Fix:** a `disposeApp(tester)` helper that unmounts the app
  (`pumpWidget(SizedBox())`) and pumps twice so the timer fires before the test
  ends.
- **Remember:** close the app explicitly in widget tests that own a database.

### 23. `debugDefaultTargetPlatformOverride` must be reset inside the test body

- **Symptom:** "The value of a foundation debug variable was changed by the
  test."
- **Cause:** `addTearDown` runs after the framework's invariant check.
- **Fix:** set the override at the top and reset it explicitly before
  `disposeApp` at the end of the body.
- **Remember:** invariant checks happen before tearDowns.

### 24. `KanbanBoardView` tests crashed without localizations

- **Symptom:** `AppLocalizations.of(context)` threw in the component test after
  i18n landed.
- **Fix:** the test harness wraps widgets in a `MaterialApp` with
  `AppLocalizations.localizationsDelegates` + `supportedLocales` and
  `locale: Locale('en')`.
- **Remember:** any widget using `context.l10n` needs the delegates in tests.

### 25. `BuildContext` across async gaps

- **Symptom:** analyzer warnings after pulling `context.l10n` inside async flows
  (clipboard paste, backup export).
- **Fix:** capture `final l10n = context.l10n;` before the first `await` and use
  the captured object afterwards.
- **Remember:** strings are cheap to capture; contexts are not safe to reuse.

### 26. Calendar format button advertised the wrong view

- **Symptom:** the month grid showed a "2 weeks" button.
- **Cause:** `table_calendar`'s `HeaderStyle.formatButtonShowsNext` defaults to
  `true` (label = next format).
- **Fix:** `formatButtonShowsNext: false` + a test that taps through
  Month → 2 weeks → Week and asserts the label matches the active view.
- **Remember:** read the widget library's defaults for "toggle" buttons.
