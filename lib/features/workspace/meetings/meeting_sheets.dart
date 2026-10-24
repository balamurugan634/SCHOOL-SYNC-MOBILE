import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/comms.dart';
import '../../../data/repositories/staff/comms_repository.dart';
import '../workspace.dart';
import 'meeting_logic.dart';

/// Opens the bottom sheet for one meeting action (`confirm`, `decline`, `reschedule`, `complete`, `cancel`).
/// Returns true when the action was saved.
Future<bool> showMeetingActionSheet(BuildContext context, StaffMeeting m, String action) async {
  final res = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _MeetingActionSheet(meeting: m, action: action));
  return res ?? false;
}

class _MeetingActionSheet extends ConsumerStatefulWidget {
  const _MeetingActionSheet({required this.meeting, required this.action});
  final StaffMeeting meeting;
  final String action;

  @override
  ConsumerState<_MeetingActionSheet> createState() => _MeetingActionSheetState();
}

class _MeetingActionSheetState extends ConsumerState<_MeetingActionSheet> {
  final _text = TextEditingController();
  final _duration = TextEditingController();
  final _place = TextEditingController();
  DateTime? _at;
  String _mode = 'in_person';
  bool _busy = false;
  String? _error;
  Map<String, String> _errors = const {};

  bool get _slot => widget.action == 'confirm' || widget.action == 'reschedule';

  @override
  void initState() {
    super.initState();
    final m = widget.meeting;
    _duration.text = '${m.durationMin}';
    _mode = m.mode;
    _place.text = m.locationOrLink ?? '';
    final seed = widget.action == 'reschedule' ? m.scheduledAt : m.proposedAt;
    if (seed != null && seed.isAfter(DateTime.now())) _at = seed;
  }

  @override
  void dispose() {
    _text.dispose();
    _duration.dispose();
    _place.dispose();
    super.dispose();
  }

  String get _title => switch (widget.action) {
    'confirm' => 'Confirm the meeting',
    'reschedule' => 'Move the meeting',
    'decline' => 'Decline the request',
    'complete' => 'Close the meeting',
    _ => 'Cancel the meeting',
  };

  String get _cta => switch (widget.action) {
    'confirm' => 'Confirm meeting',
    'reschedule' => 'Save new time',
    'decline' => 'Decline request',
    'complete' => 'Mark as done',
    _ => 'Cancel meeting',
  };

  String get _consequence => switch (widget.action) {
    'confirm' => 'The parent is told the time and place straight away.',
    'reschedule' => 'The parent is told about the new time.',
    'decline' => 'The parent is told the request was declined, with your reason.',
    'complete' => 'The meeting is closed with your notes.',
    _ => 'The other side is told the meeting was cancelled.',
  };

