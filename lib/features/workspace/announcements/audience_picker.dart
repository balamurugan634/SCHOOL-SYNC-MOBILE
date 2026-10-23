import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/design/design.dart';
import '../../../core/network/app_exception.dart';
import '../../../data/models/staff/comms.dart';
import 'announcement_logic.dart';
import 'announcement_providers.dart';

/// Chooses an announcement's audience within an [AudiencePolicy]:
/// teachers see only the classes they lead or teach; school-scope authors also get Everyone, user types and grades.
class AudiencePicker extends ConsumerWidget {
  const AudiencePicker({super.key, required this.policy, required this.selected, required this.onChanged, this.error, this.enabled = true});

  final AudiencePolicy policy;
  final List<AudienceTarget> selected;
  final ValueChanged<List<AudienceTarget>> onChanged;
  final String? error;
  final bool enabled;

  bool _has(AudienceTarget t) => selected.contains(t);

  void _toggle(AudienceTarget t) {
    if (t.type == 'all') {
      onChanged(_has(t) ? const [] : const [everyoneTarget]);
      return;
    }
    final next = [for (final s in selected) if (s.type != 'all') s];
    if (next.contains(t)) {
      next.remove(t);
    } else {
      next.add(t);
    }
    onChanged(next);
  }

  Widget _chip(AudienceTarget t) => FilterChip(label: Text(t.label), selected: _has(t), onSelected: enabled ? (_) => _toggle(t) : null, tooltip: t.label);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final sections = ref.watch(audienceSectionsProvider(policy.sectionsOnly));
    final grades = policy.sectionsOnly ? null : ref.watch(audienceGradesProvider);

    Widget retry(Object e, VoidCallback onRetry) => Row(
      children: [
        Expanded(child: Text(AppException.from(e).isNetwork ? 'You are offline, so the list could not load.' : 'The list could not load.', style: context.text.bodySmall?.copyWith(color: t.danger))),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );

    final sectionTargets = sections.value == null ? const <AudienceTarget>[] : [for (final s in sections.value!) AudienceTarget(type: 'section', id: s.id, label: s.title)];
    final gradeTargets = grades?.value == null ? const <AudienceTarget>[] : [for (final g in grades!.value!) AudienceTarget(type: 'grade', id: g.id, label: g.name)];
    // Anything already chosen (an edited draft) stays visible even when it is not in the loaded lists.
    final extras = [for (final s in selected) if (s.type != 'all' && s.type != 'user_type' && !sectionTargets.contains(s) && !gradeTargets.contains(s)) s];

    return Semantics(
      container: true,
      label: 'Audience',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(policy.sectionsOnly ? 'Which classes?' : 'Who is this for?', style: context.text.titleMedium)),
              if (policy.sectionsOnly && sectionTargets.isNotEmpty)
                TextButton(
                  onPressed: !enabled ? null : () => onChanged(selected.length == sectionTargets.length ? const [] : sectionTargets),
                  child: Text(selected.length == sectionTargets.length ? 'Clear' : 'Select all'),
                ),
            ],
          ),
          if (policy.sectionsOnly) Text('You can write to the classes you lead or teach.', style: context.text.bodySmall),
          const SizedBox(height: Gaps.sm),
          if (!policy.sectionsOnly) ...[
            Wrap(spacing: Gaps.sm, runSpacing: Gaps.xs, children: [_chip(everyoneTarget), for (final u in userTypeTargets) _chip(u)]),
            const SizedBox(height: Gaps.md),
            Text('Grades', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Gaps.xs),
            if (grades!.hasError && grades.value == null) retry(grades.error!, () => ref.invalidate(audienceGradesProvider)) else if (grades.value == null) _skeleton() else Wrap(spacing: Gaps.sm, runSpacing: Gaps.xs, children: [for (final g in gradeTargets) _chip(g)]),
            const SizedBox(height: Gaps.md),
            Text('Classes', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Gaps.xs),
          ],
          if (sections.hasError && sections.value == null)
            retry(sections.error!, () => ref.invalidate(audienceSectionsProvider(policy.sectionsOnly)))
          else if (sections.value == null)
            _skeleton()
          else if (sectionTargets.isEmpty && extras.isEmpty)
            Text(policy.sectionsOnly ? 'You are not assigned to any class yet, so there is nobody to write to.' : 'There are no classes set up yet.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary))
          else
            Wrap(spacing: Gaps.sm, runSpacing: Gaps.xs, children: [for (final s in sectionTargets) _chip(s), for (final s in extras) _chip(s)]),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: Gaps.sm),
              child: Semantics(liveRegion: true, child: Row(children: [Icon(Icons.error_outline_rounded, size: 16, color: t.danger), const SizedBox(width: 6), Expanded(child: Text(error!, style: context.text.bodySmall?.copyWith(color: t.danger)))])),
            ),
        ],
      ),
    );
  }

  Widget _skeleton() => Skeletonizer(child: Wrap(spacing: Gaps.sm, runSpacing: Gaps.xs, children: [for (var i = 0; i < 5; i++) const Chip(label: Text('Grade 6 A'))]));
}
