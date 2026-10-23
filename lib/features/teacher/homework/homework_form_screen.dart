import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/util/format.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../data/repositories/staff/staff_homework_repository.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';
import 'homework_form_logic.dart';
import 'homework_providers.dart';

/// Create or edit homework. Class and subject choices are limited to what I teach; when editing they are locked.
class HomeworkFormScreen extends ConsumerWidget {
  const HomeworkFormScreen({super.key, this.homeworkId});
  final String? homeworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = homeworkId;
    if (id != null) {
      final v = ref.watch(teacherHomeworkProvider(id));
      if (v.hasValue) return HomeworkForm(editing: v.requireValue, assignments: const []);
      return StaffFrame(
        title: 'Edit homework',
        body: v.hasError ? ErrorState(error: v.error!, onRetry: () => ref.invalidate(teacherHomeworkProvider(id))) : const Center(child: CircularProgressIndicator()),
      );
    }
    final a = ref.watch(myAssignmentsProvider);
    if (a.hasValue) {
      if (a.requireValue.isEmpty) {
        return const StaffFrame(
          title: 'New homework',
          body: EmptyState(icon: Icons.class_outlined, title: 'No classes assigned yet', message: 'Homework can only be set for a subject you teach. Ask the school office to assign your classes.'),
        );
      }
      return HomeworkForm(assignments: a.requireValue);
    }
    return StaffFrame(
      title: 'New homework',
      body: a.hasError ? ErrorState(error: a.error!, onRetry: () => ref.invalidate(myAssignmentsProvider)) : const Center(child: CircularProgressIndicator()),
    );
  }
}

/// The form itself (public for widget tests).
class HomeworkForm extends ConsumerStatefulWidget {
  const HomeworkForm({super.key, this.editing, required this.assignments});

  /// The homework being edited (null = creating).
  final HomeworkEntry? editing;
  final List<MyAssignment> assignments;

  @override
  ConsumerState<HomeworkForm> createState() => _HomeworkFormState();
}

