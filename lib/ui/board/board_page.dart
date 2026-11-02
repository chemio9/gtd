import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';
import '../common/text_prompt_dialog.dart';
import '../kanban/kanban_board_view.dart';
import 'inline_card_add.dart';
import '../search/search_button.dart';
import '../settings/settings_button.dart';
import '../tasks/task_card.dart';
import '../tasks/task_editor_sheet.dart';

class BoardPage extends ConsumerStatefulWidget {
  const BoardPage({super.key});

  @override
  ConsumerState<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends ConsumerState<BoardPage> {
  /// Column currently showing the inline "add card" field.
  int? _addingColumnId;

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(activeBoardProvider);
    final boards = ref.watch(boardsProvider).value ?? const <Board>[];

    if (board == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.boardTitle)),
        body: Center(
          child: boards.isEmpty
              ? const CircularProgressIndicator()
              : Text(context.l10n.boardNoSelection),
        ),
      );
    }

    final columnsAsync = ref.watch(boardColumnsProvider(board.id));
    final tasksAsync = ref.watch(boardTasksProvider(board.id));
    final tagsByTask = ref.watch(taskTagsProvider);
    final subtaskProgress = ref.watch(subtaskProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: _BoardSwitcher(boards: boards, active: board),
        actions: [
          IconButton(
            tooltip: context.l10n.boardAddColumn,
            onPressed: () => _showAddColumnDialog(context, ref, board.id),
            icon: const Icon(Icons.view_column_outlined),
          ),
          IconButton(
            tooltip: context.l10n.boardNewTask,
            onPressed: () => showTaskEditor(context, boardId: board.id),
            icon: const Icon(Icons.add_task),
          ),
          const SearchButton(),
          const SettingsButton(),
        ],
      ),
      body: columnsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
        data: (columns) {
          final tasks = tasksAsync.value ?? const <Task>[];
          final byColumn = <int, List<Task>>{};
          for (final task in tasks) {
            final columnId = task.columnId;
            if (columnId == null) continue;
            byColumn.putIfAbsent(columnId, () => <Task>[]).add(task);
          }
          final kanbanColumns = [
            for (final column in columns)
              KanbanColumn<Task>(
                id: '${column.id}',
                title: column.title,
                items: byColumn[column.id] ?? const <Task>[],
                isDone: column.isDone,
                accent: column.isDone
                    ? Theme.of(context).colorScheme.tertiary
                    : null,
              ),
          ];

          return KanbanBoardView<Task>(
            columns: kanbanColumns,
            style: KanbanStyle(
              columnWidth: MediaQuery.sizeOf(context).width < 600
                  ? (MediaQuery.sizeOf(context).width * .82).clamp(240.0, 320.0)
                  : 300,
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            ),
            itemIdOf: (task) => '${task.id}',
            itemBuilder: (context, task, isDragging) => TaskCard(
              task: task,
              isDragging: isDragging,
              tags: tagsByTask[task.id] ?? const [],
              subtaskProgress: subtaskProgress[task.id],
            ),
            onItemTap: (task) =>
                showTaskEditor(context, boardId: board.id, task: task),
            onAddItem: (column) => setState(
              () => _addingColumnId = int.tryParse(column.id),
            ),
            columnTopBuilder: (context, column) {
              if (_addingColumnId?.toString() != column.id) return null;
              return InlineCardAdd(
                boardId: board.id,
                columnId: int.parse(column.id),
                onDone: () => setState(() => _addingColumnId = null),
              );
            },
            onColumnMenu: (context, column) => _showColumnMenu(
              context,
              ref,
              boardId: board.id,
              columnId: int.parse(column.id),
              columns: columns,
            ),
            emptyBuilder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.kanbanNoTasks,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            onMove: (move) => _handleMove(ref, move, byColumn),
          );
        },
      ),
    );
  }

  Future<void> _handleMove(
    WidgetRef ref,
    KanbanMove<Task> move,
    Map<int, List<Task>> byColumn,
  ) async {
    final fromId = int.tryParse(move.fromColumnId);
    final toId = int.tryParse(move.toColumnId);
    if (fromId == null || toId == null) return;

    final targetItems = [...?byColumn[toId]];
    targetItems.removeWhere((task) => task.id == move.item.id);
    targetItems.insert(move.newIndex.clamp(0, targetItems.length), move.item);

    await ref
        .read(taskDaoProvider)
        .moveTask(
          taskId: move.item.id,
          fromColumnId: fromId,
          toColumnId: toId,
          targetOrderedIds: [for (final task in targetItems) task.id],
        );
  }

  Future<void> _showColumnMenu(
    BuildContext context,
    WidgetRef ref, {
    required int boardId,
    required int columnId,
    required List<BoardColumn> columns,
  }) async {
    final column = columns.firstWhere((c) => c.id == columnId);
    final index = columns.indexOf(column);
    final dao = ref.read(boardDaoProvider);

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(context.l10n.boardRenameColumn),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: Icon(
                column.isDone
                    ? Icons.radio_button_unchecked
                    : Icons.check_circle_outline,
              ),
              title: Text(
                column.isDone
                    ? context.l10n.boardMarkActive
                    : context.l10n.boardMarkDone,
              ),
              onTap: () => Navigator.pop(context, 'toggle-done'),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: Text(context.l10n.boardMoveLeft),
              enabled: index > 0,
              onTap: () => Navigator.pop(context, 'left'),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward),
              title: Text(context.l10n.boardMoveRight),
              enabled: index < columns.length - 1,
              onTap: () => Navigator.pop(context, 'right'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(context.l10n.boardDeleteColumn),
              subtitle: Text(context.l10n.boardDeleteColumnHint),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    switch (action) {
      case 'rename':
        if (!context.mounted) return;
        final name = await showTextPrompt(
          context,
          title: context.l10n.boardRenameColumn,
          initialValue: column.title,
        );
        if (name != null) await dao.renameColumn(columnId, name);
      case 'toggle-done':
        await dao.setColumnDone(columnId, !column.isDone);
      case 'left' || 'right':
        final ordered = [for (final c in columns) c.id];
        final target = action == 'left' ? index - 1 : index + 1;
        if (target < 0 || target >= ordered.length) return;
        final id = ordered.removeAt(index);
        ordered.insert(target, id);
        await dao.reorderColumns(boardId, ordered);
      case 'delete':
        if (!context.mounted) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.boardDeleteColumnQuestion),
            content: Text(context.l10n.boardDeleteColumnBody(column.title)),
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
        if (confirmed == true) await dao.deleteColumn(columnId);
    }
  }

  Future<void> _showAddColumnDialog(
    BuildContext context,
    WidgetRef ref,
    int boardId,
  ) async {
    final name = await showTextPrompt(
      context,
      title: context.l10n.boardNewColumn,
      hint: context.l10n.boardColumnHint,
      confirmLabel: context.l10n.create,
    );
    if (name == null) return;
    await ref
        .read(boardDaoProvider)
        .addColumn(boardId: boardId, title: name);
  }
}

