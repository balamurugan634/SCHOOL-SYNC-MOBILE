import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/finance.dart';
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import '../charts/money_figure.dart';
import 'finance_providers.dart';

/// Students with overdue fees, worst first, with a one-tap call to the guardian.
class DefaultersScreen extends ConsumerWidget {
  const DefaultersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = defaultersProvider(0);
    final cur = ref.watch(currencyProvider);
    return SecureScope(
      child: StaffFrame(
        title: 'Defaulters',
        body: FeatureGate(
          label: 'Defaulters',
          siteFeature: 'fees',
          anyPermission: const ['fees:view', 'payments:view'],
          child: AsyncBody<PagedList<Defaulter>>(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            isEmpty: (p) => p.items.isEmpty,
            empty: RefreshScroll(onRefresh: () async => ref.invalidate(provider), children: const [EmptyState(icon: Icons.check_circle_outline_rounded, title: 'No overdue fees', message: 'Every student is up to date.')]),
            data: (p) => RefreshScroll(
              onRefresh: () async {
                ref.invalidate(provider);
                try {
                  await ref.read(provider.future);
                } catch (_) {}
              },
              children: [
                Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: Text('${p.total} ${p.total == 1 ? 'student has' : 'students have'} overdue fees, longest overdue first.', style: context.text.bodySmall)),
                for (final d in p.items) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: _DefaulterCard(d: d, currency: cur)),
                LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DefaulterCard extends StatelessWidget {
  const _DefaulterCard({required this.d, required this.currency});
  final Defaulter d;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final hasPhone = d.guardianPhone != null && d.guardianPhone!.trim().isNotEmpty;
    return AppCard(
      semanticLabel: '${d.studentName}, ${formatMinor(d.overdueMinor, currency: currency)} overdue for ${plural(d.maxDaysOverdue, 'day')}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.studentName, style: context.text.titleSmall),
                Text([if (d.classLabel.isNotEmpty) d.classLabel, d.admissionNo].join('  ·  '), style: context.text.bodySmall),
                const SizedBox(height: Gaps.sm),
                MoneyFigure(d.overdueMinor, currency: currency, size: 22, color: t.danger),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 14, color: t.warning),
                    const SizedBox(width: 4),
                    Flexible(child: Text('${plural(d.overdueInvoices, 'invoice')}, oldest ${plural(d.maxDaysOverdue, 'day')} overdue', style: context.text.bodySmall)),
                  ],
                ),
                if (d.guardianName != null) Padding(padding: const EdgeInsets.only(top: Gaps.xs), child: Text(hasPhone ? '${d.guardianName}  ·  ${d.guardianPhone}' : '${d.guardianName}  ·  no phone on record', style: context.text.bodySmall?.copyWith(color: t.textSecondary))),
              ],
            ),
          ),
          const SizedBox(width: Gaps.sm),
          Builder(
            builder: (context) => IconButton.filledTonal(
              tooltip: hasPhone ? 'Call ${d.guardianName ?? 'guardian'}' : 'No phone number on record',
              onPressed: hasPhone ? () => callPhone(context, d.guardianPhone) : null,
              style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: const Icon(Icons.call_rounded),
            ),
          ),
        ],
      ),
    );
  }
}
