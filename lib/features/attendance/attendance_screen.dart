import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/paged.dart';
import '../../core/util/format.dart';
import '../../data/models/attendance.dart';
import '../../router/routes_shared.dart';
import '../learner/learner_context.dart';
import '../learner/screen_frame.dart';
import 'attendance_providers.dart';

/// Attendance: running percentage, per-month trend (chart + table view) and the day-by-day history.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  AttendanceStatus? _status;
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    final studentId = ref.watch(learnerStudentIdProvider);
    final summary = ref.watch(attendanceSummaryProvider);
    final recQuery = studentId == null ? null : (studentId: studentId, status: _status);
    final records = recQuery == null ? null : ref.watch(attendanceRecordsProvider(recQuery));
    final isParent = ref.watch(isParentProvider);

    Future<void> refresh() async {
      ref.invalidate(attendanceSummaryProvider);
      if (recQuery != null) ref.invalidate(attendanceRecordsProvider(recQuery));
      try {
        await ref.read(attendanceSummaryProvider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Attendance',
      subtitle: widget.embedded ? (isParent ? 'Presence, absences and leave for your child.' : 'Your presence and absences.') : null,
      embedded: widget.embedded,
      body: studentId == null
          ? const EmptyState(illo: Illo.emptyGeneric, title: 'No student selected')
          : AsyncBody<AttendanceSummary?>(
              value: summary,
              onRetry: refresh,
              data: (s) => RefreshScroll(
                onRefresh: refresh,
                children: [
                  if (s != null) _SummaryCard(s: s),
                  if (s != null && s.months.isNotEmpty) ...[
                    GroupLabel('By month', trailing: TextButton(onPressed: () => setState(() => _table = !_table), child: Text(_table ? 'Show chart' : 'Show table'))),
                    _table ? _MonthTable(months: s.months) : _MonthChart(months: s.months),
                  ],
                  const GroupLabel('History'),
                  FilterChips<AttendanceStatus?>(options: [null, ...AttendanceStatus.values], selected: _status, onSelected: (x) => setState(() => _status = x), labelOf: (x) => x == null ? 'All' : x.label, padding: EdgeInsets.zero),
                  const SizedBox(height: Gaps.sm),
                  _Records(value: records!, query: recQuery!),
                  const SizedBox(height: Gaps.lg),
                  SecondaryButton(label: isParent ? 'Apply for leave' : 'Request leave', icon: Icons.event_busy_outlined, onPressed: () => context.push(SharedRoutes.leave)),
                ],
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.s});
  final AttendanceSummary s;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = s.totals;
    final pct = c.percentage;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: Gaps.sm,
            children: [
              Text('${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%', style: figureStyle(context, size: 40)),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('attendance this year', style: context.text.bodySmall)),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: (pct / 100).clamp(0, 1).toDouble(), minHeight: 6, color: s.isShort ? t.danger : t.brand.solid)),
          if (s.isShort) Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: InfoBanner(tone: BannerTone.danger, icon: Icons.warning_amber_rounded, message: 'Attendance is below the ${s.thresholdPercent.toStringAsFixed(0)}% the school requires.')),
          const Divider(height: Gaps.xl),
          Wrap(
            spacing: Gaps.xl,
            runSpacing: Gaps.md,
            children: [
              _Count('Present', c.present, t.success, Icons.check_rounded),
              _Count('Late', c.late, t.warning, Icons.schedule_rounded),
              _Count('Absent', c.absent, t.danger, Icons.close_rounded),
              _Count('Leave', c.leave, t.brand.ink, Icons.event_busy_rounded),
              if (c.halfDay > 0) _Count('Half day', c.halfDay, t.warning, Icons.timelapse_rounded),
            ],
          ),
          if (s.from != null && s.to != null) Padding(padding: const EdgeInsets.only(top: Gaps.md), child: Text('${fmtShort(s.from!)} to ${fmtShort(s.to!)}  ·  ${plural(c.total, 'school day')}', style: context.text.bodySmall)),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.label, this.value, this.color, this.icon);
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(label, style: context.text.labelSmall)]),
      Text('$value', style: figureStyle(context, size: 24)),
    ],
  );
}

