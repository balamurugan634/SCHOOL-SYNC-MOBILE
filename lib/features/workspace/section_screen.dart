import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/me.dart';
import '../../data/models/staff/people.dart';
import '../../data/models/staff/roll_call.dart';
import '../../data/models/staff/teaching.dart';
import '../../router/routes_teacher.dart';
import 'role_paths.dart';
import 'section_providers.dart';
import 'workspace.dart';

/// One class: its students, syllabus coverage and attendance. Shared by teachers ("My classes") and management
/// (Academics); each part appears only when the person holds the matching permission.
class SectionScreen extends ConsumerWidget {
  const SectionScreen({super.key, required this.sectionId});
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(sectionDetailProvider(sectionId));
    final tabs = <(String, Widget Function())>[
      if (ref.can('students:view') || !ref.canAny(const ['syllabus:view', 'attendance:view'])) ('Students', () => _StudentsTab(sectionId: sectionId)),
      if (ref.can('syllabus:view')) ('Syllabus', () => _SyllabusTab(sectionId: sectionId)),
      if (ref.can('attendance:view')) ('Attendance', () => _AttendanceTab(sectionId: sectionId)),
    ];
    final title = detail.value?.section.title ?? 'Class';
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          bottom: tabs.length < 2 ? null : TabBar(tabs: [for (final t in tabs) Tab(text: t.$1)]),
        ),
        body: Column(
          children: [
            _Header(sectionId: sectionId, detail: detail, onRetry: () => ref.invalidate(sectionDetailProvider(sectionId))),
            Expanded(child: TabBarView(children: [for (final t in tabs) t.$2()])),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.sectionId, required this.detail, required this.onRetry});
  final String sectionId;
  final AsyncValue<SectionDetail> detail;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Widget content;
    if (detail.hasValue) {
      final d = detail.requireValue;
      final s = d.section;
      final facts = [
        plural(s.studentCount, 'student'),
        if (s.capacity != null) 'capacity ${s.capacity}',
        if (s.room != null && s.room!.isNotEmpty) 'Room ${s.room}',
      ].join('  ·  ');
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(facts, style: context.text.bodyMedium),
          if (s.classTeacherName != null) Text('Class teacher: ${s.classTeacherName}', style: context.text.bodySmall),
          if (d.teaching.isNotEmpty) ...[
            const SizedBox(height: Gaps.xs),
            Text(d.teaching.map((a) => '${a.subjectName} (${a.staffName})').join(', '), maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: t.textTertiary)),
          ],
        ],
      );
    } else if (detail.hasError) {
      content = Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: t.danger), const SizedBox(width: Gaps.sm), Expanded(child: Text(friendlyError(detail.error!), style: context.text.bodySmall)), TextButton(onPressed: onRetry, child: const Text('Retry'))]);
    } else {
      content = const SizedBox(height: 40, child: Align(alignment: Alignment.centerLeft, child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))));
    }
    return Container(
      width: double.infinity,
      color: t.surface,
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.md),
      child: content,
    );
  }
}

// ───────────────────────────── students ─────────────────────────────

class _StudentsTab extends ConsumerStatefulWidget {
  const _StudentsTab({required this.sectionId});
  final String sectionId;

  @override
  ConsumerState<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends ConsumerState<_StudentsTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final provider = sectionStudentsProvider(widget.sectionId);
    final value = ref.watch(provider);
    final experience = ref.watch(staffMeProvider.select((m) => m?.experience)) ?? Experience.teacher;
    Future<void> refresh() async {
      ref.invalidate(provider);
      ref.invalidate(sectionDetailProvider(widget.sectionId));
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return AsyncBody<List<StudentRow>>(
      value: value,
      onRetry: () => ref.invalidate(provider),
      isEmpty: (l) => l.isEmpty,
      empty: const EmptyState(illo: Illo.emptyGeneric, title: 'No students in this class yet', message: 'Students appear here once they are enrolled in the section.'),
      data: (all) {
        final q = _q.trim().toLowerCase();
        final list = q.isEmpty ? all : all.where((s) => s.name.toLowerCase().contains(q) || s.admissionNo.toLowerCase().contains(q)).toList();
        return RefreshScroll(
          onRefresh: refresh,
          children: [
            if (all.length > 10)
              Padding(
                padding: const EdgeInsets.only(bottom: Gaps.md),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(hintText: 'Search by name or admission number', prefixIcon: Icon(Icons.search_rounded)),
                ),
              ),
            if (list.isEmpty)
              EmptyState(illo: Illo.noResults, title: 'No student matches "$_q"', actionLabel: 'Clear search', onAction: () => setState(() => _q = ''), compact: true)
            else
              RowGroup(
                children: [
                  for (final s in list)
                    PersonTile(
                      name: s.name,
                      subtitle: [s.admissionNo, if (s.status != 'active') s.status].join('  ·  '),
                      photoUrl: s.photoUrl,
                      leadingNumber: s.rollNo,
                      onTap: () => context.push(RolePaths.student(experience, s.id)),
                    ),
                ],
              ),
          ],
        );
      },
    );
  }
}

// ───────────────────────────── syllabus ─────────────────────────────

