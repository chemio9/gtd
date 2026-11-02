import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../data/database.dart';
import '../../settings/settings.dart';
import '../../core/quick_parse.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';
import '../settings/settings_button.dart';
import '../tasks/quick_add_bar.dart';
import '../tasks/task_card.dart';
import '../tasks/task_editor_sheet.dart';

class TodosPage extends ConsumerStatefulWidget {
  const TodosPage({super.key});

  @override
  ConsumerState<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends ConsumerState<TodosPage> {
  final GlobalKey<QuickAddBarState> _quickAddKey =
      GlobalKey<QuickAddBarState>();
  bool _quickAddExpanded = false;

  void _expandQuickAdd() {
    setState(() => _quickAddExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _quickAddKey.currentState?.focus(),
    );
  }

  void _collapseQuickAdd() {
    if (!_quickAddExpanded) return;
    setState(() => _quickAddExpanded = false);
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

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(groupedTodosProvider);
    final filter = ref.watch(todoFilterProvider);
    final settings = ref.watch(settingsProvider);
    final linkedEvents = ref.watch(linkedEventsByTaskProvider);
    final filterNotifier = ref.read(todoFilterProvider.notifier);
    final board = ref.watch(activeBoardProvider);
    final isLoading = ref.watch(allTasksProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.todosTitle),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.l10n.todosMore,
            onSelected: (value) {
              if (board == null) return;
              switch (value) {
                case 'detailed':
                  showTaskEditor(
                    context,
                    boardId: board.id,
                    initialDueDate: _defaultDueDate(filter),
                  );
                case 'paste':
                  _pasteList(board.id, _defaultDueDate(filter));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'detailed',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_note),
                  title: Text(context.l10n.todosDetailedTask),
                ),
              ),
              PopupMenuItem(
                value: 'paste',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.content_paste_go),
                  title: Text(context.l10n.todosPasteList),
                ),
              ),
            ],
          ),
          const SettingsButton(),
        ],
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
                      label: Text(_filterLabel(context, option)),
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
      body: Column(
        children: [
          if (board != null)
            QuickAddBar(
              key: _quickAddKey,
              boardId: board.id,
              expanded: _quickAddExpanded,
              defaultDueDate: _defaultDueDate(filter),
              onExpand: _expandQuickAdd,
              onCollapse: _collapseQuickAdd,
              onTaskAdded: (task) {
                // A task added while looking at "Done" would be invisible.
                if (filter == TodoFilter.done) {
                  filterNotifier.set(TodoFilter.all);
                }
              },
            ),
          Expanded(
            child: isLoading && groups.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : groups.isEmpty
                ? _EmptyState(filter: filter)
                : SlidableAutoCloseBehavior(
                    child: ListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    children: [
                      for (final entry in groups.entries) ...[
                        _SectionHeader(
                          title: _groupLabel(context, entry.key),
                          isOverdue: entry.key == TodoGroup.overdue,
                          count: entry.value.length,
                        ),
                        for (final task in entry.value)
                          TaskTile(
                            task: task,
                            hasLinkedEvent:
                                (linkedEvents[task.id] ?? const []).isNotEmpty,
                            startAction: settings.swipeStart,
                            endAction: settings.swipeEnd,
                            onToggle: (value) => ref
                                .read(taskDaoProvider)
                                .setCompleted(task, completed: value),
                            onSwipeAction: (action) =>
                                _runSwipeAction(task, action),
                            onTap: board == null
                                ? null
                                : () => showTaskEditor(
                                    context,
                                    boardId: task.boardId ?? board.id,
                                    task: task,
                                  ),
                          ),
                      ],
                    ],
                  ),
                  ),
          ),
        ],
      ),
      floatingActionButton: board == null
          ? null
          : FloatingActionButton(
              heroTag: 'todos-fab',
              onPressed: _expandQuickAdd,
              tooltip: context.l10n.todosAddTask,
              child: const Icon(Icons.add),
            ),
    );
  }

  /// Applies the action the user configured for a swipe direction.
  Future<void> _runSwipeAction(Task task, SwipeAction action) async {
    final dao = ref.read(taskDaoProvider);
    final today = dateOnly(DateTime.now());

    switch (action) {
      case SwipeAction.toggleComplete:
        await dao.setCompleted(task, completed: task.completedAt == null);
      case SwipeAction.scheduleToday:
        await dao.updateTask(
          task.id,
          TasksCompanion(dueDate: Value(today)),
        );
      case SwipeAction.scheduleTomorrow:
        await dao.updateTask(
          task.id,
          TasksCompanion(
            dueDate: Value(today.add(const Duration(days: 1))),
          ),
        );
      case SwipeAction.delete:
        await dao.deleteTask(task.id);
        if (!mounted) return;
        _snack(
          context.l10n.todosDeletedTask(task.title),
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () async {
              final db = ref.read(databaseProvider);
              await db.into(db.tasks).insert(task.toCompanion(true));
            },
          ),
        );
    }
  }

  /// Turns the clipboard into one task per line (`- ` bullets are stripped).
  Future<void> _pasteList(int boardId, DateTime? defaultDue) async {
    final l10n = context.l10n;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.replaceFirst(RegExp(r'^\s*[-*•]\s+'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      _snack(l10n.todosClipboardEmpty);
      return;
    }

    final dao = ref.read(taskDaoProvider);
    final ids = <int>[];
    for (final line in lines) {
      final parsed = parseQuickAdd(line, fallbackDue: defaultDue);
      if (parsed.title.isEmpty) continue;
      ids.add(
        await dao.createTask(
          title: parsed.title,
          boardId: boardId,
          dueDate: parsed.dueDate,
        ),
      );
    }
    if (ids.isEmpty || !mounted) return;

    _snack(
      ids.length == 1
          ? l10n.todosAddedTask(lines.first)
          : l10n.todosAddedTasks(ids.length),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          for (final id in ids) {
            await dao.deleteTask(id);
          }
        },
      ),
    );
  }

  void _snack(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 3),
          action: action,
        ),
      );
  }

  String _filterLabel(BuildContext context, TodoFilter filter) =>
      switch (filter) {
        TodoFilter.all => context.l10n.todosFilterAll,
        TodoFilter.today => context.l10n.todosFilterToday,
        TodoFilter.upcoming => context.l10n.todosFilterUpcoming,
        TodoFilter.anytime => context.l10n.todosFilterAnytime,
        TodoFilter.done => context.l10n.todosFilterDone,
      };

  String _groupLabel(BuildContext context, TodoGroup group) => switch (group) {
    TodoGroup.overdue => context.l10n.todosGroupOverdue,
    TodoGroup.today => context.l10n.todosGroupToday,
    TodoGroup.tomorrow => context.l10n.todosGroupTomorrow,
    TodoGroup.upcoming => context.l10n.todosGroupUpcoming,
    TodoGroup.later => context.l10n.todosGroupLater,
    TodoGroup.anytime => context.l10n.todosGroupAnytime,
    TodoGroup.completed => context.l10n.todosGroupCompleted,
  };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.isOverdue = false,
  });

  final String title;
  final int count;
  final bool isOverdue;

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
            filter == TodoFilter.done
                ? context.l10n.todosEmptyCompleted
                : context.l10n.todosEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
