import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/schedule.dart';
import 'schedule_providers.dart';

/// Day-of-week tabs and the periods of the chosen day.
class TimetableView extends ConsumerStatefulWidget {
  const TimetableView({super.key});

  @override
  ConsumerState<TimetableView> createState() => _TimetableViewState();
}

class _TimetableViewState extends ConsumerState<TimetableView> {
  late DateTime _date = _dateOnly(DateTime.now());

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday..Saturday of the week containing today (shifted by [weeks]).
  List<DateTime> _week(int weeks) {
    final today = _dateOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1)).add(Duration(days: 7 * weeks));
    return [for (var i = 0; i < 6; i++) monday.add(Duration(days: i))];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final week = _week(0);
    final days = [...week, if (!week.any((d) => sameDay(d, _date))) _date];
    final v = ref.watch(timetableDayProvider(_date));
    Future<void> refresh() async {
      ref.invalidate(timetableDayProvider(_date));
      try {
        await ref.read(timetableDayProvider(_date).future);
      } catch (_) {}
    }

    return Column(
      children: [
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: Gaps.sm),
            itemBuilder: (_, i) {
              final d = days[i];
              final sel = sameDay(d, _date);
              return Semantics(
                button: true,
                selected: sel,
                label: fmtDayLong(d),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  onTap: () => setState(() => _date = d),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    width: 56,
                    decoration: BoxDecoration(color: sel ? t.brand.soft : t.surface, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: sel ? t.brand.solid.withValues(alpha: .5) : t.border)),
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1], style: context.text.labelSmall?.copyWith(color: sel ? t.brand.ink : t.textSecondary)),
                          Text('${d.day}', style: context.text.titleMedium?.copyWith(color: sel ? t.brand.ink : null)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: Gaps.sm),
        Expanded(
          child: AsyncBody<TimetableDay>(
            value: v,
            onRetry: refresh,
            data: (d) => RefreshScroll(
              onRefresh: refresh,
              children: [
                if (!d.isWorkingDay)
                  const EmptyState(illo: Illo.emptyEvents, title: 'No school this day', message: 'It is not a working day.', compact: true)
                else if (d.entries.isEmpty)
                  const EmptyState(illo: Illo.emptyGeneric, title: 'No classes scheduled', compact: true)
                else ...[
                  if (d.sectionName != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: Text(d.sectionName!, style: context.text.bodySmall)),
                  RowGroup(children: [for (final e in d.entries) _PeriodRow(e: e, isToday: sameDay(d.date, DateTime.now()))]),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.e, required this.isToday});
  final TimetableEntry e;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final current = isToday && e.state == 'current';
    return Container(
      color: current ? t.brand.soft : null,
      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: 12),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text('${formatClock(e.startTime)}\n${formatClock(e.endTime)}', style: context.text.labelMedium?.copyWith(color: t.textSecondary, height: 1.3))),
          Expanded(
            child: e.isBreak
                ? Text(e.periodName, style: context.text.bodyMedium?.copyWith(color: t.textTertiary))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.subjectName ?? e.periodName, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      Text([if (e.teacherName != null) e.teacherName!, if (e.room != null) 'Room ${e.room}'].join('  ·  '), style: context.text.bodySmall),
                      if (e.substituted) Text('Cover: ${e.substituteTeacherName ?? 'substitute teacher'}', style: context.text.labelSmall?.copyWith(color: t.warning)),
                    ],
                  ),
          ),
          if (current) const StatusChip('Now', tone: StatusTone.brand),
        ],
      ),
    );
  }
}
