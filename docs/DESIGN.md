# GTD — Design

A single-user, local-first Android app that merges a kanban board, a todo list
and a calendar. This document records **why** the app is built the way it is,
the invariants that must hold, and the alternatives that were rejected.

- Production Dart: ~8.7k lines across 39 files (`lib/`, excluding generated)
- Generated: ~6.1k lines (drift + gen-l10n)
- Tests: ~2.9k lines across 14 files, 126 test cases
- Native: 278 lines of Kotlin (one MethodChannel)
- Schema: drift/SQLite, version 4
- Locales: `en`, `zh-Hans` (216 ARB messages)

---

## 1. Scope

| In scope | Out of scope (deliberately) |
|---|---|
| Kanban board with drag & drop, multiple boards, editable columns | Accounts, cloud sync, multi-device (decided against; see §12.1) |
| Todo list over the *same* task rows, filtered by due bucket | Collaboration/sharing |
| Month / 2-week / week calendar with recurring events | Google Calendar API / CalDAV (only device calendar, one-way) |
| Tasks ↔ events link, subtasks, tags, per-task reminders | Location/geofence reminders (needs background location) |
| Device-calendar mirroring (events) | iOS/web as supported targets (web build only for inspection) |
| JSON export/import, i18n, search | Server, analytics, crash reporting |

Non-goals are load-bearing: the app's value is that data never leaves the
device and the whole state is one SQLite file plus a small prefs blob.

---

## 2. Principles

1. **Local-first, offline-only.** No network calls, no `INTERNET` permission in
   the main manifest, no HTTP client dependency. The database is the truth.
2. **Pure logic is separated from Flutter and from drift.** Date math, quick-add
   parsing, recurrence expansion and search are plain functions in `lib/core/`
   so they can be unit tested without a widget tree or a database.
3. **Platform I/O sits behind a seam.** Every plugin that needs a device
   (notifications, calendar provider, timezone, files) is wrapped in a small
   interface with a fake for tests.
4. **One entity, many views.** A board card and a todo row are the same `tasks`
   row; status lives in `column_id` + `completed_at`, never in a second table.
5. **Everything user-visible is localized** through `context.l10n`, with an ARB
   parity test to stop drift between locales.
6. **Behaviour changes ship with tests.** No feature is "done" without a test
   that exercises it through the real widgets/database.

---

## 3. Architecture

```
┌───────────────────────────── UI (lib/ui) ─────────────────────────────┐
│ app shell (3 tabs) · board · todos · calendar · search · settings     │
│ editors (task/event sheets) · reusable KanbanBoardView component      │
└───────────────▲──────────────────────────────────▲───────────────────┘
                │ context.l10n / ref.watch          │ showModalBottomSheet
┌───────────────┴──────────────────────────────────┴───────────────────┐
│ state (lib/providers.dart, lib/settings/settings.dart)               │
│ StreamProvider(DAO streams) · Provider(derived maps/counts)          │
│ Notifier(UI state: selected board, calendar day, todo filter)        │
└───────────────▲──────────────────────────────────▲───────────────────┘
                │ watch/insert/update                  │ gateway calls
┌───────────────┴────────────┐   ┌────────────────┴───────────────────┐
│ data (lib/data)            │   │ services (lib/services)            │
│ drift tables, DAOs,        │   │ notifications, reminders, device   │
│ backup, calendar sync      │   │ calendar channel, timezone         │
└───────────────▲────────────┘   └────────────────▲───────────────────┘
                │                                  │ MethodChannel
        SQLite (drift)                    Android CalendarContract
```

Cross-cutting: `lib/core/` (pure functions), `lib/l10n/` (ARB + generated),
`android/…/CalendarSyncChannel.kt` (native side).

---

## 4. Data model (schema v4)

| Table | Columns (abridged) | Why it exists |
|---|---|---|
| `boards` | id, name, position, created_at | Multiple boards; position for ordering |
| `board_columns` | id, board_id→boards, title, position, is_done | Editable columns; `is_done` drives completion semantics |
| `tasks` | id, board_id?, column_id?, title, notes, due_date?, reminder_minutes_before?, priority, position, completed_at?, created_at, updated_at | The single task entity used by board, todos, calendar, search |
| `events` | id, title, notes?, linked_task_id→tasks?, starts_at, ends_at, all_day, recurrence, by_weekday?, recurrence_until?, created_at | Calendar events; recurrence stored once, expanded on read |
| `subtasks` | id, task_id→tasks, title, is_done, position, created_at | One-level checklist per task |
| `tags` | id, name (unique), color, created_at | Global tags shared across boards |
| `task_tags` | task_id, tag_id (PK pair) | Many-to-many link |

**Key invariants**

