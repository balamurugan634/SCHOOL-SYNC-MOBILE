import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/leave.dart' show LeaveType;
import '../../../data/repositories/staff/staff_leave_repository.dart';
import '../workspace.dart';
import 'leave_logic.dart';

/// "Apply for leave" bottom sheet. Returns true when the request was sent.
Future<bool> showApplyLeaveSheet(BuildContext context) async {
  final res = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => const _ApplyLeaveSheet());
  return res ?? false;
}

class _ApplyLeaveSheet extends ConsumerStatefulWidget {
  const _ApplyLeaveSheet();

  @override
  ConsumerState<_ApplyLeaveSheet> createState() => _ApplyLeaveSheetState();
}

class _ApplyLeaveSheetState extends ConsumerState<_ApplyLeaveSheet> {
  final _reason = TextEditingController();
  LeaveType _type = LeaveType.casual;
  DateTime? _from;
  DateTime? _to;
  Map<String, String> _errors = const {};
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickFrom() async {
    final today = DateTime.now();
    final d = await pickDay(context, initial: _from ?? today, firstDate: today.subtract(const Duration(days: maxLeaveBackdateDays)), lastDate: today.add(const Duration(days: 365)), help: 'First day of leave');
    if (d == null) return;
    setState(() {
      _from = d;
      if (_to != null && _to!.isBefore(d)) _to = d;
    });
  }

  Future<void> _pickTo() async {
    final today = DateTime.now();
    final first = _from ?? today.subtract(const Duration(days: maxLeaveBackdateDays));
    final d = await pickDay(context, initial: _to ?? _from ?? today, firstDate: first, lastDate: today.add(const Duration(days: 400)), help: 'Last day of leave');
    if (d != null) setState(() => _to = d);
  }

  Future<void> _submit() async {
    final errors = validateLeaveForm(type: _type, from: _from, to: _to, reason: _reason.text);
    setState(() {
      _errors = errors;
      _error = null;
    });
    if (errors.isNotEmpty) return;
    setState(() => _busy = true);
    final done = await runWrite(
      context,
      ref,
      () => ref.read(staffLeaveRepositoryProvider).applyStaffLeave(type: _type, from: _from!, to: _to!, reason: _reason.text),
      success: 'Your leave request was sent.',
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
    final readOnly = ref.watch(readOnlyProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: KeyboardInset.of(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('Apply for leave', style: context.text.titleLarge)),
            const SizedBox(height: Gaps.md),
            if (readOnly) const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, message: 'Your school is in view-only mode, so changes are switched off until the subscription is renewed.')),
            Text('Kind of leave', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Gaps.xs),
            Wrap(spacing: Gaps.sm, runSpacing: Gaps.xs, children: [for (final l in LeaveType.values) ChoiceChip(label: Text(l.label), selected: _type == l, onSelected: _busy ? null : (_) => setState(() => _type = l))]),
            const SizedBox(height: Gaps.lg),
            _DayField(label: 'From', value: _from, error: _errors['from'], onTap: _busy ? null : _pickFrom),
            const SizedBox(height: Gaps.md),
            _DayField(label: 'To', value: _to, error: _errors['to'], onTap: _busy ? null : _pickTo),
            if (_from != null && _to != null && !_to!.isBefore(_from!)) Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: Text('${plural(calendarDays(_from!, _to!), 'calendar day')}. The school counts only its working days.', style: context.text.bodySmall)),
            const SizedBox(height: Gaps.md),
            TextField(
              controller: _reason,
              enabled: !_busy,
              minLines: 3,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Reason', alignLabelWithHint: true, errorText: _errors['reason']),
            ),
            if (_error != null) ...[const SizedBox(height: Gaps.sm), InfoBanner(tone: BannerTone.danger, message: _error!)],
            const SizedBox(height: Gaps.lg),
            Row(
              children: [
                Expanded(child: SecondaryButton(label: 'Back', onPressed: _busy ? null : () => Navigator.pop(context, false))),
                const SizedBox(width: Gaps.md),
                Expanded(flex: 2, child: PrimaryButton(label: 'Send request', loading: _busy, onPressed: readOnly ? null : _submit)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DayField extends StatelessWidget {
  const _DayField({required this.label, required this.value, required this.error, required this.onTap});
  final String label;
  final DateTime? value;
  final String? error;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$label: ${value == null ? 'not chosen' : fmtFull(value!)}',
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: Radii.field,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, errorText: error, suffixIcon: const Icon(Icons.event_outlined)),
        child: Text(value == null ? 'Pick a date' : fmtDay(value!), style: context.text.bodyLarge?.copyWith(color: value == null ? context.tokens.textTertiary : null)),
      ),
    ),
  );
}
