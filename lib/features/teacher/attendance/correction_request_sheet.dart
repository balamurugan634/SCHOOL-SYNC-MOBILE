import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/attendance.dart';
import '../../../data/repositories/staff/roll_call_repository.dart';
import '../../workspace/workspace.dart';
import 'attendance_providers.dart';

/// After the edit window has closed: ask for one saved attendance record to be changed.
/// The class teacher or the office decides (see CorrectionsScreen). Returns true when the request was sent.
Future<bool> showCorrectionRequestSheet(BuildContext context, {required String recordId, required String studentName, required DateTime date, required AttendanceStatus? current}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => CorrectionRequestSheet(recordId: recordId, studentName: studentName, date: date, current: current),
  );
  return res ?? false;
}

class CorrectionRequestSheet extends ConsumerStatefulWidget {
  const CorrectionRequestSheet({super.key, required this.recordId, required this.studentName, required this.date, required this.current});
  final String recordId;
  final String studentName;
  final DateTime date;
  final AttendanceStatus? current;

  @override
  ConsumerState<CorrectionRequestSheet> createState() => _CorrectionRequestSheetState();
}

class _CorrectionRequestSheetState extends ConsumerState<CorrectionRequestSheet> {
  final _reason = TextEditingController();
  AttendanceStatus? _to;
  bool _busy = false;
  String? _error;
  String? _reasonError;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason.text.trim();
    if (_to == null) {
      setState(() => _error = 'Choose the status it should be.');
      return;
    }
    if (reason.length < 3) {
      setState(() => _reasonError = 'Say why, in at least a few words.');
      return;
    }
    if (ref.read(readOnlyProvider)) {
      setState(() => _error = 'Your school is in view-only mode, so requests are switched off until the subscription is renewed.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _reasonError = null;
    });
    try {
      await ref.read(rollCallRepositoryProvider).requestCorrection(widget.recordId, to: _to!, reason: reason);
      ref.invalidate(correctionsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = friendlyError(e);
        });
      }
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
            Semantics(header: true, child: Text('Request a correction', style: context.text.titleLarge)),
            const SizedBox(height: 2),
            Text('${widget.studentName} · ${fmtDay(widget.date)}', style: context.text.bodySmall),
            const SizedBox(height: Gaps.md),
            Row(children: [Text('Saved as', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)), const SizedBox(width: Gaps.sm), AttendanceChip(widget.current)]),
            const SizedBox(height: Gaps.md),
            Text('It should be', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Gaps.sm),
            Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.sm,
              children: [
                for (final s in AttendanceStatus.values)
                  if (s != widget.current)
                    ChoiceChip(
                      selected: _to == s,
                      onSelected: _busy ? null : (_) => setState(() => _to = s),
                      avatar: Icon(attendanceIcon(s), size: 18),
                      label: Text(s.label),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      showCheckmark: false,
                    ),
              ],
            ),
            const SizedBox(height: Gaps.lg),
            TextField(
              controller: _reason,
              enabled: !_busy,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Reason', hintText: 'Why should this change?', errorText: _reasonError),
            ),
            if (readOnly) ...[const SizedBox(height: Gaps.sm), const InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, message: 'Your school is in view-only mode, so requests are switched off until the subscription is renewed.')],
            if (_error != null) ...[const SizedBox(height: Gaps.sm), InfoBanner(tone: BannerTone.danger, message: _error!)],
            const SizedBox(height: Gaps.lg),
            PrimaryButton(label: 'Send request', loading: _busy, onPressed: readOnly ? null : _send),
          ],
        ),
      ),
    );
  }
}
