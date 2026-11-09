# Docs

| File | Contents |
|---|---|
| [DESIGN.md](DESIGN.md) | Product scope, architecture, data model, state management, platform seams, decisions with rationale, rejected alternatives, how to extend |
| [EDGE-CASES.md](EDGE-CASES.md) | Every handled corner case by domain: dates, recurrence, quick add, kanban, completion, subtasks/tags, reminders, calendar sync, backup, migrations, i18n, search, platform |
| [PROBLEMS.md](PROBLEMS.md) | 26 real bugs and build failures: symptom → root cause → fix → lesson |
| [TESTING.md](TESTING.md) | Test strategy, harness patterns, inventory, coverage gaps, how to add tests |

## The core in ten lines

1. One SQLite database (drift, schema v4) is the only source of truth; no
   network, no accounts.
2. A board card, a todo row, a calendar entry and a search hit are all views over
   the same `tasks` rows; completion is `completed_at` + the board's done column.
3. Events are stored once and expanded into occurrences on read
   (`core/recurrence.dart`), so recurrences never duplicate rows.
4. Reusable `KanbanBoardView<T>` owns drag & drop and knows nothing about tasks.
5. Quick add parses `title + date` from one line and reports token spans so the
   field can highlight and confirm what it understood.
6. Subtasks (one level), global tags, event↔task links and per-task reminder
   offsets are all plain drift tables with cascading foreign keys.
7. Notifications and the device calendar are behind gateways
   (`TaskReminderGateway`, `CalendarGateway`) so platform failures cannot break
   the UI and tests never touch a channel.
8. Settings and the calendar sync map are two JSON blobs in
   `shared_preferences`; backups are one versioned JSON document.
9. All UI text flows through `context.l10n` (en + zh), enforced by an ARB parity
   test.
10. Behaviour ships with tests: 126 cases, real widgets, in-memory drift,
    mocked channels.
