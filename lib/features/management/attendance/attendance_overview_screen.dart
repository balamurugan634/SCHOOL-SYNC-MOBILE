import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../router/routes_management.dart';
import '../../workspace/workspace.dart';
import '../charts/attendance_trend_chart.dart';
import 'attendance_providers.dart';
import 'attendance_widgets.dart';

/// School-wide attendance for a day: totals, the 7 / 14 day trend, one card per class (unmarked first) and who is absent.
class AttendanceOverviewScreen extends ConsumerStatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  ConsumerState<AttendanceOverviewScreen> createState() => _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState extends ConsumerState<AttendanceOverviewScreen> {
  DateTime? _date;
  int _trend = 7;

  DateTime get _day {
    final n = DateTime.now();
    return _date ?? DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _date == null || sameDay(_date!, DateTime.now());

  Future<void> _pick() async {
    final picked = await pickDay(context, initial: _day, lastDate: DateTime.now(), help: 'Attendance for');
    if (picked != null) setState(() => _date = sameDay(picked, DateTime.now()) ? null : picked);
  }

  void _step(int days) {
    final next = _day.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _date = sameDay(next, DateTime.now()) ? null : next);
  }

  @override
  Widget build(BuildContext context) {
    final q = (date: _date, trendDays: _trend);
    final provider = schoolAttendanceProvider(q);
    final t = context.tokens;
    return StaffFrame(
      title: 'Attendance',
      actions: [IconButton(tooltip: 'Pick a date', onPressed: _pick, icon: const Icon(Icons.calendar_month_outlined))],
      headerExtra: Padding(
        padding: const EdgeInsets.fromLTRB(Gaps.sm, Gaps.sm, Gaps.sm, 0),
        child: Row(
          children: [
            IconButton(tooltip: 'Previous day', onPressed: () => _step(-1), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: Semantics(liveRegion: true, child: Text(relativeDay(_day) == 'Today' ? 'Today, ${fmtShort(_day)}' : fmtDay(_day), textAlign: TextAlign.center, style: context.text.titleMedium))),
            IconButton(tooltip: 'Next day', onPressed: _isToday ? null : () => _step(1), icon: const Icon(Icons.chevron_right_rounded)),
          ],
        ),
      ),
      body: AsyncBody<SchoolAttendance>(
        value: ref.watch(provider),
        onRetry: () => ref.invalidate(provider),
        data: (a) => RefreshScroll(
          onRefresh: () async {
            ref.invalidate(provider);
            try {
              await ref.read(provider.future);
            } catch (_) {}
          },
          children: [
            if (a.holiday != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(icon: Icons.event_outlined, title: 'Holiday', message: '${a.holiday}. No roll call is expected.'))
            else if (!a.isWorkingDay) const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(icon: Icons.event_outlined, title: 'Not a school day', message: 'No roll call is expected on this date.')),
            _TotalsCard(a: a),
            const SizedBox(height: Gaps.md),
            SectionCard(
              title: 'Trend',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: double.infinity, child: SegmentedButton<int>(showSelectedIcon: false, segments: const [ButtonSegment(value: 7, label: Text('7 days')), ButtonSegment(value: 14, label: Text('14 days'))], selected: {_trend}, onSelectionChanged: (s) => setState(() => _trend = s.first))),
                  const SizedBox(height: Gaps.md),
                  AttendanceTrendChart(points: a.trend),
                ],
              ),
            ),
            if (a.sections.isNotEmpty) ...[
              const GroupLabel('Classes'),
              for (final s in sortSectionRows(a.sections)) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: _SectionTile(row: s)),
            ],
            GroupLabel(a.absenteesTotal == 0 ? 'Absent' : 'Absent (${a.absenteesTotal})'),
            if (a.absentees.isEmpty)
              AppCard(child: QuietLine(a.isWorkingDay && a.holiday == null ? 'No one is marked absent.' : 'Nothing to show for this date.', icon: Icons.check_circle_outline_rounded))
            else
              RowGroup(children: [for (final x in a.absentees) PersonTile(name: x.name, subtitle: [x.sectionName, if (x.remarks != null) x.remarks!].join('  ·  '), trailing: const AttendanceChip(AttendanceStatus.absent), onTap: () => context.push(ManagementRoutes.student(x.studentId)))]),
            if (a.absenteesTotal > a.absentees.length)
              Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: Text('${a.absenteesTotal - a.absentees.length} more not shown.', style: context.text.bodySmall?.copyWith(color: t.textSecondary))),
          ],
        ),
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.a});
  final SchoolAttendance a;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = a.totals.percentPresent;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: Gaps.sm,
            children: [
              Text(pct == null ? '-' : '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%', style: figureStyle(context, size: 36)),
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('present, ${a.totals.markedStudents} of ${a.totals.activeStudents} students marked', style: context.text.bodySmall)),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          CountsWrap(counts: a.totals.counts),
          const SizedBox(height: Gaps.md),
          MeterBar(value: a.sectionsTotal == 0 ? 0 : a.sectionsMarked / a.sectionsTotal, label: '${a.sectionsMarked} of ${a.sectionsTotal}', semanticLabel: 'Classes that have marked attendance'),
          const SizedBox(height: 4),
          Text(a.sectionsMarked >= a.sectionsTotal ? 'Every class has marked attendance.' : '${plural(a.sectionsTotal - a.sectionsMarked, 'class', 'classes')} not marked yet.', style: context.text.bodySmall?.copyWith(color: a.sectionsMarked >= a.sectionsTotal ? t.textSecondary : t.warning)),
        ],
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({required this.row});
  final SchoolSectionRow row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final pct = row.percentPresent;
    return AppCard(
      onTap: () => context.push(ManagementRoutes.section(row.sectionId)),
      semanticLabel: '${row.title}, ${row.marked ? (pct == null ? 'marked' : '${pct.toStringAsFixed(0)} percent present') : 'not marked'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(row.title, style: context.text.titleSmall)),
              if (row.marked) Text(pct == null ? '-' : '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%', style: context.text.titleMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])) else const StatusChip('Not marked', tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded),
            ],
          ),
          Text([if (row.classTeacherName != null) row.classTeacherName!, '${row.strength} students'].join('  ·  '), style: context.text.bodySmall?.copyWith(color: t.textSecondary)),
          if (row.marked) ...[const SizedBox(height: Gaps.sm), CountsWrap(counts: row.counts, showZero: false)],
        ],
      ),
    );
  }
}
