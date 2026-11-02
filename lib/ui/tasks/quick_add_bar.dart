import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../core/quick_parse.dart';
import '../../data/database.dart';
import '../../providers.dart';

/// Inline "add a task" row, modelled after Microsoft To Do.
///
/// One line in, one task out: pressing Enter saves the task, clears the field
/// and keeps the keyboard/focus alive so a whole list can be typed in a row.
/// The text is parsed for dates (`tomorrow`, `fri`, `at 9pm`, `+3d`).
class QuickAddBar extends ConsumerStatefulWidget {
  const QuickAddBar({
    super.key,
    required this.boardId,
    required this.expanded,
    required this.defaultDueDate,
    required this.onExpand,
    required this.onCollapse,
    this.onTaskAdded,
    this.autofocus = false,
  });

  final int boardId;

  /// Controlled by the host so a FAB can reveal the field.
  final bool expanded;

  /// Due date applied when the typed text has no date token.
  final DateTime? defaultDueDate;

  final VoidCallback onExpand;
  final VoidCallback onCollapse;

  /// Called after a task was created (e.g. to switch the active filter).
  final void Function(Task task)? onTaskAdded;

  final bool autofocus;

  @override
  ConsumerState<QuickAddBar> createState() => QuickAddBarState();
}

class QuickAddBarState extends ConsumerState<QuickAddBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// `null` means "use [QuickAddBar.defaultDueDate]".
  DateTime? _dueOverride;
  bool _hasDueOverride = false;
  bool _saving = false;

  DateTime? get _dueDate =>
      _hasDueOverride ? _dueOverride : widget.defaultDueDate;

  @override
  void initState() {
    super.initState();
    if (widget.expanded && widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => focus());
    }
  }

  @override
  void didUpdateWidget(QuickAddBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded && !oldWidget.expanded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => focus());
    }
    if (!widget.expanded && oldWidget.expanded) {
      _controller.clear();
      _focusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Requests focus and reveals the editable row.
  void focus() {
    if (!widget.expanded) widget.onExpand();
    _focusNode.requestFocus();
  }

  Future<void> _submit() async {
    final raw = _controller.text;
    if (raw.trim().isEmpty || _saving) return;

    final parsed = parseQuickAdd(raw, fallbackDue: _dueDate);
    if (parsed.title.isEmpty) {
      _controller.clear();
      return;
    }

    setState(() => _saving = true);
    final dao = ref.read(taskDaoProvider);
    final id = await dao.createTask(
      title: parsed.title,
      boardId: widget.boardId,
      dueDate: parsed.dueDate,
    );
    final task = await dao.taskById(id);
    if (!mounted) return;

    setState(() {
      _saving = false;
      _hasDueOverride = false;
      _dueOverride = null;
    });
    _controller.clear();
    _focusNode.requestFocus();

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Added "${parsed.title}"'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => dao.deleteTask(id),
          ),
        ),
      );

    if (task != null) widget.onTaskAdded?.call(task);
  }

  Future<void> _pickDueDate() async {
    final current = _dueDate ?? DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (day == null || !mounted) return;
    setState(() {
      _hasDueOverride = true;
      _dueOverride = hasTimeOfDay(current)
          ? DateTime(day.year, day.month, day.day, current.hour, current.minute)
          : dateOnly(day);
    });
    _focusNode.requestFocus();
  }

  void _setDue(DateTime? value) {
    setState(() {
      _hasDueOverride = true;
      _dueOverride = value;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 420;

    if (!widget.expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => focus(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.add, size: 20, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Add a task',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    _DueChip(
                      due: _dueDate!,
                      compact: compact,
                      onTap: () => focus(),
                      onMenu: _openDueMenu,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
          child: Row(
            children: [
              Icon(Icons.add, size: 20, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Focus(
                  onKeyEvent: (node, event) {
                    if (event is KeyDownEvent &&
                        event.logicalKey == LogicalKeyboardKey.escape) {
                      _controller.clear();
                      widget.onCollapse();
                      return KeyEventResult.handled;
                    }
                    return KeyEventResult.ignored;
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Add a task',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ),
              _DueChip(
                due: _dueDate,
                compact: compact,
                onTap: _openDueMenu,
                onMenu: _openDueMenu,
              ),
              IconButton(
                tooltip: 'Add task',
                visualDensity: VisualDensity.compact,
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: 'Done adding',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _controller.clear();
                  widget.onCollapse();
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDueMenu() async {
    final today = dateOnly(DateTime.now());
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today_outlined),
              title: const Text('Today'),
              onTap: () => Navigator.pop(context, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Tomorrow'),
              onTap: () => Navigator.pop(context, 'tomorrow'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: const Text('Pick a date…'),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: const Text('No date'),
              onTap: () => Navigator.pop(context, 'none'),
            ),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'today':
        _setDue(today);
      case 'tomorrow':
        _setDue(today.add(const Duration(days: 1)));
      case 'pick':
        await _pickDueDate();
      case 'none':
        _setDue(null);
    }
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({
    required this.due,
    required this.onTap,
    required this.onMenu,
    this.compact = false,
  });

  final DateTime? due;
  final VoidCallback onTap;
  final VoidCallback onMenu;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = due == null ? 'No date' : friendlyDay(due!);

    return Tooltip(
      message: 'Set due date',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        onLongPress: onMenu,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: due == null
                ? scheme.surfaceContainerHighest
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                due == null ? Icons.event_busy_outlined : Icons.event_outlined,
                size: 14,
                color: due == null
                    ? scheme.onSurfaceVariant
                    : scheme.onPrimaryContainer,
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: due == null
                        ? scheme.onSurfaceVariant
                        : scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