class _SyllabusTab extends ConsumerWidget {
  const _SyllabusTab({required this.sectionId});
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sectionCoverageProvider(sectionId);
    final value = ref.watch(provider);
    final isTeacher = ref.watch(staffMeProvider.select((m) => m?.experience)) == Experience.teacher;
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return AsyncBody<List<CoverageRow>>(
      value: value,
      onRetry: () => ref.invalidate(provider),
      isEmpty: (l) => l.isEmpty,
      empty: const EmptyState(icon: Icons.menu_book_outlined, title: 'No syllabus yet', message: 'Syllabus topics have not been set up for this class.'),
      data: (rows) {
        final overall = rows.isEmpty ? 0.0 : rows.fold<double>(0, (a, r) => a + r.percent) / rows.length;
        return RefreshScroll(
          onRefresh: refresh,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Average coverage', style: context.text.labelSmall?.copyWith(color: context.tokens.textSecondary)),
                  Text('${overall.toStringAsFixed(overall % 1 == 0 ? 0 : 1)}%', style: figureStyle(context, size: 32)),
                  const SizedBox(height: Gaps.xs),
                  MeterBar(value: overall / 100, semanticLabel: 'Average syllabus coverage'),
                  if (isTeacher && ref.can('syllabus:edit')) ...[const SizedBox(height: Gaps.md), SecondaryButton(label: 'Update progress', icon: Icons.edit_note_rounded, onPressed: () => context.push(TeacherRoutes.syllabusFor(sectionId)))],
                ],
              ),
            ),
            const SizedBox(height: Gaps.md),
            RowGroup(
              padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
              children: [for (final r in rows) _CoverageTile(r)],
            ),
          ],
        );
      },
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile(this.r);
  final CoverageRow r;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(r.subjectName, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        const SizedBox(height: Gaps.xs),
        MeterBar(value: r.percent / 100, label: '${r.percent.toStringAsFixed(r.percent % 1 == 0 ? 0 : 1)}%', semanticLabel: '${r.subjectName} syllabus coverage'),
        const SizedBox(height: 2),
        Text('${r.completed} of ${plural(r.totalTopics, 'topic')} done${r.inProgress > 0 ? ', ${r.inProgress} in progress' : ''}', style: context.text.bodySmall),
      ],
    ),
  );
}

// ───────────────────────────── attendance ─────────────────────────────

class _AttendanceTab extends ConsumerWidget {
  const _AttendanceTab({required this.sectionId});
  final String sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = sectionAttendanceProvider(sectionId);
    final value = ref.watch(provider);
    final leads = ref.watch(classTeacherSectionIdsProvider).contains(sectionId) && ref.can('attendance:create');
    final experience = ref.watch(staffMeProvider.select((m) => m?.experience)) ?? Experience.teacher;
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return AsyncBody<SectionAttendanceSummary>(
      value: value,
      onRetry: () => ref.invalidate(provider),
      isEmpty: (s) => s.students.isEmpty,
      empty: const EmptyState(icon: Icons.fact_check_outlined, title: 'No attendance yet', message: 'Once a roll call is submitted, the class percentages appear here.'),
      data: (s) {
        final students = [...s.students]..sort((a, b) => (a.totals.percentage).compareTo(b.totals.percentage));
        final t = context.tokens;
        final pct = s.totals.percentage;
        final short = students.where((x) => x.isShort).length;
        return RefreshScroll(
          onRefresh: refresh,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last 30 days', style: context.text.labelSmall?.copyWith(color: t.textSecondary)),
                  Text(s.totals.total == 0 ? '-' : '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%', style: figureStyle(context, size: 32)),
                  Text(
                    s.totals.total == 0 ? 'No roll calls in this period.' : '${s.totals.present + s.totals.late + s.totals.halfDay} present of ${s.totals.total} marks. ${s.totals.absent} absent, ${s.totals.late} late, ${s.totals.leave} on leave.',
                    style: context.text.bodySmall,
                  ),
                  if (short > 0) Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: StatusChip('$short ${short == 1 ? 'student' : 'students'} below the requirement', tone: StatusTone.danger, icon: Icons.warning_amber_rounded)),
                  if (leads) ...[const SizedBox(height: Gaps.md), PrimaryButton(label: 'Take today\'s roll call', icon: Icons.fact_check_outlined, onPressed: () => context.push(TeacherRoutes.rollCall(sectionId)))],
                ],
              ),
            ),
            const SizedBox(height: Gaps.md),
            const GroupLabel('Students, lowest first'),
            RowGroup(
              children: [
                for (final x in students)
                  PersonTile(
                    name: x.name,
                    subtitle: x.totals.total == 0 ? 'No marks yet' : '${x.totals.absent} absent, ${x.totals.late} late',
                    leadingNumber: x.rollNo,
                    onTap: () => context.push(RolePaths.student(experience, x.studentId)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (x.isShort) const Padding(padding: EdgeInsets.only(right: Gaps.sm), child: StatusChip('Short', tone: StatusTone.danger, icon: Icons.warning_amber_rounded)),
                        Text(x.totals.total == 0 ? '-' : '${x.totals.percentage.toStringAsFixed(x.totals.percentage % 1 == 0 ? 0 : 1)}%', style: context.text.labelLarge?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
