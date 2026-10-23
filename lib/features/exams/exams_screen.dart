import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/exams.dart';
import '../learner/screen_frame.dart';
import 'exams_providers.dart';

/// Upcoming and published exams, with each exam's paper schedule (subject, date, time, room).
class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key, this.embedded = false, this.bare = false});
  final bool embedded;
  final bool bare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(examsProvider);
    Future<void> refresh() async {
      ref.invalidate(examsProvider);
      try {
        await ref.read(examsProvider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Exams',
      embedded: embedded,
      bare: bare,
      body: AsyncBody<List<Exam>>(
        value: v,
        onRetry: refresh,
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyState(illo: Illo.emptyEvents, title: 'No exams scheduled', message: 'Exam schedules appear here once the school publishes them.'),
        data: (exams) => RefreshScroll(onRefresh: refresh, children: [for (final e in exams) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: _ExamCard(exam: e))]),
      ),
    );
  }
}

class _ExamCard extends ConsumerStatefulWidget {
  const _ExamCard({required this.exam});
  final Exam exam;

  @override
  ConsumerState<_ExamCard> createState() => _ExamCardState();
}

class _ExamCardState extends ConsumerState<_ExamCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.exam;
    final t = context.tokens;
    final tone = e.status == 'published' ? StatusTone.success : StatusTone.neutral;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(Gaps.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name, style: context.text.titleMedium),
                        const SizedBox(height: 2),
                        Text([if (e.termName != null) e.termName!, if (e.startDate != null) '${fmtShort(e.startDate!)}${e.endDate == null ? '' : ' to ${fmtShort(e.endDate!)}'}'].join('  ·  '), style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  StatusChip(e.status == 'published' ? 'Results out' : (e.status == 'scheduled' ? 'Scheduled' : e.status.replaceAll('_', ' ')), tone: tone),
                  AnimatedRotation(turns: _open ? .5 : 0, duration: Motion.base, child: Icon(Icons.expand_more_rounded, color: t.textTertiary)),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: Motion.base,
            alignment: Alignment.topCenter,
            child: !_open
                ? const SizedBox(width: double.infinity)
                : ref.watch(examPapersProvider(e.id)).when(
                    loading: () => const Padding(padding: EdgeInsets.all(Gaps.lg), child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.2)))),
                    error: (er, _) => ErrorState(error: er, compact: true, onRetry: () => ref.invalidate(examPapersProvider(e.id))),
                    data: (papers) => papers.isEmpty
                        ? Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.lg), child: Text('The papers have not been scheduled yet.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)))
                        : Column(
                            children: [
                              const Divider(),
                              for (final p in papers)
                                ListRow(
                                  title: p.subjectName,
                                  subtitle: [if (p.examDate != null) fmtDay(p.examDate!), formatTimeRange(p.startTime, p.endTime), if (p.room != null) p.room!].where((x) => x.isNotEmpty).join('  ·  '),
                                  dense: true,
                                  chevron: false,
                                  trailing: p.maxMarks == null ? null : Text('${p.maxMarks!.toStringAsFixed(0)} marks', style: context.text.labelMedium),
                                ),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
