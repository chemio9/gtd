import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../core/search.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';
import '../calendar/event_editor_sheet.dart';
import '../tasks/task_editor_sheet.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final results = runSearch(
      query: _query,
      tasks: ref.watch(allTasksProvider).value ?? const <Task>[],
      events: ref.watch(allEventsProvider).value ?? const <Event>[],
      subtasks: ref.watch(allSubtasksProvider).value ?? const <Subtask>[],
      tagsByTask: ref.watch(taskTagsProvider),
    );
    final board = ref.watch(activeBoardProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            border: InputBorder.none,
          ),
          onChanged: (value) => setState(() => _query = value),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: l10n.close,
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.trim().isEmpty
          ? const SizedBox.shrink()
          : results.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.searchNoResults(_query.trim()),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (results.tasks.isNotEmpty) ...[
                  _Section(
                    title: l10n.searchTasks,
                    count: results.tasks.length,
                  ),
                  for (final task in results.tasks)
                    ListTile(
                      leading: Icon(
                        task.completedAt == null
                            ? Icons.check_box_outline_blank
                            : Icons.check_box,
                      ),
                      title: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          if (task.dueDate != null)
                            formatDueLabel(task.dueDate!),
                          ...?results.matchedSubtasks[task.id],
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: board == null
                          ? null
                          : () => showTaskEditor(
                              context,
                              boardId: task.boardId ?? board.id,
                              task: task,
                            ),
                    ),
                ],
                if (results.events.isNotEmpty) ...[
                  _Section(
                    title: l10n.searchEvents,
                    count: results.events.length,
                  ),
                  for (final event in results.events)
                    ListTile(
                      leading: const Icon(Icons.event_outlined),
                      title: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(formatDueLabel(event.startsAt)),
                      onTap: () => showEventEditor(context, event: event),
                    ),
                ],
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              letterSpacing: .8,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
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
