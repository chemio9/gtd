import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../data/database.dart';

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
  });

  final Task task;
  final bool isDragging;
  final VoidCallback? onTap;

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
              if (due != null || task.priority != TaskPriority.medium) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (due != null)
                      _Chip(
                        icon: Icons.schedule,
                        label: formatDueLabel(due),
                        color: overdue ? scheme.error : scheme.onSurfaceVariant,
                        background: overdue
                            ? scheme.errorContainer
                            : scheme.surfaceContainerHighest,
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

/// One line in the todo list.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.onToggle,
    this.onTap,
    this.onDelete,
  });

  final Task task;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = task.completedAt != null;
    final due = task.dueDate;
    final overdue =
        due != null && !done && dateOnly(due).isBefore(dateOnly(DateTime.now()));

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      direction: onDelete == null
          ? DismissDirection.none
          : DismissDirection.endToStart,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.errorContainer,
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
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
        subtitle: due == null
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
                    Text(
                      formatDueLabel(due),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: overdue
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
        trailing: task.priority == TaskPriority.medium
            ? null
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: priorityColor(context, task.priority),
                  shape: BoxShape.circle,
                ),
              ),
      ),
    );
  }
}
