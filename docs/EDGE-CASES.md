# Edge cases

Every corner the app deliberately handles, what it does, and where it lives.
Use this as a checklist when touching the related area.

---

## 1. Dates & times

| Case | Behaviour | Where |
|---|---|---|
| Due date without a time | Stored as local **midnight**; UI shows `Today`, not `Today · 00:00` | `core/date_x.dart` (`hasTimeOfDay`, `formatDueLabel`) |
| Due date with a time | `Today · 18:00`; reminders use the real time | `formatDueLabel` |
| Task saved at 23:59 vs 00:01 | All grouping compares `dateOnly()`, never raw timestamps | `providers.dart` (`groupedTodosProvider`) |
| Overdue check | Only when not completed and `dateOnly(due) < dateOnly(now)` | `task_card.dart` |
| Tomorrow bucket | `due == today + 1 day`, compared as dates | `groupedTodosProvider` |
| DST transitions | No arithmetic on timestamps for day math (`DateTime(y,m,d)` only), so a 23/25-hour day never shifts a bucket | `date_x.dart` |
| Device timezone changes | Reminders are rescheduled from local wall-clock fields on every task change; calendar sync passes the current zone name | `task_reminder_scheduler.dart`, `settings_page.dart` |
| Very old/future dates | Date pickers clamp to now − 2/3 years … + 5/6 years; tables store whatever arrives | editors |

## 2. Recurrence

| Case | Behaviour | Where |
|---|---|---|
| Stored once, expanded on read | One `events` row per series, occurrences generated per window | `core/recurrence.dart` |
| Window boundaries | Occurrence included if `start < rangeEnd && end > rangeStart` | `expandEvent` |
| Recurrence `until` | Inclusive of that day (`dateOnly(start).isAfter(until)` rejects) | `expandEvent` |
| Weekly without weekdays | Falls back to the series start weekday | `expandEvent` |
| Weekly with weekdays | `by_weekday` CSV, order-insensitive on read, normalized (sorted) when exported to RRULE | `WeekdayCodeX`, `buildRRule` |
| Monthly on the 31st | Clamps to the last day of short months (31 → 28/30) | `_clampedDay` |
| Multi-day event | Bucketed on every covered day; the end is treated as exclusive for bucketing | `bucketByDay` |
| Runaway rules | 1000-iteration guards for daily/weekly, 400 for monthly | `expandEvent` |
| Deleting a series | Deletes the single row and therefore every occurrence | `event_dao.dart` |
| Editing a series | Edits the template; future occurrences change, past ones are not preserved | event editor |

## 3. Quick add parsing

| Case | Behaviour | Where |
|---|---|---|
| `buy milk tomorrow 9am` | Title `buy milk`, due tomorrow 09:00 | `parseQuickAdd` |
| `a conference 2026-11-03 9:45` | Absolute ISO date + time | `parseQuickAdd` |
| `2026/11/3 at 14:30`, `2026-11-03T09:45` | Accepted variants | `parseQuickAdd` |
| `2026-02-31` | Rejected as a date (round-trip validation) and kept in the title | `_dateFromParts` |
| `at 25:99` | Not treated as a time | hour/minute range checks |
| `+3d` vs `in 3 days` | Both supported; `+3d` needs no word boundary before `+` | `_offsetPattern` |
| Token anchoring | Tokens are replaced with equal-length spaces, so reported `spans` stay valid for highlighting | `consume()` |
| Empty title after stripping (`tomorrow`) | Treated as "nothing to add", field is cleared | `QuickAddBar._submit` |
| Multi-line clipboard paste | One task per line, bullets (`- * •`) stripped, per-line date parsing | `todos_page.dart` (`_pasteList`) |
| Multi-line text typed into the single-line field | Newlines never reach the parser (field is single line); the submit path still splits defensively | `quick_add_bar.dart` |

## 4. Kanban & ordering

