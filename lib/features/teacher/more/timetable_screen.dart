import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';
import 'more_providers.dart';

DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
DateTime _plusDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// My week: pick a day, see each period with its class, room and any cover arrangement.
class TeacherTimetableScreen extends ConsumerStatefulWidget {
  const TeacherTimetableScreen({super.key});

  @override
  ConsumerState<TeacherTimetableScreen> createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends ConsumerState<TeacherTimetableScreen> {
  late DateTime _selected = _midnight(DateTime.now());
  DateTime get _monday => _mondayOf(_selected);

  void _shiftWeek(int weeks) => setState(() => _selected = _plusDays(_selected, 7 * weeks));

  @override
  Widget build(BuildContext context) {
    final today = _midnight(DateTime.now());
    final thisWeek = _monday == _mondayOf(today);
    // Mon-Sat; Sunday only when it is the selected day (so a Sunday check still works).
    final days = [for (var i = 0; i < (_selected.weekday == 7 ? 7 : 6); i++) _plusDays(_monday, i)];
    final provider = teacherDayProvider(_selected);
    final value = ref.watch(provider);
    final weekLabel = thisWeek ? 'This week' : '${DateFormat('d MMM').format(_monday)} to ${DateFormat('d MMM').format(_plusDays(_monday, 5))}';

    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return FeatureGate(
      label: 'Timetable',
      anyPermission: const ['timetable:view'],
      child: StaffFrame(
        title: 'Timetable',
        actions: [if (_selected != today) TextButton(onPressed: () => setState(() => _selected = today), child: const Text('Today'))],
        headerExtra: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gaps.xs),
              child: Row(
                children: [
                  IconButton(tooltip: 'Previous week', onPressed: () => _shiftWeek(-1), icon: const Icon(Icons.chevron_left_rounded)),
                  Expanded(child: Semantics(liveRegion: true, child: Text(weekLabel, textAlign: TextAlign.center, style: context.text.titleSmall))),
                  IconButton(tooltip: 'Next week', onPressed: () => _shiftWeek(1), icon: const Icon(Icons.chevron_right_rounded)),
                ],
              ),
            ),
            _DayStrip(days: days, selected: _selected, today: today, onSelect: (d) => setState(() => _selected = d)),
            const SizedBox(height: Gaps.sm),
          ],
        ),
        body: AsyncBody<TeacherDay>(
          value: value,
          onRetry: () => ref.invalidate(provider),
          data: (d) => RefreshScroll(
            onRefresh: refresh,
            children: [
              Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: Text(fmtDayLong(_selected), style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary))),
              if (!d.isWorkingDay)
                ConstrainedBox(constraints: const BoxConstraints(minHeight: 320), child: const EmptyState(icon: Icons.event_busy_outlined, title: 'No school on this day', message: 'It is not a working day, so there are no lessons.'))
              else if (d.entries.isEmpty)
                ConstrainedBox(constraints: const BoxConstraints(minHeight: 320), child: const EmptyState(illo: Illo.emptyEvents, title: 'No lessons this day', message: 'Nothing is timetabled for you on this day.'))
              else
                RowGroup(children: [for (final e in d.entries) _PeriodRow(e)]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({required this.days, required this.selected, required this.today, required this.onSelect});
  final List<DateTime> days;
  final DateTime selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Semantics(
                button: true,
                selected: d == selected,
                label: '${DateFormat('EEEE d MMMM').format(d)}${d == today ? ', today' : ''}',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.lg),
                  onTap: () => onSelect(d),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: d == selected ? t.brand.soft : null, borderRadius: BorderRadius.circular(Radii.lg), border: Border.all(color: d == selected ? t.brand.solid.withValues(alpha: .5) : Colors.transparent)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('E').format(d), style: context.text.labelSmall?.copyWith(color: d == selected ? t.brand.ink : t.textSecondary)),
                        const SizedBox(height: 2),
                        Text('${d.day}', style: context.text.titleSmall?.copyWith(color: d == selected ? t.brand.ink : t.text, fontWeight: d == selected ? FontWeight.w600 : FontWeight.w500)),
                        const SizedBox(height: 2),
                        // The one amber mark on this screen: today.
                        Container(width: 5, height: 5, decoration: BoxDecoration(color: d == today ? t.accent : Colors.transparent, shape: BoxShape.circle)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow(this.e);
  final TeacherPeriod e;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final time = formatTimeRange(e.startTime, e.endTime);
    if (e.isBreak) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
        child: Row(children: [SizedBox(width: 104, child: Text(time, style: _timeStyle(context, t.textTertiary))), Expanded(child: Text(e.periodName, style: context.text.bodyMedium?.copyWith(color: t.textTertiary)))]),
      );
    }
    final free = e.isFree;
    final covering = e.isCovering;
    final detail = free
        ? 'Free: covered by ${e.substituteTeacherName ?? e.teacherName ?? 'another teacher'}'
        : covering
        ? 'You are covering${e.originalTeacherName == null ? '' : ' for ${e.originalTeacherName}'}'
        : null;
    final lines = [if (e.sectionName != null) e.sectionName!, if (e.room != null) 'Room ${e.room}', e.periodName].join('  ·  ');
    final canOpen = e.sectionId != null && !free;

    return Semantics(
      button: canOpen,
      label: '${e.periodName}, $time. ${e.subjectName ?? ''}. $lines. ${detail ?? ''}${e.isCurrent ? '. Now' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: canOpen ? () => context.push(TeacherRoutes.section(e.sectionId!)) : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          color: e.isCurrent ? t.brand.soft : null,
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 104, child: Padding(padding: const EdgeInsets.only(top: 2), child: Text(time, style: _timeStyle(context, e.isCurrent ? t.brand.ink : t.textSecondary)))),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.subjectName ?? e.periodName, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: free ? t.textTertiary : null)),
                    Text(lines, style: context.text.bodySmall),
                    if (detail != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(detail, style: context.text.labelMedium?.copyWith(color: free ? t.textSecondary : t.warning))),
                  ],
                ),
              ),
              if (e.isCurrent) const Padding(padding: EdgeInsets.only(left: Gaps.sm), child: StatusChip('Now', tone: StatusTone.accent, icon: Icons.play_arrow_rounded))
              else if (free) const Padding(padding: EdgeInsets.only(left: Gaps.sm), child: StatusChip('Free', tone: StatusTone.neutral, icon: Icons.event_available_rounded))
              else if (covering) const Padding(padding: EdgeInsets.only(left: Gaps.sm), child: StatusChip('Cover', tone: StatusTone.warning, icon: Icons.swap_horiz_rounded))
              else if (canOpen) Icon(Icons.chevron_right_rounded, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle? _timeStyle(BuildContext context, Color color) => context.text.labelMedium?.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]);
}