class _MonthChart extends StatelessWidget {
  const _MonthChart({required this.months});
  final List<AttendanceMonth> months;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final list = months.length > 8 ? months.sublist(months.length - 8) : months;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(Gaps.sm, Gaps.lg, Gaps.lg, Gaps.sm),
      child: Semantics(
        label: 'Attendance by month. ${list.map((m) => '${_monthLabel(m.month)} ${m.counts.percentage.toStringAsFixed(0)} percent').join(', ')}.',
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: 100,
              minY: 0,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(drawVerticalLine: false, horizontalInterval: 25, getDrawingHorizontalLine: (_) => FlLine(color: t.border, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 25, getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: TextStyle(fontSize: 11, color: t.textTertiary)))),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (v, _) => Padding(padding: const EdgeInsets.only(top: 6), child: Text(_monthLabel(list[v.toInt()].month), style: TextStyle(fontSize: 11, color: t.textSecondary))))),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => t.text,
                  getTooltipItem: (group, _, rod, _) {
                    final m = list[group.x];
                    return BarTooltipItem('${_monthLabel(m.month)}\n${m.counts.percentage.toStringAsFixed(1)}%  (${m.counts.present + m.counts.late} of ${m.counts.total} days)', TextStyle(color: t.surface, fontSize: 12, fontWeight: FontWeight.w500));
                  },
                ),
              ),
              barGroups: [
                for (final (i, m) in list.indexed)
                  BarChartGroupData(x: i, barRods: [BarChartRodData(toY: m.counts.percentage, width: 18, color: t.brand.solid, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)), backDrawRodData: BackgroundBarChartRodData(show: true, toY: 100, color: t.sunken))]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _monthLabel(String ym) {
  final p = ym.split('-');
  if (p.length < 2) return ym;
  return DateFormat('MMM').format(DateTime(int.tryParse(p[0]) ?? 2000, int.tryParse(p[1]) ?? 1));
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({required this.months});
  final List<AttendanceMonth> months;

  @override
  Widget build(BuildContext context) => RowGroup(
    children: [
      for (final m in months.reversed)
        ListRow(
          title: DateFormat('MMMM y').format(DateTime(int.tryParse(m.month.split('-').first) ?? 2000, int.tryParse(m.month.split('-').last) ?? 1)),
          subtitle: '${m.counts.present} present, ${m.counts.late} late, ${m.counts.absent} absent, ${m.counts.leave} leave',
          dense: true,
          chevron: false,
          trailing: Text('${m.counts.percentage.toStringAsFixed(0)}%', style: figureStyle(context, size: 20)),
        ),
    ],
  );
}

class _Records extends ConsumerWidget {
  const _Records({required this.value, required this.query});
  final AsyncValue<CursorList<AttendanceRecord>> value;
  final RecordsQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return value.when(
      loading: () => const SkeletonList(count: 3, padding: EdgeInsets.zero),
      error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(attendanceRecordsProvider(query))),
      data: (l) {
        if (l.items.isEmpty) return const EmptyState(illo: Illo.noResults, title: 'No records', message: 'There is no attendance to show for this filter.', compact: true);
        return Column(
          children: [
            RowGroup(
              children: [
                for (final r in l.items)
                  ListRow(
                    title: fmtDay(r.date),
                    subtitle: [if (r.periodName != null) r.periodName!, if (r.subjectName != null) r.subjectName!, if (r.remarks != null) r.remarks!, if (r.correctionPending) 'Correction requested'].join('  ·  '),
                    dense: true,
                    chevron: false,
                    trailing: StatusChip(
                      r.status.label,
                      tone: switch (r.status) { AttendanceStatus.present => StatusTone.success, AttendanceStatus.late || AttendanceStatus.halfDay => StatusTone.warning, AttendanceStatus.absent => StatusTone.danger, AttendanceStatus.leave => StatusTone.info },
                      icon: switch (r.status) { AttendanceStatus.present => Icons.check_rounded, AttendanceStatus.absent => Icons.close_rounded, AttendanceStatus.late => Icons.schedule_rounded, AttendanceStatus.leave => Icons.event_busy_rounded, AttendanceStatus.halfDay => Icons.timelapse_rounded },
                    ),
                  ),
              ],
            ),
            CursorFooter(list: l, onMore: () => ref.read(attendanceRecordsProvider(query).notifier).loadMore()),
            if (!l.hasMore) Padding(padding: const EdgeInsets.only(top: Gaps.xs), child: Text('That is everything', style: context.text.bodySmall?.copyWith(color: t.textTertiary))),
          ],
        );
      },
    );
  }
}