| Case | Behaviour | Where |
|---|---|---|
| Drop onto a card | Inserts **before** that card | `KanbanBoardView._list` |
| Drop on empty column space | Appends at the end | trailing `DragTarget` |
| Move down within the same column | Target index is decremented so the card does not land one slot too far | `_DraggableCard.onDropAt` |
| Drop where nothing changes | `onMove` is not called (current index == new index) | `_handleDrop` |
| Cross-column move | Positions of both source and target columns are rewritten in one transaction | `TaskDao.moveTask` |
| Moving into a done column | Sets `completed_at` | `TaskDao.moveTask` |
| Moving out of a done column | Clears `completed_at` | `TaskDao.moveTask` |
| Deleting a column | Its tasks move to the first remaining column (completion recomputed), then it is deleted | `BoardDao.deleteColumn` |
| Column reordering | Positions rewritten from the caller's ordered id list | `BoardDao.reorderColumns` |
| Auto-scroll while dragging | Only near the horizontal edges (64 px zone, 18 px/tick), clamped to scroll extent | `_tickAutoScroll` |
| Long-press vs scrolling | 120 ms long-press delay + `pointerDragAnchorStrategy` keeps list scrolling usable | `LongPressDraggable` config |
| Empty board/column | Placeholder drop zone with a localized hint | `emptyBuilder` |

## 5. Completion semantics

| Case | Behaviour | Where |
|---|---|---|
| Checkbox on a todo | Completes the task **and** moves it to the board's done column | `TaskDao.setCompleted` |
| No done column configured | Only `completed_at` is set, the task stays in place | `_doneColumnFor` returns null |
| Unchecking | Clears `completed_at` and moves the task to the first non-done column | `setCompleted` |
| Editor checkbox | Writes `completed_at` directly on save (no column move) | `task_editor_sheet.dart` |
| Task in a done column without `completed_at` | Editable; the editor shows the checkbox state from `completed_at` | editor |
| Swiping to "complete" | Toggles via the same DAO path, so the same rules apply | `todos_page.dart` |

## 6. Subtasks & tags

| Case | Behaviour | Where |
|---|---|---|
| New (unsaved) task with subtasks/tags | Kept in memory and written after the insert returns an id | `TaskEditorSheet._save` |
| Subtask cascade | Deleting a task or board removes its subtasks | FK `ON DELETE CASCADE` (`PRAGMA foreign_keys = ON`) |
| Tag names | Unique; `create('work')` twice returns the same id | `TagDao.create` |
| Replacing a task's tags | Delete + insert inside a transaction | `TagDao.setForTask` |
| Deleting a tag | Removes the links, leaves tasks intact | FK cascade |
| Long subtask text | Wraps and keeps `\n` (no `maxLines`), tree connector aligned with the first line | `subtask_tree.dart` |
| Renaming | Editor row tap, pencil button, or long-press in the todo list; multi-line prompt | `subtask_dialogs.dart` |
| Subtask order | `position`, then `id` as a tiebreaker | `SubtaskDao.watchForTask`, `subtasksByTaskProvider` |
| Tag palette | Cycles through 8 colours by existing tag count | `tagPalette` |

## 7. Reminders & notifications

| Case | Behaviour | Where |
|---|---|---|
| No due date | Reminder dropdown disabled + hint | task editor |
| Clearing the due date | Clears the reminder value too | task editor |
| Offset before a date-only task | Anchors at 09:00 that day, then subtracts the offset | `reminderTimeFor` |
| Offset lands in the past | Skipped (never scheduled) | `reminderTimeFor`, scheduler |
| Completed task | Reminder cancelled | `reminderTimeFor` returns null |
| Task deleted | Next sync cancels orphaned reminders (pending ids ≥ 5000 are cancelled first) | `TaskReminderScheduler.syncAll` |
| Notifications disabled | Scheduler runs with an empty list → cancels everything | `HomeShell._syncReminders` |
| Id collisions | Daily reminder is 1001; task reminders are 5000 + task id | `notification_service.dart` |
| Channel split | `daily_reminder` vs `task_reminders` so users can mute separately | `notification_service.dart` |
| Platform failure | `try/catch` around the whole sync; notifications are best-effort | `HomeShell`, `NotificationService` |
| Snackbar with undo | Must pass `persist: false`; Material defaults `persist` to `action != null` | `todos_page.dart` |

## 8. Device calendar sync

