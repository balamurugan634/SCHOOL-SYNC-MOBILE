import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/models/tasks.dart';
import '../../data/repositories/tasks_repository.dart';

/// Bottom sheet to add (or edit) a personal task. Returns true when something was saved.
Future<bool?> showTaskForm(BuildContext context, {TaskFeedItem? existing}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _TaskForm(existing: existing),
);

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm({this.existing});
  final TaskFeedItem? existing;

  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _notes = TextEditingController(text: widget.existing?.subtitle);
  DateTime? _due;
  TaskPriority _priority = TaskPriority.normal;
  bool _remind = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _due = widget.existing?.dueAt;
    _priority = widget.existing?.priority ?? TaskPriority.normal;
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: _due ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 2));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due ?? DateTime(now.year, now.month, now.day, 18)));
    if (!mounted) return;
    setState(() => _due = DateTime(date.year, date.month, date.day, time?.hour ?? 18, time?.minute ?? 0));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the task a title.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repo = ref.read(tasksRepositoryProvider);
      final remindAt = _remind && _due != null ? _due!.subtract(const Duration(hours: 1)) : null;
      if (widget.existing == null) {
        await repo.create(title: _title.text, notes: _notes.text, dueAt: _due, remindAt: remindAt, priority: _priority);
      } else {
        await repo.update(widget.existing!.id, title: _title.text, notes: _notes.text, dueAt: _due, priority: _priority);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = AppException.from(e).displayMessage;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, KeyboardInset.of(context) + Gaps.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? 'Add a task' : 'Edit task', style: context.text.headlineSmall),
            const SizedBox(height: Gaps.lg),
            TextField(controller: _title, autofocus: widget.existing == null, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What needs doing?')),
            const SizedBox(height: Gaps.md),
            TextField(controller: _notes, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Notes (optional)')),
            const SizedBox(height: Gaps.md),
            Row(
              children: [
                Expanded(child: OutlinedButton.icon(onPressed: _pickDue, icon: const Icon(Icons.event_outlined, size: 18), label: Text(_due == null ? 'Set a due date' : '${fmtDay(_due!)}, ${fmtTime(_due!)}'))),
                if (_due != null) IconButton(tooltip: 'Clear due date', onPressed: () => setState(() => _due = null), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            if (_due != null && widget.existing == null)
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Remind me 1 hour before'), value: _remind, onChanged: (v) => setState(() => _remind = v)),
            const SizedBox(height: Gaps.sm),
            Text('Priority', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<TaskPriority>(
                showSelectedIcon: false,
                segments: [for (final p in TaskPriority.values) ButtonSegment(value: p, label: Text(p.label))],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: Gaps.md), InfoBanner(tone: BannerTone.danger, message: _error!)],
            const SizedBox(height: Gaps.lg),
            PrimaryButton(label: widget.existing == null ? 'Add task' : 'Save', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
