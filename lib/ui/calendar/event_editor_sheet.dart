import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_x.dart';
import '../../core/recurrence.dart';
import '../../data/database.dart';
import '../../providers.dart';

Future<bool?> showEventEditor(
  BuildContext context, {
  Event? event,
  DateTime? initialDay,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EventEditorSheet(event: event, initialDay: initialDay),
  );
}

class EventEditorSheet extends ConsumerStatefulWidget {
  const EventEditorSheet({super.key, this.event, this.initialDay});

  final Event? event;
  final DateTime? initialDay;

  @override
  ConsumerState<EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends ConsumerState<EventEditorSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.event?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.event?.notes ?? '',
  );

  late DateTime _start =
      widget.event?.startsAt ??
      combine(widget.initialDay ?? DateTime.now(), hour: 9);
  late DateTime _end =
      widget.event?.endsAt ?? _start.add(const Duration(hours: 1));
  late bool _allDay = widget.event?.allDay ?? false;
  late RecurrenceFrequency _recurrence =
      widget.event?.recurrence ?? RecurrenceFrequency.none;
  late Set<WeekdayCode> _weekdays =
      WeekdayCodeX.parse(widget.event?.byWeekday).toSet();
  late DateTime? _until = widget.event?.recurrenceUntil;

  bool get _isEditing => widget.event != null;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 6),
    );
    if (day == null || !mounted) return;
    setState(() {
      if (isStart) {
        _start = DateTime(
          day.year,
          day.month,
          day.day,
          _allDay ? 0 : _start.hour,
          _allDay ? 0 : _start.minute,
        );
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = DateTime(
          day.year,
          day.month,
          day.day,
          _allDay ? 0 : _end.hour,
          _allDay ? 0 : _end.minute,
        );
        if (_end.isBefore(_start)) _end = _start;
      }
    });
  }

  Future<void> _pickTime({required bool isStart}) async {
    final current = isStart ? _start : _end;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final updated = DateTime(
        current.year,
        current.month,
        current.day,
        time.hour,
        time.minute,
      );
      if (isStart) {
        final duration = _end.difference(_start);
        _start = updated;
        _end = _start.add(duration.isNegative ? const Duration(hours: 1) : duration);
      } else {
        _end = updated.isBefore(_start) ? _start : updated;
      }
    });
  }

  Future<void> _pickUntil() async {
    final day = await showDatePicker(
      context: context,
      initialDate: _until ?? _start.add(const Duration(days: 30)),
      firstDate: _start,
      lastDate: DateTime(_start.year + 6),
    );
    if (day == null || !mounted) return;
    setState(() => _until = dateOnly(day));
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;

    final notes = _notes.text.trim();
    final start = _allDay ? combine(_start) : _start;
    var end = _allDay ? combine(_end) : _end;
    if (!end.isAfter(start)) {
      end = start.add(
        _allDay ? const Duration(days: 1) : const Duration(hours: 1),
      );
    }
    final dao = ref.read(eventDaoProvider);

    if (_isEditing) {
      await dao.updateEvent(
        widget.event!.id,
        eventCompanion(
          title: title,
          notes: notes.isEmpty ? null : notes,
          startsAt: start,
          endsAt: end,
          allDay: _allDay,
          recurrence: _recurrence,
          byWeekday: _recurrence == RecurrenceFrequency.weekly
              ? _weekdays
              : const [],
          recurrenceUntil: _recurrence == RecurrenceFrequency.none
              ? null
              : _until,
          clearRecurrenceUntil:
              _recurrence == RecurrenceFrequency.none || _until == null,
        ),
      );
    } else {
      await dao.createEvent(
        eventCompanion(
          title: title,
          notes: notes.isEmpty ? null : notes,
          startsAt: start,
          endsAt: end,
          allDay: _allDay,
          recurrence: _recurrence,
          byWeekday: _recurrence == RecurrenceFrequency.weekly
              ? _weekdays
              : const [],
          recurrenceUntil: _recurrence == RecurrenceFrequency.none
              ? null
              : _until,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final event = widget.event;
    if (event == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text(
          event.recurrence == RecurrenceFrequency.none
              ? '"${event.title}" will be removed.'
              : '"${event.title}" and all of its repetitions will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(eventDaoProvider).deleteEvent(event.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing ? 'Edit event' : 'New event',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _allDay,
              onChanged: (value) => setState(() {
                _allDay = value;
                if (value) {
                  _start = combine(_start);
                  _end = combine(_end);
                }
              }),
            ),
            _DateTimeRow(
              label: 'Starts',
              value: _start,
              onPickDate: () => _pickDate(isStart: true),
              onPickTime: _allDay ? null : () => _pickTime(isStart: true),
            ),
            const SizedBox(height: 8),
            _DateTimeRow(
              label: 'Ends',
              value: _end,
              onPickDate: () => _pickDate(isStart: false),
              onPickTime: _allDay ? null : () => _pickTime(isStart: false),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _recurrence,
              decoration: const InputDecoration(
                labelText: 'Repeat',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: RecurrenceFrequency.none,
                  child: Text('Does not repeat'),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.daily,
                  child: Text('Every day'),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.weekly,
                  child: Text('Every week'),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.monthly,
                  child: Text('Every month'),
                ),
              ],
              onChanged: (value) => setState(() {
                _recurrence = value ?? RecurrenceFrequency.none;
                if (_recurrence == RecurrenceFrequency.weekly &&
                    _weekdays.isEmpty) {
                  _weekdays = {WeekdayCodeX.fromWeekday(_start.weekday)};
                }
              }),
            ),
            if (_recurrence == RecurrenceFrequency.weekly) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (final code in WeekdayCode.values)
                    FilterChip(
                      label: Text(code.short),
                      selected: _weekdays.contains(code),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _weekdays.add(code);
                        } else {
                          _weekdays.remove(code);
                        }
                      }),
                    ),
                ],
              ),
            ],
            if (_recurrence != RecurrenceFrequency.none) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickUntil,
                      icon: const Icon(Icons.event_repeat),
                      label: Text(
                        _until == null
                            ? 'No end date'
                            : 'Until ${formatFullDate(_until!)}',
                      ),
                    ),
                  ),
                  if (_until != null)
                    IconButton(
                      tooltip: 'Clear end date',
                      onPressed: () => setState(() => _until = null),
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (_isEditing)
                  TextButton.icon(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: Text(_isEditing ? 'Save' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onPickDate,
    this.onPickTime,
  });

  final String label;
  final DateTime value;
  final VoidCallback onPickDate;
  final VoidCallback? onPickTime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: Theme.of(context).textTheme.labelLarge),
        ),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickDate,
            icon: const Icon(Icons.calendar_today_outlined, size: 16),
            label: Text(formatFullDate(value)),
          ),
        ),
        if (onPickTime != null) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onPickTime,
            child: Text(formatTime(value)),
          ),
        ],
      ],
    );
  }
}
