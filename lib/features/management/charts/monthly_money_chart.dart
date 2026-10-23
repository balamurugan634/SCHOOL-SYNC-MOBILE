import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/finance.dart';
import 'chart_text.dart';

/// Collected per month (chart colour 1) with expenses beside it (chart colour 2) when the caller may see expenses.
/// Rounded 4 px bars anchored to the baseline, thin gridlines, a legend, a tooltip, a text summary and a table view.
class MonthlyMoneyChart extends StatefulWidget {
  const MonthlyMoneyChart({super.key, required this.months, required this.currency, this.height = 190});

  final List<MonthMoney> months;
  final String currency;
  final double height;

  @override
  State<MonthlyMoneyChart> createState() => _MonthlyMoneyChartState();
}

class _MonthlyMoneyChartState extends State<MonthlyMoneyChart> {
  bool _table = false;

  /// Compact axis label: 1.2L, 3.4Cr (Indian) kept short, otherwise k / M.
  static String _short(double major, String currency) {
    if (currency == 'INR') {
      if (major >= 1e7) return '${(major / 1e7).toStringAsFixed(major >= 1e8 ? 0 : 1)}Cr';
      if (major >= 1e5) return '${(major / 1e5).toStringAsFixed(major >= 1e6 ? 0 : 1)}L';
      if (major >= 1e3) return '${(major / 1e3).toStringAsFixed(0)}k';
      return major.toStringAsFixed(0);
    }
    if (major >= 1e6) return '${(major / 1e6).toStringAsFixed(1)}M';
    if (major >= 1e3) return '${(major / 1e3).toStringAsFixed(0)}k';
    return major.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final months = widget.months;
    final hasExpenses = months.any((m) => m.expensesMinor != null);
    final summary = monthlyMoneySummary(months, widget.currency);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final maxMinor = months.fold<int>(0, (a, m) => [a, m.collectedMinor, m.expensesMinor ?? 0].reduce((x, y) => x > y ? x : y));
    final maxMajor = maxMinor / 100;
    final top = maxMajor <= 0 ? 1.0 : maxMajor * 1.15;

    Widget body;
    if (months.isEmpty) {
      body = SizedBox(height: widget.height, child: Center(child: Text(summary, style: context.text.bodyMedium?.copyWith(color: t.textSecondary))));
    } else if (_table) {
      body = Column(
        children: [
          for (final (i, m) in months.indexed) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(monthLabel(m.month), style: context.text.bodyMedium)),
                  Expanded(flex: 4, child: Text('Collected ${formatMinor(m.collectedMinor, currency: widget.currency)}', style: context.text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]))),
                  if (m.expensesMinor != null) Expanded(flex: 4, child: Text('Spent ${formatMinor(m.expensesMinor!, currency: widget.currency)}', textAlign: TextAlign.end, style: context.text.bodySmall?.copyWith(color: t.textSecondary))),
                ],
              ),
            ),
          ],
        ],
      );
    } else {
      body = SizedBox(
        height: widget.height,
        child: BarChart(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
          curve: Motion.enter,
          BarChartData(
            maxY: top,
            minY: 0,
            alignment: BarChartAlignment.spaceAround,
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: top / 4, getDrawingHorizontalLine: (_) => FlLine(color: t.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: top / 4,
                  getTitlesWidget: (v, meta) => v >= top - .001 || v < 0 ? const SizedBox.shrink() : Padding(padding: const EdgeInsets.only(right: 6), child: Text(_short(v, widget.currency), textAlign: TextAlign.right, style: context.text.labelSmall?.copyWith(color: t.textTertiary))),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 26,
                  getTitlesWidget: (v, meta) {
                    final i = v.round();
                    if (i < 0 || i >= months.length) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 6), child: Text(monthLabel(months[i].month), style: context.text.labelSmall?.copyWith(color: t.textTertiary)));
                  },
                ),
              ),
            ),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipColor: (_) => t.surfaceRaised,
                tooltipBorder: BorderSide(color: t.borderStrong),
                getTooltipItem: (group, gi, rod, ri) {
                  final m = months[group.x];
                  final label = ri == 0 ? 'Collected' : 'Spent';
                  final v = ri == 0 ? m.collectedMinor : (m.expensesMinor ?? 0);
                  return BarTooltipItem('${monthLabel(m.month)}\n$label ${formatMinor(v, currency: widget.currency)}', (context.text.labelMedium ?? const TextStyle()).copyWith(color: t.text));
                },
              ),
            ),
            barGroups: [
              for (final (i, m) in months.indexed)
                BarChartGroupData(
                  x: i,
                  barsSpace: 2,
                  barRods: [
                    BarChartRodData(toY: m.collectedMinor / 100, width: hasExpenses ? 12 : 20, color: t.chart[0], borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                    if (hasExpenses) BarChartRodData(toY: (m.expensesMinor ?? 0) / 100, width: 12, color: t.chart[1], borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(label: 'Collected by month chart. $summary', container: true, child: ExcludeSemantics(child: body)),
        const SizedBox(height: Gaps.sm),
        Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: Gaps.md,
                runSpacing: 4,
                children: [
                  _Key(color: t.chart[0], label: 'Collected'),
                  if (hasExpenses) _Key(color: t.chart[1], label: 'Expenses'),
                ],
              ),
            ),
            if (months.isNotEmpty)
              TextButton.icon(
                onPressed: () => setState(() => _table = !_table),
                style: TextButton.styleFrom(minimumSize: const Size(48, 44), visualDensity: VisualDensity.compact),
                icon: Icon(_table ? Icons.bar_chart_rounded : Icons.table_rows_outlined, size: 18),
                label: Text(_table ? 'Chart' : 'Table'),
              ),
          ],
        ),
        Text(summary, style: context.text.bodySmall),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: context.text.labelSmall?.copyWith(color: context.tokens.textSecondary))),
    ],
  );
}
