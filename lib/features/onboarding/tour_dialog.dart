import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../data/models/me.dart';
import '../../router/role_modules.dart';

class _TourStep {
  const _TourStep(this.title, this.body, this.tabs);
  final String title;
  final String body;

  /// Indexes into the experience's bottom-navigation tabs that this step points at.
  final List<int> tabs;
}

List<_TourStep> _stepsFor(Experience e, String name) => switch (e) {
  Experience.student => [
    _TourStep('Welcome, $name', 'Home shows today\'s classes, what is due and what is coming up.', const [0]),
    const _TourStep('Plan your work', 'Homework and your own to-dos are in My Tasks. Your timetable, exams and events are in Calendar.', [1, 2]),
    const _TourStep('Learn and manage your account', 'Study materials and results are in Learning. Your account and privacy settings are in Profile.', [3, 4]),
  ],
  Experience.parent => [
    _TourStep('Welcome, $name', 'Home gives a quick view of your child\'s day. If you have more than one child, switch between them at the top.', const [0]),
    const _TourStep('Follow their progress', 'Attendance shows presence and lets you apply for leave. Academics has homework, exams and results.', [1, 2]),
    const _TourStep('Fees and more', 'Check balances and receipts in Fees. Announcements, meetings and your account are in More.', [3, 4]),
  ],
  Experience.teacher => [
    _TourStep('Welcome, $name', 'Home shows your day: today\'s periods, attendance still to mark and work to review.', const [0]),
    const _TourStep('Your classes', 'Classes lists the sections you teach. Attendance lets you mark a register in a few taps.', [1, 2]),
    const _TourStep('Homework and more', 'Set homework and review submissions in Homework. Marks entry, leave and your account are in More.', [3, 4]),
  ],
  Experience.management => [
    _TourStep('Welcome, $name', 'Home is your school overview: attendance today, requests waiting for approval and anything that needs attention.', const [0]),
    const _TourStep('Run the school', 'Academics covers structure, timetable and exams. People covers students, parents, staff and admissions.', [1, 2]),
    const _TourStep('Finance and more', 'Finance shows collection and dues, for roles with access. Reports, announcements and settings are in More.', [3, 4]),
  ],
};

/// The welcome tour: a small dialog with a title, two lines, step dots and Next.
/// Shown once per user over the real home screen; the tabs it mentions are in the bar behind it.
class TourDialog extends StatefulWidget {
  const TourDialog({super.key, required this.me});
  final Me me;

  @override
  State<TourDialog> createState() => _TourDialogState();
}

class _TourDialogState extends State<TourDialog> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tabs = tabsFor(widget.me.experience);
    final steps = _stepsFor(widget.me.experience, widget.me.firstName);
    final step = steps[_i];
    final last = _i == steps.length - 1;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: Gaps.xxl),
      child: Padding(
        padding: const EdgeInsets.all(Gaps.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.me.experience.label} tour  ·  ${_i + 1} of ${steps.length}', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Gaps.sm),
            AnimatedSwitcher(
              duration: Motion.base,
              child: Column(
                key: ValueKey(_i),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: context.text.titleLarge),
                  const SizedBox(height: 6),
                  Text(step.body, style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
                  const SizedBox(height: Gaps.md),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final i in step.tabs) StatusChip(tabs[i].label, tone: StatusTone.brand, icon: tabs[i].selectedIcon)],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Gaps.xl),
            Row(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Container(margin: const EdgeInsets.only(right: 6), width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: i == _i ? t.brand.solid : t.borderStrong)),
                const Spacer(),
                if (!last) TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Skip')),
                const SizedBox(width: Gaps.xs),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                  onPressed: () => last ? Navigator.of(context).pop() : setState(() => _i++),
                  child: Text(last ? 'Done' : 'Next'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
