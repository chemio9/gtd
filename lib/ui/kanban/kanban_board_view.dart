import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// One column of a [KanbanBoardView].
@immutable
class KanbanColumn<T extends Object> {
  const KanbanColumn({
    required this.id,
    required this.title,
    required this.items,
    this.accent,
    this.isDone = false,
    this.headerTrailing,
  });

  final String id;
  final String title;
  final List<T> items;

  /// Optional colour used for the header dot / drop highlight.
  final Color? accent;

  /// Marks a terminal column (e.g. "Done"). Not used by the board itself;
  /// exposed so hosts can render terminal cards differently.
  final bool isDone;

  /// Optional trailing widget in the column header.
  final Widget? headerTrailing;
}

/// Result of a drag & drop gesture in a [KanbanBoardView].
@immutable
class KanbanMove<T extends Object> {
  const KanbanMove({
    required this.item,
    required this.fromColumnId,
    required this.toColumnId,
    required this.newIndex,
  });

  final T item;
  final String fromColumnId;
  final String toColumnId;

  /// Index the item should occupy in [toColumnId] *after* the move.
  final int newIndex;

  bool get isCrossColumn => fromColumnId != toColumnId;
}

/// Visual knobs, so hosts can restyle the board without forking it.
@immutable
class KanbanStyle {
  const KanbanStyle({
    this.columnWidth = 280,
    this.columnSpacing = 12,
    this.padding = const EdgeInsets.all(12),
    this.cardRadius = 14,
    this.columnRadius = 18,
    this.autoScrollEdge = 64,
    this.autoScrollSpeed = 18,
  });

  final double columnWidth;
  final double columnSpacing;
  final EdgeInsets padding;
  final double cardRadius;
  final double columnRadius;

  /// Distance from the horizontal viewport edge that triggers auto-scroll.
  final double autoScrollEdge;

  /// Pixels scrolled per tick while auto-scrolling.
  final double autoScrollSpeed;
}

/// A horizontally scrolling kanban board with cross-column drag & drop.
///
/// The widget is data-agnostic: it knows nothing about tasks, persistence or
/// models. The host supplies [columns], an [itemBuilder] and an [onMove]
/// callback; the board owns gestures, drop indicators and edge auto-scroll.
///
/// ```dart
/// KanbanBoardView<Task>(
///   columns: [
///     KanbanColumn(id: 'todo', title: 'To do', items: todoItems),
///   ],
///   itemIdOf: (task) => '${task.id}',
///   itemBuilder: (context, task, isDragging) => TaskCard(task: task),
///   onMove: (move) => dao.moveTask(...),
/// );
/// ```
///
/// Interaction contract:
/// * long press an item, then drag it onto another column or item;
/// * dropping onto an item inserts *before* that item;
/// * dropping onto empty column space appends;
/// * [onMove] fires only when the resulting position differs.
class KanbanBoardView<T extends Object> extends StatefulWidget {
  const KanbanBoardView({
    super.key,
    required this.columns,
    required this.itemBuilder,
    required this.onMove,
    this.itemIdOf,
    this.onItemTap,
    this.onAddItem,
    this.onColumnMenu,
    this.emptyBuilder,
    this.columnTopBuilder,
    this.dragBuilder,
    this.style = const KanbanStyle(),
    this.scrollController,
  });

  final List<KanbanColumn<T>> columns;

  /// Stable identity for drag bookkeeping. Defaults to `item.toString()`;
  /// pass a real id (database id, uuid, ...) whenever possible.
  final String Function(T item)? itemIdOf;

  /// Builds the card content. [isDragging] is true for the card currently
  /// being dragged away from its column.
  final Widget Function(BuildContext context, T item, bool isDragging)
  itemBuilder;

  /// Called when an item was dropped somewhere that changes its position.
  final ValueChanged<KanbanMove<T>> onMove;

  final ValueChanged<T>? onItemTap;

  /// Renders an "add" button in the column header when non-null.
  final void Function(KanbanColumn<T> column)? onAddItem;

  /// Renders an overflow menu in the column header when non-null.
  final void Function(BuildContext context, KanbanColumn<T> column)?
  onColumnMenu;

  /// Shown by columns without items.
  final WidgetBuilder? emptyBuilder;

  /// Rendered above the column's items, inside the column body. Handy for
  /// inline "add card" fields.
  final Widget? Function(BuildContext context, KanbanColumn<T> column)?
  columnTopBuilder;

  /// Custom drag feedback. Defaults to the built card.
  final Widget Function(BuildContext context, T item)? dragBuilder;

  final KanbanStyle style;
  final ScrollController? scrollController;

