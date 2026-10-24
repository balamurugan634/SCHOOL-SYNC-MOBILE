import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import 'error_copy.dart';
import 'staff_context.dart';

/// The approval flow used for leave, corrections, mark sheets, concessions, refunds, expenses and admissions.
///
/// A bottom sheet with the request's details, a note field, and two steps: choose a decision, then confirm it
/// (the confirm button names the object and the consequence). Reject requires a note when [noteRequiredOnReject].
/// [onDecide] performs the API call; an exception is shown inside the sheet and the sheet stays open.
/// Returns `true` when a decision was saved.
Future<bool> showDecisionSheet(
  BuildContext context, {
  required String title,
  required Widget details,
  required Future<void> Function(bool approve, String note) onDecide,
  String approveLabel = 'Approve',
  String rejectLabel = 'Reject',
  String approveConsequence = 'The requester will be told it was approved.',
  String rejectConsequence = 'The requester will be told it was rejected, with your note.',
  bool canApprove = true,
  bool canReject = true,
  bool noteRequiredOnReject = true,
  bool noteRequiredOnApprove = false,
  String noteLabel = 'Note (optional)',
}) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DecisionBody(
      title: title,
      details: details,
      onDecide: onDecide,
      approveLabel: approveLabel,
      rejectLabel: rejectLabel,
      approveConsequence: approveConsequence,
      rejectConsequence: rejectConsequence,
      canApprove: canApprove,
      canReject: canReject,
      noteRequiredOnReject: noteRequiredOnReject,
      noteRequiredOnApprove: noteRequiredOnApprove,
      noteLabel: noteLabel,
    ),
  );
  return res ?? false;
}

class _DecisionBody extends ConsumerStatefulWidget {
  const _DecisionBody({
    required this.title,
    required this.details,
    required this.onDecide,
    required this.approveLabel,
    required this.rejectLabel,
    required this.approveConsequence,
    required this.rejectConsequence,
    required this.canApprove,
    required this.canReject,
    required this.noteRequiredOnReject,
    required this.noteRequiredOnApprove,
    required this.noteLabel,
  });

  final String title;
  final Widget details;
  final Future<void> Function(bool approve, String note) onDecide;
  final String approveLabel;
  final String rejectLabel;
  final String approveConsequence;
  final String rejectConsequence;
  final bool canApprove;
  final bool canReject;
  final bool noteRequiredOnReject;
  final bool noteRequiredOnApprove;
  final String noteLabel;

  @override
  ConsumerState<_DecisionBody> createState() => _DecisionBodyState();
}

class _DecisionBodyState extends ConsumerState<_DecisionBody> {
  final _note = TextEditingController();

  /// null = choosing; true / false = confirming that decision.
  bool? _pending;
  bool _busy = false;
  String? _error;
  String? _noteError;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _choose(bool approve) {
    final text = _note.text.trim();
    final required = approve ? widget.noteRequiredOnApprove : widget.noteRequiredOnReject;
    if (required && text.length < 3) {
      setState(() => _noteError = approve ? 'Add a short note before approving.' : 'Add a short note saying why, so the requester understands.');
      return;
    }
    setState(() {
      _noteError = null;
      _error = null;
      _pending = approve;
    });
  }

  Future<void> _confirm() async {
    final approve = _pending;
    if (approve == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onDecide(approve, _note.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
        if (isStaleStateError(e)) _pending = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final readOnly = ref.watch(readOnlyProvider);
    final confirming = _pending != null;
    final approving = _pending ?? true;
    return Padding(
      padding: EdgeInsets.only(bottom: KeyboardInset.of(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(widget.title, style: context.text.titleLarge)),
            const SizedBox(height: Gaps.md),
            widget.details,
            const SizedBox(height: Gaps.lg),
            TextField(
              controller: _note,
              enabled: !_busy && !confirming,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: widget.noteLabel, errorText: _noteError),
            ),
            if (readOnly) ...[
              const SizedBox(height: Gaps.sm),
              const InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, message: 'Your school is in view-only mode, so decisions are switched off until the subscription is renewed.'),
            ],
            if (_error != null) ...[const SizedBox(height: Gaps.sm), InfoBanner(tone: BannerTone.danger, message: _error!)],
            const SizedBox(height: Gaps.lg),
            if (!confirming)
              Row(
                children: [
                  if (widget.canReject)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: readOnly ? null : () => _choose(false),
                        style: OutlinedButton.styleFrom(foregroundColor: t.danger, side: BorderSide(color: t.danger.withValues(alpha: .5))),
                        child: Text(widget.rejectLabel),
                      ),
                    ),
                  if (widget.canReject && widget.canApprove) const SizedBox(width: Gaps.md),
                  if (widget.canApprove) Expanded(child: PrimaryButton(label: widget.approveLabel, onPressed: readOnly ? null : () => _choose(true))),
                ],
              )
            else ...[
              Semantics(
                liveRegion: true,
                child: Text(approving ? widget.approveConsequence : widget.rejectConsequence, style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
              ),
              const SizedBox(height: Gaps.md),
              Row(
                children: [
                  Expanded(child: SecondaryButton(label: 'Back', onPressed: _busy ? null : () => setState(() => _pending = null))),
                  const SizedBox(width: Gaps.md),
                  Expanded(child: PrimaryButton(label: 'Confirm ${(approving ? widget.approveLabel : widget.rejectLabel).toLowerCase()}', loading: _busy, onPressed: _confirm)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Label above a block of text inside a detail sheet.
class DetailBlock extends StatelessWidget {
  const DetailBlock(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Gaps.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelSmall?.copyWith(color: context.tokens.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: context.text.bodyMedium),
      ],
    ),
  );
}
