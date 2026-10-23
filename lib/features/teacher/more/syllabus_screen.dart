import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../data/repositories/staff/academics_repository.dart';
import '../../workspace/workspace.dart';
import 'more_providers.dart';
import 'syllabus_logic.dart';

/// Update how far each class has got in the syllabus. Pick a class and subject you teach, set each topic's
/// status, then save once (the API applies all changes together).
class SyllabusScreen extends ConsumerStatefulWidget {
  const SyllabusScreen({super.key, this.sectionId});
  final String? sectionId;

  @override
  ConsumerState<SyllabusScreen> createState() => _SyllabusScreenState();
}

class _SyllabusScreenState extends ConsumerState<SyllabusScreen> {
  String? _sectionId;
  String? _subjectId;
  Map<String, SyllabusStatus> _changes = const {};
  bool _saving = false;

  /// Keeps the chosen class / subject valid for the assignments that loaded.
  MyAssignment? _current(List<MyAssignment> all) {
    if (all.isEmpty) return null;
    final sectionId = (_sectionId != null && all.any((a) => a.sectionId == _sectionId)) ? _sectionId! : (widget.sectionId != null && all.any((a) => a.sectionId == widget.sectionId) ? widget.sectionId! : all.first.sectionId);
    final inSection = all.where((a) => a.sectionId == sectionId).toList();
    return inSection.firstWhere((a) => a.subjectId == _subjectId, orElse: () => inSection.first);
  }

  Future<bool> _okToLeaveChanges() async {
    if (_changes.isEmpty) return true;
    return confirmAction(context, title: 'Discard your changes?', message: 'You changed ${_changes.length} ${_changes.length == 1 ? 'topic' : 'topics'} that are not saved yet.', confirmLabel: 'Discard', destructive: true);
  }

  Future<void> _choose({String? sectionId, String? subjectId, required List<MyAssignment> all}) async {
    if (!await _okToLeaveChanges()) return;
    setState(() {
      _changes = const {};
      if (sectionId != null) {
        _sectionId = sectionId;
        _subjectId = all.firstWhere((a) => a.sectionId == sectionId).subjectId;
      }
      if (subjectId != null) _subjectId = subjectId;
    });
  }

