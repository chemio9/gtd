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
import '../common/text_prompt_dialog.dart';
import '../search/search_button.dart';
import '../settings/settings_button.dart';
import '../tasks/quick_add_bar.dart';
import '../tasks/subtask_tree.dart';
import '../tasks/task_card.dart';
import '../tasks/task_editor_sheet.dart';
import '../tasks/task_metadata_section.dart' show tagPalette;

class TodosPage extends ConsumerStatefulWidget {
  const TodosPage({super.key});

  @override
  ConsumerState<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends ConsumerState<TodosPage> {
  final GlobalKey<QuickAddBarState> _quickAddKey =
      GlobalKey<QuickAddBarState>();
  bool _quickAddExpanded = false;

  /// Multi-selection state. Kept in the page because it is transient.
  bool _selecting = false;
  final Set<int> _selected = <int>{};

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

  // ----------------------------------------------------------- selection
  void _enterSelection(Task task) {
    setState(() {
      _selecting = true;
      _selected.add(task.id);
    });
  }

  void _exitSelection() {
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selected.clear();
    });
  }

  void _toggleSelected(Task task, bool value) {
    setState(() {
      if (value) {
        _selected.add(task.id);
      } else {
        _selected.remove(task.id);
      }
      if (_selected.isEmpty) _selecting = false;
    });
  }

  /// Every task currently rendered, de-duplicated (subject groups repeat rows).
  List<Task> _visibleTasks() {
    final grouping = ref.read(todoGroupingProvider);
    final Iterable<Task> tasks = grouping == TodoGrouping.subject
        ? ref.read(subjectTodosProvider).values.expand((list) => list)
        : ref.read(groupedTodosProvider).values.expand((list) => list);
    final seen = <int>{};
    return [
      for (final task in tasks)
        if (seen.add(task.id)) task,
    ];
  }

  void _selectAll() {
    final tasks = _visibleTasks();
    setState(() {
      for (final task in tasks) {
        _selected.add(task.id);
      }
    });
  }

  List<Task> get _selectedTasks {
    final ids = _selected;
    final all = ref.read(allTasksProvider).value ?? const <Task>[];
    return [
      for (final task in all)
        if (ids.contains(task.id)) task,
    ];
  }

  // ------------------------------------------------------------ bulk ops
  Future<void> _applyDue(DateTime? due) async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    await ref.read(taskDaoProvider).setDueDates(ids, due);
    if (!mounted) return;
    _exitSelection();
    _snack(context.l10n.todosBulkUpdated(ids.length));
  }

  Future<void> _pickDue() async {
    final today = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today.subtract(const Duration(days: 365 * 2)),
      lastDate: today.add(const Duration(days: 365 * 3)),
    );
    if (picked == null) return;
    await _applyDue(dateOnly(picked));
  }

  Future<void> _applyCompleted(bool completed) async {
    final tasks = _selectedTasks;
    if (tasks.isEmpty) return;
    await ref
        .read(taskDaoProvider)
        .setCompletedMany(tasks, completed: completed);
    if (!mounted) return;
    _exitSelection();
    _snack(context.l10n.todosBulkUpdated(tasks.length));
  }

  Future<void> _deleteSelected() async {
    final ids = _selected.toList();
    if (ids.isEmpty) return;
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.todosBulkDelete),
        content: Text(l10n.todosSelectedCount(ids.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.todosBulkDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(taskDaoProvider).deleteTasks(ids);
    if (!mounted) return;
    _exitSelection();
    _snack(context.l10n.todosBulkDeleted(ids.length));
  }

  Future<void> _addTags() async {
    final tags = ref.read(tagsProvider).value ?? const <Tag>[];
    final chosen = await showModalBottomSheet<Set<int>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _BulkTagSheet(tags: tags),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    final ids = _selected.toList();
    final dao = ref.read(tagDaoProvider);
    for (final taskId in ids) {
      for (final tagId in chosen) {
        await dao.attach(taskId, tagId);
      }
    }
    if (!mounted) return;
    _exitSelection();
    _snack(context.l10n.todosBulkUpdated(ids.length));
  }

  // -------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filter = ref.watch(todoFilterProvider);
    final grouping = ref.watch(todoGroupingProvider);
    final subjectFilter = ref.watch(todoSubjectFilterProvider);
    final board = ref.watch(activeBoardProvider);
    final isLoading = ref.watch(allTasksProvider).isLoading;
    final empty = grouping == TodoGrouping.subject
        ? ref.watch(subjectTodosProvider).isEmpty
        : ref.watch(groupedTodosProvider).isEmpty;

    return Scaffold(
      appBar: _selecting
          ? _selectionAppBar(l10n)
          : _defaultAppBar(l10n, filter, grouping, subjectFilter),
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
                  ref
                      .read(todoFilterProvider.notifier)
                      .set(TodoFilter.all);
                }
              },
            ),
          Expanded(
            child: isLoading && empty
                ? const Center(child: CircularProgressIndicator())
                : empty
                ? _EmptyState(filter: filter)
                : SlidableAutoCloseBehavior(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 96),
                      children: _buildList(context, l10n),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _selecting ? _selectionBar(l10n) : null,
      floatingActionButton: board == null || _selecting
          ? null
          : FloatingActionButton(
              heroTag: 'todos-fab',
              onPressed: _expandQuickAdd,
              tooltip: l10n.todosAddTask,
              child: const Icon(Icons.add),
            ),
    );
  }

  AppBar _defaultAppBar(
    AppLocalizations l10n,
    TodoFilter filter,
    TodoGrouping grouping,
    Set<int?> subjectFilter,
  ) {
    final board = ref.watch(activeBoardProvider);
    final bySubject = grouping == TodoGrouping.subject;
    return AppBar(
      title: Text(l10n.todosTitle),
      actions: [
        IconButton(
          tooltip: bySubject ? l10n.todosGroupByDay : l10n.todosGroupBySubject,
          icon: Icon(
            bySubject ? Icons.event_note_outlined : Icons.category_outlined,
          ),
          onPressed: () => ref
              .read(todoGroupingProvider.notifier)
              .set(bySubject ? TodoGrouping.day : TodoGrouping.subject),
        ),
        PopupMenuButton<String>(
          tooltip: l10n.todosMore,
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
              case 'select':
                setState(() => _selecting = true);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'select',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.checklist_rtl),
                title: Text(l10n.todosSelectTasks),
              ),
            ),
            PopupMenuItem(
              value: 'detailed',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note),
                title: Text(l10n.todosDetailedTask),
              ),
            ),
            PopupMenuItem(
              value: 'paste',
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.content_paste_go),
                title: Text(l10n.todosPasteList),
              ),
            ),
          ],
        ),
        const SearchButton(),
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
                    onSelected: (_) =>
                        ref.read(todoFilterProvider.notifier).set(option),
                  ),
                  const SizedBox(width: 8),
                ],
                if (subjectFilter.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: Text(l10n.todosShowAllSubjects),
                    onPressed: () =>
                        ref.read(todoSubjectFilterProvider.notifier).clear(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _selectionAppBar(AppLocalizations l10n) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: l10n.todosClearSelection,
        onPressed: _exitSelection,
      ),
      title: Text(l10n.todosSelectedCount(_selected.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: l10n.todosSelectAll,
          onPressed: _selectAll,
        ),
      ],
    );
  }

  Widget _selectionBar(AppLocalizations l10n) {
    final today = dateOnly(DateTime.now());
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              _barAction(
                Icons.today,
                l10n.todosBulkToday,
                () => _applyDue(today),
              ),
              _barAction(
                Icons.event,
                l10n.todosBulkTomorrow,
                () => _applyDue(today.add(const Duration(days: 1))),
              ),
              _barAction(Icons.date_range, l10n.todosBulkPickDate, _pickDue),
              _barAction(
                Icons.event_busy_outlined,
                l10n.todosBulkClearDate,
                () => _applyDue(null),
              ),
              _barAction(
                Icons.check_circle_outline,
                l10n.todosBulkComplete,
                () => _applyCompleted(true),
              ),
              _barAction(
                Icons.radio_button_unchecked,
                l10n.todosBulkReopen,
                () => _applyCompleted(false),
              ),
              _barAction(Icons.sell_outlined, l10n.todosBulkTags, _addTags),
              _barAction(
                Icons.delete_outline,
                l10n.todosBulkDelete,
                _deleteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barAction(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: _selected.isEmpty ? null : onPressed,
    );
  }

  /// Renders the sections of the active grouping as a flat widget list.
  List<Widget> _buildList(BuildContext context, AppLocalizations l10n) {
    final grouping = ref.watch(todoGroupingProvider);
    if (grouping == TodoGrouping.day) {
      final groups = ref.watch(groupedTodosProvider);
      return [
        for (final entry in groups.entries) ...[
          _SectionHeader(
            title: _groupLabel(context, entry.key),
            count: entry.value.length,
            isOverdue: entry.key == TodoGroup.overdue,
          ),
          ..._taskRows(context, entry.value),
        ],
      ];
    }

    final sections = ref.watch(subjectTodosProvider);
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final tagById = {for (final tag in tags) tag.id: tag};
    final collapsed = ref.watch(collapsedTodoSubjectsProvider);
    final subjectFilter = ref.watch(todoSubjectFilterProvider);

    return [
      for (final entry in sections.entries) ...[
        _SectionHeader(
          key: ValueKey('todo-group-${entry.key ?? 'none'}'),
          title: entry.key == null
              ? l10n.todosUncategorized
              : tagById[entry.key]?.name ?? l10n.todosUncategorized,
          count: entry.value.length,
          accent: entry.key == null
              ? Theme.of(context).colorScheme.outline
              : Color(tagById[entry.key]?.color ?? 0xFF4F46E5),
          uppercase: false,
          collapsed: collapsed.contains(entry.key),
          active: subjectFilter.contains(entry.key),
          onTap: () =>
              ref.read(collapsedTodoSubjectsProvider.notifier).toggle(entry.key),
          onLongPress: () => ref
              .read(todoSubjectFilterProvider.notifier)
              .toggle(entry.key),
        ),
        if (!collapsed.contains(entry.key))
          ..._taskRows(context, entry.value),
      ],
    ];
  }

  List<Widget> _taskRows(BuildContext context, List<Task> tasks) {
    final settings = ref.watch(settingsProvider);
    final linkedEvents = ref.watch(linkedEventsByTaskProvider);
    final tagsByTask = ref.watch(taskTagsProvider);
    final progress = ref.watch(subtaskProgressProvider);
    final subtasksByTask = ref.watch(subtasksByTaskProvider);
    final board = ref.watch(activeBoardProvider);

    return [
      for (final task in tasks) ...[
        TaskTile(
          task: task,
          selectionMode: _selecting,
          selected: _selected.contains(task.id),
          onSelectedChanged: (value) => _toggleSelected(task, value),
          onLongPress: () => _enterSelection(task),
          tags: tagsByTask[task.id] ?? const <Tag>[],
          subtaskProgress: progress[task.id],
          hasLinkedEvent: (linkedEvents[task.id] ?? const []).isNotEmpty,
          startAction: settings.swipeStart,
          endAction: settings.swipeEnd,
          onToggle: (value) =>
              ref.read(taskDaoProvider).setCompleted(task, completed: value),
          onSwipeAction: (action) => _runSwipeAction(task, action),
          onTap: () => _openTask(task, board),
        ),
        for (final subtask in subtasksByTask[task.id] ?? const <Subtask>[])
          SubtaskTreeRow(subtask: subtask),
      ],
    ];
  }

  void _openTask(Task task, Board? board) {
    if (_selecting) {
      _toggleSelected(task, !_selected.contains(task.id));
      return;
    }
    if (board == null) return;
    showTaskEditor(
      context,
      boardId: task.boardId ?? board.id,
      task: task,
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
        await dao.updateTask(task.id, TasksCompanion(dueDate: Value(today)));
      case SwipeAction.scheduleTomorrow:
        await dao.updateTask(
          task.id,
          TasksCompanion(dueDate: Value(today.add(const Duration(days: 1)))),
        );
      case SwipeAction.delete:
        await dao.deleteTask(task.id);
        if (!mounted) return;
        _snack(
          context.l10n.todosDeletedTask(task.title),
          duration: const Duration(seconds: 4),
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

    // Informational only: undo is reserved for destructive actions.
    _snack(
      ids.length == 1
          ? l10n.todosAddedTask(lines.first)
          : l10n.todosAddedTasks(ids.length),
    );
  }

  void _snack(
    String message, {
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          // SnackBars with an action persist by default in Material 3; the
          // undo hint must disappear with the timer like any other toast.
          persist: false,
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
    super.key,
    required this.title,
    required this.count,
    this.isOverdue = false,
    this.accent,
    this.uppercase = true,
    this.collapsed = false,
    this.active = false,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final int count;
  final bool isOverdue;
  final Color? accent;

  /// Day buckets read better in caps; subject names must keep their casing.
  final bool uppercase;

  final bool collapsed;

  /// True when the list is pinned to this group.
  final bool active;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isOverdue
        ? theme.colorScheme.error
        : active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Row(
          children: [
            if (onTap != null)
              Icon(
                collapsed ? Icons.chevron_right : Icons.expand_more,
                size: 18,
                color: color,
              ),
            if (accent != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                uppercase ? title.toUpperCase() : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  letterSpacing: uppercase ? .8 : 0,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(Icons.filter_alt, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tag picker used when tagging several tasks at once.
class _BulkTagSheet extends ConsumerStatefulWidget {
  const _BulkTagSheet({required this.tags});

  final List<Tag> tags;

  @override
  ConsumerState<_BulkTagSheet> createState() => _BulkTagSheetState();
}

class _BulkTagSheetState extends ConsumerState<_BulkTagSheet> {
  final Set<int> _selected = <int>{};

  Future<void> _createTag() async {
    final l10n = context.l10n;
    final name = await showTextPrompt(
      context,
      title: l10n.tagNew,
      label: l10n.tagName,
      confirmLabel: l10n.create,
    );
    if (name == null || !mounted) return;
    final existing = ref.read(tagsProvider).value ?? const <Tag>[];
    final id = await ref.read(tagDaoProvider).create(
      name,
      color: tagPalette[existing.length % tagPalette.length],
    );
    if (!mounted) return;
    setState(() => _selected.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tags = ref.watch(tagsProvider).value ?? widget.tags;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l10n.tagNew),
              onTap: _createTag,
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final tag in tags)
                    CheckboxListTile(
                      value: _selected.contains(tag.id),
                      title: Text(tag.name),
                      secondary: CircleAvatar(
                        radius: 8,
                        backgroundColor: Color(tag.color),
                      ),
                      onChanged: (value) => setState(() {
                        if (value ?? false) {
                          _selected.add(tag.id);
                        } else {
                          _selected.remove(tag.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: Text(l10n.save),
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
