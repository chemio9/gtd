# GTD — Kanban · Todos · Calendar

A local-first Flutter app that combines a kanban board, a todo list and a
calendar in one place. Everything is stored on-device in SQLite (drift), so the
app works offline and never sends data anywhere. UI available in English and
Simplified Chinese.

## Features

- **Board** — kanban with draggable cards, multiple boards, editable columns,
  "done" columns that complete tasks automatically, edge auto-scroll while
  dragging. The column "+" opens an inline card field (same Enter-to-continue
  flow, same date parsing) instead of a dialog.
- **Todos** — the same tasks as the board, grouped **by subject tag** by
  default: each tag becomes a collapsible section (tap the header) and a task
  with several tags appears under each one; untagged tasks land in
  *Uncategorized*. Long-press a header to pin the list to that subject, and the
  toolbar toggle switches back to due-date grouping (Overdue / Today / Tomorrow
  / Upcoming / Later / Anytime). Filters narrow by time bucket. Long-press a
  row to multi-select: the bottom bar sets one due date (today, tomorrow, picker
  or clear), completes/reopens, adds tags, or deletes with a confirmation.
  Adding is a single inline row (Microsoft To Do style): Enter saves, the field
  clears and stays focused, so a whole list can be typed in a row. The line is
  parsed for dates — `buy milk tomorrow`, `gym fri 9am`, `rent +3d`, `plan
  next week`, `a conference 2026-11-03 9:45`. Recognised tokens are
  highlighted in the field and confirmed by a `Due …` badge (tap it to change
  the date, ✕ to drop the recognised date). Press <kbd>Esc</kbd> or the ✕ to
  stop adding. The app bar menu also has **Paste list**: one task per clipboard
  line, bullets stripped, same date parsing.
- **Calendar** — month / 2-week / week views, day agenda, events with
  daily-weekly-monthly recurrence, plus the tasks due on the selected day.
  Events can be linked to a task: the agenda row and the todo list both show
  the link, and the task sheet lists its events with a "New event" shortcut.
- **Settings** — configurable swipe actions (complete / today / tomorrow /
  delete, per direction), an optional daily reminder notification, JSON
  export & import, Android device-calendar sync, app version and the
  open-source license page.
- **Subtasks & tags** — one level of checkable steps per task with a
  done/total badge on cards, plus global colour-coded tags shared across
  boards.
- **Reminders** — per-task "remind me N minutes before the due time" (5m, 15m,
  1h, 3h, 1d or at the due time) scheduled as local notifications and kept in
  sync with the tasks automatically.
- **Search** — one search field across task titles/notes, subtasks, tags and
  events, localised and reachable from every tab.
- Tasks and cards are the *same entity*: a task created in the todo list shows
  up on the board and vice versa.

## Stack

| Concern        | Choice                                      |
| -------------- | ------------------------------------------- |
| Persistence    | `drift` 2.x + SQLite (native + WASM on web) |
| State          | `flutter_riverpod` 3 (StreamProvider + Notifier) |
| Calendar view  | `table_calendar` 3.x                        |
| Drag & drop    | built in-house (`KanbanBoardView`)          |
| Swipe actions  | `flutter_slidable`                          |
| Preferences    | `shared_preferences` (single JSON key)      |
| Notifications  | `flutter_local_notifications` + `timezone`  |
| Files          | `file_picker` (import + save dialog)        |
| Calendar sync  | Android `CalendarContract` via MethodChannel |
| Version        | `package_info_plus`                         |
| Dates          | `intl` + `flutter_localizations` (gen-l10n) |

## Project layout

```
lib/
├── main.dart                     # bootstrap
├── app.dart                      # MaterialApp + 3-tab shell
├── providers.dart                # every provider (db, daos, queries, UI state)
├── l10n/                         # ARB files (en, zh) + generated AppLocalizations
├── core/
│   ├── date_x.dart               # day math + human date formatting
│   ├── quick_parse.dart          # "buy milk tomorrow 9am" -> title + due date
│   ├── search.dart               # pure search across tasks/events/subtasks/tags
│   └── recurrence.dart           # event occurrence expansion (pure functions)
├── settings/settings.dart        # AppSettings, swipe actions, store + notifier
├── services/
│   ├── notification_service.dart      # daily reminder wrapper
│   ├── device_calendar_service.dart   # MethodChannel `gtd/calendar`
│   ├── task_reminder_scheduler.dart   # task due reminders <-> notifications
│   └── time_zone_service.dart         # IANA zone lookup with fallback
├── data/
│   ├── tables.dart               # drift table definitions + enums
│   ├── database.dart             # AppDatabase + seed + migrations
│   ├── backup.dart               # JSON export / import of every table
│   ├── calendar_sync.dart        # event -> device calendar sync + RRULE
│   └── daos/
│       ├── board_dao.dart        # boards, columns, column reordering
│       ├── task_dao.dart         # tasks, completion, cross-column moves
│       └── event_dao.dart        # events + "events overlapping window"
└── ui/
    ├── kanban/kanban_board_view.dart   # reusable drag & drop board
    ├── board/board_page.dart           # board tab
    ├── board/inline_card_add.dart       # per-column inline card entry
    ├── todos/todos_page.dart           # todo tab
    ├── calendar/calendar_page.dart      # calendar tab
    ├── calendar/event_editor_sheet.dart
    ├── tasks/task_editor_sheet.dart
    ├── tasks/quick_add_bar.dart         # inline multi-add row
    ├── tasks/task_card.dart             # board card + todo tile
    └── common/text_prompt_dialog.dart
```

