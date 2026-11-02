import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';
import '../calendar/event_editor_sheet.dart';
import 'task_metadata_section.dart';

/// Opens the create/edit sheet for a task.
///
/// Returns `true` when the task was saved or deleted.
Future<bool?> showTaskEditor(
  BuildContext context, {
  required int boardId,
  Task? task,
  int? initialColumnId,
  DateTime? initialDueDate,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => TaskEditorSheet(
      boardId: boardId,
      task: task,
      pageContext: context,
      initialColumnId: initialColumnId,
      initialDueDate: initialDueDate,
    ),
  );
}

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.boardId,
    required this.pageContext,
    this.task,
    this.initialColumnId,
    this.initialDueDate,
  });

  final int boardId;

  /// Context of the page that opened the sheet; used to push the event editor
  /// after the task sheet is closed.
  final BuildContext pageContext;
  final Task? task;
  final int? initialColumnId;
  final DateTime? initialDueDate;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.task?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.task?.notes ?? '',
  );

  late DateTime? _dueDate = widget.task?.dueDate ?? widget.initialDueDate;
  late TaskPriority _priority = widget.task?.priority ?? TaskPriority.medium;
  late int? _columnId = widget.task?.columnId ?? widget.initialColumnId;
  late bool _completed = widget.task?.completedAt != null;
  late int? _reminder = widget.task?.reminderMinutesBefore;
  Set<int> _tagIds = {};
  final List<String> _pendingSubtasks = [];
  bool _saving = false;

  bool get _isEditing => widget.task != null;

  String _reminderLabel(BuildContext context, int minutes) =>
      switch (minutes) {
        5 => context.l10n.reminderBefore5m,
        15 => context.l10n.reminderBefore15m,
        60 => context.l10n.reminderBefore1h,
        180 => context.l10n.reminderBefore3h,
        1440 => context.l10n.reminderBefore1d,
        _ => context.l10n.taskReminderNone,
      };

  String _priorityLabel(BuildContext context, TaskPriority priority) =>
      switch (priority) {
        TaskPriority.low => context.l10n.taskPriorityLow,
        TaskPriority.medium => context.l10n.taskPriorityMedium,
        TaskPriority.high => context.l10n.taskPriorityHigh,
        TaskPriority.urgent => context.l10n.taskPriorityUrgent,
      };

  @override
  void initState() {
    super.initState();
    final taskId = widget.task?.id;
    if (taskId == null) return;
    ref
        .read(tagDaoProvider)
        .watchForTask(taskId)
        .first
        .then((tags) {
          if (!mounted) return;
          setState(() => _tagIds = tags.map((tag) => tag.id).toSet());
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final initial = _dueDate ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (day == null || !mounted) return;
    setState(() {
      final current = _dueDate;
      _dueDate = current == null
          ? dateOnly(day)
          : DateTime(
              day.year,
              day.month,
              day.day,
              current.hour,
              current.minute,
            );
    });
  }

  Future<void> _pickDueTime() async {
    final current = _dueDate;
    if (current == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      _dueDate = DateTime(
        current.year,
        current.month,
        current.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    final dao = ref.read(taskDaoProvider);
    final notes = _notes.text.trim();
    final columns =
        ref.read(boardColumnsProvider(widget.boardId)).value ??
        const <BoardColumn>[];
    final columnId = _columnId ?? (columns.isEmpty ? null : columns.first.id);

    final tagDao = ref.read(tagDaoProvider);
    final subtaskDao = ref.read(subtaskDaoProvider);

    if (_isEditing) {
      final task = widget.task!;
      await dao.updateTask(
        task.id,
        TasksCompanion(
          title: Value(title),
          notes: Value(notes.isEmpty ? null : notes),
          dueDate: Value(_dueDate),
          reminderMinutesBefore: Value(_reminder),
          priority: Value(_priority),
          columnId: Value(columnId),
          boardId: Value(widget.boardId),
          completedAt: _completed
              ? Value(task.completedAt ?? DateTime.now())
              : const Value(null),
        ),
      );
      await tagDao.setForTask(task.id, _tagIds);
    } else {
      final id = await dao.createTask(
        title: title,
        notes: notes.isEmpty ? null : notes,
        boardId: widget.boardId,
        columnId: columnId,
        dueDate: _dueDate,
        reminderMinutesBefore: _reminder,
        priority: _priority,
      );
      await tagDao.setForTask(id, _tagIds);
      for (final subtaskTitle in _pendingSubtasks) {
        await subtaskDao.add(taskId: id, title: subtaskTitle);
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// Closes the sheet and opens the event editor (optionally pre-linked).
  Future<void> _openEventEditor(Event? event) async {
    final taskId = widget.task?.id;
    final navigator = Navigator.of(context);
    navigator.pop(false);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    if (!widget.pageContext.mounted) return;
    await showEventEditor(
      widget.pageContext,
      event: event,
      initialDay: widget.task?.dueDate ?? DateTime.now(),
      initialLinkedTaskId: event == null ? taskId : null,
    );
  }

  Future<void> _delete() async {
    final task = widget.task;
    if (task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.taskDeleteQuestion),
        content: Text(context.l10n.taskDeleteBody(task.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(taskDaoProvider).deleteTask(task.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columns =
        ref.watch(boardColumnsProvider(widget.boardId)).value ??
        const <BoardColumn>[];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing
                  ? context.l10n.taskEditTitle
                  : context.l10n.taskNewTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.title,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.l10n.notes,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(context.l10n.taskPriority, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              showSelectedIcon: false,
              segments: [
                for (final priority in TaskPriority.values)
                  ButtonSegment(
                    value: priority,
                    label: Text(_priorityLabel(context, priority)),
                  ),
              ],
              selected: {_priority},
              onSelectionChanged: (value) =>
                  setState(() => _priority = value.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDueDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      _dueDate == null
                          ? context.l10n.taskAddDueDate
                          : friendlyDay(_dueDate!),
                    ),
                  ),
                ),
                if (_dueDate != null) ...[
                  const SizedBox(width: 8),
                  if (hasTimeOfDay(_dueDate!))
                    OutlinedButton(
                      onPressed: _pickDueTime,
                      child: Text(formatTime(_dueDate!)),
                    )
                  else
                    OutlinedButton(
                      onPressed: _pickDueTime,
                      child: Text(context.l10n.taskAddTime),
                    ),
                  IconButton(
                    tooltip: context.l10n.taskClearDueDate,
                    onPressed: () => setState(() {
                      _dueDate = null;
                      _reminder = null;
                    }),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _reminder,
              decoration: InputDecoration(
                labelText: context.l10n.taskReminder,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notifications_active_outlined),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(context.l10n.taskReminderNone),
                ),
                DropdownMenuItem(
                  value: 0,
                  child: Text(context.l10n.taskReminderAtDue),
                ),
                for (final minutes in const [5, 15, 60, 180, 1440])
                  DropdownMenuItem(
                    value: minutes,
                    child: Text(_reminderLabel(context, minutes)),
                  ),
              ],
              onChanged: _dueDate == null
                  ? null
                  : (value) => setState(() => _reminder = value),
            ),
            if (_dueDate == null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  context.l10n.taskReminderNeedsDue,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if (columns.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: columns.any((c) => c.id == _columnId)
                    ? _columnId
                    : columns.first.id,
                decoration: InputDecoration(
                  labelText: context.l10n.taskColumn,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final column in columns)
                    DropdownMenuItem(
                      value: column.id,
                      child: Text(column.title),
                    ),
                ],
                onChanged: (value) => setState(() => _columnId = value),
              ),
            ],
            const SizedBox(height: 16),
            TaskTagsEditor(
              selectedTagIds: _tagIds,
              onChanged: (ids) => setState(() => _tagIds = ids),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              LiveSubtasksEditor(taskId: widget.task!.id)
            else
              PendingSubtasksEditor(
                titles: _pendingSubtasks,
                onChanged: (titles) => setState(() {
                  _pendingSubtasks
                    ..clear()
                    ..addAll(titles);
                }),
              ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.taskCompleted),
                value: _completed,
                onChanged: (value) => setState(() => _completed = value),
              ),
              _LinkedEventsSection(
                taskId: widget.task!.id,
                onOpenEvent: _openEventEditor,
                onCreateEvent: () => _openEventEditor(null),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (_isEditing)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(context.l10n.delete),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _isEditing ? context.l10n.save : context.l10n.create,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Events attached to this task, with a shortcut to create a new one.
class _LinkedEventsSection extends ConsumerWidget {
  const _LinkedEventsSection({
    required this.taskId,
    required this.onOpenEvent,
    required this.onCreateEvent,
  });

  final int taskId;
  final void Function(Event event) onOpenEvent;
  final VoidCallback onCreateEvent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final events =
        ref.watch(eventsForTaskProvider(taskId)).value ?? const <Event>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              context.l10n.taskLinkedEvents,
              style: theme.textTheme.labelMedium?.copyWith(
                letterSpacing: .8,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onCreateEvent,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.taskNewEventShort),
            ),
          ],
        ),
        if (events.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              context.l10n.taskNoLinkedEvents,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final event in events)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(
                event.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                event.recurrence == RecurrenceFrequency.none
                    ? '${formatDay(event.startsAt)}'
                          '${event.allDay ? '' : ' · ${formatTime(event.startsAt)}'}'
                    : '${formatDay(event.startsAt)} · repeats',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => onOpenEvent(event),
            ),
      ],
    );
  }
}
