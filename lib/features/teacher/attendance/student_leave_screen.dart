import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/leave.dart';
import '../../../data/repositories/staff/staff_leave_repository.dart';
import '../../workspace/workspace.dart';
import 'attendance_providers.dart';
import 'detail_sheet.dart';

/// Student leave requests for the classes I lead: pending first, with approve / reject (and a note).
/// Approved leave pre-fills "Leave" on the roll call.
class StudentLeaveScreen extends ConsumerStatefulWidget {
  const StudentLeaveScreen({super.key});

  @override
  ConsumerState<StudentLeaveScreen> createState() => _StudentLeaveScreenState();
}

class _StudentLeaveScreenState extends ConsumerState<StudentLeaveScreen> {
  String _status = 'pending';
  static const _labels = {'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected'};

  @override
  Widget build(BuildContext context) {
    final provider = studentLeaveListProvider(_status);
    final v = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return FeatureGate(
      label: 'Student leave',
      anyPermission: const ['leave:view'],
      child: Scaffold(
        appBar: AppBar(title: const Text('Student leave')),
        body: Column(
          children: [
            const SizedBox(height: Gaps.sm),
            FilterChips<String>(options: _labels.keys.toList(), selected: _status, onSelected: (s) => setState(() => _status = s), labelOf: (s) => _labels[s]!),
            const SizedBox(height: Gaps.sm),
            Expanded(
              child: AsyncBody<PagedList<StudentLeaveItem>>(
                value: v,
                onRetry: () => ref.invalidate(provider),
                isEmpty: (p) => p.items.isEmpty,
                empty: RefreshScroll(
                  onRefresh: refresh,
                  children: [EmptyState(icon: Icons.event_available_outlined, title: _status == 'pending' ? 'No leave waiting for you' : 'No ${_labels[_status]!.toLowerCase()} leave', message: _status == 'pending' ? 'Parents apply for leave in the app; class teachers decide here.' : null)],
                ),
                data: (p) => RefreshScroll(
                  onRefresh: refresh,
                  children: [
                    RowGroup(children: [for (final l in p.items) LeaveTile(item: l, onTap: () => _open(l))]),
                    LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(StudentLeaveItem l) async {
    if (!(l.pending && l.canDecide)) {
      await showDetailSheet(context, title: 'Leave request', child: LeaveDetails(item: l));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final done = await showDecisionSheet(
      context,
      title: 'Leave request',
      details: LeaveDetails(item: l),
      approveConsequence: 'Leave is approved for ${plural(l.days, 'school day')}. The roll call shows ${l.studentName} on leave and the parents are told.',
      rejectConsequence: 'Leave is rejected. The parents are told, with your note.',
      noteLabel: 'Note to the parents (optional)',
      onDecide: (approve, note) async {
        try {
          await ref.read(staffLeaveRepositoryProvider).decideStudentLeave(l.id, approve: approve, note: note);
        } catch (e) {
          if (isStaleStateError(e)) ref.invalidate(studentLeaveListProvider);
          rethrow;
        }
      },
    );
    if (done) {
      ref.invalidate(studentLeaveListProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Decision saved.')));
    }
  }
}

String leaveRange(StudentLeaveItem l) => sameDay(l.fromDate, l.toDate) ? fmtDay(l.fromDate) : '${fmtShort(l.fromDate)} to ${fmtShort(l.toDate)}';

class LeaveTile extends StatelessWidget {
  const LeaveTile({super.key, required this.item, required this.onTap});
  final StudentLeaveItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: '${item.studentName}, ${item.sectionName ?? ''}, ${leaveRange(item)}, ${plural(item.days, 'day')}, ${item.leaveType.label} leave, ${item.status}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(item.studentName, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  const SizedBox(width: Gaps.sm),
                  DecisionChip(item.status),
                ],
              ),
              if (item.sectionName != null) Text(item.sectionName!, style: context.text.bodySmall),
              const SizedBox(height: Gaps.sm),
              Wrap(spacing: 6, runSpacing: 4, children: [StatusChip(leaveRange(item), icon: Icons.event_outlined), StatusChip(plural(item.days, 'day'), icon: Icons.today_outlined), StatusChip('${item.leaveType.label} leave')]),
              const SizedBox(height: Gaps.sm),
              Text(item.reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class LeaveDetails extends StatelessWidget {
  const LeaveDetails({super.key, required this.item});
  final StudentLeaveItem item;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(item.studentName, style: context.text.titleMedium),
      Text([?item.sectionName, if (item.admissionNo.isNotEmpty) item.admissionNo].join(' · '), style: context.text.bodySmall),
      const SizedBox(height: Gaps.md),
      DetailBlock('Dates', '${leaveRange(item)} (${plural(item.days, 'school day')})'),
      DetailBlock('Type', '${item.leaveType.label} leave'),
      DetailBlock('Reason', item.reason),
      if (item.requestedByName != null) DetailBlock('Requested by', '${item.requestedByName}${item.createdAt != null ? ' on ${fmtDateTime(item.createdAt!)}' : ''}'),
      if (!item.pending) ...[
        DetailBlock('Decision', '${item.status[0].toUpperCase()}${item.status.substring(1)}${item.decidedByName != null ? ' by ${item.decidedByName}' : ''}${item.decidedAt != null ? ' on ${fmtDateTime(item.decidedAt!)}' : ''}'),
        if (item.decisionNote != null && item.decisionNote!.isNotEmpty) DetailBlock('Note', item.decisionNote!),
      ],
    ],
  );
}