  Future<void> _pickTime() async {
    final at = await pickDayTime(context, initial: _at ?? widget.meeting.proposedAt ?? DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), help: 'Meeting time');
    if (at != null) setState(() => _at = at);
  }

  Future<void> _submit() async {
    final a = widget.action;
    Map<String, String> errors = {};
    if (_slot) {
      errors = validateMeetingSlot(at: _at, durationText: _duration.text, mode: _mode, place: _place.text);
    } else {
      final msg = switch (a) {
        'decline' => validateMeetingText(_text.text, required: true, message: 'Say why, so the parent understands.'),
        'complete' => validateMeetingText(_text.text, required: true, max: 3000, message: 'Write a line about what was discussed.'),
        _ => validateMeetingText(_text.text, required: false),
      };
      if (msg != null) errors['text'] = msg;
    }
    setState(() {
      _errors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) return;

    setState(() => _busy = true);
    final repo = ref.read(commsRepositoryProvider);
    final id = widget.meeting.id;
    final duration = int.tryParse(_duration.text.trim()) ?? 15;
    final done = await runWrite(
      context,
      ref,
      () => switch (a) {
        'confirm' => repo.confirmMeeting(id, at: _at!, durationMin: duration, mode: _mode, locationOrLink: _place.text),
        'reschedule' => repo.rescheduleMeeting(id, at: _at!, durationMin: duration, mode: _mode, locationOrLink: _place.text),
        'decline' => repo.declineMeeting(id, reason: _text.text),
        'complete' => repo.completeMeeting(id, outcomeNotes: _text.text),
        _ => repo.cancelMeeting(id, reason: _text.text),
      },
      success: switch (a) {
        'confirm' => 'Meeting confirmed.',
        'reschedule' => 'Meeting moved.',
        'decline' => 'Request declined.',
        'complete' => 'Meeting closed.',
        _ => 'Meeting cancelled.',
      },
      onError: (e) {
        if (mounted) setState(() => _error = friendlyError(e));
      },
    );
    if (!mounted) return;
    if (done) {
      Navigator.pop(context, true);
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = widget.meeting;
    final readOnly = ref.watch(readOnlyProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: KeyboardInset.of(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(_title, style: context.text.titleLarge)),
            const SizedBox(height: 4),
            Text('${m.studentName}${m.classLabel.isEmpty ? '' : '  ·  ${m.classLabel}'}', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
            Text(m.topic, style: context.text.bodySmall),
            const SizedBox(height: Gaps.lg),
            if (readOnly) const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, message: 'Your school is in view-only mode, so changes are switched off until the subscription is renewed.')),
            if (_slot) ...[
              Text('When', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
              const SizedBox(height: Gaps.xs),
              Row(
                children: [
                  Expanded(child: Text(_at == null ? 'Not chosen yet' : '${fmtDay(_at!)}, ${fmtTime(_at!)}', style: context.text.bodyLarge)),
                  TextButton.icon(onPressed: _busy ? null : _pickTime, icon: const Icon(Icons.event_outlined, size: 18), label: Text(_at == null ? 'Pick' : 'Change')),
                ],
              ),
              if (_errors['at'] != null) _Err(_errors['at']!),
              const SizedBox(height: Gaps.md),
              TextField(
                controller: _duration,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Length in minutes', helperText: '5 to 180', errorText: _errors['duration']),
              ),
              const SizedBox(height: Gaps.md),
              Wrap(
                spacing: Gaps.sm,
                runSpacing: Gaps.xs,
                children: [for (final o in meetingModes) ChoiceChip(label: Text(o.$2), selected: _mode == o.$1, onSelected: _busy ? null : (_) => setState(() => _mode = o.$1))],
              ),
              const SizedBox(height: Gaps.md),
              TextField(
                controller: _place,
                enabled: !_busy,
                keyboardType: _mode == 'online' ? TextInputType.url : TextInputType.text,
                decoration: InputDecoration(labelText: _mode == 'online' ? 'Meeting link' : (_mode == 'phone' ? 'Phone number or note (optional)' : 'Room (optional)'), errorText: _errors['place']),
              ),
            ] else
              TextField(
                controller: _text,
                enabled: !_busy,
                minLines: 3,
                maxLines: 6,
                maxLength: widget.action == 'complete' ? 3000 : 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: switch (widget.action) { 'decline' => 'Reason', 'complete' => 'What was discussed', _ => 'Reason (optional)' },
                  alignLabelWithHint: true,
                  errorText: _errors['text'],
                ),
              ),
            if (_error != null) ...[const SizedBox(height: Gaps.sm), InfoBanner(tone: BannerTone.danger, message: _error!)],
            const SizedBox(height: Gaps.md),
            Text(_consequence, style: context.text.bodySmall),
            const SizedBox(height: Gaps.lg),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: 'Back', onPressed: _busy ? null : () => Navigator.pop(context, false))),
                const SizedBox(width: Gaps.md),
                Expanded(flex: 2, child: PrimaryButton(label: _cta, loading: _busy, onPressed: readOnly ? null : _submit)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Err extends StatelessWidget {
  const _Err(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(children: [Icon(Icons.error_outline_rounded, size: 16, color: context.tokens.danger), const SizedBox(width: 6), Expanded(child: Text(text, style: context.text.bodySmall?.copyWith(color: context.tokens.danger)))]),
  );
}
