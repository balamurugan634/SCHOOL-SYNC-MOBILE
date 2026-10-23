import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../workspace/workspace.dart';
import 'chart_text.dart';

/// Percent present per school day as a single-series line (design.md section 10): brand colour, 2 px line, 8 px markers,
/// thin gridlines, recessive axes, an explicit height, a tooltip on touch, a one-sentence text summary and a table view.
class AttendanceTrendChart extends StatefulWidget {
  const AttendanceTrendChart({super.key, required this.points, this.height = 180});

  final List<TrendPoint> points;
  final double height;

  @override
  State<AttendanceTrendChart> createState() => _AttendanceTrendChartState();
}

class _AttendanceTrendChartState extends State<AttendanceTrendChart> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final points = [for (final p in widget.points) if (p.percentPresent != null) p];
    final summary = attendanceTrendSummary(widget.points);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    Widget body;
    if (points.length < 2 && !_table) {
      body = SizedBox(height: widget.height, child: Center(child: Text(summary, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: t.textSecondary))));
    } else if (_table) {
      body = _TrendTable(points: widget.points);
    } else {
      final lows = points.map((p) => p.percentPresent!).reduce((a, b) => a < b ? a : b);
      final minY = ((lows - 4) / 5).floorToDouble() * 5;
      final lo = minY.clamp(0, 90).toDouble();
      final day = DateFormat('EEE');
      final dayLong = DateFormat('EEE d MMM');
      body = SizedBox(
        height: widget.height,
        child: LineChart(
          duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
          curve: Motion.enter,
          LineChartData(
            minY: lo,
            maxY: 100,
            minX: 0,
            maxX: (points.length - 1).toDouble(),
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: ((100 - lo) / 4).clamp(1, 25).toDouble(), getDrawingHorizontalLine: (_) => FlLine(color: t.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(),
              rightTitles: const AxisTitles(),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: ((100 - lo) / 4).clamp(1, 25).toDouble(),
                  getTitlesWidget: (v, meta) => Padding(padding: const EdgeInsets.only(right: 6), child: Text('${v.round()}%', textAlign: TextAlign.right, style: context.text.labelSmall?.copyWith(color: t.textTertiary))),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 1,
                  getTitlesWidget: (v, meta) {
                    final i = v.round();
                    if (i < 0 || i >= points.length || (v - i).abs() > .01) return const SizedBox.shrink();
                    return Padding(padding: const EdgeInsets.only(top: 6), child: Text(day.format(points[i].date), style: context.text.labelSmall?.copyWith(color: t.textTertiary)));
                  },
                ),
              ),
            ),
            lineTouchData: LineTouchData(
              handleBuiltInTouches: true,
              touchSpotThreshold: 24,
              touchTooltipData: LineTouchTooltipData(
                fitInsideHorizontally: true,
                getTooltipColor: (_) => t.surfaceRaised,
                tooltipBorder: BorderSide(color: t.borderStrong),
                getTooltipItems: (spots) => [
                  for (final s in spots)
                    LineTooltipItem(
                      '${dayLong.format(points[s.x.round()].date)}\n${s.y.toStringAsFixed(1)}% present',
                      (context.text.labelMedium ?? const TextStyle()).copyWith(color: t.text),
                    ),
                ],
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: [for (final (i, p) in points.indexed) FlSpot(i.toDouble(), p.percentPresent!)],
                isCurved: false,
                color: t.brand.solid,
                barWidth: 2,
                dotData: FlDotData(show: true, getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 4, color: t.brand.solid, strokeWidth: 2, strokeColor: t.surface)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Attendance trend chart. $summary',
          container: true,
          child: ExcludeSemantics(child: body),
        ),
        const SizedBox(height: Gaps.sm),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(width: 12, height: 2, color: t.brand.solid),
                  const SizedBox(width: 6),
                  Flexible(child: Text('Present, % of students marked', style: context.text.labelSmall?.copyWith(color: t.textSecondary))),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _table = !_table),
              style: TextButton.styleFrom(minimumSize: const Size(48, 44), visualDensity: VisualDensity.compact),
              icon: Icon(_table ? Icons.show_chart_rounded : Icons.table_rows_outlined, size: 18),
              label: Text(_table ? 'Chart' : 'Table'),
            ),
          ],
        ),
        Text(summary, style: context.text.bodySmall),
      ],
    );
  }
}

class _TrendTable extends StatelessWidget {
  const _TrendTable({required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fmt = DateFormat('EEE d MMM');
    if (points.isEmpty) return const QuietLine('No attendance has been recorded for this period yet.');
    return Column(
      children: [
        for (final (i, p) in points.indexed) ...[
          if (i > 0) const Divider(),
          Semantics(
            label: '${fmt.format(p.date)}: ${p.percentPresent == null ? 'not marked' : '${p.percentPresent!.toStringAsFixed(1)} percent present'}. ${attendanceCountsSummary(p.counts)}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text(fmt.format(p.date), style: context.text.bodyMedium)),
                  Expanded(flex: 2, child: Text(p.percentPresent == null ? '-' : '${p.percentPresent!.toStringAsFixed(1)}%', style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]))),
                  Expanded(flex: 4, child: Text('${p.counts.present} present, ${p.counts.absent} absent', textAlign: TextAlign.end, style: context.text.bodySmall?.copyWith(color: t.textSecondary))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
