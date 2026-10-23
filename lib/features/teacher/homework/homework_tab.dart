import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';
import 'homework_providers.dart';
import 'homework_widgets.dart';

const _filters = <(String, String)>[('published', 'Active'), ('draft', 'Drafts'), ('closed', 'Closed')];

/// Homework tab: my homework by state, with one tap to set new work.
class TeacherHomeworkTab extends ConsumerStatefulWidget {
  const TeacherHomeworkTab({super.key});

  @override
  ConsumerState<TeacherHomeworkTab> createState() => _TeacherHomeworkTabState();
}

class _TeacherHomeworkTabState extends ConsumerState<TeacherHomeworkTab> {
  String _status = 'published';

  @override
  Widget build(BuildContext context) {
    final canCreate = ref.can('homework:create');
    return FeatureGate(
      label: 'Homework',
      anyPermission: const ['homework:view', 'homework:create'],
      child: StaffFrame(
        title: 'Homework',
        subtitle: 'Set work, then review submissions.',
        embedded: true,
        fab: canCreate
            ? FloatingActionButton.extended(
                onPressed: () => context.push(TeacherRoutes.homeworkNew),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New homework'),
                tooltip: 'Set new homework',
              )
            : null,
        headerExtra: Padding(
          padding: const EdgeInsets.only(bottom: Gaps.sm),
          child: FilterChips<String>(options: [for (final f in _filters) f.$1], selected: _status, onSelected: (s) => setState(() => _status = s), labelOf: (s) => _filters.firstWhere((f) => f.$1 == s).$2),
        ),
        body: _HomeworkList(status: _status, onClearFilter: () => setState(() => _status = 'published')),
      ),
    );
  }
}

class _HomeworkList extends ConsumerWidget {
  const _HomeworkList({required this.status, required this.onClearFilter});
  final String status;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = teacherHomeworkListProvider(status);
    final value = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return AsyncBody<PagedList<HomeworkEntry>>(
      value: value,
      onRetry: () => ref.invalidate(provider),
      isEmpty: (p) => p.items.isEmpty,
      empty: _Empty(status: status, onClear: onClearFilter),
      data: (p) => RefreshScroll(
        onRefresh: refresh,
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 96),
        children: [
          RowGroup(children: [for (final h in p.items) HomeworkRow(entry: h, onTap: () => context.push(TeacherRoutes.homework(h.id)))]),
          LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.status, required this.onClear});
  final String status;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => switch (status) {
    'draft' => const EmptyState(illo: Illo.emptyHomework, title: 'No drafts', message: 'Homework you save without publishing waits here until you are ready.'),
    'closed' => EmptyState(illo: Illo.emptyHomework, title: 'Nothing closed yet', message: 'Closed homework no longer takes submissions.', actionLabel: 'Show active', onAction: onClear),
    _ => const EmptyState(illo: Illo.emptyHomework, title: 'No active homework', message: 'Set homework for a class you teach and it appears here once published.'),
  };
}

/// When it is due, worded for the person who set it.
String homeworkDueText(DateTime due, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return due.isAfter(n) ? dueLabel(due, n) : 'Due date passed, ${fmtShort(due)}';
}

/// One homework in a list: title, class and subject, due text, hand-in meter and what needs review.
class HomeworkRow extends StatelessWidget {
  const HomeworkRow({super.key, required this.entry, required this.onTap});
  final HomeworkEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stats = entry.stats;
    final showStats = stats != null && !entry.isDraft && stats.totalStudents > 0;
    final summary = [entry.title, '${entry.sectionTitle}, ${entry.subjectName}', homeworkDueText(entry.dueAt), if (showStats) '${stats.handedIn} of ${stats.totalStudents} handed in', if (showStats && stats.toReview > 0) '${stats.toReview} to review'].join('. ');
    return Semantics(
      button: true,
      label: summary,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  if (entry.isDraft || entry.isClosed) ...[const SizedBox(width: Gaps.sm), HomeworkStateChip(entry.status)],
                ],
              ),
              const SizedBox(height: 2),
              Text('${entry.sectionTitle}  ·  ${entry.subjectName}', style: context.text.bodySmall),
              const SizedBox(height: 2),
              Text(homeworkDueText(entry.dueAt), style: context.text.bodySmall?.copyWith(color: t.textTertiary)),
              if (showStats) ...[
                const SizedBox(height: Gaps.sm),
                LabelledMeter(value: stats.handedIn / stats.totalStudents, label: '${stats.handedIn} of ${stats.totalStudents} handed in'),
                if (stats.toReview > 0) ...[const SizedBox(height: Gaps.xs), StatusChip('${stats.toReview} to review', tone: StatusTone.info, icon: Icons.rate_review_outlined)],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
