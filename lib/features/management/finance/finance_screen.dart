import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/finance.dart';
import '../../../router/routes_management.dart';
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import '../charts/money_figure.dart';
import '../charts/monthly_money_chart.dart';
import 'finance_providers.dart';
import 'finance_widgets.dart';

/// Finance tab (read-only): money at a glance, collection by month, ageing of what is owed, and the follow-up lists.
/// Hidden behind the school's fees module and the fee / payment / expense permissions; the API still enforces scope.
class ManagementFinanceScreen extends ConsumerWidget {
  const ManagementFinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SecureScope(
      child: FeatureGate(
        label: 'Finance',
        siteFeature: 'fees',
        anyPermission: const ['fees:view', 'payments:view', 'expenses:view'],
        child: StaffFrame(
          embedded: true,
          title: 'Finance',
          subtitle: 'Collection, dues and expenses.',
          body: AsyncBody<FinanceSummary>(
            value: ref.watch(financeSummaryProvider),
            onRetry: () => ref.invalidate(financeSummaryProvider),
            data: (f) => RefreshScroll(
              onRefresh: () async {
                ref.invalidate(financeSummaryProvider);
                ref.invalidate(outstandingProvider);
                try {
                  await ref.read(financeSummaryProvider.future);
                } catch (_) {}
              },
              children: [_Summary(f: f), const SizedBox(height: Gaps.md), _Pending(f: f), const SizedBox(height: Gaps.md), _Chart(f: f), const SizedBox(height: Gaps.md), const _Aging(), const SizedBox(height: Gaps.md), const _Links()],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.f});
  final FinanceSummary f;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: MoneyFact(label: 'Collected', minor: f.netCollectedMinor, currency: f.currency)), const SizedBox(width: Gaps.md), Expanded(child: MoneyFact(label: 'Outstanding', minor: f.outstandingMinor, currency: f.currency))]),
          const SizedBox(height: Gaps.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: MoneyFact(label: 'Overdue', minor: f.overdueMinor, currency: f.currency, color: f.overdueMinor > 0 ? t.danger : null)),
              const SizedBox(width: Gaps.md),
              Expanded(child: f.expensesMinor == null ? const SizedBox.shrink() : MoneyFact(label: 'Expenses', minor: f.expensesMinor!, currency: f.currency)),
            ],
          ),
          if (f.collectionRatePercent != null) ...[
            const SizedBox(height: Gaps.lg),
            Text('Collection rate, of ${formatMinor(f.invoicedMinor, currency: f.currency)} invoiced', style: context.text.labelSmall?.copyWith(color: t.textSecondary)),
            const SizedBox(height: 4),
            MeterBar(value: f.collectionRatePercent! / 100, label: '${f.collectionRatePercent!.toStringAsFixed(1)}%', semanticLabel: 'Collection rate'),
          ],
          if (f.from != null && f.to != null) Padding(padding: const EdgeInsets.only(top: Gaps.md), child: Text('${fmtFull(f.from!)} to ${fmtFull(f.to!)}', style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

/// Pending refunds / concessions / expenses: a link to the queue for people who can decide, a plain count otherwise.
class _Pending extends ConsumerWidget {
  const _Pending({required this.f});
  final FinanceSummary f;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[];
    void add(String label, int? n, IconData icon, String kind, String approve) {
      if (n == null) return;
      final canAct = ref.can(approve);
      rows.add(ListRow(title: label, subtitle: n == 0 ? 'Nothing waiting' : '$n waiting for approval', leading: icon, onTap: canAct ? () => context.push(ManagementRoutes.approval(kind)) : null, trailing: n > 0 ? StatusChip('$n', tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded) : null));
    }

    add('Refund requests', f.pendingRefunds, Icons.currency_rupee_rounded, 'refunds', 'payments:approve');
    add('Concessions', f.pendingConcessions, Icons.percent_rounded, 'concessions', 'fees:approve');
    add('Expenses', f.pendingExpenses, Icons.request_quote_outlined, 'expenses', 'expenses:approve');
    if (rows.isEmpty) return const SizedBox.shrink();
    return SectionCard(title: 'Waiting for approval', padding: const EdgeInsets.only(bottom: Gaps.xs), child: Column(children: rows));
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.f});
  final FinanceSummary f;

  @override
  Widget build(BuildContext context) => SectionCard(title: 'Collected by month', child: MonthlyMoneyChart(months: f.byMonth, currency: f.currency));
}

class _Aging extends ConsumerWidget {
  const _Aging();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(outstandingProvider('grade'));
    return v.when(
      loading: () => const SkeletonList(count: 1, padding: EdgeInsets.zero),
      error: (e, _) => AppException.from(e).kind == ErrorKind.forbidden ? const SizedBox.shrink() : SizedBox(height: 240, child: ErrorState(compact: true, error: e, onRetry: () => ref.invalidate(outstandingProvider))),
      data: (o) => SectionCard(
        title: 'What is owed, by age',
        action: 'By class',
        onAction: () => context.push(ManagementRoutes.outstanding),
        child: AgingBars(buckets: o.buckets, currency: o.currency),
      ),
    );
  }
}

class _Links extends StatelessWidget {
  const _Links();

  @override
  Widget build(BuildContext context) => RowGroup(
    children: [
      ListRow(title: 'Defaulters', subtitle: 'Students with overdue fees, worst first', leading: Icons.warning_amber_rounded, onTap: () => context.push(ManagementRoutes.defaulters)),
      ListRow(title: 'Outstanding fees', subtitle: 'By grade or class, with ageing', leading: Icons.account_balance_wallet_outlined, onTap: () => context.push(ManagementRoutes.outstanding)),
      ListRow(title: 'Collection', subtitle: 'By month or day, method and category', leading: Icons.savings_outlined, onTap: () => context.push(ManagementRoutes.collection)),
    ],
  );
}