  @override
  State<KanbanBoardView<T>> createState() => _KanbanBoardViewState<T>();
}

class _KanbanBoardViewState<T extends Object>
    extends State<KanbanBoardView<T>> {
  late final ScrollController _controller =
      widget.scrollController ?? ScrollController();
  final GlobalKey _viewportKey = GlobalKey();

  Timer? _autoScrollTimer;
  Offset? _pointerPosition;
  String? _draggingId;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    if (widget.scrollController == null) _controller.dispose();
    super.dispose();
  }

  String _idOf(T item) => widget.itemIdOf?.call(item) ?? item.toString();

  String? _columnIdOf(T item) {
    final id = _idOf(item);
    for (final column in widget.columns) {
      if (column.items.any((candidate) => _idOf(candidate) == id)) {
        return column.id;
      }
    }
    return null;
  }

  void _onDragStarted(T item) {
    setState(() => _draggingId = _idOf(item));
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) => _tickAutoScroll(),
    );
  }

  void _onDragEnded() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _pointerPosition = null;
    if (mounted) setState(() => _draggingId = null);
  }

  void _tickAutoScroll() {
    final position = _pointerPosition;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || position == null || box == null || !_controller.hasClients) {
      return;
    }

    final local = box.globalToLocal(position);
    final edge = widget.style.autoScrollEdge;
    var delta = 0.0;
    if (local.dx < edge) {
      delta = -widget.style.autoScrollSpeed * (1 - local.dx / edge);
    } else if (local.dx > box.size.width - edge) {
      delta =
          widget.style.autoScrollSpeed *
          (1 - (box.size.width - local.dx) / edge);
    }
    if (delta == 0) return;

    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    if (target != _controller.offset) _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    return Listener(
      onPointerMove: (event) => _pointerPosition = event.position,
      child: SingleChildScrollView(
        key: _viewportKey,
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: style.padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, column) in widget.columns.indexed) ...[
              if (index > 0) SizedBox(width: style.columnSpacing),
              SizedBox(
                width: style.columnWidth,
                child: _KanbanColumnView<T>(
                  column: column,
                  style: style,
                  draggingId: _draggingId,
                  idOf: _idOf,
                  columnIdOf: _columnIdOf,
                  onItemTap: widget.onItemTap,
                  onAddItem: widget.onAddItem,
                  onColumnMenu: widget.onColumnMenu,
                  emptyBuilder: widget.emptyBuilder,
                  columnTopBuilder: widget.columnTopBuilder,
                  dragBuilder: widget.dragBuilder,
                  itemBuilder: widget.itemBuilder,
                  onDragStarted: _onDragStarted,
                  onDragEnded: _onDragEnded,
                  onDrop: _handleDrop,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _handleDrop(T item, String toColumnId, int newIndex) {
    final fromColumnId = _columnIdOf(item);
    if (fromColumnId == null) return;

    if (fromColumnId == toColumnId) {
      final source = widget.columns.firstWhere((c) => c.id == fromColumnId);
      final currentIndex = source.items.indexWhere(
        (candidate) => _idOf(candidate) == _idOf(item),
      );
      if (currentIndex == newIndex) return;
    }

    widget.onMove(
      KanbanMove(
        item: item,
        fromColumnId: fromColumnId,
        toColumnId: toColumnId,
        newIndex: newIndex,
      ),
    );
  }
}

class _KanbanColumnView<T extends Object> extends StatelessWidget {
  const _KanbanColumnView({
    required this.column,
    required this.style,
    required this.draggingId,
    required this.idOf,
    required this.columnIdOf,
    required this.itemBuilder,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onDrop,
    this.onItemTap,
    this.onAddItem,
    this.onColumnMenu,
    this.emptyBuilder,
    this.columnTopBuilder,
    this.dragBuilder,
  });

  final KanbanColumn<T> column;
  final KanbanStyle style;
  final String? draggingId;
  final String Function(T item) idOf;
  final String? Function(T item) columnIdOf;
  final Widget Function(BuildContext, T, bool) itemBuilder;
  final Widget Function(BuildContext, T)? dragBuilder;
  final void Function(T item) onDragStarted;
  final VoidCallback onDragEnded;
  final void Function(T item, String toColumnId, int newIndex) onDrop;
  final ValueChanged<T>? onItemTap;
  final void Function(KanbanColumn<T>)? onAddItem;
  final void Function(BuildContext, KanbanColumn<T>)? onColumnMenu;
  final WidgetBuilder? emptyBuilder;
  final Widget? Function(BuildContext, KanbanColumn<T>)? columnTopBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = column.accent ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(style.columnRadius),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, accent),
          ?columnTopBuilder?.call(context, column),
          Expanded(
            child: column.items.isEmpty
                ? _emptyDropZone(context, accent)
                : _list(context, accent),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 2),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              column.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (column.headerTrailing != null) column.headerTrailing!,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              context.l10n.kanbanTaskCount(column.items.length),
              style: theme.textTheme.labelSmall,
            ),
          ),
          if (onAddItem != null)
            IconButton(
              tooltip: context.l10n.kanbanAddTask,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => onAddItem!(column),
              icon: const Icon(Icons.add),
            ),
          if (onColumnMenu != null)
            IconButton(
              tooltip: context.l10n.kanbanColumnOptions,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => onColumnMenu!(context, column),
              icon: const Icon(Icons.more_horiz),
            ),
        ],
      ),
    );
  }

  Widget _emptyDropZone(BuildContext context, Color accent) {
    return DragTarget<T>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => onDrop(details.data, column.id, 0),
      builder: (context, candidates, _) {
        final highlight = candidates.isNotEmpty;
        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            height: 132,
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: highlight ? accent.withValues(alpha: .08) : null,
              border: Border.all(
                color: highlight
                    ? accent
                    : Theme.of(context).colorScheme.outlineVariant,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(style.cardRadius),
            ),
            child: Center(
              child:
                  emptyBuilder?.call(context) ??
                  Text(
                    context.l10n.kanbanDropHere,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            ),
          ),
        );
      },
    );
  }

  Widget _list(BuildContext context, Color accent) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      itemCount: column.items.length + 1,
      itemBuilder: (context, index) {
        if (index == column.items.length) {
          return DragTarget<T>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) =>
                onDrop(details.data, column.id, column.items.length),
            builder: (context, candidates, _) => AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              height: candidates.isNotEmpty ? 48 : 24,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: candidates.isNotEmpty
                    ? accent.withValues(alpha: .1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: candidates.isNotEmpty
                    ? Border.all(color: accent)
                    : null,
              ),
              child: candidates.isNotEmpty
                  ? Center(
                      child: Icon(
                        Icons.arrow_downward,
                        size: 16,
                        color: accent,
                      ),
                    )
                  : null,
            ),
          );
        }

        final item = column.items[index];
        final id = idOf(item);
        return _DraggableCard<T>(
          key: ValueKey(id),
          item: item,
          columnId: column.id,
          index: index,
          isPlaceholder: id == draggingId,
          style: style,
          card: itemBuilder(context, item, id == draggingId),
          dragFeedback: dragBuilder?.call(context, item),
          onTap: onItemTap,
          onDragStarted: onDragStarted,
          onDragEnded: onDragEnded,
          onDropAt: (dragged, fromColumnId) {
            var targetIndex = index;
            if (fromColumnId == column.id) {
              final draggedIndex = column.items.indexWhere(
                (candidate) => idOf(candidate) == idOf(dragged),
              );
              if (draggedIndex != -1 && draggedIndex < index) targetIndex -= 1;
            }
            onDrop(dragged, column.id, targetIndex);
          },
        );
      },
    );
  }
}

