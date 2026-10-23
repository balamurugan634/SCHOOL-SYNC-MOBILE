import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../marks/marks_logic.dart';
import 'homework_providers.dart';
import 'homework_widgets.dart';
import 'review_logic.dart';

/// Review one student's hand-in: marks and feedback, or send it back for rework.
class SubmissionReviewScreen extends ConsumerWidget {
  const SubmissionReviewScreen({super.key, required this.homeworkId, required this.submissionId});
  final String homeworkId;
  final String submissionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(submissionProvider(submissionId));
    final roster = ref.watch(homeworkRosterProvider(homeworkId));
    if (sub.hasValue && roster.hasValue) {
      return ReviewForm(key: ValueKey(submissionId), submission: sub.requireValue, roster: roster.requireValue);
    }
    final err = sub.hasError ? sub.error : (roster.hasError ? roster.error : null);
    return StaffFrame(
      title: 'Review',
      body: err != null
          ? ErrorState(
              error: err,
              onRetry: () {
                ref.invalidate(submissionProvider(submissionId));
                ref.invalidate(homeworkRosterProvider(homeworkId));
              },
            )
          : const SingleChildScrollView(physics: NeverScrollableScrollPhysics(), child: Padding(padding: EdgeInsets.only(top: Gaps.sm), child: SkeletonList(count: 3))),
    );
  }
}

/// The review form (public for widget tests).
class ReviewForm extends ConsumerStatefulWidget {
  const ReviewForm({super.key, required this.submission, required this.roster});
  final SubmissionEntry submission;
  final HomeworkRoster roster;

