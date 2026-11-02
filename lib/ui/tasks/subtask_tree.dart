import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../providers.dart';

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

    return InkWell(
      key: ValueKey('subtask-row-${subtask.id}'),
      onTap: toggle,
      child: Padding(
        padding: const EdgeInsets.only(left: 40, right: 16, bottom: 2),
        child: Row(
          children: [
            // Tree connector: vertical guide + short horizontal branch.
            SizedBox(
              width: 28,
              height: 28,
              child: Row(
                children: [
                  Container(width: 1, height: 28, color: scheme.outlineVariant),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(height: 1, color: scheme.outlineVariant),
                    ),
                  ),
                ],
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
              child: Text(
                subtask.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
