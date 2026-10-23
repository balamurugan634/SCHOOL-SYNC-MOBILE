import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';
import 'attendance_providers.dart';

String percentText(double? p) => p == null ? '-' : '${p.toStringAsFixed(p % 1 == 0 ? 0 : 1)}%';

/// History: pick one of my sections, open an earlier roll call, and see every student's attendance percentage
/// (students below the school's requirement are flagged).
class HistorySection extends ConsumerStatefulWidget {
  const HistorySection({super.key});

  @override
  ConsumerState<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<HistorySection> {
  String? _sectionId;

  @override
  Widget build(BuildContext context) {
    final sections = ref.watch(attendanceSectionsProvider);
    return AsyncBody<List<SectionItem>>(
      value: sections,
      onRetry: () => ref.invalidate(attendanceSectionsProvider),
      isEmpty: (l) => l.isEmpty,
      empty: const EmptyState(icon: Icons.groups_outlined, title: 'No classes yet', message: 'The classes you teach or lead will appear here once the school assigns them to you.'),
      data: (list) {
        final led = ref.watch(classTeacherSectionIdsProvider);
        final fallback = list.firstWhere((s) => led.contains(s.id), orElse: () => list.first).id;
        final id = list.any((s) => s.id == _sectionId) ? _sectionId! : fallback;
        return Column(
          children: [
            if (list.length > 1) ...[
              const SizedBox(height: Gaps.xs),
              FilterChips<String>(options: [for (final s in list) s.id], selected: id, onSelected: (s) => setState(() => _sectionId = s), labelOf: (s) => list.firstWhere((e) => e.id == s).title),
              const SizedBox(height: Gaps.sm),
            ],
            Expanded(child: _SectionHistory(sectionId: id)),
          ],
        );
      },
    );
  }
}

class _SectionHistory extends ConsumerWidget {
  const _SectionHistory({required this.sectionId});
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sectionAttendanceSummaryProvider(sectionId);
    final v = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return AsyncBody<SectionAttendanceSummary>(
      value: v,
      onRetry: () => ref.invalidate(provider),
      data: (s) {
        final days = s.days.reversed.take(14).toList(growable: false);
        final short = s.students.where((e) => e.isShort).length;
        return RefreshScroll(
          onRefresh: refresh,
          children: [
            SectionCard(
              title: 'Earlier roll calls',
              action: 'Pick a date',
              onAction: () async {
                final d = await pickDay(context, initial: DateTime.now(), lastDate: DateTime.now(), help: 'Open the roll call for');
                if (d != null && context.mounted) await context.push(TeacherRoutes.rollCall(sectionId, date: d));
              },
              padding: EdgeInsets.zero,
              child: days.isEmpty
                  ? const Padding(padding: EdgeInsets.fromLTRB(Gaps.lg, Gaps.xs, Gaps.lg, Gaps.md), child: QuietLine('No roll calls in the last 30 days.'))
                  : Column(
                      children: [
                        for (final d in days)
                          ListRow(
                            title: fmtDay(d.date),
                            subtitle: [if (d.counts.present > 0) '${d.counts.present} present', if (d.counts.absent > 0) '${d.counts.absent} absent', if (d.counts.late > 0) '${d.counts.late} late', if (d.counts.leave > 0) '${d.counts.leave} leave', if (d.counts.halfDay > 0) '${d.counts.halfDay} half day'].join(' · '),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(percentText(d.percentage), style: context.text.labelMedium), const Icon(Icons.chevron_right_rounded)]),
                            onTap: () => context.push(TeacherRoutes.rollCall(sectionId, date: d.date)),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: Gaps.md),
            SectionCard(
              title: 'Students',
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.sm),
                    child: Text(
                      s.totals.total == 0 ? 'No attendance recorded yet.' : 'Class average ${percentText(s.totals.percentage)} from ${fmtShort(s.from)} to ${fmtShort(s.to)}.${short > 0 ? ' $short below the requirement.' : ''}',
                      style: context.text.bodySmall,
                    ),
                  ),
                  if (s.students.isEmpty)
                    const Padding(padding: EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md), child: QuietLine('No students in this class yet.'))
                  else
                    for (final st in s.students)
                      PersonTile(
                        name: st.name,
                        leadingNumber: st.rollNo,
                        subtitle: st.totals.total == 0 ? 'No attendance yet' : '${st.totals.present + st.totals.late + st.totals.halfDay} of ${st.totals.total} days present',
                        trailing: st.isShort ? StatusChip('${percentText(st.totals.percentage)} · short', tone: StatusTone.danger, icon: Icons.warning_amber_rounded) : Text(st.totals.total == 0 ? '-' : percentText(st.totals.percentage), style: context.text.labelMedium),
                        onTap: () => context.push(TeacherRoutes.student(st.studentId)),
                      ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
