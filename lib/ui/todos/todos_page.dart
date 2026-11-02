import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../providers.dart';
import '../tasks/task_card.dart';
import '../tasks/task_editor_sheet.dart';

class TodosPage extends ConsumerWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupedTodosProvider);
    final filter = ref.watch(todoFilterProvider);
    final filterNotifier = ref.read(todoFilterProvider.notifier);
    final board = ref.watch(activeBoardProvider);
    final isLoading = ref.watch(allTasksProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  for (final option in TodoFilter.values) ...[
                    ChoiceChip(
                      label: Text(_filterLabel(option)),
                      selected: filter == option,
                      showCheckmark: false,
                      onSelected: (_) => filterNotifier.set(option),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      body: isLoading && groups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
          ? _EmptyState(filter: filter)
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                for (final entry in groups.entries) ...[
                  _SectionHeader(
                    title: entry.key,
                    count: entry.value.length,
                  ),
                  for (final task in entry.value)
                    TaskTile(
                      task: task,
                      onToggle: (value) => ref
                          .read(taskDaoProvider)
                          .setCompleted(task, completed: value),
                      onTap: board == null
                          ? null
                          : () => showTaskEditor(
                              context,
                              boardId: task.boardId ?? board.id,
                              task: task,
                            ),
                      onDelete: () =>
                          ref.read(taskDaoProvider).deleteTask(task.id),
                    ),
                ],
              ],
            ),
      floatingActionButton: board == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showTaskEditor(
                context,
                boardId: board.id,
                initialDueDate: _defaultDueDate(filter),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                filter == TodoFilter.today ? 'Add for today' : 'New task',
              ),
            ),
    );
  }

  DateTime? _defaultDueDate(TodoFilter filter) {
    final today = dateOnly(DateTime.now());
    return switch (filter) {
      TodoFilter.today => today,
      TodoFilter.upcoming => today.add(const Duration(days: 1)),
      TodoFilter.anytime => null,
      TodoFilter.done => null,
      TodoFilter.all => today,
    };
  }

  String _filterLabel(TodoFilter filter) => switch (filter) {
    TodoFilter.all => 'All',
    TodoFilter.today => 'Today',
    TodoFilter.upcoming => 'Upcoming',
    TodoFilter.anytime => 'Anytime',
    TodoFilter.done => 'Done',
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOverdue = title == 'Overdue';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: .8,
              fontWeight: FontWeight.w700,
              color: isOverdue
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});

  final TodoFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filter == TodoFilter.done
                ? Icons.inbox_outlined
                : Icons.check_circle_outline,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            filter == TodoFilter.all
                ? 'Nothing to do. Add your first task.'
                : 'No tasks in this view.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
