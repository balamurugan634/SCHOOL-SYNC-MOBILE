import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../data/repositories/files_repository.dart';
import '../../../data/repositories/staff/staff_homework_repository.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';
import 'homework_providers.dart';
import 'homework_widgets.dart';

enum RosterFilter {
  all('All'),
  toReview('To review'),
  missing('Missing'),
  reviewed('Reviewed'),
  returned('Returned');

  const RosterFilter(this.label);
  final String label;

  bool matches(HomeworkRosterRow r) => switch (this) {
    RosterFilter.all => true,
    RosterFilter.toReview => r.status == 'submitted' || r.status == 'late',
    RosterFilter.missing => r.status == 'missing',
    RosterFilter.reviewed => r.status == 'reviewed',
    RosterFilter.returned => r.status == 'returned',
  };
}

/// One homework: details, who has handed in, and the actions its state allows.
class TeacherHomeworkDetailScreen extends ConsumerStatefulWidget {
  const TeacherHomeworkDetailScreen({super.key, required this.homeworkId});
  final String homeworkId;

  @override
  ConsumerState<TeacherHomeworkDetailScreen> createState() => _TeacherHomeworkDetailScreenState();
}

class _TeacherHomeworkDetailScreenState extends ConsumerState<TeacherHomeworkDetailScreen> {
  RosterFilter _filter = RosterFilter.all;
  bool _busy = false;

  String get _id => widget.homeworkId;

  Future<void> _refresh() async {
    ref.invalidate(homeworkRosterProvider(_id));
    try {
      await ref.read(homeworkRosterProvider(_id).future);
    } catch (_) {}
  }

  Future<void> _publish(HomeworkEntry h) async {
    final ok = await confirmAction(context, title: 'Publish this homework?', message: 'Students of ${h.sectionTitle} and their guardians will be notified straight away. It can be closed later but not unpublished.', confirmLabel: 'Publish');
    if (!ok || !mounted) return;
    await _run(() => ref.read(staffHomeworkRepositoryProvider).publish(_id), 'Homework published');
  }

  Future<void> _close(HomeworkEntry h) async {
    final ok = await confirmAction(context, title: 'Close this homework?', message: 'Students of ${h.sectionTitle} will no longer be able to hand in work. What they already submitted stays here for review.', confirmLabel: 'Close homework');
    if (!ok || !mounted) return;
    await _run(() => ref.read(staffHomeworkRepositoryProvider).close(_id), 'Homework closed');
  }

  Future<void> _delete(HomeworkEntry h) async {
    final ok = await confirmAction(context, title: 'Delete this homework?', message: '"${h.title}" will be removed. This cannot be undone.', confirmLabel: 'Delete', destructive: true);
    if (!ok || !mounted) return;
    final done = await _run(() => ref.read(staffHomeworkRepositoryProvider).delete(_id), 'Homework deleted', refreshSelf: false);
    if (done && mounted) context.pop();
  }

  Future<bool> _run(Future<void> Function() action, String success, {bool refreshSelf = true}) async {
    setState(() => _busy = true);
    final done = await runWrite(context, ref, action, success: success);
    if (!mounted) return done;
    setState(() => _busy = false);
    if (done) refreshHomework(ref, id: refreshSelf ? _id : null);
    return done;
  }

