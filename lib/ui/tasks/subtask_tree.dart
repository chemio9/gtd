import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers.dart';
import 'subtask_dialogs.dart';

/// One subtask rendered as a branch under its task, file-tree style.
///
/// Only one level exists, so an indented row with a connector is enough;
/// tapping the row toggles it, just like the task checkbox.
class SubtaskTreeRow extends ConsumerWidget {
  const SubtaskTreeRow({super.key, required this.subtask});

  final Subtask subtask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = subtask.isDone;

    void toggle() =>
        ref.read(subtaskDaoProvider).setDone(subtask.id, !done);

    Future<void> rename() async {
      final title = await promptSubtaskTitle(
        context,
        initialValue: subtask.title,
      );
      if (title == null) return;
      await ref.read(subtaskDaoProvider).rename(subtask.id, title);
    }

    return InkWell(
      key: ValueKey('subtask-row-${subtask.id}'),
      onTap: toggle,
      onLongPress: rename,
      child: Padding(
        padding: const EdgeInsets.only(left: 40, right: 16, bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tree connector: vertical guide + short horizontal branch,
            // aligned with the first line of a wrapped title.
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: 28,
                height: 16,
                child: Row(
                  children: [
                    Container(
                      width: 1,
                      height: 16,
                      color: scheme.outlineVariant,
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          height: 1,
                          color: scheme.outlineVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Checkbox(
              key: ValueKey('subtask-checkbox-${subtask.id}'),
              value: done,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const CircleBorder(),
              onChanged: (_) => toggle(),
            ),
            const SizedBox(width: 4),
            Expanded(
              // No maxLines: long subtasks wrap and keep their own
              // line breaks instead of being truncated.
              child: Text(
                subtask.title,
                style: theme.textTheme.bodySmall?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? scheme.onSurfaceVariant : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
