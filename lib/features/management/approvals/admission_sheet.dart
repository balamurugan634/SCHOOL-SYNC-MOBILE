import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/people.dart';
import '../../../core/network/app_exception.dart';
import '../../../data/repositories/staff/people_repository.dart';
import '../../workspace/workspace.dart';
import 'approval_kinds.dart';

/// Move an admission application along (review, waitlist, accept, reject). Two steps like the decision sheet:
/// choose a move, then confirm it. Rejecting needs a reason. [onMove] does the API call; errors stay in the sheet.
/// Returns the status the application was moved to, or null.
Future<String?> showAdmissionSheet(BuildContext context, {required AdmissionApplication app, required bool canEdit, required bool canApprove, required Future<void> Function(String to, String note) onMove}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _AdmissionBody(app: app, moves: admissionMoves(app.status, canEdit: canEdit, canApprove: canApprove), onMove: onMove),
  );
}

/// The facts of an application, shared by the sheet and read-only views.
class AdmissionDetails extends StatelessWidget {
  const AdmissionDetails({super.key, required this.app});
  final AdmissionApplication app;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [Expanded(child: Text(app.name, style: context.text.titleMedium)), DecisionChip(app.status)]),
      const SizedBox(height: Gaps.xs),
      Text(app.applicationNo, style: context.text.bodySmall),
      const SizedBox(height: Gaps.md),
      if (app.gradeAppliedName != null) FactRow('Applying for', app.gradeAppliedName!),
      if (app.dob != null) FactRow('Date of birth', fmtFull(app.dob!)),
      FactRow('Guardian', app.guardianName),
      FactRow('Phone', app.guardianPhone),
      if (app.previousSchool != null) FactRow('Previous school', app.previousSchool!),
      if (app.createdAt != null) FactRow('Applied', fmtFull(app.createdAt!)),
      if (app.notes != null) DetailBlock('Notes', app.notes!),
      if (app.decisionNote != null) DetailBlock('Decision note', app.decisionNote!),
    ],
  );
}

class _AdmissionBody extends ConsumerStatefulWidget {
  const _AdmissionBody({required this.app, required this.moves, required this.onMove});
  final AdmissionApplication app;
  final List<AdmissionMove> moves;
  final Future<void> Function(String to, String note) onMove;

  @override
  ConsumerState<_AdmissionBody> createState() => _AdmissionBodyState();
}

class _AdmissionBodyState extends ConsumerState<_AdmissionBody> {
  final _note = TextEditingController();
  AdmissionMove? _chosen;
  bool _busy = false;
  String? _error;
  String? _noteError;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _choose(AdmissionMove m) {
    if (m.noteRequired && _note.text.trim().length < 3) {
      setState(() => _noteError = 'Add a short reason first, so it is on record.');
      return;
    }
    setState(() {
      _noteError = null;
      _error = null;
      _chosen = m;
    });
  }

  Future<void> _confirm() async {
    final m = _chosen;
    if (m == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onMove(m.to, _note.text.trim());
      if (mounted) Navigator.pop(context, m.to);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
        if (isStaleStateError(e)) _chosen = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final readOnly = ref.watch(readOnlyProvider);
    final chosen = _chosen;
    return Padding(
      padding: EdgeInsets.only(bottom: KeyboardInset.of(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text('Application', style: context.text.titleLarge)),
            const SizedBox(height: Gaps.md),
            AdmissionDetails(app: widget.app),
            if (widget.moves.isNotEmpty) ...[
              const SizedBox(height: Gaps.sm),
              TextField(
                controller: _note,
                enabled: !_busy && chosen == null,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Note (required to reject)', errorText: _noteError),
              ),
            ] else
              Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: Text(widget.app.status == 'enrolled' ? 'This student has been enrolled.' : 'You can view this application. Your role cannot change its status.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary))),
            if (readOnly) ...[const SizedBox(height: Gaps.sm), const InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, message: 'Your school is in view-only mode, so changes are switched off until the subscription is renewed.')],
            if (_error != null) ...[const SizedBox(height: Gaps.sm), InfoBanner(tone: BannerTone.danger, message: _error!)],
            const SizedBox(height: Gaps.lg),
            if (chosen == null)
              for (final m in widget.moves)
                Padding(
                  padding: const EdgeInsets.only(bottom: Gaps.sm),
                  child: m.destructive
                      ? OutlinedButton(onPressed: readOnly ? null : () => _choose(m), style: OutlinedButton.styleFrom(foregroundColor: t.danger, side: BorderSide(color: t.danger.withValues(alpha: .5))), child: Text(m.label))
                      : PrimaryButton(label: m.label, onPressed: readOnly ? null : () => _choose(m)),
                )
            else ...[
              Semantics(liveRegion: true, child: Text(chosen.consequence, style: context.text.bodyMedium?.copyWith(color: t.textSecondary))),
              const SizedBox(height: Gaps.md),
              Row(
                children: [
                  Expanded(child: SecondaryButton(label: 'Back', onPressed: _busy ? null : () => setState(() => _chosen = null))),
                  const SizedBox(width: Gaps.md),
                  Expanded(child: PrimaryButton(label: 'Confirm ${chosen.label.toLowerCase()}', loading: _busy, onPressed: _confirm)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the admission sheet and performs the status change through the people repository.
/// [onChanged] runs after a successful move and also when a conflict shows the list is stale (refresh the lists there).
Future<void> openAdmission(BuildContext context, WidgetRef ref, AdmissionApplication a, {required VoidCallback onChanged}) async {
  final me = ref.read(staffMeProvider);
  if (me == null) return;
  final to = await showAdmissionSheet(
    context,
    app: a,
    canEdit: me.can('admissions:edit'),
    canApprove: me.can('admissions:approve'),
    onMove: (to, note) async {
      try {
        await ref.read(peopleRepositoryProvider).setAdmissionStatus(a.id, to, note: note);
      } catch (e) {
        if (isStaleStateError(e) || AppException.from(e).code == 'INVALID_TRANSITION') onChanged();
        rethrow;
      }
    },
  );
  if (to == null) return;
  onChanged();
  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Application moved to ${to.replaceAll('_', ' ')}.')));
}
