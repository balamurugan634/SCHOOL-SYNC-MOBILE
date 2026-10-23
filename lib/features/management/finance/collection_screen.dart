import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/finance.dart';
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import '../charts/hbars.dart';
import '../charts/money_figure.dart';
import '../charts/monthly_money_chart.dart';
import 'finance_providers.dart';

/// What was collected: by month (6 months) or by day (30 days), by payment method and by fee category.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  String _group = 'month';

  @override
  Widget build(BuildContext context) {
    final provider = collectionProvider(_group);
    return SecureScope(
      child: StaffFrame(
        title: 'Collection',
        headerExtra: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.sm),
          child: SizedBox(width: double.infinity, child: SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'month', label: Text('By month')), ButtonSegment(value: 'day', label: Text('By day'))], selected: {_group}, onSelectionChanged: (s) => setState(() => _group = s.first))),
        ),
        body: FeatureGate(
          label: 'Collection',
          siteFeature: 'fees',
          anyPermission: const ['fees:view', 'payments:view'],
          child: AsyncBody<CollectionReport>(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            data: (c) => RefreshScroll(
              onRefresh: () async {
                ref.invalidate(provider);
                try {
                  await ref.read(provider.future);
                } catch (_) {}
              },
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: MoneyFact(label: 'Collected', minor: c.collectedMinor, currency: c.currency)), const SizedBox(width: Gaps.md), Expanded(child: MoneyFact(label: 'Refunded', minor: c.refundedMinor, currency: c.currency))]),
                      const SizedBox(height: Gaps.md),
                      Text('${plural(c.count, 'payment')}${c.from != null && c.to != null ? '  ·  ${fmtFull(c.from!)} to ${fmtFull(c.to!)}' : ''}', style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: Gaps.md),
                if (_group == 'month')
                  SectionCard(title: 'By month', child: MonthlyMoneyChart(months: [for (final p in c.series) MonthMoney(month: p.period, collectedMinor: p.collectedMinor)], currency: c.currency))
                else
                  SectionCard(
                    title: 'By day',
                    padding: const EdgeInsets.only(bottom: Gaps.xs),
                    child: c.series.isEmpty
                        ? const Padding(padding: EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.sm), child: QuietLine('No payments in this period.'))
                        : Column(children: [for (final p in c.series.reversed) ListRow(title: _dayLabel(p.period), subtitle: plural(p.count, 'payment'), trailing: Text(formatMinor(p.collectedMinor, currency: c.currency), style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])), chevron: false, dense: true)]),
                  ),
                if (c.byMethod.isNotEmpty) ...[
                  const SizedBox(height: Gaps.md),
                  SectionCard(title: 'By payment method', child: HorizontalBars(items: [for (final m in c.byMethod) BarItem(label: '${paymentMethodLabel(m.label)} (${m.count})', value: m.minor.toDouble(), text: formatMinor(m.minor, currency: c.currency))])),
                ],
                if (c.byCategory.isNotEmpty) ...[
                  const SizedBox(height: Gaps.md),
                  SectionCard(title: 'By fee category', child: HorizontalBars(items: [for (final m in c.byCategory) BarItem(label: m.label, value: m.minor.toDouble(), text: formatMinor(m.minor, currency: c.currency))])),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _dayLabel(String period) {
    final d = DateTime.tryParse(period);
    return d == null ? period : fmtDay(d);
  }
}