  Future<void> _open(Attachment a) async {
    try {
      await ref.read(filesRepositoryProvider).openStored(a);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${a.name}. ${friendlyError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(homeworkRosterProvider(_id));
    final h = v.value?.homework;
    final canEdit = ref.can('homework:edit');
    final canPublish = ref.can('homework:publish');
    final canDelete = ref.can('homework:delete');
    final hasHandIns = (h?.stats?.handedIn ?? 0) > 0;

    return StaffFrame(
      title: 'Homework',
      actions: [
        if (h != null && (canDelete || (canEdit && !h.isClosed)))
          PopupMenuButton<String>(
            tooltip: 'More actions',
            onSelected: (a) {
              if (a == 'edit') context.push(TeacherRoutes.homeworkEdit(_id));
              if (a == 'delete') _delete(h);
            },
            itemBuilder: (_) => [
              if (canEdit && !h.isClosed) const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
              if (canDelete)
                PopupMenuItem(
                  value: 'delete',
                  enabled: !hasHandIns,
                  child: ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Delete'),
                    subtitle: hasHandIns ? const Text('Has hand-ins. Close it instead.') : null,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
            ],
          ),
      ],
      body: AsyncBody<HomeworkRoster>(
        value: v,
        onRetry: () => ref.invalidate(homeworkRosterProvider(_id)),
        data: (r) => RefreshScroll(
          onRefresh: _refresh,
          children: [
            const ReadOnlyBanner(),
            _Header(h: r.homework),
            const SizedBox(height: Gaps.md),
            _Actions(h: r.homework, busy: _busy, canEdit: canEdit, canPublish: canPublish, onPublish: () => _publish(r.homework), onClose: () => _close(r.homework), onEdit: () => context.push(TeacherRoutes.homeworkEdit(_id))),
            if ((r.homework.description ?? '').isNotEmpty || r.homework.attachments.isNotEmpty) ...[
              const SizedBox(height: Gaps.md),
              SectionCard(
                title: 'Instructions',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if ((r.homework.description ?? '').isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: Text(r.homework.description!, style: context.text.bodyMedium)),
                    for (final a in r.homework.attachments)
                      ListRow(title: a.name, subtitle: a.sizeBytes == null ? null : fileSize(a.sizeBytes), leading: Icons.attach_file_rounded, trailing: const Icon(Icons.open_in_new_rounded, size: 18), onTap: () => _open(a), dense: true),
                  ],
                ),
              ),
            ],
            _Roster(roster: r, filter: _filter, onFilter: (f) => setState(() => _filter = f)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.h});
  final HomeworkEntry h;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final stats = h.stats;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Semantics(header: true, child: Text(h.title, style: context.text.headlineSmall))),
              const SizedBox(width: Gaps.sm),
              HomeworkStateChip(h.status),
            ],
          ),
          const SizedBox(height: Gaps.xs),
          Text('${h.sectionTitle}  ·  ${h.subjectName}', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
          const SizedBox(height: Gaps.md),
          FactRow('Due', '${fmtDay(h.dueAt)}, ${fmtTime(h.dueAt)}'),
          if (h.assignedAt != null) FactRow('Set on', fmtDay(h.assignedAt!)),
          FactRow('Online submissions', h.allowSubmission ? 'Allowed' : 'Not needed'),
          if (h.maxMarks != null) FactRow('Maximum marks', '${h.maxMarks}'),
          if (stats != null && !h.isDraft && stats.totalStudents > 0) ...[
            const SizedBox(height: Gaps.sm),
            LabelledMeter(value: stats.handedIn / stats.totalStudents, label: '${stats.handedIn} of ${stats.totalStudents} handed in'),
            const SizedBox(height: Gaps.sm),
            Wrap(
              spacing: Gaps.sm,
              runSpacing: Gaps.xs,
              children: [
                if (stats.toReview > 0) StatusChip('${stats.toReview} to review', tone: StatusTone.info, icon: Icons.rate_review_outlined),
                if (stats.reviewed > 0) StatusChip('${stats.reviewed} reviewed', tone: StatusTone.success, icon: Icons.check_rounded),
                if (stats.returned > 0) StatusChip('${stats.returned} returned', icon: Icons.undo_rounded),
                if (stats.missing > 0) StatusChip('${stats.missing} missing', tone: StatusTone.warning, icon: Icons.remove_circle_outline_rounded),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.h, required this.busy, required this.canEdit, required this.canPublish, required this.onPublish, required this.onClose, required this.onEdit});
  final HomeworkEntry h;
  final bool busy;
  final bool canEdit;
  final bool canPublish;
  final VoidCallback onPublish;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (h.isClosed) {
      return const InfoBanner(icon: Icons.lock_outline_rounded, message: 'This homework is closed. Students can no longer hand in work, and it cannot be edited.');
    }
    return Row(
      children: [
        if (canEdit) Expanded(child: SecondaryButton(label: 'Edit', icon: Icons.edit_outlined, onPressed: busy ? null : onEdit)),
        if (canEdit && ((h.isDraft && canPublish) || h.isPublished)) const SizedBox(width: Gaps.md),
        if (h.isDraft && canPublish) Expanded(child: PrimaryButton(label: 'Publish', icon: Icons.send_rounded, loading: busy, onPressed: onPublish)),
        if (h.isPublished) Expanded(child: SecondaryButton(label: 'Close homework', icon: Icons.lock_outline_rounded, onPressed: busy ? null : onClose)),
      ],
    );
  }
}

class _Roster extends StatelessWidget {
  const _Roster({required this.roster, required this.filter, required this.onFilter});
  final HomeworkRoster roster;
  final RosterFilter filter;
  final ValueChanged<RosterFilter> onFilter;

  @override
  Widget build(BuildContext context) {
    final h = roster.homework;
    if (h.isDraft) {
      return const Padding(padding: EdgeInsets.only(top: Gaps.md), child: QuietLine('Hand-ins appear here once the homework is published.', icon: Icons.info_outline_rounded));
    }
    final rows = roster.rows;
    int count(RosterFilter f) => rows.where(f.matches).length;
    final visible = rows.where(filter.matches).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GroupLabel('Students (${rows.length})'),
        Padding(
          padding: const EdgeInsets.only(bottom: Gaps.sm),
          child: FilterChips<RosterFilter>(padding: EdgeInsets.zero, options: RosterFilter.values, selected: filter, onSelected: onFilter, labelOf: (f) => '${f.label} ${count(f)}'),
        ),
        if (visible.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: Gaps.lg), child: EmptyState(compact: true, icon: Icons.filter_list_off_rounded, title: 'No students here', message: 'Nobody is "${filter.label.toLowerCase()}" right now.', actionLabel: 'Show all', onAction: () => onFilter(RosterFilter.all)))
        else
          RowGroup(
            children: [
              for (final r in visible)
                PersonTile(
                  name: r.name,
                  leadingNumber: r.rollNo,
                  subtitle: r.submission?.submittedAt == null ? r.admissionNo : '${r.admissionNo}  ·  handed in ${fmtDateTime(r.submission!.submittedAt!)}',
                  trailing: RosterStatusChip(r.status, marks: r.submission?.marks, maxMarks: h.maxMarks),
                  onTap: r.submission == null ? null : () => context.push(TeacherRoutes.submission(h.id, r.submission!.id)),
                ),
            ],
          ),
      ],
    );
  }
}
