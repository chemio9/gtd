import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../data/database.dart';
import '../../providers.dart';

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
      initialColumnId: initialColumnId,
      initialDueDate: initialDueDate,
    ),
  );
}

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({
    super.key,
    required this.boardId,
    this.task,
    this.initialColumnId,
    this.initialDueDate,
  });

  final int boardId;
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
  bool _saving = false;

  bool get _isEditing => widget.task != null;

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

    if (_isEditing) {
      final task = widget.task!;
      await dao.updateTask(
        task.id,
        TasksCompanion(
          title: Value(title),
          notes: Value(notes.isEmpty ? null : notes),
          dueDate: Value(_dueDate),
          priority: Value(_priority),
          columnId: Value(columnId),
          boardId: Value(widget.boardId),
          completedAt: _completed
              ? Value(task.completedAt ?? DateTime.now())
              : const Value(null),
        ),
      );
    } else {
      await dao.createTask(
        title: title,
        notes: notes.isEmpty ? null : notes,
        boardId: widget.boardId,
        columnId: columnId,
        dueDate: _dueDate,
        priority: _priority,
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final task = widget.task;
    if (task == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
              _isEditing ? 'Edit task' : 'New task',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Priority', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              showSelectedIcon: false,
              segments: [
                for (final priority in TaskPriority.values)
                  ButtonSegment(
                    value: priority,
                    label: Text(priority.label),
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
                          ? 'Add due date'
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
                      child: const Text('Add time'),
                    ),
                  IconButton(
                    tooltip: 'Clear due date',
                    onPressed: () => setState(() => _dueDate = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
            if (columns.isNotEmpty) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: columns.any((c) => c.id == _columnId)
                    ? _columnId
                    : columns.first.id,
                decoration: const InputDecoration(
                  labelText: 'Column',
                  border: OutlineInputBorder(),
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
            if (_isEditing) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Completed'),
                value: _completed,
                onChanged: (value) => setState(() => _completed = value),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (_isEditing)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_isEditing ? 'Save' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
