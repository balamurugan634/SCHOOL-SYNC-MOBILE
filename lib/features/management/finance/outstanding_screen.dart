import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/finance.dart';
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import '../charts/money_figure.dart';
import 'finance_providers.dart';
import 'finance_widgets.dart';

/// Outstanding fees by grade or class, with the ageing of everything owed.
class OutstandingScreen extends ConsumerStatefulWidget {
  const OutstandingScreen({super.key});

  @override
  ConsumerState<OutstandingScreen> createState() => _OutstandingScreenState();
}

class _OutstandingScreenState extends ConsumerState<OutstandingScreen> {
  String _group = 'grade';

  @override
  Widget build(BuildContext context) {
    final provider = outstandingProvider(_group);
    return SecureScope(
      child: StaffFrame(
        title: 'Outstanding fees',
        headerExtra: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.sm),
          child: SizedBox(width: double.infinity, child: SegmentedButton<String>(showSelectedIcon: false, segments: const [ButtonSegment(value: 'grade', label: Text('By grade')), ButtonSegment(value: 'section', label: Text('By class'))], selected: {_group}, onSelectionChanged: (s) => setState(() => _group = s.first))),
        ),
        body: FeatureGate(
          label: 'Outstanding fees',
          siteFeature: 'fees',
          anyPermission: const ['fees:view', 'payments:view'],
          child: AsyncBody<OutstandingReport>(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            data: (o) => RefreshScroll(
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
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: MoneyFact(label: 'Outstanding', minor: o.outstandingMinor, currency: o.currency)), const SizedBox(width: Gaps.md), Expanded(child: MoneyFact(label: 'Overdue', minor: o.overdueMinor, currency: o.currency, color: o.overdueMinor > 0 ? context.tokens.danger : null))]),
                      const SizedBox(height: Gaps.sm),
                      Text(plural(o.invoices, 'open invoice'), style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: Gaps.md),
                SectionCard(title: 'By age', child: AgingBars(buckets: o.buckets, currency: o.currency)),
                GroupLabel(_group == 'grade' ? 'By grade' : 'By class'),
                if (o.rows.isEmpty)
                  const AppCard(child: QuietLine('Nothing is outstanding.', icon: Icons.check_circle_outline_rounded))
                else
                  RowGroup(children: [for (final r in o.rows) ListRow(title: r.name, subtitle: '${plural(r.invoices, 'invoice')}${r.overdueMinor > 0 ? '  ·  ${formatMinor(r.overdueMinor, currency: o.currency)} overdue' : ''}', trailing: Text(formatMinor(r.outstandingMinor, currency: o.currency), style: context.text.titleSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])), chevron: false)]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
