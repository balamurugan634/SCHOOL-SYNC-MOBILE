import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/finance.dart';
import '../../../data/models/staff/leave.dart';
import '../../../data/models/staff/marks.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../data/repositories/staff/finance_repository.dart';
import '../../../data/repositories/staff/marks_repository.dart';
import '../../../data/repositories/staff/roll_call_repository.dart';
import '../../../data/repositories/staff/staff_leave_repository.dart';
import '../../../router/routes_management.dart' show ApprovalKind;
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import '../home/management_home_providers.dart';
import 'admission_sheet.dart';
import 'approval_kinds.dart';
import 'approvals_providers.dart';

/// One approval queue: filter chips by status, rows with the key facts, a detail sheet with a note and a confirmation.
class ApprovalListScreen extends ConsumerStatefulWidget {
  const ApprovalListScreen({super.key, required this.kind});

  /// One of `ApprovalKind`.
  final String kind;

  @override
  ConsumerState<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends ConsumerState<ApprovalListScreen> {
  int _filter = 0;

  void _refreshAll() {
    ref.invalidate(approvalFeedProvider);
    ref.invalidate(managementDashboardProvider);
  }

  @override
  Widget build(BuildContext context) {
    final spec = approvalSpecFor(widget.kind);
    if (spec == null) {
      return const StaffFrame(title: 'Approvals', body: EmptyState(icon: Icons.search_off_rounded, title: 'That list does not exist', message: 'Open Approvals from Home or More to see what is waiting.'));
    }
    final status = spec.statuses[_filter.clamp(0, spec.statuses.length - 1)].$1;
    final query = (kind: spec.kind, status: status);
    final provider = approvalFeedProvider(query);
    final me = ref.watch(staffMeProvider);
    final canAct = me != null && spec.canAct(me);

    return SecureScope(secure: spec.needsFees || spec.kind == ApprovalKind.marks, child: StaffFrame(
      title: spec.label,
      headerExtra: Padding(
        padding: const EdgeInsets.only(top: Gaps.sm, bottom: Gaps.sm),
        child: FilterChips<int>(options: List.generate(spec.statuses.length, (i) => i), selected: _filter, onSelected: (i) => setState(() => _filter = i), labelOf: (i) => spec.statuses[i].$2),
      ),
      body: FeatureGate(
        label: spec.label,
        anyPermission: [...spec.viewAny, spec.actPermission],
        siteFeature: spec.needsFees ? 'fees' : null,
        child: Column(
          children: [
            if (!canAct) const Padding(padding: EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm), child: InfoBanner(icon: Icons.visibility_outlined, message: 'You can view these, but your role cannot decide them.')),
            Expanded(
              child: AsyncBody<PagedList<Object>>(
                value: ref.watch(provider),
                onRetry: () => ref.invalidate(provider),
                isEmpty: (p) => p.items.isEmpty,
                empty: RefreshScroll(
                  onRefresh: () async => ref.invalidate(provider),
                  children: [EmptyState(icon: spec.icon, title: _filter == 0 ? spec.emptyTitle : 'Nothing ${spec.statuses[_filter].$2.toLowerCase()}', message: _filter == 0 ? spec.emptyMessage : 'Nothing matches this filter.')],
                ),
                data: (p) => RefreshScroll(
                  onRefresh: () async {
                    ref.invalidate(provider);
                    try {
                      await ref.read(provider.future);
                    } catch (_) {}
                  },
                  children: [
                    const ReadOnlyBanner(),
                    RowGroup(children: [for (final item in p.items) _row(context, item, canAct)]),
                    LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  // ── rows ──────────────────────────────────────────────────────────────────

  Widget _row(BuildContext context, Object item, bool canAct) {
    final cur = ref.read(currencyProvider);
    return switch (item) {
      StudentLeaveItem l => ListRow(title: l.studentName, subtitle: '${[if (l.sectionName != null) l.sectionName!, l.leaveType.label].join('  ·  ')}\n${_range(l.fromDate, l.toDate)} (${plural(l.days, 'day')})', trailing: DecisionChip(l.status), onTap: () => _studentLeave(l, canAct)),
      StaffLeaveItem l => ListRow(title: l.staffName, subtitle: '${[if (l.designation != null) l.designation!, l.leaveType.label].join('  ·  ')}\n${_range(l.fromDate, l.toDate)} (${plural(l.days, 'day')})', trailing: DecisionChip(l.status), onTap: () => _staffLeave(l, canAct)),
      CorrectionItem c => ListRow(title: c.studentName, subtitle: '${c.sectionName}  ·  ${fmtDay(c.date)}\n${c.fromStatus?.label ?? '?'} to ${c.toStatus?.label ?? '?'}', trailing: DecisionChip(c.status), onTap: () => _correction(c, canAct)),
      MarkSheet s => ListRow(title: '${s.subjectName}, ${s.sectionTitle}', subtitle: '${s.examName}\n${s.enteredCount} of ${s.studentCount} entered${s.absentCount > 0 ? ', ${s.absentCount} absent' : ''}${s.teacherName != null ? '  ·  ${s.teacherName}' : ''}', trailing: DecisionChip(s.status), onTap: () => _sheet(s, canAct)),
      ConcessionItem c => ListRow(title: c.studentName, subtitle: '${c.name}\n${_concessionValue(c, cur)}', trailing: DecisionChip(c.status), onTap: () => _concession(c, canAct, cur)),
      RefundItem r => ListRow(title: r.studentName, subtitle: '${formatMinor(r.amountMinor, currency: cur)}  ·  ${r.invoiceNo}\n${r.reason}', trailing: DecisionChip(r.status), onTap: () => _refund(r, canAct, cur)),
      ExpenseItem e => ListRow(title: e.description, subtitle: '${formatMinor(e.amountMinor, currency: cur)}  ·  ${e.category}${e.createdByName != null ? '\nBy ${e.createdByName}' : ''}', trailing: DecisionChip(e.status), onTap: () => _expense(e, canAct, cur)),
      AdmissionApplication a => ListRow(title: a.name, subtitle: '${[if (a.gradeAppliedName != null) a.gradeAppliedName!, a.applicationNo].join('  ·  ')}\n${a.guardianName}, ${a.guardianPhone}', trailing: DecisionChip(a.status), onTap: () => _admission(a)),
      _ => const SizedBox.shrink(),
    };
  }

  static String _range(DateTime a, DateTime b) => sameDay(a, b) ? fmtDay(a) : '${fmtDay(a)} to ${fmtDay(b)}';

  static String _concessionValue(ConcessionItem c, String cur) => c.type == 'percent' ? '${(c.value / 100).toStringAsFixed(c.value % 100 == 0 ? 0 : 2)}% off fees' : '${formatMinor(c.value, currency: cur)} off for the year';

  // ── decisions ─────────────────────────────────────────────────────────────

  /// Runs [call] for a decision sheet: stale-state errors also refresh the lists behind it.
  Future<void> Function(bool, String) _guard(Future<void> Function(bool approve, String note) call, void Function(String) done) => (approve, note) async {
    try {
      await call(approve, note);
      done(approve ? 'Approved' : 'Rejected');
    } catch (e) {
      if (isStaleStateError(e)) _refreshAll();
      rethrow;
    }
  };

  Future<void> _decide({required String title, required Widget details, required bool actionable, required Future<void> Function(bool approve, String note) call, String approveLabel = 'Approve', String rejectLabel = 'Reject', String approveConsequence = 'The requester will be told it was approved.', String rejectConsequence = 'The requester will be told it was rejected, with your note.', bool canApprove = true, bool canReject = true, bool noteRequiredOnReject = true, String noteLabel = 'Note (optional)'}) async {
    if (!actionable) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Semantics(header: true, child: Text(title, style: context.text.titleLarge)), const SizedBox(height: Gaps.md), details]),
        ),
      );
      return;
    }
    String? message;
    final saved = await showDecisionSheet(
      context,
      title: title,
      details: details,
      onDecide: _guard(call, (m) => message = m),
      approveLabel: approveLabel,
      rejectLabel: rejectLabel,
      approveConsequence: approveConsequence,
      rejectConsequence: rejectConsequence,
      canApprove: canApprove,
      canReject: canReject,
      noteRequiredOnReject: noteRequiredOnReject,
      noteLabel: noteLabel,
    );
    if (!saved) return;
    _refreshAll();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message ?? 'Saved')));
  }

  Future<void> _studentLeave(StudentLeaveItem l, bool canAct) => _decide(
    title: 'Student leave',
    details: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(l.studentName, style: context.text.titleMedium)), DecisionChip(l.status)]),
        const SizedBox(height: Gaps.sm),
        FactRow('Class', l.sectionName ?? 'Not assigned'),
        FactRow('Type', l.leaveType.label),
        FactRow('Dates', _range(l.fromDate, l.toDate)),
        FactRow('School days', '${l.days}'),
        if (l.requestedByName != null) FactRow('Asked by', l.requestedByName!),
        const SizedBox(height: Gaps.sm),
        DetailBlock('Reason', l.reason),
        if (l.decisionNote != null) DetailBlock('Decision note${l.decidedByName != null ? ' (${l.decidedByName})' : ''}', l.decisionNote!),
      ],
    ),
    actionable: canAct && l.pending && l.canDecide,
    call: (approve, note) => ref.read(staffLeaveRepositoryProvider).decideStudentLeave(l.id, approve: approve, note: note),
    approveConsequence: 'The days are marked as leave on the register, and the family is told.',
    rejectConsequence: 'The family is told it was rejected, with your note.',
  );

  Future<void> _staffLeave(StaffLeaveItem l, bool canAct) => _decide(
    title: 'Staff leave',
    details: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(l.staffName, style: context.text.titleMedium)), DecisionChip(l.status)]),
        const SizedBox(height: Gaps.sm),
        if (l.designation != null) FactRow('Role', l.designation!),
        FactRow('Type', l.leaveType.label),
        FactRow('Dates', _range(l.fromDate, l.toDate)),
        FactRow('School days', '${l.days}'),
        const SizedBox(height: Gaps.sm),
        DetailBlock('Reason', l.reason),
        if (l.decisionNote != null) DetailBlock('Decision note${l.decidedByName != null ? ' (${l.decidedByName})' : ''}', l.decisionNote!),
      ],
    ),
    actionable: canAct && l.pending && l.canDecide,
    call: (approve, note) => ref.read(staffLeaveRepositoryProvider).decideStaffLeave(l.id, approve: approve, note: note),
    approveConsequence: 'The leave is approved and the staff member is told.',
  );

  Future<void> _correction(CorrectionItem c, bool canAct) => _decide(
    title: 'Attendance correction',
    details: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(c.studentName, style: context.text.titleMedium)), DecisionChip(c.status)]),
        const SizedBox(height: Gaps.sm),
        FactRow('Class', c.sectionName),
        FactRow('Date', fmtDay(c.date)),
        Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [AttendanceChip(c.fromStatus), const Padding(padding: EdgeInsets.symmetric(horizontal: Gaps.sm), child: Icon(Icons.arrow_forward_rounded, size: 18)), AttendanceChip(c.toStatus)])),
        if (c.requestedByName != null) FactRow('Asked by', c.requestedByName!),
        const SizedBox(height: Gaps.sm),
        DetailBlock('Reason', c.reason),
        if (c.decisionNote != null) DetailBlock('Decision note${c.decidedByName != null ? ' (${c.decidedByName})' : ''}', c.decisionNote!),
      ],
    ),
    actionable: canAct && c.pending && c.canDecide,
    call: (approve, note) => ref.read(rollCallRepositoryProvider).decideCorrection(c.id, approve: approve, note: note),
    approveConsequence: 'The register is changed to ${c.toStatus?.label.toLowerCase() ?? 'the new status'} and the family is told.',
    rejectConsequence: 'The register stays as it is and the teacher is told, with your note.',
  );

  Future<void> _sheet(MarkSheet s, bool canAct) {
    final reviewable = canAct && s.status == 'submitted';
    final returnable = canAct && (s.status == 'submitted' || s.status == 'approved');
    return _decide(
      title: 'Mark sheet',
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text('${s.subjectName}, ${s.sectionTitle}', style: context.text.titleMedium)), DecisionChip(s.status)]),
          const SizedBox(height: Gaps.sm),
          FactRow('Exam', s.examName),
          if (s.teacherName != null) FactRow('Teacher', s.teacherName!),
          FactRow('Marks entered', '${s.enteredCount} of ${s.studentCount}'),
          FactRow('Absent', '${s.absentCount}'),
          FactRow('Out of', s.maxMarks.toStringAsFixed(s.maxMarks == s.maxMarks.roundToDouble() ? 0 : 1)),
          if (s.passMarks != null) FactRow('Pass mark', s.passMarks!.toStringAsFixed(s.passMarks == s.passMarks!.roundToDouble() ? 0 : 1)),
          if (s.submittedAt != null) FactRow('Submitted', fmtDateTime(s.submittedAt!)),
          if (s.returnNote != null) DetailBlock('Earlier return note', s.returnNote!),
        ],
      ),
      actionable: reviewable || returnable,
      call: (approve, note) async {
        final repo = ref.read(marksRepositoryProvider);
        if (approve) {
          await repo.approve(s.id, note: note);
        } else {
          await repo.returnSheet(s.id, note: note);
        }
      },
      approveLabel: 'Approve',
      rejectLabel: 'Return',
      canApprove: reviewable,
      canReject: returnable,
      approveConsequence: 'The sheet is approved. It can then be published to students and parents.',
      rejectConsequence: 'The sheet goes back to the teacher with your note to fix and submit again.',
      noteLabel: 'Note (required to return, at least 3 characters)',
    );
  }

  Future<void> _concession(ConcessionItem c, bool canAct, String cur) => _decide(
    title: 'Fee concession',
    details: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(c.studentName, style: context.text.titleMedium)), DecisionChip(c.status)]),
        const SizedBox(height: Gaps.sm),
        FactRow('Admission no.', c.admissionNo),
        FactRow('Concession', c.name),
        FactRow('Value', _concessionValue(c, cur)),
        if (c.categoryName != null) FactRow('Applies to', c.categoryName!),
        if (c.appliedMinor > 0) FactRow('Applied so far', formatMinor(c.appliedMinor, currency: cur)),
        if (c.reason != null) DetailBlock('Reason', c.reason!),
      ],
    ),
    actionable: canAct && c.pending,
    call: (approve, note) => ref.read(financeRepositoryProvider).decideConcession(c.id, approve: approve, note: note),
    approveConsequence: 'The discount applies to dues generated from now on.',
    rejectConsequence: 'No discount is applied. The request is closed.',
    noteRequiredOnReject: false,
  );

  Future<void> _refund(RefundItem r, bool canAct, String cur) => _decide(
    title: 'Refund request',
    details: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(r.studentName, style: context.text.titleMedium)), DecisionChip(r.status)]),
        const SizedBox(height: Gaps.sm),
        FactRow('Amount', formatMinor(r.amountMinor, currency: cur), bold: true),
        if (r.invoiceNo.isNotEmpty) FactRow('Invoice', r.invoiceNo),
        if (r.requestedByName != null) FactRow('Asked by', r.requestedByName!),
        DetailBlock('Reason', r.reason),
      ],
    ),
    actionable: canAct && r.requested,
    call: (approve, note) => ref.read(financeRepositoryProvider).decideRefund(r.id, approve: approve, note: note),
    approveConsequence: 'The refund is approved and processed now: the payment and invoice are adjusted.',
    rejectConsequence: 'The refund is rejected and the requester is told, with your note.',
    noteLabel: 'Note (required to reject, at least 3 characters)',
  );

  Future<void> _expense(ExpenseItem e, bool canAct, String cur) => _decide(
    title: 'Expense',
    details: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(e.description, style: context.text.titleMedium)), DecisionChip(e.status)]),
        const SizedBox(height: Gaps.sm),
        FactRow('Amount', formatMinor(e.amountMinor, currency: cur), bold: true),
        FactRow('Category', e.category),
        if (e.spentOn != null) FactRow('Spent on', fmtFull(e.spentOn!)),
        if (e.paidTo != null) FactRow('Paid to', e.paidTo!),
        if (e.reference != null) FactRow('Reference', e.reference!),
        if (e.createdByName != null) FactRow('Recorded by', e.createdByName!),
      ],
    ),
    actionable: canAct && e.pending,
    call: (approve, note) => ref.read(financeRepositoryProvider).decideExpense(e.id, approve: approve, note: note),
    approveConsequence: 'The expense counts towards the school\'s spending.',
    rejectConsequence: 'The expense is rejected and the person who recorded it is told.',
    noteRequiredOnReject: false,
  );

  Future<void> _admission(AdmissionApplication a) => openAdmission(context, ref, a, onChanged: _refreshAll);
}