class _DraggableCard<T extends Object> extends StatelessWidget {
  const _DraggableCard({
    super.key,
    required this.item,
    required this.columnId,
    required this.index,
    required this.isPlaceholder,
    required this.style,
    required this.card,
    required this.onTap,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onDropAt,
    this.dragFeedback,
  });

  final T item;
  final String columnId;
  final int index;
  final bool isPlaceholder;
  final KanbanStyle style;
  final Widget card;
  final Widget? dragFeedback;
  final ValueChanged<T>? onTap;
  final void Function(T item) onDragStarted;
  final VoidCallback onDragEnded;
  final void Function(T dragged, String fromColumnId) onDropAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<T>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) =>
          onDropAt(details.data, columnId),
      builder: (context, candidates, _) {
        final highlight = candidates.isNotEmpty;
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LongPressDraggable<T>(
                data: item,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                hapticFeedbackOnStart: true,
                delay: const Duration(milliseconds: 120),
                onDragStarted: () => onDragStarted(item),
                onDragEnd: (_) => onDragEnded(),
                onDraggableCanceled: (_, _) => onDragEnded(),
                feedback: Material(
                  color: Colors.transparent,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(style.cardRadius),
                  child: Opacity(
                    opacity: .95,
                    child: SizedBox(
                      width: style.columnWidth - 16,
                      child: dragFeedback ?? card,
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: .3, child: card),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap == null ? null : () => onTap!(item),
                  child: card,
                ),
              ),
            ),
            if (highlight)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
