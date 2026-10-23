import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../data/models/materials.dart';
import '../learner/screen_frame.dart';
import 'learning_providers.dart';

/// Syllabus topics per subject with how far the class has got.
class SyllabusScreen extends ConsumerWidget {
  const SyllabusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(syllabusProvider);
    final t = context.tokens;
    Future<void> refresh() async {
      ref.invalidate(syllabusProvider);
      try {
        await ref.read(syllabusProvider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Syllabus',
      body: AsyncBody<List<SyllabusTopic>>(
        value: v,
        onRetry: refresh,
        isEmpty: (l) => l.isEmpty,
        empty: const EmptyState(illo: Illo.emptyGeneric, title: 'No syllabus yet', message: 'Topics for each subject will appear here once the school adds them.'),
        data: (topics) {
          final bySubject = <String, List<SyllabusTopic>>{};
          for (final x in topics) {
            bySubject.putIfAbsent(x.subjectName, () => []).add(x);
          }
          return RefreshScroll(
            onRefresh: refresh,
            children: [
              for (final e in bySubject.entries) ...[
                _SubjectProgress(subject: e.key, topics: e.value),
                const SizedBox(height: Gaps.md),
              ],
              Text('Progress shows how many topics your class has completed.', style: context.text.bodySmall?.copyWith(color: t.textTertiary)),
            ],
          );
        },
      ),
    );
  }
}

class _SubjectProgress extends StatefulWidget {
  const _SubjectProgress({required this.subject, required this.topics});
  final String subject;
  final List<SyllabusTopic> topics;

  @override
  State<_SubjectProgress> createState() => _SubjectProgressState();
}

class _SubjectProgressState extends State<_SubjectProgress> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final done = widget.topics.where((x) => x.status == 'completed').length;
    final total = widget.topics.length;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(Gaps.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Expanded(child: Text(widget.subject, style: context.text.titleMedium)), Text('$done of $total', style: context.text.labelMedium?.copyWith(color: t.textSecondary)), AnimatedRotation(turns: _open ? .5 : 0, duration: Motion.base, child: Icon(Icons.expand_more_rounded, color: t.textTertiary))]),
                  const SizedBox(height: Gaps.sm),
                  ClipRRect(borderRadius: BorderRadius.circular(3), child: LinearProgressIndicator(value: total == 0 ? 0 : done / total, minHeight: 6, color: t.brand.solid)),
                ],
              ),
            ),
          ),
          if (_open) ...[
            const Divider(),
            for (final x in widget.topics)
              ListRow(
                title: x.title,
                subtitle: [if (x.termName != null) x.termName!, if (x.plannedHours != null) '${x.plannedHours} h planned'].join('  ·  '),
                dense: true,
                chevron: false,
                trailing: StatusChip(switch (x.status) { 'completed' => 'Done', 'in_progress' => 'In progress', _ => 'Not started' }, tone: switch (x.status) { 'completed' => StatusTone.success, 'in_progress' => StatusTone.brand, _ => StatusTone.neutral }),
              ),
          ],
        ],
      ),
    );
  }
}