| Case | Behaviour | Where |
|---|---|---|
| Web/desktop | Service reports unsupported; settings shows a disabled tile; channel is never called | `DeviceCalendarService.isSupported` |
| No calendar permission | Requests at runtime; denial surfaces as a snackbar | `CalendarSyncChannel`, settings page |
| No writable calendar | Offers to create a local "GTD" calendar (`ACCOUNT_TYPE_LOCAL`) | `createLocalCalendar` |
| Recurring events | Written as `RRULE` + `DURATION` (Android ignores `DTEND` for series) | `CalendarSyncChannel.durationString` |
| All-day events | UTC midnight, end exclusive | `DeviceCalendarEvent.toMap` |
| Repeat sync | `calendarSync.v1` maps app event id → device event id; updates instead of duplicating | `CalendarSyncService` |
| Event deleted in the app | Device copy deleted, mapping entry removed | `CalendarSyncService.sync` |
| Failed insert | Counted as `failed`, no mapping stored | `sync` |
| External edits in the device calendar | Overwritten on the next sync (one-way by design) | documented limitation |
| Unlinking | `unlinkAll()` deletes mapped device copies and clears the mapping | settings page |
| Timezone | Current IANA zone at sync time, `"UTC"` fallback if the lookup times out | `TimeZoneService` |

## 9. Backup & restore

| Case | Behaviour | Where |
|---|---|---|
| Empty database | Exports empty arrays, still valid | `BackupService.export` |
| Import into non-empty DB | Replaces content in one transaction (events, task_tags, subtasks, tags, tasks, columns, boards) | `importJson` |
| Wrong `app` value | `FormatException` | `importJson` |
| Unsupported `version` | `FormatException` | `importJson` |
| Malformed JSON | `FormatException` from `jsonDecode` | settings page handles it |
| Old backup (no subtasks/tags/reminders/link) | Optional fields default to null/empty | `_list(...)` returns empty |
| Explicit ids | Preserved via `insertOrReplace`, so links survive | `importJson` |
| Foreign keys during import | Insert order respects them (tags/subtasks → tasks → columns → boards) | `importJson` |
| Cancelled file picker | No-op | settings page |
| Import while a board is selected | Selection reset so the UI re-resolves the active board | settings page |

## 10. Migrations & foreign keys

| Case | Behaviour | Where |
|---|---|---|
| Fresh install | `createAll()` + seed board/columns | `MigrationStrategy.onCreate` |
| v1 → v4 | Adds `linked_task_id`, `reminder_minutes_before`, creates the three new tables | `onUpgrade` |
| FKs on a raw connection | Enabled in `beforeOpen`; SQLite defaults them **off** per connection | `beforeOpen` |
| Board deletion | Cascades columns and tasks | FK cascade |
| Column deletion with tasks | DAO reassigns tasks before deleting (FK would `SET NULL` and hide them) | `BoardDao.deleteColumn` |
| Task deletion | Cascades subtasks/links, nulls `events.linked_task_id` | FK actions |
| Migration test | Build current schema → drop new columns/tables → set `user_version` → reopen (see `test/event_task_link_test.dart`) | tests |

## 11. Localization

| Case | Behaviour | Where |
|---|---|---|
| Missing translation | `gen-l10n` falls back to the template; parity test fails first | `test/l10n_test.dart` |
| Empty translation | Rejected by the parity test | same |
| Plurals | ICU: `calendarTaskCount` renders 0/1/n | ARB |
| Date formatting | `Intl.defaultLocale` follows the app locale | `app.dart` builder |
| Language switch | Follows the system locale; no in-app override (yet) | `MaterialApp` |

## 12. Search

| Case | Behaviour | Where |
|---|---|---|
| Empty/whitespace query | No results, no UI noise | `runSearch` |
| Case-insensitive | Everything lowered before comparing | `runSearch` |
| Match reasons | Task matches on title, notes, subtask titles or tag names; matching subtask titles shown as hints | `runSearch` |
| Completed tasks | Still searchable | `runSearch` |
| No hits | Localized "Nothing found for …" | search page |
| Tag/subtask changes | Search results update because it watches the same providers | search page |

## 13. Platform & build

| Case | Behaviour | Where |
|---|---|---|
| Web preview | No notifications, no device calendar, sync section disabled | `isSupported` guards |
| Android-only channel | Dart service no-ops off Android (never invokes the channel) | `DeviceCalendarService` |
| Package id | `io.github.chemio9.gtd` (was `…gtd.gtd`) | `build.gradle.kts`, manifest |
| Release signing | Falls back to debug keys until `android/key.properties` exists | `build.gradle.kts` |
| Network | No `INTERNET` permission, no HTTP dependency; adding sync needs both | manifest, pubspec |
| Desugaring | Required by `flutter_local_notifications` (java.time) | `build.gradle.kts` |
| Notification boot receiver | Declared so reminders survive reboots | `AndroidManifest.xml` |