class _BoardSwitcher extends ConsumerWidget {
  const _BoardSwitcher({required this.boards, required this.active});

  final List<Board> boards;
  final Board active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<int>(
      tooltip: context.l10n.boardSwitch,
      onSelected: (value) async {
        if (value == -1) {
          await _createBoard(context, ref);
        } else if (value == -2) {
          await _deleteBoard(context, ref);
        } else {
          ref.read(selectedBoardIdProvider.notifier).select(value);
        }
      },
      itemBuilder: (context) => [
        for (final board in boards)
          PopupMenuItem(
            value: board.id,
            child: Row(
              children: [
                Icon(
                  board.id == active.id
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(board.name),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: -1,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add),
            title: Text(context.l10n.boardNewBoard),
          ),
        ),
        if (boards.length > 1)
          PopupMenuItem(
            value: -2,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline),
              title: Text(context.l10n.boardDeleteBoard),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(active.name),
          const Icon(Icons.arrow_drop_down),
        ],
      ),
    );
  }

  Future<void> _createBoard(BuildContext context, WidgetRef ref) async {
    final name = await showTextPrompt(
      context,
      title: context.l10n.boardNewBoard,
      label: context.l10n.name,
      hint: context.l10n.boardHint,
      confirmLabel: context.l10n.create,
    );
    if (name == null) return;
    final id = await ref.read(boardDaoProvider).createBoard(name);
    ref.read(selectedBoardIdProvider.notifier).select(id);
  }

  Future<void> _deleteBoard(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.boardDeleteBoardQuestion(active.name)),
        content: Text(context.l10n.boardDeleteBoardBody),
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
    await ref.read(boardDaoProvider).deleteBoard(active.id);
    ref.read(selectedBoardIdProvider.notifier).select(null);
  }
}
