import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../core/quick_parse.dart';
import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';

/// Inline "add a task" row, modelled after Microsoft To Do.
///
/// One line in, one task out: pressing Enter saves the task, clears the field
/// and keeps the keyboard/focus alive so a whole list can be typed in a row.
///
/// While typing, recognised tokens (`tomorrow`, `2026-11-03 9:45`, `fri 9am`,
/// `+3d`) are highlighted in the field and the parsed due date is shown in a
/// chip underneath, so the user sees exactly what will be saved.
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
  final _QuickAddController _controller = _QuickAddController();
  final FocusNode _focusNode = FocusNode();

  /// `null` means "use [QuickAddBar.defaultDueDate]".
  DateTime? _dueOverride;
  bool _hasDueOverride = false;
  bool _saving = false;
  late QuickAddResult _parsed = parseQuickAdd('');

  DateTime? get _dueDate =>
      _hasDueOverride ? _dueOverride : widget.defaultDueDate;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
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
    if (widget.defaultDueDate != oldWidget.defaultDueDate) {
      _onTextChanged();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Requests focus and reveals the editable row.
  void focus() {
    if (!widget.expanded) widget.onExpand();
    _focusNode.requestFocus();
  }

  void _onTextChanged() {
    final parsed = parseQuickAdd(_controller.text, fallbackDue: _dueDate);
    _controller.setHighlight([
      for (final (start, end) in parsed.spans)
        TextRange(start: start, end: end),
    ]);
    if (!mounted) {
      _parsed = parsed;
      return;
    }
    setState(() => _parsed = parsed);
  }

  /// Removes the recognised tokens from the field (the chip's "clear" action).
  void _clearRecognisedTokens() {
    var text = _controller.text;
    final spans = [..._parsed.spans]
      ..sort((a, b) => b.$1.compareTo(a.$1));
    for (final (start, end) in spans) {
      if (end <= text.length) text = text.replaceRange(start, end, '');
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _resetDue() {
    if (_parsed.hasTokens) {
      _clearRecognisedTokens();
    } else {
      setState(() {
        _hasDueOverride = true;
        _dueOverride = null;
      });
    }
    _focusNode.requestFocus();
  }

  Future<void> _submit() async {
    final raw = _controller.text;
    if (raw.trim().isEmpty || _saving) return;

    // Pasting a list produces one task per line.
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final parsedLines = [for (final line in lines) parseQuickAdd(line, fallbackDue: _dueDate)]
      ..removeWhere((parsed) => parsed.title.isEmpty);
    if (parsedLines.isEmpty) {
      _controller.clear();
      return;
    }

    setState(() => _saving = true);
    final dao = ref.read(taskDaoProvider);
    final ids = <int>[];
    for (final parsed in parsedLines) {
      ids.add(
        await dao.createTask(
          title: parsed.title,
          boardId: widget.boardId,
          dueDate: parsed.dueDate,
        ),
      );
    }
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
          content: Text(
            ids.length == 1
                ? context.l10n.quickAddAddedOne(parsedLines.single.title)
                : context.l10n.quickAddAddedMany(ids.length),
          ),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: context.l10n.undo,
            onPressed: () async {
              for (final id in ids) {
                await dao.deleteTask(id);
              }
            },
          ),
        ),
      );

    if (parsedLines.length == 1) {
      final task = await dao.taskById(ids.single);
      if (task != null) widget.onTaskAdded?.call(task);
    }
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
    final due = _parsed.dueDate;
    final l10n = context.l10n;

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
                      l10n.quickAddHint,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (due != null)
                    _DueChip(
                      due: due,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
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
                        decoration: InputDecoration(
                          hintText: context.l10n.quickAddHint,
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ),
                  if (!_parsed.hasTokens)
                    _DueChip(
                      due: due,
                      compact: compact,
                      onTap: _openDueMenu,
                      onMenu: _openDueMenu,
                    ),
                  IconButton(
                    tooltip: context.l10n.quickAddAction,
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
                    tooltip: context.l10n.quickAddDone,
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _controller.clear();
                      widget.onCollapse();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (_parsed.hasTokens && due != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 0, 0, 6),
                  child: Row(
                    children: [
                      _ParsedDueBadge(
                        label: context.l10n.dueLabel(
                          formatDueLabel(due),
                        ),
                        onTap: _openDueMenu,
                        onClear: _resetDue,
                      ),
                    ],
                  ),
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
              title: Text(context.l10n.today),
              onTap: () => Navigator.pop(context, 'today'),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(context.l10n.tomorrow),
              onTap: () => Navigator.pop(context, 'tomorrow'),
            ),
            ListTile(
              leading: const Icon(Icons.date_range_outlined),
              title: Text(context.l10n.pickDate),
              onTap: () => Navigator.pop(context, 'pick'),
            ),
            ListTile(
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(context.l10n.noDate),
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

/// Text field content where the recognised date/time tokens are highlighted.
class _QuickAddController extends TextEditingController {
  List<TextRange> _highlight = const [];

  void setHighlight(List<TextRange> ranges) {
    if (_sameRanges(ranges, _highlight)) return;
    _highlight = ranges;
    notifyListeners();
  }

  static bool _sameRanges(List<TextRange> a, List<TextRange> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].end != b[i].end) return false;
    }
    return true;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_highlight.isEmpty || text.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final ranges = [..._highlight]
      ..removeWhere((r) => r.start >= text.length)
      ..sort((a, b) => a.start.compareTo(b.start));

    final children = <InlineSpan>[];
    var cursor = 0;
    for (final range in ranges) {
      final start = range.start.clamp(cursor, text.length);
      final end = range.end.clamp(start, text.length);
      if (end <= start) continue;
      if (start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, start)));
      }
      children.add(
        TextSpan(
          text: text.substring(start, end),
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            backgroundColor: scheme.primaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
      cursor = end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }

    return TextSpan(style: style, children: children);
  }
}

/// Chip under the input that confirms the recognised due date.
class _ParsedDueBadge extends StatelessWidget {
  const _ParsedDueBadge({
    required this.label,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, right: 2, top: 2, bottom: 2),
          child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
            Icon(
              Icons.auto_awesome,
              size: 13,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
          IconButton(
            tooltip: context.l10n.quickAddClearParsed,
            visualDensity: VisualDensity.compact,
            iconSize: 14,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: onClear,
            icon: const Icon(Icons.close),
            color: scheme.onSecondaryContainer,
          ),
            ],
          ),
        ),
      ),
    );
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
    final background = due == null
        ? scheme.surfaceContainerHighest
        : scheme.secondaryContainer;
    final foreground = due == null
        ? scheme.onSurfaceVariant
        : scheme.onSecondaryContainer;

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
            color: background,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                due == null ? Icons.event_busy_outlined : Icons.event_outlined,
                size: 14,
                color: foreground,
              ),
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: foreground,
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
