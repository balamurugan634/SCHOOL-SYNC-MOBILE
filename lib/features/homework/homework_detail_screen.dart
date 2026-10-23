import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/json.dart';
import '../../data/models/homework.dart';
import '../../data/repositories/files_repository.dart';
import '../../data/repositories/homework_repository.dart';
import '../auth/session.dart';
import '../dashboard/dashboard_providers.dart';
import '../learner/learner_context.dart';
import 'homework_providers.dart';

/// One homework: the brief, the learner's submission and (for students) the submit form with file upload.
class HomeworkDetailScreen extends ConsumerWidget {
  const HomeworkDetailScreen({super.key, required this.homeworkId});
  final String homeworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hw = ref.watch(homeworkDetailProvider(homeworkId));
    final sub = ref.watch(homeworkSubmissionProvider(homeworkId));
    final isParent = ref.watch(isParentProvider);
    Future<void> refresh() async {
      ref.invalidate(homeworkDetailProvider(homeworkId));
      ref.invalidate(homeworkSubmissionProvider(homeworkId));
      try {
        await ref.read(homeworkDetailProvider(homeworkId).future);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Homework')),
      body: AsyncBody<Homework>(
        value: hw,
        onRetry: refresh,
        data: (h) => RefreshScroll(
          onRefresh: refresh,
          children: [
            _Brief(h: h),
            const SizedBox(height: Gaps.lg),
            _SubmissionSection(h: h, submission: sub.value, loading: sub.isLoading && !sub.hasValue, readOnly: isParent, onChanged: refresh),
          ],
        ),
      ),
    );
  }
}

class _Brief extends ConsumerWidget {
  const _Brief({required this.h});
  final Homework h;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final overdue = h.dueAt != null && h.dueAt!.isBefore(appNow()) && h.learnerStatus.needsAction;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(h.subjectName, style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
          const SizedBox(height: 2),
          Text(h.title, style: context.text.headlineSmall),
          const SizedBox(height: Gaps.md),
          Wrap(spacing: 6, runSpacing: 6, children: [
            StatusChip(h.learnerStatus.label, tone: switch (h.learnerStatus) { LearnerStatus.reviewed => StatusTone.success, LearnerStatus.submitted || LearnerStatus.late => StatusTone.brand, LearnerStatus.returned => StatusTone.warning, LearnerStatus.overdue => StatusTone.danger, _ => StatusTone.neutral }),
            if (overdue) const StatusChip('Past due', tone: StatusTone.danger),
            if (h.closed) const StatusChip('Closed'),
          ]),
          const Divider(height: Gaps.xl),
          if (h.dueAt != null) FactRow('Due', '${fmtDay(h.dueAt!)}, ${fmtTime(h.dueAt!)}'),
          if (h.teacherName != null) FactRow('Set by', h.teacherName!),
          if (h.assignedAt != null) FactRow('Set on', fmtShort(h.assignedAt!)),
          if (h.maxMarks != null) FactRow('Marks', 'out of ${h.maxMarks}'),
          if (h.description != null && h.description!.trim().isNotEmpty) ...[
            const SizedBox(height: Gaps.sm),
            Text(h.description!, style: context.text.bodyMedium),
          ],
          if (h.attachments.isNotEmpty) ...[
            const SizedBox(height: Gaps.md),
            for (final a in h.attachments) _AttachmentTile(a),
          ],
        ],
      ),
    );
  }
}

class _AttachmentTile extends ConsumerWidget {
  const _AttachmentTile(this.a);
  final Attachment a;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListRow(
    title: a.name,
    subtitle: fileSize(a.sizeBytes),
    leading: Icons.attach_file_rounded,
    dense: true,
    chevron: false,
    trailing: const Icon(Icons.open_in_new_rounded, size: 18),
    onTap: () async {
      try {
        await ref.read(filesRepositoryProvider).openStored(a);
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
      }
    },
  );
}

class _SubmissionSection extends ConsumerStatefulWidget {
  const _SubmissionSection({required this.h, required this.submission, required this.loading, required this.readOnly, required this.onChanged});
  final Homework h;
  final Submission? submission;
  final bool loading;
  final bool readOnly;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_SubmissionSection> createState() => _SubmissionSectionState();
}