  @override
  ConsumerState<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<ReviewForm> {
  late final TextEditingController _marks;
  late final TextEditingController _feedback;
  String? _marksError;
  String? _feedbackError;
  String? _formError;
  bool _busy = false;
  List<HomeworkRosterRow>? _next; // set after a successful save

  SubmissionEntry get _s => widget.submission;
  HomeworkEntry get _h => widget.roster.homework;

  @override
  void initState() {
    super.initState();
    _marks = TextEditingController(text: _s.marks == null ? '' : fmtMark(_s.marks!));
    _feedback = TextEditingController(text: _s.feedback ?? '');
  }

  @override
  void dispose() {
    _marks.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _open(Attachment a) async {
    try {
      await ref.read(filesRepositoryProvider).openStored(a);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open ${a.name}. ${friendlyError(e)}')));
    }
  }

  Future<void> _afterSave() async {
    ref.invalidate(submissionProvider(_s.id));
    ref.invalidate(homeworkRosterProvider(_h.id));
    ref.invalidate(teacherHomeworkListProvider);
    List<HomeworkRosterRow> next = const [];
    try {
      next = nextToReview(await ref.read(homeworkRosterProvider(_h.id).future), _s.id);
    } catch (_) {}
    if (mounted) setState(() => _next = next);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final v = validateReview(marksText: _marks.text, feedback: _feedback.text, maxMarks: _h.maxMarks);
    setState(() {
      _marksError = v.marks;
      _feedbackError = v.feedback;
      _formError = v.general;
    });
    if (v.marks != null || v.feedback != null || v.general != null) return;
    setState(() => _busy = true);
    final marks = parseMarkText(_marks.text);
    final done = await runWrite(
      context,
      ref,
      () => ref.read(staffHomeworkRepositoryProvider).review(_s.id, marks: marks, feedback: _feedback.text),
      success: 'Review saved. ${_s.studentName} has been told.',
      onError: _fail,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) await _afterSave();
  }

  Future<void> _returnForRework() async {
    FocusScope.of(context).unfocus();
    final v = validateReview(marksText: '', feedback: _feedback.text, maxMarks: _h.maxMarks, requireFeedback: true);
    setState(() {
      _marksError = null;
      _feedbackError = v.feedback;
      _formError = null;
    });
    if (v.feedback != null) return;
    final ok = await confirmAction(context, title: 'Return for rework?', message: '${_s.studentName} will be asked to redo this and hand it in again. Any marks you gave are cleared.', confirmLabel: 'Return to student');
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final done = await runWrite(context, ref, () => ref.read(staffHomeworkRepositoryProvider).returnForRework(_s.id, feedback: _feedback.text), success: 'Returned to ${_s.studentName}', onError: _fail);
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) await _afterSave();
  }

  void _fail(Object e) {
    setState(() => _formError = friendlyError(e));
    if (isStaleStateError(e)) {
      ref.invalidate(submissionProvider(_s.id));
      ref.invalidate(homeworkRosterProvider(_h.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final canReview = ref.can('submissions:edit');
    final returned = _s.status == 'returned';
    final hasMarks = _h.maxMarks != null;
    final enabled = !_busy && canReview && !returned;

    return StaffFrame(
      title: 'Review',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.huge),
        children: [
          const ReadOnlyBanner(),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    UserAvatar(name: _s.studentName, size: 44),
                    const SizedBox(width: Gaps.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Semantics(header: true, child: Text(_s.studentName, style: context.text.titleMedium)),
                          Text([if (_s.rollNo != null) 'Roll ${_s.rollNo}', _h.title].join('  ·  '), maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    RosterStatusChip(_s.status, marks: _s.marks, maxMarks: _h.maxMarks),
                  ],
                ),
                if (_s.submittedAt != null) ...[
                  const SizedBox(height: Gaps.sm),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 16, color: t.textTertiary),
                      const SizedBox(width: 6),
                      Expanded(child: Text('Handed in ${fmtDateTime(_s.submittedAt!)}${_s.isLate ? ' (after the due time)' : ''}', style: context.text.bodySmall)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Gaps.md),
          SectionCard(
            title: 'Their work',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((_s.text ?? '').trim().isEmpty && _s.attachments.isEmpty) const QuietLine('Nothing was written or attached.', icon: Icons.info_outline_rounded),
                if ((_s.text ?? '').trim().isNotEmpty) SelectableText(_s.text!, style: context.text.bodyMedium),
                for (final a in _s.attachments) ListRow(title: a.name, subtitle: a.sizeBytes == null ? null : fileSize(a.sizeBytes), leading: Icons.attach_file_rounded, trailing: const Icon(Icons.open_in_new_rounded, size: 18), onTap: () => _open(a), dense: true),
              ],
            ),
          ),
          const SizedBox(height: Gaps.md),
          if (_next != null)
            _Saved(next: _next!, studentName: _s.studentName, onNext: () => context.pushReplacement(TeacherRoutes.submission(_h.id, _next!.first.submission!.id)), onBack: () => context.pop())
          else ...[
            if (returned)
              InfoBanner(tone: BannerTone.warning, icon: Icons.undo_rounded, title: 'Returned for rework', message: 'Waiting for ${_s.studentName} to hand it in again.${(_s.feedback ?? '').isEmpty ? '' : ' Your note: ${_s.feedback}'}')
            else ...[
              if (!canReview) const InfoBanner(icon: Icons.lock_outline_rounded, message: 'Your role cannot review hand-ins.'),
              if (_s.status == 'reviewed') const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.success, icon: Icons.check_rounded, message: 'Already reviewed. Saving again replaces the earlier review.')),
              if (_formError != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.danger, message: _formError!)),
              if (hasMarks)
                TextField(
                  controller: _marks,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(7)],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: 'Marks (out of ${_h.maxMarks})', errorText: _marksError),
                  onChanged: (_) => setState(() {
                    _marksError = markError(_marks.text, _h.maxMarks!.toDouble());
                    _formError = null;
                  }),
                )
              else
                const QuietLine('This homework carries no marks. Give feedback only.', icon: Icons.info_outline_rounded),
              const SizedBox(height: Gaps.md),
              TextField(
                controller: _feedback,
                enabled: enabled,
                minLines: 3,
                maxLines: 8,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: 'Feedback for the student', alignLabelWithHint: true, errorText: _feedbackError),
                onChanged: (_) => setState(() {
                  _feedbackError = null;
                  _formError = null;
                }),
              ),
              const SizedBox(height: Gaps.md),
              PrimaryButton(label: 'Save review', icon: Icons.check_rounded, loading: _busy, onPressed: enabled ? _save : null),
              if (!_h.isClosed) ...[
                const SizedBox(height: Gaps.sm),
                SecondaryButton(label: 'Return for rework', icon: Icons.undo_rounded, onPressed: enabled ? _returnForRework : null),
                const SizedBox(height: Gaps.xs),
                Text('Returning needs feedback. The student can then hand it in again.', textAlign: TextAlign.center, style: context.text.bodySmall),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _Saved extends StatelessWidget {
  const _Saved({required this.next, required this.studentName, required this.onNext, required this.onBack});
  final List<HomeworkRosterRow> next;
  final String studentName;
  final VoidCallback onNext;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(Icons.check_circle_outline_rounded, color: context.tokens.success), const SizedBox(width: Gaps.sm), Expanded(child: Text('Saved for $studentName', style: context.text.titleMedium))]),
        const SizedBox(height: Gaps.md),
        if (next.isNotEmpty) ...[
          PrimaryButton(label: 'Next to review (${next.length} left)', trailingIcon: Icons.arrow_forward_rounded, onPressed: onNext),
          const SizedBox(height: Gaps.sm),
          SecondaryButton(label: 'Back to the class list', onPressed: onBack),
        ] else ...[
          const QuietLine('Nothing else is waiting for review.', icon: Icons.done_all_rounded),
          const SizedBox(height: Gaps.sm),
          PrimaryButton(label: 'Back to the class list', onPressed: onBack),
        ],
      ],
    ),
  );
}
