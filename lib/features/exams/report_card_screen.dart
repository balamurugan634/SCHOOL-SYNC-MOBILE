import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../data/models/exams.dart';
import '../../data/repositories/exams_repository.dart';
import '../../data/repositories/files_repository.dart';
import '../learner/learner_context.dart';
import '../security/secure_scope.dart';
import 'exams_providers.dart';

/// A published report card: overall result, subject marks, attendance, teacher remarks, grade scale, PDF.
class ReportCardScreen extends ConsumerStatefulWidget {
  const ReportCardScreen({super.key, required this.examId});
  final String examId;

  @override
  ConsumerState<ReportCardScreen> createState() => _ReportCardScreenState();
}

class _ReportCardScreenState extends ConsumerState<ReportCardScreen> {
  bool _downloading = false;

  Future<void> _pdf(ReportCard rc) async {
    final studentId = ref.read(learnerStudentIdProvider);
    if (studentId == null) return;
    setState(() => _downloading = true);
    try {
      await ref.read(filesRepositoryProvider).openFile(ref.read(examsRepositoryProvider).reportCardPdfPath(widget.examId, studentId), fileName: 'report-card-${rc.result.examName}.pdf');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(reportCardProvider(widget.examId));
    Future<void> refresh() async {
      ref.invalidate(reportCardProvider(widget.examId));
      try {
        await ref.read(reportCardProvider(widget.examId).future);
      } catch (_) {}
    }

    return SecureScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Report card')),
        body: AsyncBody<ReportCard>(
          value: v,
          onRetry: refresh,
          data: (rc) => RefreshScroll(
            onRefresh: refresh,
            children: [
              _Overall(rc: rc),
              const GroupLabel('Subjects'),
              _SubjectTable(subjects: rc.result.subjects),
              if (rc.attendancePercent != null) ...[
                const GroupLabel('Attendance'),
                AppCard(child: Column(children: [FactRow('Attendance', '${rc.attendancePercent!.toStringAsFixed(0)}%', bold: true), if (rc.attendanceDays != null) FactRow('Days present', '${rc.presentDays ?? 0} of ${rc.attendanceDays}')])),
              ],
              if (rc.teacherRemark != null || rc.areasToImprove != null || rc.conduct != null) ...[
                const GroupLabel('Class teacher\'s remarks'),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (rc.teacherRemark != null) Text(rc.teacherRemark!, style: context.text.bodyMedium),
                      if (rc.areasToImprove != null) ...[const SizedBox(height: Gaps.md), Text('To work on', style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary)), Text(rc.areasToImprove!, style: context.text.bodyMedium)],
                      if (rc.conduct != null) ...[const SizedBox(height: Gaps.md), FactRow('Conduct', rc.conduct!)],
                    ],
                  ),
                ),
              ],
              if (rc.gradeScale.isNotEmpty) ...[const GroupLabel('Grade scale'), _Scale(bands: rc.gradeScale)],
              const SizedBox(height: Gaps.lg),
              SecondaryButton(label: _downloading ? 'Preparing PDF' : 'Open as PDF', icon: Icons.picture_as_pdf_outlined, onPressed: _downloading ? null : () => _pdf(rc)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Overall extends StatelessWidget {
  const _Overall({required this.rc});
  final ReportCard rc;

  @override
  Widget build(BuildContext context) {
    final r = rc.result;
    final t = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rc.schoolName != null) Text(rc.schoolName!, style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
          Text(r.examName, style: context.text.headlineSmall),
          Text([if (r.termName != null) r.termName!, if (rc.academicYear != null) rc.academicYear!].join('  ·  '), style: context.text.bodySmall),
          const Divider(height: Gaps.xl),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: Gaps.md,
            children: [
              Text(r.percent == null ? '-' : '${r.percent!.toStringAsFixed(1)}%', style: figureStyle(context, size: 40)),
              if (r.grade != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusChip('Grade ${r.grade}${r.gradeRemark == null ? '' : '  ·  ${r.gradeRemark}'}', tone: StatusTone.brand)),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          if (r.totalMarks != null && r.maxTotal != null) FactRow('Total', '${r.totalMarks!.toStringAsFixed(r.totalMarks! % 1 == 0 ? 0 : 1)} / ${r.maxTotal!.toStringAsFixed(0)}'),
          if (r.rank != null) FactRow('Class rank', '${r.rank}${r.classSize == null ? '' : ' of ${r.classSize}'}'),
          if (r.result != null) FactRow('Result', r.passed ? 'Pass' : 'Fail', valueColor: r.passed ? t.success : t.danger, bold: true),
        ],
      ),
    );
  }
}

class _SubjectTable extends StatelessWidget {
  const _SubjectTable({required this.subjects});
  final List<SubjectResult> subjects;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return RowGroup(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: 10),
          child: Row(children: [Expanded(flex: 5, child: Text('Subject', style: context.text.labelSmall?.copyWith(color: t.textSecondary))), Expanded(flex: 3, child: Text('Marks', textAlign: TextAlign.end, style: context.text.labelSmall?.copyWith(color: t.textSecondary))), SizedBox(width: 56, child: Text('Grade', textAlign: TextAlign.end, style: context.text.labelSmall?.copyWith(color: t.textSecondary)))]),
        ),
        for (final s in subjects)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: 12),
            child: Row(
              children: [
                Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.subjectName, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)), if (s.remarks != null) Text(s.remarks!, style: context.text.bodySmall)])),
                Expanded(flex: 3, child: Text(s.isAbsent ? 'Absent' : '${s.marksObtained?.toStringAsFixed(s.marksObtained! % 1 == 0 ? 0 : 1) ?? '-'} / ${s.maxMarks.toStringAsFixed(0)}', textAlign: TextAlign.end, style: context.text.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()], color: s.isAbsent ? t.danger : null))),
                SizedBox(width: 56, child: Align(alignment: Alignment.centerRight, child: s.grade == null ? const SizedBox.shrink() : StatusChip(s.grade!, tone: s.passed == false ? StatusTone.danger : StatusTone.neutral))),
              ],
            ),
          ),
      ],
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale({required this.bands});
  final List<GradeBand> bands;

  @override
  Widget build(BuildContext context) => RowGroup(
    children: [
      for (final b in bands.reversed)
        ListRow(title: 'Grade ${b.label}', subtitle: b.remark, dense: true, chevron: false, trailing: Text('${b.minPercent.toStringAsFixed(0)}% - ${b.maxPercent.toStringAsFixed(0)}%', style: context.text.labelMedium)),
    ],
  );
}