class _HomeworkFormState extends ConsumerState<HomeworkForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _max = TextEditingController();
  String? _sectionId;
  String? _subjectId;
  DateTime? _due;
  bool _allow = true;
  List<Attachment> _attachments = const [];

  late HomeworkFormInput _initial;
  late List<String> _initialFiles;
  HomeworkFormErrors _errors = const HomeworkFormErrors();
  String? _formError;
  bool _busy = false;
  bool _leaving = false;

  bool get _editing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _title.text = e.title;
      _desc.text = e.description ?? '';
      _max.text = e.maxMarks?.toString() ?? '';
      _sectionId = e.sectionId;
      _subjectId = e.subjectId;
      _due = e.dueAt;
      _allow = e.allowSubmission;
      _attachments = e.attachments;
    } else {
      _due = defaultDueAt();
      final sections = distinctSections(widget.assignments);
      if (sections.length == 1) {
        _sectionId = sections.first.sectionId;
        final subjects = subjectsFor(widget.assignments, _sectionId);
        if (subjects.length == 1) _subjectId = subjects.first.subjectId;
      }
    }
    _initial = _input();
    _initialFiles = [for (final a in _attachments) a.fileId];
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _max.dispose();
    super.dispose();
  }

  HomeworkFormInput _input() => HomeworkFormInput(sectionId: _sectionId, subjectId: _subjectId, title: _title.text, description: _desc.text, dueAt: _due, allowSubmission: _allow, maxMarksText: _max.text);

  bool get _dirty => _input() != _initial || !_sameFiles();

  bool _sameFiles() {
    final now = [for (final a in _attachments) a.fileId];
    if (now.length != _initialFiles.length) return false;
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _initialFiles[i]) return false;
    }
    return true;
  }

  bool get _closed => widget.editing?.isClosed ?? false;

  Future<void> _pickDue() async {
    final picked = await pickDayTime(context, initial: _due, firstDate: DateTime.now(), help: 'Due date');
    if (picked != null) {
      setState(() {
        _due = picked;
        _errors = _errors.copyWith();
      });
    }
  }

  Future<void> _save({required bool publish}) async {
    FocusScope.of(context).unfocus();
    final input = _input();
    final dueChanged = _editing && input.dueAt != widget.editing!.dueAt;
    final errs = validateHomeworkForm(input, creating: !_editing, requireFutureDue: !_editing || publish || dueChanged);
    setState(() {
      _errors = errs;
      _formError = null;
    });
    if (errs.any) return;

    final className = _editing ? widget.editing!.sectionTitle : widget.assignments.firstWhere((a) => a.sectionId == _sectionId).sectionTitle;
    if (publish) {
      final ok = await confirmAction(
        context,
        title: 'Publish this homework?',
        message: 'Students of $className and their guardians will be notified straight away. You can close it later, but it cannot be unpublished.',
        confirmLabel: 'Publish',
      );
      if (!ok || !mounted) return;
    }

    final draft = buildHomeworkDraft(input, _attachments);
    final repo = ref.read(staffHomeworkRepositoryProvider);
    setState(() => _busy = true);
    String? savedId = widget.editing?.id;
    final done = await runWrite(
      context,
      ref,
      () async {
        if (_editing) {
          final id = widget.editing!.id;
          await repo.update(id, draft);
          if (publish) await repo.publish(id);
        } else {
          final created = await repo.create(draft, publish: publish);
          savedId = created.id;
        }
      },
      success: publish ? 'Homework published' : (_editing ? 'Changes saved' : 'Saved as a draft'),
      onError: _showError,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!done) return;
    refreshHomework(ref, id: savedId);
    _leaving = true;
    if (_editing) {
      context.pop();
    } else {
      context.pushReplacement(TeacherRoutes.homework(savedId!));
    }
  }

  void _showError(Object e) {
    final ex = AppException.from(e);
    setState(() {
      _errors = mapServerFieldErrors(ex.errors, _errors);
      _formError = friendlyError(e);
    });
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmAction(context, title: 'Discard your changes?', message: 'What you entered has not been saved.', confirmLabel: 'Discard', destructive: true);
    if (leave && mounted) {
      setState(() => _leaving = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final readOnlyMode = ref.watch(readOnlyProvider);
    final canPublish = ref.can('homework:publish');
    final sections = distinctSections(widget.assignments);
    final subjects = subjectsFor(widget.assignments, _sectionId);
    final editing = widget.editing;
    final blocked = _closed || readOnlyMode;
    final enabled = !_busy && !_closed;

    return PopScope(
      canPop: _leaving || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: StaffFrame(
        title: _editing ? 'Edit homework' : 'New homework',
        bottom: _closed
            ? null
            : SafeArea(
                child: Container(
                  decoration: BoxDecoration(color: context.tokens.surface, border: Border(top: BorderSide(color: context.tokens.border))),
                  padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.sm),
                  child: _actions(canPublish, blocked),
                ),
              ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.huge),
          children: [
            const ReadOnlyBanner(),
            if (_closed) ...[const InfoBanner(tone: BannerTone.warning, icon: Icons.lock_outline_rounded, title: 'This homework is closed', message: 'Closed homework can no longer be edited.'), const SizedBox(height: Gaps.md)],
            if (_formError != null) ...[InfoBanner(tone: BannerTone.danger, message: _formError!), const SizedBox(height: Gaps.md)],
            if (_editing)
              AppCard(
                tone: CardTone.subtle,
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 18),
                    const SizedBox(width: Gaps.sm),
                    Expanded(child: Text('${editing!.sectionTitle}  ·  ${editing.subjectName}\nClass and subject cannot be changed after the homework is created.', style: context.text.bodySmall)),
                  ],
                ),
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _sectionId,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Class', errorText: _errors.section),
                items: [for (final s in sections) DropdownMenuItem(value: s.sectionId, child: Text(s.sectionTitle, overflow: TextOverflow.ellipsis))],
                onChanged: enabled
                    ? (v) => setState(() {
                        _sectionId = v;
                        final subs = subjectsFor(widget.assignments, v);
                        _subjectId = subs.length == 1 ? subs.first.subjectId : null;
                      })
                    : null,
              ),
              const SizedBox(height: Gaps.md),
              DropdownButtonFormField<String>(
                key: ValueKey('subject-$_sectionId-$_subjectId'),
                initialValue: _subjectId,
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Subject', errorText: _errors.subject, helperText: _sectionId == null ? 'Choose a class first.' : null),
                items: [for (final s in subjects) DropdownMenuItem(value: s.subjectId, child: Text(s.subjectName, overflow: TextOverflow.ellipsis))],
                onChanged: enabled && _sectionId != null ? (v) => setState(() => _subjectId = v) : null,
              ),
            ],
            const SizedBox(height: Gaps.md),
            TextField(
              controller: _title,
              enabled: enabled,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: 'Title', errorText: _errors.title),
              onChanged: (_) => setState(() => _errors = HomeworkFormErrors(section: _errors.section, subject: _errors.subject, description: _errors.description, due: _errors.due, maxMarks: _errors.maxMarks)),
            ),
            const SizedBox(height: Gaps.sm),
            TextField(
              controller: _desc,
              enabled: enabled,
              minLines: 3,
              maxLines: 8,
              maxLength: 5000,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Instructions (optional)', alignLabelWithHint: true, errorText: _errors.description),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: Gaps.sm),
            _DueField(due: _due, error: _errors.due, enabled: enabled, onTap: _pickDue),
            const SizedBox(height: Gaps.md),
            AppCard(
              tone: CardTone.outlined,
              padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.xs, Gaps.sm, Gaps.xs),
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow online submissions'),
                subtitle: Text(_allow ? 'Students can hand in text or photos in the app.' : 'Students do the work on paper; nothing to review here.'),
                value: _allow,
                onChanged: enabled ? (v) => setState(() => _allow = v) : null,
              ),
            ),
            if (_allow) ...[
              const SizedBox(height: Gaps.md),
              TextField(
                controller: _max,
                enabled: enabled,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                decoration: InputDecoration(labelText: 'Maximum marks (optional)', helperText: 'Leave empty if this work is not marked.', errorText: _errors.maxMarks),
                onChanged: (_) => setState(() => _errors = HomeworkFormErrors(section: _errors.section, subject: _errors.subject, title: _errors.title, description: _errors.description, due: _errors.due)),
              ),
            ],
            const SizedBox(height: Gaps.lg),
            AttachmentEditor(purpose: 'homework', attachments: _attachments, enabled: enabled, onChanged: (a) => setState(() => _attachments = a)),
          ],
        ),
      ),
    );
  }

  Widget _actions(bool canPublish, bool blocked) {
    final draftNow = !_editing || (widget.editing?.isDraft ?? false);
    final busy = _busy;
    final Widget primary;
    final Widget? secondary;
    if (draftNow) {
      secondary = SecondaryButton(label: _editing ? 'Save draft' : 'Save as draft', onPressed: busy || blocked ? null : () => _save(publish: false));
      primary = PrimaryButton(label: 'Publish', icon: Icons.send_rounded, loading: busy, onPressed: blocked || !canPublish ? null : () => _save(publish: true));
    } else {
      secondary = null;
      primary = PrimaryButton(label: 'Save changes', loading: busy, onPressed: blocked ? null : () => _save(publish: false));
    }
    return Row(
      children: [
        if (secondary != null) ...[Expanded(child: secondary), const SizedBox(width: Gaps.md)],
        Expanded(child: primary),
      ],
    );
  }
}

class _DueField extends StatelessWidget {
  const _DueField({required this.due, required this.error, required this.enabled, required this.onTap});
  final DateTime? due;
  final String? error;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = due == null ? 'Choose date and time' : '${fmtDayLong(due!)}, ${fmtTime(due!)}';
    return Semantics(
      button: true,
      label: 'Due date, $text${error == null ? '' : '. $error'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: Radii.field,
        child: InputDecorator(
          decoration: InputDecoration(labelText: 'Due', errorText: error, suffixIcon: const Icon(Icons.event_rounded)),
          child: Text(text, style: context.text.bodyMedium?.copyWith(color: enabled ? t.text : t.inkDisabled)),
        ),
      ),
    );
  }
}
