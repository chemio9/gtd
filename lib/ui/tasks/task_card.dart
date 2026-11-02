import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../core/date_x.dart';
import '../../data/database.dart';
import '../../settings/settings.dart';

Color priorityColor(BuildContext context, TaskPriority priority) {
  final scheme = Theme.of(context).colorScheme;
  return switch (priority) {
    TaskPriority.low => scheme.outline,
    TaskPriority.medium => scheme.primary,
    TaskPriority.high => scheme.tertiary,
    TaskPriority.urgent => scheme.error,
  };
}

/// Board card.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    this.isDragging = false,
    this.onTap,
    this.tags = const [],
    this.subtaskProgress,
  });

  final Task task;
  final bool isDragging;
  final VoidCallback? onTap;
  final List<Tag> tags;
  final ({int done, int total})? subtaskProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = task.completedAt != null;
    final accent = priorityColor(context, task.priority);
    final due = task.dueDate;
    final overdue = due != null && !done && dateOnly(due).isBefore(dateOnly(DateTime.now()));

    return Material(
      color: scheme.surface,
      elevation: isDragging ? 0 : 0.5,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3, right: 8),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? scheme.onSurfaceVariant : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              if (task.notes != null && task.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.notes,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.notes!.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tag in tags.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Color(tag.color).withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag.name,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Color(tag.color),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (subtaskProgress != null || due != null ||
                  task.priority != TaskPriority.medium) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (subtaskProgress case final progress?)
                      _Chip(
                        icon: Icons.checklist,
                        label: '${progress.done}/${progress.total}',
                        color: scheme.onSurfaceVariant,
                        background: scheme.surfaceContainerHighest,
                      ),
                    if (due != null)
                      _Chip(
                        icon: Icons.schedule,
                        label: formatDueLabel(due),
                        color: overdue ? scheme.error : scheme.onSurfaceVariant,
                        background: overdue
                            ? scheme.errorContainer
                            : scheme.surfaceContainerHighest,
                      ),
                    if (task.reminderMinutesBefore != null)
                      _Chip(
                        icon: Icons.notifications_active,
                        label: '${task.reminderMinutesBefore}m',
                        color: scheme.onSurfaceVariant,
                        background: scheme.surfaceContainerHighest,
                      ),
                    if (task.priority != TaskPriority.medium)
                      _Chip(
                        label: task.priority.label,
                        color: accent,
                        background: accent.withValues(alpha: .12),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// One line in the todo list, with configurable swipe actions.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    this.onTap,
    this.startAction = SwipeAction.toggleComplete,
    this.endAction = SwipeAction.delete,
    this.onSwipeAction,
    this.hasLinkedEvent = false,
    this.tags = const [],
    this.subtaskProgress,
  });

  final Task task;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;

  /// Action revealed when swiping towards the end (left in LTR).
  final SwipeAction startAction;

  /// Action revealed when swiping towards the start (right in LTR).
  final SwipeAction endAction;

  final ValueChanged<SwipeAction>? onSwipeAction;

  /// Shows a calendar badge: the task is linked to at least one event.
  final bool hasLinkedEvent;

  final List<Tag> tags;
  final ({int done, int total})? subtaskProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = task.completedAt != null;
    final due = task.dueDate;
    final overdue =
        due != null && !done && dateOnly(due).isBefore(dateOnly(DateTime.now()));

    return Slidable(
      key: ValueKey('task-${task.id}'),
      startActionPane: _pane(scheme, startAction),
      endActionPane: _pane(scheme, endAction),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Checkbox(
          value: done,
          onChanged: (value) => onToggle(value ?? false),
          shape: const CircleBorder(),
        ),
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? scheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: (due == null && tags.isEmpty && subtaskProgress == null)
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 12,
                      color: overdue ? scheme.error : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    if (due != null)
                      Text(
                        formatDueLabel(due),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: overdue
                              ? scheme.error
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    if (subtaskProgress case final progress?) ...[
                      if (due != null) const SizedBox(width: 8),
                      Icon(
                        Icons.checklist,
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${progress.done}/${progress.total}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    for (final tag in tags.take(2)) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Color(tag.color),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        tag.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Color(tag.color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        trailing: (task.priority == TaskPriority.medium && !hasLinkedEvent)
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (task.reminderMinutesBefore != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.notifications_active_outlined,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (hasLinkedEvent)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.event_outlined,
                        size: 16,
                        color: scheme.tertiary,
                      ),
                    ),
                  if (task.priority != TaskPriority.medium)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: priorityColor(context, task.priority),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  ActionPane? _pane(ColorScheme scheme, SwipeAction action) {
    if (onSwipeAction == null) return null;
    return ActionPane(
      motion: const DrawerMotion(),
      extentRatio: .34,
      children: [
        SlidableAction(
          onPressed: (_) => onSwipeAction!(action),
          backgroundColor: action.isDestructive
              ? scheme.errorContainer
              : scheme.secondaryContainer,
          foregroundColor: action.isDestructive
              ? scheme.onErrorContainer
              : scheme.onSecondaryContainer,
          icon: action.icon,
          label: action.shortLabel,
        ),
      ],
    );
  }
}
