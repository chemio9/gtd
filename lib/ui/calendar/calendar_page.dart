import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart' hide isSameDay;

import '../../core/date_x.dart';
import '../../core/recurrence.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';
import '../search/search_button.dart';
import '../settings/settings_button.dart';
import '../tasks/task_editor_sheet.dart';
import 'event_editor_sheet.dart';

/// A row in the day agenda: either a calendar event or a task due on that day.
sealed class AgendaEntry {
  const AgendaEntry();

  DateTime get sortTime;
}

class EventEntry extends AgendaEntry {
  const EventEntry(this.occurrence);

  final EventOccurrence occurrence;

  @override
  DateTime get sortTime => occurrence.start;
}

class TaskEntry extends AgendaEntry {
  const TaskEntry(this.task);

  final Task task;

  @override
  DateTime get sortTime => task.dueDate ?? DateTime(0);
}

class CalendarPage extends ConsumerStatefulWidget {
  const CalendarPage({super.key});

  @override
  ConsumerState<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends ConsumerState<CalendarPage> {
  CalendarFormat _format = CalendarFormat.month;

  (DateTime, DateTime) _window(DateTime focused) {
    // Pad by one month on each side so the calendar always has data for the
    // days it renders outside the focused month.
    return (
      DateTime(focused.year, focused.month - 1, 1),
      DateTime(focused.year, focused.month + 2, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusedDay = ref.watch(calendarFocusedDayProvider);
    final window = _window(focusedDay);
    final byDay = ref.watch(occurrencesByDayProvider(window));

    // Tasks due anywhere in the visible window, keyed by day for the markers.
    final tasksInWindow =
        ref.watch(tasksDueBetweenProvider(window)).value ?? const <Task>[];
    final tasksByDay = <DateTime, List<Task>>{};
    for (final task in tasksInWindow) {
      final due = task.dueDate;
      if (due == null) continue;
      tasksByDay.putIfAbsent(dateOnly(due), () => <Task>[]).add(task);
    }

    final dayStart = dateOnly(focusedDay);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final tasksDue =
        ref.watch(tasksDueBetweenProvider((dayStart, dayEnd))).value ??
        const <Task>[];

    List<AgendaEntry> entriesFor(DateTime day) {
      final entries = <AgendaEntry>[
        for (final occurrence in byDay[dateOnly(day)] ?? const [])
          EventEntry(occurrence),
      ];
      if (isSameDay(day, dayStart)) {
        entries.addAll(tasksDue.map(TaskEntry.new));
      }
      entries.sort((a, b) => a.sortTime.compareTo(b.sortTime));
      return entries;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.calendarTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.calendarToday,
            onPressed: () => ref
                .read(calendarFocusedDayProvider.notifier)
                .set(DateTime.now()),
            icon: const Icon(Icons.today_outlined),
          ),
          const SearchButton(),
          const SettingsButton(),
        ],
      ),
      body: Column(
        children: [
          TableCalendar<Object>(
            firstDay: DateTime(DateTime.now().year - 3),
            lastDay: DateTime(DateTime.now().year + 6),
            focusedDay: focusedDay,
            calendarFormat: _format,
            availableCalendarFormats: {
              CalendarFormat.month: context.l10n.calendarMonth,
              CalendarFormat.twoWeeks: context.l10n.calendarTwoWeeks,
              CalendarFormat.week: context.l10n.calendarWeek,
            },
            startingDayOfWeek: StartingDayOfWeek.monday,
            availableGestures: AvailableGestures.horizontalSwipe,
            selectedDayPredicate: (day) => isSameDay(day, focusedDay),
            onDaySelected: (selected, _) =>
                ref.read(calendarFocusedDayProvider.notifier).set(selected),
            onFormatChanged: (format) => setState(() => _format = format),
            onPageChanged: (focused) =>
                ref.read(calendarFocusedDayProvider.notifier).set(focused),
            eventLoader: (day) => [
              for (final occurrence in byDay[dateOnly(day)] ?? const [])
                occurrence,
            ],
            calendarStyle: CalendarStyle(
              isTodayHighlighted: true,
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .28),
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.w700,
              ),
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
              markersMaxCount: 3,
            ),
            headerStyle: HeaderStyle(
              formatButtonDecoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: theme.textTheme.labelMedium!,
              titleCentered: false,
              leftChevronIcon: const Icon(Icons.chevron_left),
              rightChevronIcon: const Icon(Icons.chevron_right),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final dayTasks = tasksByDay[dateOnly(day)] ?? const <Task>[];
                if (events.isEmpty && dayTasks.isEmpty) return null;
                return Padding(
                  padding: const EdgeInsets.only(top: 26),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < events.length.clamp(0, 3); i++)
                        _CalendarDot(
                          key: const ValueKey('calendar-event-dot'),
                          color: theme.colorScheme.tertiary,
                        ),
                      if (dayTasks.isNotEmpty)
                        _CalendarDot(
                          key: const ValueKey('calendar-task-dot'),
                          color: theme.colorScheme.secondary,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  friendlyDay(focusedDay),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  context.l10n.calendarTaskCount(tasksDue.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _AgendaList(
              entries: entriesFor(focusedDay),
              day: focusedDay,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'calendar-fab',
        onPressed: () => showEventEditor(context, initialDay: focusedDay),
        icon: const Icon(Icons.event),
        label: Text(context.l10n.calendarNewEvent),
      ),
    );
  }
}

class _AgendaList extends ConsumerWidget {
  const _AgendaList({required this.entries, required this.day});

  final List<AgendaEntry> entries;
  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 40,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.calendarNothingScheduled,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showEventEditor(context, initialDay: day),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.calendarAddEntry),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return switch (entry) {
          EventEntry(:final occurrence) => _EventTile(occurrence: occurrence),
          TaskEntry(:final task) => _TaskEntryTile(task: task),
        };
      },
    );
  }
}

