import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/people.dart';
import '../../../router/routes_management.dart';
import '../../workspace/workspace.dart';
import '../charts/hbars.dart';
import '../home/home_blocks.dart';
import '../home/management_home_providers.dart';
import 'academics_providers.dart';

/// Academics tab: classes by grade, attendance today, mark sheets waiting for review, exams, syllabus coverage.
class ManagementAcademicsScreen extends ConsumerWidget {
  const ManagementAcademicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FeatureGate(
      label: 'Academics',
      anyPermission: const ['academics:view', 'exams:view', 'timetable:view', 'attendance:view'],
      child: StaffFrame(
        embedded: true,
        title: 'Academics',
        subtitle: 'Classes, attendance and exams.',
        body: RefreshScroll(
          onRefresh: () async {
            ref.invalidate(managementDashboardProvider);
            ref.invalidate(managementSectionsProvider);
            ref.invalidate(managementCoverageProvider);
            try {
              await Future.wait([ref.read(managementSectionsProvider.future), ref.read(managementCoverageProvider.future)]);
            } catch (_) {}
          },
          children: const [_TodayBlocks(), SizedBox(height: Gaps.md), _SectionsBlock(), SizedBox(height: Gaps.md), _CoverageBlock()],
        ),
      ),
    );
  }
}

/// Attendance today, mark sheets under review and upcoming exams: all from the dashboard payload (null blocks vanish).
class _TodayBlocks extends ConsumerWidget {
  const _TodayBlocks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(managementDashboardProvider);
    final d = v.value?.value;
    if (d == null) {
      if (v.hasError && !v.isLoading) return SizedBox(height: 260, child: ErrorState(compact: true, error: v.error!, onRetry: () => ref.invalidate(managementDashboardProvider)));
      return const SkeletonList(count: 2, padding: EdgeInsets.zero);
    }
    final review = d.approvals.markSheetsForReview;
    final exams = d.upcomingExams;
    return Column(
      children: [
        if (d.attendance != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: HomeAttendanceCard(attendance: d.attendance!, onOpen: () => context.push(ManagementRoutes.attendance))),
        if (review != null)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.md),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: ListRow(title: 'Mark sheets to review', subtitle: review == 0 ? 'Nothing waiting' : '$review waiting for approval', leading: Icons.grading_rounded, onTap: () => context.push(ManagementRoutes.approval('marks')), trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (review > 0) StatusChip('$review', tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded), const Icon(Icons.chevron_right_rounded)])),
            ),
          ),
        if (exams != null) ExamsCard(exams: exams, underReview: d.examsUnderReview),
      ],
    );
  }
}

class _SectionsBlock extends ConsumerWidget {
  const _SectionsBlock();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(managementSectionsProvider);
    return v.when(
      loading: () => const SkeletonList(count: 2, padding: EdgeInsets.zero),
      error: (e, _) => _hideIfForbidden(e, SizedBox(height: 240, child: ErrorState(compact: true, error: e, onRetry: () => ref.invalidate(managementSectionsProvider)))),
      data: (sections) {
        if (sections.isEmpty) return const AppCard(child: EmptyState(compact: true, icon: Icons.groups_outlined, title: 'No classes yet', message: 'Classes for the current academic year will appear here.'));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GroupLabel('Classes'),
            for (final (grade, list) in groupSectionsByGrade(sections))
              Padding(
                padding: const EdgeInsets.only(bottom: Gaps.sm),
                child: SectionCard(
                  title: grade,
                  padding: const EdgeInsets.only(bottom: Gaps.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.xs), child: Text('${plural(list.length, 'class', 'classes')}, ${plural(list.fold<int>(0, (a, s) => a + s.studentCount), 'student')}', style: context.text.bodySmall)),
                      for (final s in list) _SectionRow(s),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

Widget _hideIfForbidden(Object e, Widget child) => AppException.from(e).kind == ErrorKind.forbidden ? const SizedBox.shrink() : child;

class _SectionRow extends StatelessWidget {
  const _SectionRow(this.s);
  final SectionItem s;

  @override
  Widget build(BuildContext context) => ListRow(
    title: s.title,
    subtitle: [s.classTeacherName ?? 'No class teacher yet', plural(s.studentCount, 'student'), if (s.room != null) 'Room ${s.room}'].join('  ·  '),
    onTap: () => context.push(ManagementRoutes.section(s.id)),
  );
}

class _CoverageBlock extends ConsumerStatefulWidget {
  const _CoverageBlock();

  @override
  ConsumerState<_CoverageBlock> createState() => _CoverageBlockState();
}

class _CoverageBlockState extends ConsumerState<_CoverageBlock> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(managementCoverageProvider);
    return v.when(
      loading: () => const SkeletonList(count: 1, padding: EdgeInsets.zero),
      error: (e, _) => _hideIfForbidden(e, SizedBox(height: 240, child: ErrorState(compact: true, error: e, onRetry: () => ref.invalidate(managementCoverageProvider)))),
      data: (rows) {
        final list = aggregateCoverage(rows);
        if (list.isEmpty) return const SizedBox.shrink();
        final shown = _all ? list : list.take(8).toList();
        return SectionCard(
          title: 'Syllabus coverage',
          action: list.length > 8 ? (_all ? 'Less' : 'All ${list.length}') : null,
          onAction: () => setState(() => _all = !_all),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_all ? 'Lowest coverage first.' : 'Lowest coverage first. Topics completed out of all topics of the grade.', style: context.text.bodySmall),
              const SizedBox(height: Gaps.sm),
              HorizontalBars(max: 100, items: [for (final c in shown) BarItem(label: '${c.gradeName}, ${c.subjectName}', value: c.percent, text: '${c.percent.toStringAsFixed(c.percent == c.percent.roundToDouble() ? 0 : 1)}%')]),
            ],
          ),
        );
      },
    );
  }
}
