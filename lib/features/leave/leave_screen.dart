import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/paged.dart';
import '../../core/util/format.dart';
import '../../data/models/leave.dart';
import '../../data/repositories/leave_repository.dart';
import '../../router/routes_shared.dart';
import '../auth/session.dart';
import '../dashboard/dashboard_providers.dart';
import '../learner/learner_context.dart';
import '../learner/screen_frame.dart';
import 'leave_providers.dart';

/// Leave requests: status of each, cancel a pending one, apply for new leave.
class LeaveScreen extends ConsumerWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(learnerQueryIdProvider);
    final provider = leaveListProvider(q);
    final v = ref.watch(provider);
    final readOnly = ref.watch(sessionProvider.select((s) => s.siteInfo?.readOnly ?? false));
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Leave',
      fab: readOnly ? null : FloatingActionButton.extended(onPressed: () => context.push(SharedRoutes.leaveNew), icon: const Icon(Icons.add_rounded), label: const Text('Apply for leave')),
      body: AsyncBody<PagedList<LeaveRequest>>(
        value: v,
        onRetry: refresh,
        isEmpty: (p) => p.items.isEmpty,
        empty: EmptyState(illo: Illo.emptyEvents, title: 'No leave requests', message: 'Apply here when a day off is planned. The school will approve or decline it.', actionLabel: readOnly ? null : 'Apply for leave', onAction: () => context.push(SharedRoutes.leaveNew)),
        data: (p) => RefreshScroll(
          onRefresh: refresh,
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 96),
          children: [
            for (final l in p.items) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: _LeaveCard(l, q)),
            LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
          ],
        ),
      ),
    );
  }
}

class _LeaveCard extends ConsumerStatefulWidget {
  const _LeaveCard(this.l, this.q);
  final LeaveRequest l;
  final String? q;

  @override
  ConsumerState<_LeaveCard> createState() => _LeaveCardState();
}

class _LeaveCardState extends ConsumerState<_LeaveCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    setState(() => _busy = true);
    try {
      await ref.read(leaveRepositoryProvider).cancel(widget.l.id);
      ref.invalidate(leaveListProvider(widget.q));
      ref.invalidate(parentDashboardProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final t = context.tokens;
    final tone = switch (l.status) { 'approved' => StatusTone.success, 'rejected' => StatusTone.danger, 'pending' => StatusTone.warning, _ => StatusTone.neutral };
    final same = l.fromDate == l.toDate;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(same ? fmtDay(l.fromDate) : '${fmtShort(l.fromDate)} to ${fmtShort(l.toDate)}', style: context.text.titleMedium)), StatusChip('${l.status[0].toUpperCase()}${l.status.substring(1)}', tone: tone)]),
          Text('${l.studentName}  ·  ${l.leaveType.label}  ·  ${plural(l.days, 'day')}', style: context.text.bodySmall),
          const SizedBox(height: Gaps.sm),
          Text(l.reason, style: context.text.bodyMedium),
          if (l.decisionNote != null) ...[const SizedBox(height: Gaps.sm), Text('${l.decidedByName ?? 'School'}: ${l.decisionNote}', style: context.text.bodySmall?.copyWith(color: t.textSecondary))],
          if (l.canCancel) Padding(padding: const EdgeInsets.only(top: Gaps.md), child: SecondaryButton(label: _busy ? 'Cancelling' : 'Cancel request', onPressed: _busy ? null : _cancel)),
        ],
      ),
    );
  }
}
