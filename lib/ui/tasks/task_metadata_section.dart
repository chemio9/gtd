import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../l10n/l10n.dart';
import '../../providers.dart';
import '../common/text_prompt_dialog.dart';

const tagPalette = <int>[
  0xFF4F46E5,
  0xFF0EA5E9,
  0xFF10B981,
  0xFFF59E0B,
  0xFFEF4444,
  0xFF8B5CF6,
  0xFFEC4899,
  0xFF64748B,
];

/// Chip row with the tags selected for a task, plus "add" and remove actions.
class TaskTagsEditor extends ConsumerWidget {
  const TaskTagsEditor({
    super.key,
    required this.selectedTagIds,
    required this.onChanged,
  });

  final Set<int> selectedTagIds;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final selected = tags.where((tag) => selectedTagIds.contains(tag.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.tagsTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in selected)
              InputChip(
                label: Text(tag.name),
                labelStyle: const TextStyle(color: Colors.white),
                backgroundColor: Color(tag.color),
                deleteIconColor: Colors.white,
                onDeleted: () => onChanged({...selectedTagIds}..remove(tag.id)),
              ),
            ActionChip(
              avatar: const Icon(Icons.add, size: 16),
              label: Text(context.l10n.tagAdd),
              onPressed: () => _pickTags(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickTags(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TagPickerSheet(selected: selectedTagIds),
    );
    if (result != null) onChanged(result);
  }
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.selected});

  final Set<int> selected;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late final Set<int> _selected = {...widget.selected};
  String _query = '';

  Future<void> _createTag() async {
    final name = await showTextPrompt(
      context,
      title: context.l10n.tagNew,
      label: context.l10n.tagName,
      confirmLabel: context.l10n.create,
    );
    if (name == null) return;
    final existing = ref.read(tagsProvider).value ?? const <Tag>[];
    final color = tagPalette[existing.length % tagPalette.length];
    final id = await ref.read(tagDaoProvider).create(name, color: color);
    if (!mounted) return;
    setState(() => _selected.add(id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final query = _query.toLowerCase();
    final matches = tags
        .where((tag) => query.isEmpty || tag.name.toLowerCase().contains(query))
        .toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.tagsTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.l10n.search,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: Text(context.l10n.tagNew),
                    onTap: _createTag,
                  ),
                  for (final tag in matches)
                    CheckboxListTile(
                      value: _selected.contains(tag.id),
                      title: Text(tag.name),
                      secondary: CircleAvatar(
                        radius: 8,
                        backgroundColor: Color(tag.color),
                      ),
                      onChanged: (checked) => setState(() {
                        if (checked ?? false) {
                          _selected.add(tag.id);
                        } else {
                          _selected.remove(tag.id);
                        }
                      }),
                    ),
                  if (matches.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(context.l10n.tagNoMatches),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: Text(context.l10n.save),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}

/// Subtask list for a saved task: changes are stored immediately.
class LiveSubtasksEditor extends ConsumerWidget {
  const LiveSubtasksEditor({super.key, required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subtasks =
        ref.watch(subtasksForTaskProvider(taskId)).value ?? const <Subtask>[];
    final done = subtasks.where((s) => s.isDone).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(context.l10n.subtasksTitle, style: theme.textTheme.labelLarge),
            const SizedBox(width: 8),
            if (subtasks.isNotEmpty)
              Text(
                context.l10n.subtaskProgress(done, subtasks.length),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        for (final subtask in subtasks)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Checkbox(
              value: subtask.isDone,
              onChanged: (value) => ref
                  .read(subtaskDaoProvider)
                  .setDone(subtask.id, value ?? false),
            ),
            title: Text(
              subtask.title,
              style: TextStyle(
                decoration: subtask.isDone ? TextDecoration.lineThrough : null,
                color: subtask.isDone
                    ? theme.colorScheme.onSurfaceVariant
                    : null,
              ),
            ),
            trailing: IconButton(
              tooltip: context.l10n.delete,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  ref.read(subtaskDaoProvider).deleteSubtask(subtask.id),
            ),
          ),
        _AddSubtaskField(
          onAdd: (title) =>
              ref.read(subtaskDaoProvider).add(taskId: taskId, title: title),
        ),
      ],
    );
  }
}

/// Subtask editor for a task that is not saved yet.
class PendingSubtasksEditor extends StatefulWidget {
  const PendingSubtasksEditor({
    super.key,
    required this.titles,
    required this.onChanged,
  });

  final List<String> titles;
  final ValueChanged<List<String>> onChanged;

  @override
  State<PendingSubtasksEditor> createState() => _PendingSubtasksEditorState();
}

class _PendingSubtasksEditorState extends State<PendingSubtasksEditor> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.subtasksTitle, style: theme.textTheme.labelLarge),
        for (final (index, title) in widget.titles.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.check_box_outline_blank, size: 20),
            title: Text(title),
            trailing: IconButton(
              tooltip: context.l10n.delete,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  widget.onChanged([...widget.titles]..removeAt(index)),
            ),
          ),
        _AddSubtaskField(
          onAdd: (title) async => widget.onChanged([...widget.titles, title]),
        ),
      ],
    );
  }
}

class _AddSubtaskField extends StatefulWidget {
  const _AddSubtaskField({required this.onAdd});

  final Future<void> Function(String title) onAdd;

  @override
  State<_AddSubtaskField> createState() => _AddSubtaskFieldState();
}

class _AddSubtaskFieldState extends State<_AddSubtaskField> {
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
    final title = _controller.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    await widget.onAdd(title);
    if (!mounted) return;
    setState(() => _saving = false);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.add, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.l10n.subtaskAdd,
                isDense: true,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
          IconButton(
            tooltip: context.l10n.subtaskAdd,
            iconSize: 18,
            onPressed: _saving ? null : _submit,
            icon: const Icon(Icons.arrow_upward),
          ),
        ],
      ),
    );
  }
}