- `tasks.board_id`/`column_id` are nullable in SQL but the DAO never leaves a
  task without a column when a board exists (falls back to the first column).
  This keeps every task visible somewhere.
- Completion is derived state: `completed_at != null` ⇔ the task sits in a
  `is_done` column. Moving into a done column sets `completed_at`; moving out or
  unchecking clears it and returns the task to the first non-done column.
- Dates are stored as local `DateTime` (drift `dateTime()` = unix seconds).
  **Midnight means "date only"**; `hasTimeOfDay()` is the single predicate used
  by cards, rows, the calendar and reminders.
- Foreign keys are enforced per connection (`PRAGMA foreign_keys = ON` in
  `beforeOpen`) so cascades and `ON DELETE SET NULL` actually run.
- All primary keys are `int autoincrement()`. Fine for one device, and the
  reason account sync was rejected (§12.1).

**Migrations** (`MigrationStrategy.onUpgrade`, versioned by `from < N`):

| v | Change |
|---|---|
| 2 | `addColumn(events.linkedTaskId)` |
| 3 | `addColumn(tasks.reminderMinutesBefore)` |
| 4 | `createTable(subtasks)`, `createTable(tags)`, `createTable(taskTags)` |

`onCreate` also seeds one board ("Personal") with three columns
(To do / In progress / Done, the last flagged `is_done`).

---

## 5. State management

Riverpod 3, with one file (`lib/providers.dart`) owning every provider. Three
kinds are used, each for a reason:

| Kind | Example | Why |
|---|---|---|
| `StreamProvider` over a DAO watch | `allTasksProvider`, `subtasksForTaskProvider` | Drift re-emits on any write, so the UI never calls `setState` after mutations |
| `Provider` (derived, synchronous) | `groupedTodosProvider`, `filteredTodoTasksProvider`, `subjectTodosProvider`, `taskTagsProvider`, `subtaskProgressProvider` | Cheap joins/buckets done once per change instead of per row widget |
| `NotifierProvider` (UI state) | `selectedBoardIdProvider`, `calendarFocusedDayProvider`, `todoFilterProvider`, `todoGroupingProvider`, `todoSubjectFilterProvider`, `collapsedTodoSubjectsProvider`, `settingsProvider` | Ephemeral view state that must survive tab switches |

Derived state is preferred over per-widget `FutureBuilder`s: the list rows take
pre-computed maps (`tags`, `subtaskProgress`, `linkedEvents`) as parameters, so
list rendering stays O(n) and no provider is watched per row.

Settings are a `Notifier<AppSettings>` over a `SettingsStore` seam (in-memory in
tests, `shared_preferences` in `main()`), so tests never touch platform
channels. Same pattern for the sync mapping (`SyncMappingStore`).

---

## 6. Domain logic (`lib/core/`)

| File | Responsibility | Notable rules |
|---|---|---|
| `date_x.dart` | Day math + formatting (`friendlyDay`, `formatDueLabel`, `hasTimeOfDay`) | Midnight == no time |
| `quick_parse.dart` | `parseQuickAdd()`: title + due date from one line | Returns `spans` for token highlighting; blanks tokens with spaces to preserve offsets |
| `recurrence.dart` | `expandEvent` / `bucketByDay` | Recurrence is expanded on read, never duplicated in storage; 1000-iteration guard |
| `search.dart` | `runSearch()` across tasks/events/subtasks/tags | Pure, case-insensitive, sorts results |

These are intentionally dependency-free (no Flutter widgets, no drift queries),
which is why quick-add parsing, recurrence and search have dense unit tests.

---

## 7. UI structure

- **Shell** (`app.dart`): `IndexedStack` keeps the three tabs alive (scroll
  positions, quick-add state), `NavigationBar` switches them. Reminder syncing
  is hooked here via `ref.listen(allTasksProvider|settingsProvider)`.
- **Board**: `BoardPage` (stateful for the inline-add column) + `KanbanBoardView`
  (generic component, §7.1) + `TaskCard`.
- **Todos**: filter chips, pinned `QuickAddBar`, sections grouped by subject tag
  (collapsible, long-press to pin) or by due bucket, `TaskTile` (slidable) and
  inline `SubtaskTreeRow`s. Long-press starts multi-selection: the bottom bar
  sets one due date, completes/reopens, tags or deletes the selection.
- **Calendar**: `TableCalendar` (month/2-week/week) + agenda below; markers carry
  event dots (tertiary) and a task dot (secondary); tapping opens editors.
- **Editors**: modal bottom sheets (`TaskEditorSheet`, `EventEditorSheet`) with
  `showDragHandle`, `isScrollControlled`, and pickers for tags/tasks/dates.