class _SubmissionSectionState extends ConsumerState<_SubmissionSection> {
  final _text = TextEditingController();
  final List<Attachment> _files = [];
  final Map<String, double> _uploading = {};
  bool _submitting = false;
  bool _editing = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final res = await FilePicker.pickFiles();
    for (final f in res) {
      final path = f.path;
      if (path == null) continue;
      setState(() => _uploading[f.name] = 0);
      try {
        final att = await ref.read(filesRepositoryProvider).upload(path, name: f.name, purpose: 'submission', onProgress: (sent, total) {
          if (mounted && total > 0) setState(() => _uploading[f.name] = sent / total);
        });
        if (mounted) setState(() => _files.add(att));
      } catch (e) {
        if (mounted) setState(() => _error = 'Could not upload ${f.name}: ${AppException.from(e).displayMessage}');
      } finally {
        if (mounted) setState(() => _uploading.remove(f.name));
      }
    }
  }

  Future<void> _submit() async {
    if (_text.text.trim().isEmpty && _files.isEmpty && widget.submission == null) {
      setState(() => _error = 'Write an answer or attach a file first.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(homeworkRepositoryProvider).submit(widget.h.id, text: _text.text, attachments: _files);
      ref.invalidate(studentDashboardProvider);
      ref.invalidate(homeworkListProvider);
      await widget.onChanged();
      if (mounted) {
        setState(() {
          _done = true;
          _editing = false;
          _files.clear();
          _text.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppException.from(e).displayMessage);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final h = widget.h;
    final s = widget.submission;
    final readOnly = widget.readOnly;
    final readOnlySite = ref.watch(sessionProvider.select((x) => x.siteInfo?.readOnly ?? false));

    if (widget.loading) return const SkeletonList(count: 1, padding: EdgeInsets.zero);

    final children = <Widget>[];
    if (s != null) {
      children.add(GroupLabel(readOnly ? 'Submission' : 'Your submission'));
      children.add(
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(s.submittedAt == null ? 'Submitted' : 'Submitted ${fmtDateTime(s.submittedAt!)}', style: context.text.titleSmall)),
                if (s.isLate) const StatusChip('Late', tone: StatusTone.warning),
              ]),
              if (s.text != null && s.text!.trim().isNotEmpty) ...[const SizedBox(height: Gaps.sm), Text(s.text!, style: context.text.bodyMedium)],
              for (final a in s.attachments) _AttachmentTile(a),
              if (s.marks != null || s.feedback != null) ...[
                const Divider(height: Gaps.xl),
                if (s.marks != null) FactRow('Marks', '${s.marks!.toStringAsFixed(s.marks! % 1 == 0 ? 0 : 1)}${h.maxMarks == null ? '' : ' / ${h.maxMarks}'}', bold: true),
                if (s.feedback != null) ...[Text('Teacher feedback', style: context.text.labelMedium?.copyWith(color: t.textSecondary)), const SizedBox(height: 4), Text(s.feedback!, style: context.text.bodyMedium)],
              ],
            ],
          ),
        ),
      );
    } else if (readOnly) {
      children.add(const GroupLabel('Submission'));
      children.add(AppCard(child: Text(h.allowSubmission ? 'Nothing has been submitted yet.' : 'This homework does not need a submission.', style: context.text.bodyMedium)));
    }

    if (_done) {
      children.add(const SizedBox(height: Gaps.lg));
      children.add(const AppCard(child: Row(children: [SizedBox(width: 96, child: IllustrationView(Illo.success, width: 96, decorative: true)), SizedBox(width: Gaps.md), Expanded(child: Text('Submitted. Your teacher will review it.'))])));
    }

    final canSubmit = !readOnly && h.canSubmit && !readOnlySite && (s == null || _editing || h.learnerStatus == LearnerStatus.returned);
    if (!readOnly && s != null && h.canSubmit && !_editing && h.learnerStatus != LearnerStatus.returned && h.learnerStatus != LearnerStatus.reviewed) {
      children.add(const SizedBox(height: Gaps.md));
      children.add(SecondaryButton(label: 'Edit and resubmit', icon: Icons.edit_outlined, onPressed: () => setState(() => _editing = true)));
    }
    if (canSubmit) {
      children.add(GroupLabel(s == null ? 'Submit your work' : 'Resubmit'));
      children.add(
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (h.dueAt != null && h.dueAt!.isBefore(appNow())) const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, message: 'This is past the due date, so it will be marked late.')),
              if (h.learnerStatus == LearnerStatus.returned && s?.feedback != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, title: 'Returned for rework', message: s!.feedback!)),
              TextField(controller: _text, minLines: 3, maxLines: 8, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Your answer (optional if you attach a file)', alignLabelWithHint: true)),
              const SizedBox(height: Gaps.md),
              for (final a in _files) ListRow(title: a.name, subtitle: fileSize(a.sizeBytes), leading: Icons.insert_drive_file_outlined, dense: true, chevron: false, trailing: IconButton(tooltip: 'Remove', icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => setState(() => _files.remove(a)))),
              for (final e in _uploading.entries) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Uploading ${e.key}', style: context.text.bodySmall), const SizedBox(height: 4), LinearProgressIndicator(value: e.value == 0 ? null : e.value, minHeight: 6, borderRadius: BorderRadius.circular(3))])),
              const SizedBox(height: Gaps.sm),
              SecondaryButton(label: 'Attach files', icon: Icons.attach_file_rounded, onPressed: _uploading.isEmpty && !_submitting ? _pick : null),
              if (_error != null) ...[const SizedBox(height: Gaps.md), InfoBanner(tone: BannerTone.danger, message: _error!)],
              const SizedBox(height: Gaps.md),
              PrimaryButton(label: s == null ? 'Submit' : 'Resubmit', loading: _submitting, onPressed: _uploading.isEmpty ? _submit : null),
            ],
          ),
        ),
      );
    } else if (!readOnly && s == null && !h.allowSubmission) {
      children.add(const SizedBox(height: Gaps.md));
      children.add(const InfoBanner(message: 'This homework does not need a submission.'));
    } else if (!readOnly && s == null && h.closed) {
      children.add(const SizedBox(height: Gaps.md));
      children.add(const InfoBanner(tone: BannerTone.warning, message: 'This homework is closed. Submissions are no longer accepted.'));
    } else if (!readOnly && readOnlySite && s == null) {
      children.add(const SizedBox(height: Gaps.md));
      children.add(const InfoBanner(tone: BannerTone.warning, message: 'Your school\'s subscription has ended, so changes are disabled.'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}
