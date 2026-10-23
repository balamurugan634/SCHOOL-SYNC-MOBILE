import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../data/models/me.dart';
import '../../../data/models/staff/dashboards.dart';
import '../../../router/routes_management.dart';
import '../../workspace/workspace.dart';
import '../home/management_home_providers.dart';
import 'approval_kinds.dart';

/// Every queue the person can act on, with how many items wait in each.
class ApprovalsHubScreen extends ConsumerWidget {
  const ApprovalsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(managementDashboardProvider);
    final me = ref.watch(staffMeProvider);
    final fees = ref.watch(feesEnabledProvider);

    Future<void> refresh() async {
      ref.invalidate(managementDashboardProvider);
      try {
        await ref.read(managementDashboardProvider.future);
      } catch (_) {}
    }

    return StaffFrame(
      title: 'Approvals',
      body: AsyncBody(
        value: value,
        onRetry: () => ref.invalidate(managementDashboardProvider),
        data: (loaded) => RefreshScroll(
          onRefresh: refresh,
          children: [
            if (loaded.fromCache) const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, icon: Icons.cloud_off_rounded, message: 'You are offline. These counts may be out of date.')),
            _Queues(counts: loaded.value.approvals, me: me, fees: fees),
          ],
        ),
      ),
    );
  }
}

class _Queues extends StatelessWidget {
  const _Queues({required this.counts, required this.me, required this.fees});
  final ApprovalCounts counts;
  final Me? me;
  final bool fees;

  @override
  Widget build(BuildContext context) {
    final who = me;
    if (who == null) return const SizedBox.shrink();
    final queues = visibleQueues(counts, who, feesEnabled: fees);
    if (queues.isEmpty) {
      return const EmptyState(icon: Icons.fact_check_outlined, title: 'No approvals for your role', message: 'Requests that need your decision will be listed here. Your role does not decide any queue right now.');
    }
    final total = queues.fold<int>(0, (a, q) => a + q.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: Text(total == 0 ? 'Nothing is waiting for a decision.' : '${total == 1 ? '1 item is' : '$total items are'} waiting for a decision.', style: context.text.bodyMedium?.copyWith(color: context.tokens.textSecondary))),
        RowGroup(
          children: [
            for (final (spec, n) in queues)
              ListRow(
                title: spec.label,
                subtitle: n == 0 ? 'Nothing waiting' : '$n waiting',
                leading: spec.icon,
                onTap: () => context.push(ManagementRoutes.approval(spec.kind)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (n > 0) StatusChip('$n', tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded),
                    Icon(Icons.chevron_right_rounded, color: context.tokens.textTertiary),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
