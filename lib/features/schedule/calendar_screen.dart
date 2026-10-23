import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/schedule.dart';
import '../dashboard/dashboard_widgets.dart';
import '../learner/screen_frame.dart';
import 'schedule_providers.dart';
import 'timetable_view.dart';

enum _Mode { agenda, timetable }

/// Calendar (events, holidays, exam papers, homework due) and the weekly timetable.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.embedded = false, this.initialTimetable = false});
  final bool embedded;
  final bool initialTimetable;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late _Mode _mode = widget.initialTimetable ? _Mode.timetable : _Mode.agenda;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _day;
  CalendarKind? _kind;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: _mode == _Mode.timetable ? 'Timetable' : 'Calendar',
      subtitle: widget.embedded ? 'Timetable, exams, holidays and events.' : null,
      embedded: widget.embedded,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Mode>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: _Mode.agenda, label: Text('Calendar'), icon: Icon(Icons.calendar_month_outlined, size: 18)), ButtonSegment(value: _Mode.timetable, label: Text('Timetable'), icon: Icon(Icons.schedule_rounded, size: 18))],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
          ),
          Expanded(child: _mode == _Mode.timetable ? const TimetableView() : _agenda(context)),
        ],
      ),
    );
  }

  Widget _agenda(BuildContext context) {
    final t = context.tokens;
    final v = ref.watch(calendarMonthProvider(_month));
    Future<void> refresh() async {
      ref.invalidate(calendarMonthProvider(_month));
      try {
        await ref.read(calendarMonthProvider(_month).future);
      } catch (_) {}
    }

    return AsyncBody<List<CalendarItem>>(
      value: v,
      onRetry: refresh,
      data: (all) {
        final items = all.where((c) => (_kind == null || c.kind == _kind) && (_day == null || c.occursOn(_day!))).toList();
        return RefreshScroll(
          onRefresh: refresh,
          children: [
            Row(
              children: [
                IconButton(tooltip: 'Previous month', onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month - 1);
                  _day = null;
                }), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: Center(child: Text(DateFormat('MMMM y').format(_month), style: context.text.titleLarge))),
                IconButton(tooltip: 'Next month', onPressed: () => setState(() {
                  _month = DateTime(_month.year, _month.month + 1);
                  _day = null;
                }), icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            AppCard(padding: const EdgeInsets.all(Gaps.sm), child: _MonthGrid(month: _month, items: all, selected: _day, onSelect: (d) => setState(() => _day = sameDayN(_day, d) ? null : d))),
            const SizedBox(height: Gaps.md),
            FilterChips<CalendarKind?>(
              options: const [null, CalendarKind.event, CalendarKind.holiday, CalendarKind.exam, CalendarKind.homeworkDue],
              selected: _kind,
              onSelected: (k) => setState(() => _kind = k),
              labelOf: (k) => k == null ? 'All' : (k == CalendarKind.homeworkDue ? 'Homework' : '${k.label}s'),
              padding: EdgeInsets.zero,
            ),
            GroupLabel(_day == null ? 'This month' : fmtDayLong(_day!), trailing: _day == null ? null : TextButton(onPressed: () => setState(() => _day = null), child: const Text('Show all'))),
            if (items.isEmpty)
              EmptyState(illo: all.isEmpty ? Illo.emptyEvents : Illo.noResults, title: all.isEmpty ? 'Nothing scheduled' : 'Nothing matches', message: all.isEmpty ? 'No events, holidays or deadlines in ${DateFormat('MMMM').format(_month)}.' : 'Try another day or filter.', compact: true)
            else
              RowGroup(children: [for (final c in items) CalendarRow(c)]),
            if (_kind == null && _day == null) Padding(padding: const EdgeInsets.only(top: Gaps.md), child: Text('Dots show days with something on: ${_legend(t)}', style: context.text.bodySmall)),
          ],
        );
      },
    );
  }

  static String _legend(SchoolSyncTheme t) => 'brand = event or homework, amber = exam, green = holiday.';

  bool sameDayN(DateTime? a, DateTime b) => a != null && sameDay(a, b);
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.items, required this.selected, required this.onSelect});
  final DateTime month;
  final List<CalendarItem> items;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday - 1; // Monday first
    final today = DateTime.now();
    final cells = <Widget>[
      for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Center(child: Text(d, style: context.text.labelSmall?.copyWith(color: t.textTertiary))),
      for (var i = 0; i < lead; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++) _cell(context, DateTime(month.year, month.month, day), today),
    ];
    return GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.05, children: cells);
  }

  Widget _cell(BuildContext context, DateTime d, DateTime today) {
    final t = context.tokens;
    final on = items.where((c) => c.occursOn(d)).toList();
    final isToday = sameDay(d, today);
    final sel = selected != null && sameDay(selected!, d);
    Color? dot;
    if (on.any((c) => c.kind == CalendarKind.exam)) {
      dot = t.accent;
    } else if (on.any((c) => c.kind == CalendarKind.holiday)) {
      dot = t.success;
    } else if (on.isNotEmpty) {
      dot = t.brand.solid;
    }
    return Semantics(
      button: true,
      label: '${fmtDayLong(d)}${on.isEmpty ? '' : ', ${plural(on.length, 'item')}'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => onSelect(d),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: sel ? t.brand.soft : null, borderRadius: BorderRadius.circular(Radii.md), border: isToday ? Border.all(color: t.brand.solid) : null),
          // A calendar cell has a fixed shape: keep its digits readable but never let them outgrow it.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${d.day}', style: context.text.bodyMedium?.copyWith(fontWeight: isToday || sel ? FontWeight.w600 : FontWeight.w400, color: sel ? t.brand.ink : null)),
                  const SizedBox(height: 3),
                  Container(width: 5, height: 5, decoration: BoxDecoration(color: dot ?? Colors.transparent, shape: BoxShape.circle)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