class _EventTile extends ConsumerWidget {
  const _EventTile({required this.occurrence});

  final EventOccurrence occurrence;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final event = occurrence.event;
    final timeLabel = event.allDay
        ? context.l10n.calendarAllDay
        : '${formatTime(occurrence.start)} – ${formatTime(occurrence.end)}';
    final tasks = ref.watch(allTasksProvider).value ?? const <Task>[];
    final linkedTask = event.linkedTaskId == null
        ? null
        : tasks.where((task) => task.id == event.linkedTaskId).firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: ListTile(
        onTap: () => showEventEditor(context, event: event),
        isThreeLine: linkedTask != null,
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (occurrence.isRecurring)
              Icon(
                Icons.repeat,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.notes == null || event.notes!.trim().isEmpty
                  ? timeLabel
                  : '$timeLabel · ${event.notes}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            if (linkedTask != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 12, color: scheme.tertiary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        linkedTask.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.tertiary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskEntryTile extends ConsumerWidget {
  const _TaskEntryTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final board = ref.watch(activeBoardProvider);
    final done = task.completedAt != null;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: ListTile(
        onTap: board == null
            ? null
            : () => showTaskEditor(
                context,
                boardId: task.boardId ?? board.id,
                task: task,
              ),
        leading: Checkbox(
          value: done,
          shape: const CircleBorder(),
          onChanged: (value) => ref
              .read(taskDaoProvider)
              .setCompleted(task, completed: value ?? false),
        ),
        title: Text(
          task.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.check_box_outlined, size: 12, color: scheme.outline),
            const SizedBox(width: 4),
            Text(
              task.dueDate == null || !hasTimeOfDay(task.dueDate!)
                  ? context.l10n.calendarTask
                  : context.l10n.calendarTaskWithTime(
                      formatTime(task.dueDate!),
                    ),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small marker rendered under a day number.
class _CalendarDot extends StatelessWidget {
  const _CalendarDot({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