### Data model

```
boards(id, name, position)
board_columns(id, board_id, title, position, is_done)
tasks(id, board_id, column_id, title, notes, due_date,
      priority(enum), position, completed_at, created_at, updated_at)
events(id, title, notes, linked_task_id?, starts_at, ends_at, all_day,
       recurrence(none|daily|weekly|monthly), by_weekday, recurrence_until)
subtasks(id, task_id, title, is_done, position, created_at)
tags(id, name UNIQUE, color, created_at)
task_tags(task_id, tag_id)            -- PK(task_id, tag_id)
-- tasks also carry reminder_minutes_before (nullable)
```

Schema version 4 migrates v1 databases in place: v2 added
`events.linked_task_id`, v3 `tasks.reminder_minutes_before`, v4 the subtask,
tag and task-tag tables. Foreign keys are switched on per connection, so
`board → column → task`, `task → subtask` and the tag links cascade (and
`task → event` links are set to null when a task is deleted).

Recurring events are **expanded on read**, never duplicated in storage:
`expandEvent()` produces the occurrences inside the requested window and
`bucketByDay()` groups them per day for the calendar.

## `KanbanBoardView<T>` — the drag & drop component

The board is deliberately decoupled from tasks and from drift. Its whole API is
five things:

```dart
KanbanBoardView<Task>(
  columns: [
    KanbanColumn(id: '12', title: 'To do', items: todoTasks),
  ],
  itemIdOf: (task) => '${task.id}',           // drag identity
  itemBuilder: (context, task, isDragging) => TaskCard(task: task),
  onMove: (KanbanMove<Task> move) { /* persist */ },
  // optional
  onItemTap: ..., onAddItem: ..., onColumnMenu: ...,
  emptyBuilder: ..., dragBuilder: ...,
  columnTopBuilder: (context, column) => InlineCardAdd(...), // above the cards
  style: KanbanStyle(columnWidth: 300),
);
```

`KanbanMove` reports `item`, `fromColumnId`, `toColumnId` and `newIndex`, and is
only emitted when the position actually changed. Dropping onto a card inserts
*before* it; dropping onto empty column space appends. Cards are picked up with
a 120 ms long press so scrolling still works on touch devices.

`KanbanStyle` exposes column width/spacing/padding, card and column radius and
the edge auto-scroll threshold/speed.

### Quick add parsing

`parseQuickAdd()` returns `title`, `dueDate` and the character `spans` of every
recognised token. Tokens are blanked with spaces instead of being deleted, so
the reported offsets always point into the original input and the text field can
highlight them. Absolute dates (`2026-11-03`, `2026/11/3`, `2026-11-03T09:45`)
are validated, so `2026-02-31` stays part of the title instead of producing an
invalid date.

### Due dates are day-first

A task's `due_date` at midnight means "this day, no time"; the UI then shows
`Today` instead of `Today · 00:00`. Adding a time (editor or `9am` in the quick
add row) is opt-in.

## Localization

`l10n.yaml` + `lib/l10n/app_en.arb` / `app_zh.arb` feed Flutter's `gen-l10n`
pipeline (run automatically because `generate: true`). UI code uses
`context.l10n.<key>`; `Intl.defaultLocale` follows the app locale so date
formatting matches. `test/l10n_test.dart` fails if the two ARB files drift
apart or a message is empty.

## Settings

Reached from the gear icon in any tab.

- **Swipe actions** — each direction of a Todos row can be set to complete /
  reopen, schedule for today, schedule for tomorrow or delete. Stored as one
  JSON blob in `shared_preferences` (`settings.v1`).
