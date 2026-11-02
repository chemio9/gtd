import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../core/quick_parse.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';

/// Inline "add a card" field rendered at the top of a kanban column.
///
/// Enter saves the card and keeps the field open, so several cards can be
/// typed in a row. The typed line gets the same date parsing as the todo
/// quick add (`design review fri 2pm`).
class InlineCardAdd extends ConsumerStatefulWidget {
  const InlineCardAdd({
    super.key,
    required this.boardId,
    required this.columnId,
    required this.onDone,
  });

  final int boardId;
  final int columnId;

  /// Called when the user is finished adding (Esc, ✕ or an empty submit).
  final VoidCallback onDone;

  @override
  ConsumerState<InlineCardAdd> createState() => _InlineCardAddState();
}

class _InlineCardAddState extends ConsumerState<InlineCardAdd> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) {
      widget.onDone();
      return;
    }
    if (_saving) return;

    final parsed = parseQuickAdd(raw);
    if (parsed.title.isEmpty) {
      _controller.clear();
      return;
    }

    setState(() => _saving = true);
    await ref
        .read(taskDaoProvider)
        .createTask(
          title: parsed.title,
          boardId: widget.boardId,
          columnId: widget.columnId,
          dueDate: parsed.dueDate,
        );
    if (!mounted) return;

    setState(() => _saving = false);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final parsed = parseQuickAdd(_controller.text);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            widget.onDone();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.primary),
          ),
          padding: const EdgeInsets.fromLTRB(10, 2, 2, 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: context.l10n.boardNewCard,
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  IconButton(
                    tooltip: context.l10n.boardAddCard,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: _saving ? null : _submit,
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                  IconButton(
                    tooltip: context.l10n.close,
                    visualDensity: VisualDensity.compact,
                    iconSize: 18,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: widget.onDone,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              if (parsed.hasTokens && parsed.dueDate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 11,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          context.l10n.dueLabel(
                            formatDueLabel(parsed.dueDate!),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
}
