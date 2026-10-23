import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/leave.dart';
import '../../../data/repositories/staff/staff_leave_repository.dart';
import '../workspace.dart';
import 'leave_form_sheet.dart';
import 'me_providers.dart';

/// My own staff leave: what I have taken, what is waiting, and a form to ask for more.
class MyLeaveScreen extends ConsumerWidget {
  const MyLeaveScreen({super.key});

  void _reload(WidgetRef ref) {
    ref.invalidate(myLeaveProvider);
    ref.invalidate(staffLeaveBalanceProvider);
  }

  Future<void> _apply(BuildContext context, WidgetRef ref) async {
    final saved = await showApplyLeaveSheet(context);
    if (saved) _reload(ref);
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, StaffLeaveItem l) async {
    final ok = await confirmAction(context, title: 'Cancel this leave request?', message: '${l.leaveType.label} leave, ${_range(l)}, will be withdrawn.', confirmLabel: 'Cancel request', destructive: true);
    if (!ok || !context.mounted) return;
    await runWrite(context, ref, () => ref.read(staffLeaveRepositoryProvider).cancelStaffLeave(l.id), success: 'The request was cancelled.');
    _reload(ref);
  }

  static String _range(StaffLeaveItem l) => l.fromDate == l.toDate ? fmtFull(l.fromDate) : '${fmtShort(l.fromDate)} to ${fmtFull(l.toDate)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canApply = ref.can('staff_leave:create');
    final readOnly = ref.watch(readOnlyProvider);
    final provider = myLeaveProvider(0);
    final list = ref.watch(provider);

    Future<void> refresh() async {
      _reload(ref);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return FeatureGate(
      label: 'My leave',
      anyPermission: const ['staff_leave:view', 'staff_leave:create'],
      child: StaffFrame(
        title: 'My leave',
        fab: canApply ? FloatingActionButton.extended(onPressed: readOnly ? null : () => _apply(context, ref), icon: const Icon(Icons.add_rounded), label: const Text('Apply for leave'), tooltip: readOnly ? 'View-only mode' : 'Apply for leave') : null,
        body: AsyncBody<PagedList<StaffLeaveItem>>(
          value: list,
          onRetry: () => ref.invalidate(provider),
          data: (p) => RefreshScroll(
            onRefresh: refresh,
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 96),
            children: [
              const ReadOnlyBanner(),
              const _Balance(),
              const GroupLabel('My requests'),
              if (p.items.isEmpty)
                EmptyState(illo: Illo.emptyEvents, title: 'No leave requests yet', message: 'When you ask for leave it is listed here with the decision.', compact: true, actionLabel: canApply && !readOnly ? 'Apply for leave' : null, onAction: canApply && !readOnly ? () => _apply(context, ref) : null)
              else ...[
                for (final l in p.items) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: _LeaveCard(l, onCancel: () => _cancel(context, ref, l), readOnly: readOnly)),
                LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Balance extends ConsumerWidget {
  const _Balance();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = ref.watch(staffLeaveBalanceProvider);
    return SectionCard(
      title: b.value?.academicYear == null ? 'Leave this year' : 'Leave in ${b.value!.academicYear}',
      child: b.when(
        skipLoadingOnReload: true,
        loading: () => const Skeletonizer(child: Padding(padding: EdgeInsets.symmetric(vertical: Gaps.sm), child: Column(children: [Bone.text(words: 5), SizedBox(height: 8), Bone.text(words: 3)]))),
        error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(staffLeaveBalanceProvider)),
        data: (v) => v.lines.isEmpty && v.totalPendingDays == 0
            ? const QuietLine('No leave taken or waiting this year.', icon: Icons.beach_access_outlined)
            : Column(
                children: [
                  for (final l in v.lines) FactRow(l.leaveType.label, '${l.approvedDays} ${l.approvedDays == 1 ? 'day' : 'days'} taken${l.pendingDays > 0 ? ', ${l.pendingDays} waiting' : ''}'),
                  const Divider(),
                  FactRow('Total taken', '${v.totalApprovedDays} ${v.totalApprovedDays == 1 ? 'day' : 'days'}', bold: true),
                  if (v.totalPendingDays > 0) FactRow('Waiting for a decision', '${v.totalPendingDays} ${v.totalPendingDays == 1 ? 'day' : 'days'}'),
                ],
              ),
      ),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard(this.l, {required this.onCancel, required this.readOnly});
  final StaffLeaveItem l;
  final VoidCallback onCancel;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      semanticLabel: '${l.leaveType.label} leave, ${MyLeaveScreen._range(l)}, ${l.status}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text('${l.leaveType.label} leave', style: context.text.titleMedium)), DecisionChip(l.status)]),
          const SizedBox(height: 2),
          Text('${MyLeaveScreen._range(l)}  ·  ${plural(l.days, 'school day')}', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
          const SizedBox(height: Gaps.sm),
          Text(l.reason, style: context.text.bodyMedium),
          if (l.decidedByName != null || (l.decisionNote ?? '').isNotEmpty) ...[
            const SizedBox(height: Gaps.sm),
            AppCard(
              tone: CardTone.subtle,
              padding: const EdgeInsets.all(Gaps.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (l.decidedByName != null) Text('Decided by ${l.decidedByName}${l.decidedAt == null ? '' : ', ${fmtShort(l.decidedAt!)}'}', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
                  if ((l.decisionNote ?? '').isNotEmpty) Text(l.decisionNote!, style: context.text.bodyMedium),
                ],
              ),
            ),
          ],
          if (l.canCancel) ...[
            const SizedBox(height: Gaps.sm),
            Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: readOnly ? null : onCancel, icon: const Icon(Icons.close_rounded, size: 18), label: const Text('Cancel request'), style: TextButton.styleFrom(foregroundColor: t.danger))),
          ],
        ],
      ),
    );
  }
}