- **Reminders** — a daily local notification at a chosen time
  (`flutter_local_notifications` + the device timezone). The switch is hidden
  on web, where scheduled notifications are not supported.
- **Backup** — `BackupService.export()` serialises every table to JSON with the
  original row ids, so task → column → board links survive an import.
  Imports validate `app`/`version`, then replace the database in a transaction.
- **Calendar sync** (Android only) — pick a device calendar (or create a local
  `GTD` one) and mirror every event, recurring series included
  (`RRULE` + `DURATION`); events linked to a task get `Task: <title>` appended
  to the device description. `CalendarSyncService` keeps a `eventId -> deviceEventId`
  map so repeat syncs update instead of duplicating, and deletes device copies
  whose app event is gone. "Remove synced events" deletes only the copies this
  app created.
- **About** — version from `package_info_plus` and Flutter's `LicensePage`.

### Calendar sync

`android/app/src/main/kotlin/.../CalendarSyncChannel.kt` owns the native side:
permissions (`READ_CALENDAR`/`WRITE_CALENDAR`), calendar listing, local calendar
creation and `CalendarContract.Events` insert/update/delete (recurring events
use `RRULE` plus a `DURATION`, all-day events use UTC midnight with an
exclusive end). The Dart service is a thin channel wrapper; all bookkeeping
lives in `data/calendar_sync.dart`, which is why the sync logic is testable
without a device.

## Reminders

`TaskReminderScheduler` is the only writer of task reminders: on startup and on
every task/settings change the shell calls `syncAll()`, which cancels the
pending task reminders and reschedules the ones still ahead (id space 5000+,
separate `task_reminders` channel). Date-only due dates anchor at 09:00, so
"3 hours before" still lands somewhere sensible. Everything is behind a
`TaskReminderGateway` seam, so the logic is unit tested with a fake gateway.

## Running

```bash
fvm flutter pub get
fvm dart run build_runner build      # regenerates *.g.dart (drift)
fvm flutter run -d chrome            # or -d <android device>
```

Web needs `web/sqlite3.wasm` and `web/drift_worker.js` (copied from the `drift`
package); they are committed, but re-copy them after a drift upgrade:

```bash
cp "$(fvm dart pub cache list | ... )"  # see drift package folder:
cp ~/.pub-cache/hosted/*/drift-*/drift_worker.js web/
cp ~/.pub-cache/hosted/*/drift-*/extension/devtools/build/sqlite3.wasm web/
```

## Documentation

Deeper material lives in [`docs/`](docs/):

| File | What it covers |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | Scope, architecture, schema, state management, platform seams, every design decision with rationale and rejected alternatives |
| [docs/EDGE-CASES.md](docs/EDGE-CASES.md) | Handled corner cases by domain (dates, recurrence, quick add, kanban, completion, subtasks/tags, reminders, calendar sync, backup, migrations, i18n, search, platform) |
| [docs/PROBLEMS.md](docs/PROBLEMS.md) | 26 real bugs/build failures: symptom → root cause → fix → lesson |
| [docs/TESTING.md](docs/TESTING.md) | Test strategy, harness patterns, inventory and coverage gaps |

## Tests

```bash
fvm flutter analyze
fvm flutter test
```

- `test/quick_parse_test.dart` — natural-language due dates in quick add.
- `test/settings_test.dart` — settings JSON and store persistence.
- `test/backup_test.dart` — export/import round trip, replacement and rejects
  invalid files.
- `test/calendar_sync_test.dart` — create/update/delete behaviour, mapping
  persistence, RRULE generation.
- `test/device_calendar_service_test.dart` — the `gtd/calendar` MethodChannel
  contract (payload shape, all-day conversion, parsing) with a mock channel.
- `test/event_task_link_test.dart` — foreign-key enforcement and cascades, link
  persistence from both sides, and the v1 → v4 migration on a real database.
- `test/task_reminder_test.dart` — reminder time maths and the scheduler.
- `test/subtasks_tags_test.dart` — subtask ordering/deletes, tag idempotency,
  set replacement, cascades and backup round trip.
- `test/search_test.dart` — the pure search matcher.
- `test/l10n_test.dart` — ARB parity (en ↔ zh).
- `test/recurrence_test.dart` — occurrence expansion for all recurrence modes.
- `test/widget_test.dart` — `KanbanBoardView` rendering/callbacks.
- `test/app_flow_test.dart` — the real app against an in-memory drift database:
  create a task, drag a card across columns, complete a todo (moves it to the
  done column), create a recurring event, add a column, add three tasks in a
  row from the quick-add row, link an event to a task, set a reminder, add a
  subtask and a tag, and search for tasks/events.
