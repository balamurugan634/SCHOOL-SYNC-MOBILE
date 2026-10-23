import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/exams.dart';
import '../../router/routes_shared.dart';
import '../learner/screen_frame.dart';
import '../security/secure_scope.dart';
import 'exams_providers.dart';

/// Published results and the progress trend across exams.
class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key, this.embedded = false, this.bare = false});
  final bool embedded;
  final bool bare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(resultsProvider);
    final progress = ref.watch(progressProvider);
    Future<void> refresh() async {
      ref.invalidate(resultsProvider);
      ref.invalidate(progressProvider);
      try {
        await ref.read(resultsProvider.future);
      } catch (_) {}
    }

    return SecureScope(
      child: ScreenFrame(
        title: 'Results',
        embedded: embedded,
        bare: bare,
        body: AsyncBody<List<ExamResult>>(
          value: v,
          onRetry: refresh,
          isEmpty: (l) => l.isEmpty,
          empty: const EmptyState(illo: Illo.emptyGeneric, title: 'No results published yet', message: 'Marks and report cards appear here after the school publishes them.'),
          data: (results) => RefreshScroll(
            onRefresh: refresh,
            children: [
              if ((progress.value?.length ?? 0) >= 2) _ProgressChart(points: progress.value!),
              const GroupLabel('Exams'),
              for (final r in results) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: _ResultCard(r: r)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.r});
  final ExamResult r;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: () => context.push(SharedRoutes.reportCard(r.examId)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(r.examName, style: context.text.titleMedium)),
              if (r.result != null) StatusChip(r.passed ? 'Pass' : 'Fail', tone: r.passed ? StatusTone.success : StatusTone.danger, icon: r.passed ? Icons.check_rounded : Icons.close_rounded),
            ],
          ),
          Text([if (r.termName != null) r.termName!, if (r.startDate != null) fmtShort(r.startDate!)].join('  ·  '), style: context.text.bodySmall),
          const SizedBox(height: Gaps.md),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: Gaps.md,
            runSpacing: 4,
            children: [
              Text(r.percent == null ? '-' : '${r.percent!.toStringAsFixed(1)}%', style: figureStyle(context, size: 32)),
              if (r.grade != null) Padding(padding: const EdgeInsets.only(bottom: 6), child: StatusChip('Grade ${r.grade}', tone: StatusTone.brand)),
              if (r.rank != null) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('Rank ${r.rank}${r.classSize == null ? '' : ' of ${r.classSize}'}', style: context.text.labelMedium?.copyWith(color: t.textSecondary))),
            ],
          ),
          if (!r.complete) Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: Text('Some subjects are still being published.', style: context.text.bodySmall?.copyWith(color: t.warning))),
        ],
      ),
    );
  }
}

class _ProgressChart extends StatelessWidget {
  const _ProgressChart({required this.points});
  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final spots = [for (final (i, p) in points.indexed) FlSpot(i.toDouble(), p.percent)];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Gaps.sm, Gaps.lg, Gaps.lg, Gaps.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(left: Gaps.md), child: Text('Progress', style: context.text.titleMedium)),
          const SizedBox(height: Gaps.md),
          Semantics(
            label: 'Overall percentage by exam. ${points.map((p) => '${p.name} ${p.percent.toStringAsFixed(0)} percent').join(', ')}.',
            child: SizedBox(
              height: 160,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (_) => FlLine(color: t.border, strokeWidth: 1)),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 25, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: TextStyle(fontSize: 11, color: t.textTertiary)))),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, getTitlesWidget: (v, _) => v % 1 == 0 && v.toInt() < points.length ? Padding(padding: const EdgeInsets.only(top: 6), child: Text(_short(points[v.toInt()].name), style: TextStyle(fontSize: 11, color: t.textSecondary))) : const SizedBox.shrink())),
                  ),
                  lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(getTooltipColor: (_) => t.text, getTooltipItems: (spots) => [for (final s in spots) LineTooltipItem('${points[s.x.toInt()].name}\n${s.y.toStringAsFixed(1)}%${points[s.x.toInt()].grade == null ? '' : '  ·  Grade ${points[s.x.toInt()].grade}'}', TextStyle(color: t.surface, fontSize: 12, fontWeight: FontWeight.w500))])),
                  lineBarsData: [LineChartBarData(spots: spots, isCurved: false, color: t.brand.solid, barWidth: 2, dotData: FlDotData(getDotPainter: (_, _, _, _) => FlDotCirclePainter(radius: 4, color: t.brand.solid, strokeWidth: 2, strokeColor: t.surface)))],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _short(String name) => name.length <= 10 ? name : '${name.substring(0, 9)}…';
}