- **Search**: full-page with autofocused field, grouped results.
- **Settings**: swipe actions, daily reminder, device-calendar sync, backup,
  about.

### 7.1 `KanbanBoardView<T>` — the reusable component

The board is data-agnostic. Its whole contract:

```dart
KanbanBoardView<Task>(
  columns: [KanbanColumn(id: '12', title: 'To do', items: tasks, isDone: false)],
  itemIdOf: (t) => '${t.id}',
  itemBuilder: (ctx, t, isDragging) => TaskCard(task: t),
  onMove: (KanbanMove<Task> m) { /* item, fromColumnId, toColumnId, newIndex */ },
  onItemTap: ..., onAddItem: ..., onColumnMenu: ...,
  emptyBuilder: ..., columnTopBuilder: ..., dragBuilder: ...,
  style: KanbanStyle(columnWidth: 300),
)
```

Behavioural contract: long-press (120 ms) picks a card up so scrolling still
works; dropping onto a card inserts **before** it; dropping on empty column
space appends; `onMove` only fires when the position actually changes; edge
auto-scroll (64 px zone, 18 px/tick) runs off pointer position. Hosts supply
`columnTopBuilder` for inline card entry, which keeps the component free of task
semantics.

---

## 8. Platform integration

Everything Android-specific is behind a seam so widget tests never touch a
platform channel.

| Capability | Seam | Real implementation | Test double |
|---|---|---|---|
| Notifications | `TaskReminderGateway` | `NotificationService` | `FakeReminderGateway` |
| Device calendar | `CalendarGateway` + `DeviceCalendarService` | `gtd/calendar` MethodChannel | fake gateway / mocked channel |
| Timezone | `TimeZoneService` | `flutter_timezone` (2 s timeout → UTC) | fixed value |
| Files | `file_picker` behind the settings page | SAF on Android | not exercised in tests |

**Native side** (`CalendarSyncChannel.kt`) exposes `hasPermission`,
`requestPermission`, `listCalendars`, `createLocalCalendar`, `insertEvent`,
`updateEvent`, `deleteEvent` over `CalendarContract`. Recurring events are
written as `RRULE` + `DURATION` (Android ignores `DTEND` for series); all-day
events use UTC midnight with an exclusive end. The Dart side keeps the
`eventId → deviceEventId` map in prefs (`calendarSync.v1`) so repeated syncs
update instead of duplicating, and removes device copies of deleted events.

**Reminders**: `TaskReminderScheduler` diffs the OS's pending task reminders
(ids ≥ 5000, channel `task_reminders`) against stored tasks on every task/settings
change: cancel all, then schedule the future ones. The daily nudge uses id 1001
and `matchDateTimeComponents: DateTimeComponents.time`.

---

## 9. Interchange & settings formats

- **Backup** (`data/backup.dart`): `{app: 'gtd', version: 1, exportedAt,
  boards, columns, tasks, events, subtasks, tags, taskTags}`. Import validates
  `app` + `version`, then replaces the database inside one transaction using
  explicit ids (`insertOrReplace`). New optional fields (`linkedTaskId`,
  `reminderMinutesBefore`) mean v1 files stay importable.
- **Settings** (`settings.v1`): one JSON blob — swipe actions per direction,
  daily reminder on/off + minutes, device calendar id/name + last sync time.
  Unknown/corrupt values fall back to defaults instead of throwing.
- **Sync mapping** (`calendarSync.v1`): `{gtdEventId: deviceEventId}`, per device
  by design.

---

## 10. Localization

`l10n.yaml` + `app_en.arb`/`app_zh.arb` feed `flutter gen-l10n` (automatic via
`generate: true`). UI code uses `context.l10n.<key>`; `Intl.defaultLocale`
follows the app locale in `MaterialApp.builder`, so dates/times localize too.
Plurals go through ICU (`calendarTaskCount`). `test/l10n_test.dart` enforces
that both ARBs define the same keys with non-empty values.

---

## 11. Testing strategy

See `docs/TESTING.md`. Short version: real widgets, real drift in memory,
mocked channels; no adb-driven end-to-end testing.

---

## 12. Decisions and rejected alternatives

### 12.1 No account / no cloud sync

**Decision:** local-only; JSON export/import is the backup story.

**Why:** accounts add a second source of truth, conflict resolution, server
cost, Play account-deletion obligations and a privacy shift. For a single-user
personal tool the local database is sufficient, and the app stays usable
offline forever. The blockers for later sync are already documented: integer
autoincrement ids, hard deletes without tombstones, and `events` lacking
`updated_at`.

**Rejected:** Supabase/Firebase/PocketBase now; device-to-device file sync now.

### 12.2 Device calendar instead of Google Calendar API