  Future<void> _save(MyAssignment a) async {
    setState(() => _saving = true);
    final n = _changes.length;
    final done = await runWrite(context, ref, () => ref.read(academicsRepositoryProvider).setProgress(a.sectionId, _changes), success: 'Progress saved for $n ${n == 1 ? 'topic' : 'topics'}.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (!done) return;
    final key = (gradeId: a.gradeId, sectionId: a.sectionId, subjectId: a.subjectId);
    ref.invalidate(syllabusTopicsProvider(key));
    ref.invalidate(syllabusCoverageProvider((sectionId: a.sectionId, subjectId: a.subjectId)));
    setState(() => _changes = const {});
  }

  @override
  Widget build(BuildContext context) {
    final assignments = ref.watch(myTeachingAssignmentsProvider);
    return PopScope(
      canPop: _changes.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _okToLeaveChanges()) {
          setState(() => _changes = const {});
          nav.pop();
        }
      },
      child: FeatureGate(
        label: 'Syllabus progress',
        anyPermission: const ['syllabus:view', 'syllabus:edit'],
        child: StaffFrame(
          title: 'Syllabus progress',
          body: AsyncBody<List<MyAssignment>>(
            value: assignments,
            onRetry: () => ref.invalidate(myTeachingAssignmentsProvider),
            isEmpty: (l) => l.isEmpty,
            empty: const EmptyState(illo: Illo.emptyGeneric, title: 'No classes assigned yet', message: 'Syllabus progress is kept for the subjects you teach. Ask the office to assign your classes.'),
            data: (all) {
              final a = _current(all)!;
              return _Body(
                all: all,
                current: a,
                changes: _changes,
                saving: _saving,
                canEdit: ref.can('syllabus:edit'),
                onSection: (id) => _choose(sectionId: id, all: all),
                onSubject: (id) => _choose(subjectId: id, all: all),
                onChange: (topic, s) => setState(() => _changes = withChange(_changes, topic, s)),
                onSave: () => _save(a),
                onDiscard: () => setState(() => _changes = const {}),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.all, required this.current, required this.changes, required this.saving, required this.canEdit, required this.onSection, required this.onSubject, required this.onChange, required this.onSave, required this.onDiscard});
  final List<MyAssignment> all;
  final MyAssignment current;
  final Map<String, SyllabusStatus> changes;
  final bool saving;
  final bool canEdit;
  final ValueChanged<String> onSection;
  final ValueChanged<String> onSubject;
  final void Function(TopicEntry topic, SyllabusStatus status) onChange;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final readOnly = ref.watch(readOnlyProvider);
    final sections = <String, MyAssignment>{for (final a in all) a.sectionId: a};
    final subjects = all.where((a) => a.sectionId == current.sectionId).toList();
    final key = (gradeId: current.gradeId, sectionId: current.sectionId, subjectId: current.subjectId);
    final topics = ref.watch(syllabusTopicsProvider(key));
    final serverCoverage = ref.watch(syllabusCoverageProvider((sectionId: current.sectionId, subjectId: current.subjectId))).value;

    Future<void> refresh() async {
      ref.invalidate(syllabusTopicsProvider(key));
      ref.invalidate(syllabusCoverageProvider((sectionId: current.sectionId, subjectId: current.subjectId)));
      try {
        await ref.read(syllabusTopicsProvider(key).future);
      } catch (_) {}
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.sm),
          child: DropdownButtonFormField<String>(
            initialValue: current.sectionId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Class'),
            items: [for (final s in sections.values) DropdownMenuItem(value: s.sectionId, child: Text(s.sectionTitle, overflow: TextOverflow.ellipsis))],
            onChanged: (v) {
              if (v != null && v != current.sectionId) onSection(v);
            },
          ),
        ),
        if (subjects.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            child: FilterChips<String>(options: [for (final s in subjects) s.subjectId], selected: current.subjectId, onSelected: onSubject, labelOf: (id) => subjects.firstWhere((s) => s.subjectId == id).subjectName),
          )
        else
          Padding(padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm), child: Align(alignment: Alignment.centerLeft, child: StatusChip(current.subjectName, tone: StatusTone.neutral, icon: Icons.menu_book_outlined))),
        Expanded(
          child: AsyncBody<List<TopicEntry>>(
            value: topics,
            onRetry: refresh,
            isEmpty: (l) => l.isEmpty,
            empty: EmptyState(illo: Illo.emptyGeneric, title: 'No topics yet', message: 'There is no syllabus for ${current.subjectName} in ${current.gradeName} yet. The office adds the topics.', actionLabel: 'Refresh', onAction: refresh),
            data: (list) {
              final preview = previewCoverage(list, changes);
              final groups = groupByTerm(list);
              return RefreshScroll(
                onRefresh: refresh,
                padding: EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, changes.isEmpty ? Gaps.huge : 96),
                children: [
                  const ReadOnlyBanner(),
                  if (!canEdit) const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(message: 'You can see this progress but not change it.')),
                  SectionCard(
                    title: 'Coverage',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${preview.percent.toStringAsFixed(preview.percent % 1 == 0 ? 0 : 1)}%', style: figureStyle(context, size: 32)),
                            const SizedBox(width: Gaps.sm),
                            Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${preview.completed} of ${preview.total} topics completed${preview.inProgress > 0 ? ', ${preview.inProgress} in progress' : ''}', style: context.text.bodyMedium))),
                          ],
                        ),
                        const SizedBox(height: Gaps.sm),
                        MeterBar(value: preview.percent / 100, semanticLabel: 'Syllabus coverage'),
                        if (changes.isNotEmpty && serverCoverage != null) Padding(padding: const EdgeInsets.only(top: Gaps.xs), child: Text('Saved so far: ${serverCoverage.percent.toStringAsFixed(serverCoverage.percent % 1 == 0 ? 0 : 1)}%', style: context.text.bodySmall)),
                      ],
                    ),
                  ),
                  for (final g in groups) ...[
                    GroupLabel(g.$1),
                    RowGroup(
                      children: [
                        for (final topic in g.$2)
                          _TopicRow(topic: topic, status: effectiveStatus(topic, changes), changed: changes.containsKey(topic.id), enabled: canEdit && !readOnly && !saving, onChange: (s) => onChange(topic, s)),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        if (changes.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.border))),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(Gaps.md),
                child: Row(
                  children: [
                    Expanded(child: SecondaryButton(label: 'Discard', onPressed: saving ? null : onDiscard)),
                    const SizedBox(width: Gaps.md),
                    Expanded(flex: 2, child: PrimaryButton(label: 'Save ${changes.length} ${changes.length == 1 ? 'change' : 'changes'}', loading: saving, onPressed: readOnly ? null : onSave)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.status, required this.changed, required this.enabled, required this.onChange});
  final TopicEntry topic;
  final SyllabusStatus status;
  final bool changed;
  final bool enabled;
  final ValueChanged<SyllabusStatus> onChange;

  static (StatusTone, IconData) _look(SyllabusStatus s) => switch (s) {
    SyllabusStatus.notStarted => (StatusTone.neutral, Icons.radio_button_unchecked_rounded),
    SyllabusStatus.inProgress => (StatusTone.info, Icons.timelapse_rounded),
    SyllabusStatus.completed => (StatusTone.success, Icons.check_circle_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (tone, icon) = _look(status);
    final iconColor = switch (status) { SyllabusStatus.completed => t.success, SyllabusStatus.inProgress => t.brand.ink, _ => t.textTertiary };
    return Semantics(
      container: true,
      label: '${topic.title}, ${status.label}${changed ? ', not saved yet' : ''}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Row(
          children: [
            // Tap to cycle: not started -> in progress -> completed.
            IconButton(
              tooltip: enabled ? 'Mark "${topic.title}" as ${nextSyllabusStatus(status).label.toLowerCase()}' : status.label,
              onPressed: enabled ? () => onChange(nextSyllabusStatus(status)) : null,
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              icon: Icon(icon, color: iconColor),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: Gaps.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.title, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    Row(children: [
                      Flexible(child: Text([if (topic.plannedHours != null) '${topic.plannedHours} h planned'].join(), style: context.text.bodySmall)),
                      if (changed) Text(topic.plannedHours != null ? '  ·  Not saved' : 'Not saved', style: context.text.labelSmall?.copyWith(color: t.warning)),
                    ]),
                  ],
                ),
              ),
            ),
            PopupMenuButton<SyllabusStatus>(
              enabled: enabled,
              tooltip: 'Set the status of "${topic.title}"',
              onSelected: onChange,
              itemBuilder: (_) => [for (final s in SyllabusStatus.values) CheckedPopupMenuItem(value: s, checked: s == status, child: Text(s.label))],
              child: Padding(padding: const EdgeInsets.fromLTRB(Gaps.sm, Gaps.sm, Gaps.md, Gaps.sm), child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 40), child: Center(child: StatusChip(status.label, tone: tone, icon: icon)))),
            ),
          ],
        ),
      ),
    );
  }
}
