import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';
import 'attendance_providers.dart';
import 'roll_call_widgets.dart';

/// Today: the sections (or period slots) I take attendance for, marked or not, one tap from the roll call.
class TodaySection extends ConsumerWidget {
  const TodaySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(attendanceTodayProvider);
    Future<void> refresh() async {
      ref.invalidate(attendanceTodayProvider);
      try {
        await ref.read(attendanceTodayProvider.future);
      } catch (_) {}
    }

    return AsyncBody<AttendanceToday>(
      value: v,
      onRetry: () => ref.invalidate(attendanceTodayProvider),
      data: (d) => RefreshScroll(
        onRefresh: refresh,
        children: [
          if (!d.isWorkingDay || d.holiday != null) ...[
            InfoBanner(tone: BannerTone.info, icon: Icons.event_outlined, title: d.holiday != null ? 'Holiday: ${d.holiday}' : 'No school today', message: 'Attendance cannot be taken today. You can still open earlier days from History.'),
            const SizedBox(height: Gaps.md),
          ],
          if (d.items.isEmpty)
            EmptyState(
              icon: Icons.fact_check_outlined,
              title: 'No attendance to take today',
              message: d.mode == 'period' ? 'You have no teaching periods today.' : 'In this school only the class teacher takes the daily roll call. If you lead a class it will appear here.',
              compact: true,
            )
          else ...[
            _Summary(today: d),
            const SizedBox(height: Gaps.md),
            for (final item in d.items) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: _TodayCard(item: item, periodMode: d.mode == 'period')),
          ],
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.today});
  final AttendanceToday today;

  @override
  Widget build(BuildContext context) {
    final total = today.items.length;
    final marked = total - today.pendingCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(fmtDayLong(today.date), style: context.text.bodySmall),
        const SizedBox(height: Gaps.xs),
        Text(today.pendingCount == 0 ? 'All marked for today' : '${today.pendingCount} not yet marked', style: context.text.titleMedium),
        const SizedBox(height: Gaps.sm),
        MeterBar(value: total == 0 ? 0 : marked / total, label: '$marked of $total marked', semanticLabel: 'Sections marked today'),
      ],
    );
  }
}

class _TodayCard extends ConsumerWidget {
  const _TodayCard({required this.item, required this.periodMode});
  final AttendanceTodayItem item;
  final bool periodMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final canMark = ref.can('attendance:create');
    final path = TeacherRoutes.rollCall(item.sectionId, periodId: item.periodId);
    final detail = [if (periodMode && item.periodName != null) item.periodName!, ?item.subjectName, plural(item.strength, 'student')].join(' · ');
    // A column, not a row: the state chip never competes with the class name for width (text can scale to 200%).
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.sectionName, style: context.text.titleMedium),
        const SizedBox(height: 2),
        Text(detail, style: context.text.bodySmall),
        const SizedBox(height: Gaps.sm),
        item.marked ? const StatusChip('Marked', tone: StatusTone.success, icon: Icons.check_rounded) : const StatusChip('Not yet marked', tone: StatusTone.warning, icon: Icons.schedule_rounded),
      ],
    );
    if (item.marked) {
      return AppCard(
        onTap: () => context.push(path),
        semanticLabel: '${item.sectionName}, marked. Open to review',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            header,
            if (item.counts != null) ...[const SizedBox(height: Gaps.sm), CountChips(counts: item.counts!)],
            const SizedBox(height: Gaps.sm),
            Row(children: [Expanded(child: Text(canMark ? 'Review or change' : 'View', style: context.text.labelMedium?.copyWith(color: t.brand.ink))), Icon(Icons.chevron_right_rounded, color: t.textTertiary)]),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, const SizedBox(height: Gaps.md), PrimaryButton(label: canMark ? 'Take attendance' : 'Open', icon: canMark ? Icons.touch_app_outlined : Icons.visibility_outlined, onPressed: () => context.push(path))],
      ),
    );
  }
}