**Decision:** write events into the device calendar via `CalendarContract`.

**Why:** no OAuth verification, no CASA security assessment, works offline, and
the user keeps their own calendar account. Restriction: one-way (app → device),
series edits from the other side get overwritten.

### 12.3 Recurrence expanded on read

**Decision:** store one `events` row + `recurrence`/`by_weekday`/`recurrence_until`;
`expandEvent()` materializes occurrences for the requested window.

**Why:** no row explosion, edits stay atomic, deletions are trivial. Cost:
`expandEvent` runs for the visible window only and recurrence rules are a small
subset (no `COUNT`, no exception dates).

### 12.4 One task entity, status derived

**Decision:** board and todos share `tasks`; `completed_at` + `is_done` column
carry completion.

**Why:** avoids duplicating fields and lets a task move between views. Cost:
every mutation that changes a column must keep completion in sync — centralized
in `TaskDao` (`setCompleted`, `moveTask`, `deleteColumn`).

### 12.5 Swipe actions are user-configurable

**Decision:** each direction maps to complete / today / tomorrow / delete.

**Why:** swipe semantics are personal; a fixed action always annoys someone.
Cost: undo only makes sense for delete, so add-flows show no action at all.

### 12.6 Sheets instead of pages for editing

**Decision:** task/event editing happens in `showModalBottomSheet`.

**Why:** keeps context (board/list) visible, cheap to dismiss. Cost: keyboard
insets, nested sheets (tag/task pickers) and "edit the other entity" navigation
need care — the task sheet closes before opening the event editor.

### 12.7 ID-based widget keys and stable semantics

**Decision:** every row that can be dragged/slid/toggled has a stable key
(`ValueKey('task-${id}')`, `subtask-checkbox-${id}`, `task-completed-checkbox`).

**Why:** drag & drop and `flutter_slidable` need identity across rebuilds; tests
need deterministic finders.

### 12.8 i18n from the shell up

**Decision:** introduce gen-l10n before adding more features, and route every
string through it.

**Why:** retrofitting strings is expensive; taking the enum-based refactor of
todo buckets (`TodoGroup`) early avoided hardcoded English leaking into logic.

### 12.9 Subject grouping in the todo list

**Decision:** the todo list groups by subject tag by default; due-date buckets
stay one toolbar tap away. A task with several tags is listed under each of
them, and untagged tasks form an *Uncategorized* section rendered last.

**Why:** the app is used to track coursework, and "which subject is this?" is
the first question — much more useful than a single flat date-sorted list. Tags
already existed, were already colour-coded and were already visible on rows, so
this reuses them instead of adding a second taxonomy (boards stay for project
views). Repeating a multi-tag task is intentional: each subject section is a
complete checklist for that subject.

**Rejected:** grouping by board (boards are heavier and a task belongs to one),
a dedicated `subjects` table (tags already carry name + colour and are shared
across boards), and a single "primary subject" field (loses the cross-listing).

---

## 13. Known gaps / next steps

| Gap | Note |
|---|---|
| Place (geofence) reminders | Needs background location + a geofence plugin; time-based reminders are done |
| Sync across devices | See §12.1; requires UUID ids, tombstones, `events.updated_at`, conflict policy |
| Task → device calendar | Events mirror today; tasks with due dates do not |
| Recurring tasks | Only events repeat |
| Nested subtasks, task tags on cards beyond 3 | Deliberate limits |
| Release signing | `android/app/build.gradle.kts` falls back to debug keys until `key.properties` exists |
| `INTERNET` permission | Not in the main manifest; required before any network feature |
| Web | Works for inspection; notifications and device calendar are disabled |

---

## 14. How to extend

**Add a table/column**
1. Edit `lib/data/tables.dart`.
2. Bump `schemaVersion` and add an `onUpgrade` branch in `database.dart`.
3. `fvm dart run build_runner build`.
4. Extend `BackupService` (export + import, optional fields for compatibility).
5. Add a DAO method returning a `Stream`, expose it in `providers.dart`.

**Add a screen**
1. New file under `lib/ui/<area>/`, `ConsumerWidget` when it only reads.
2. Reach it from a tab's `AppBar` actions (`SearchButton`/`SettingsButton`
   pattern) or a FAB.
3. Add ARB keys to both locales, `fvm flutter gen-l10n`.

**Add platform I/O**
1. Define an `abstract interface class` gateway next to the service.
2. Implement it with the plugin; guard with `isSupported`.
3. Expose it via `Provider`; pass a fake in tests.

**Add a behaviour**
1. Put pure logic in `lib/core/`, test it in isolation.
2. Wire it through a provider/DAO, then a widget test through the real UI.
3. Commit with Conventional Commits + the Co-Authored-By trailer.
