import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../data/models/me.dart';
import '../auth/session.dart';

class _Slide {
  const _Slide(this.role, this.illo, this.audience, this.title, this.body);
  final Experience role;
  final Illo illo;
  final String audience;
  final String title;
  final String body;
}

const _slides = <_Slide>[
  _Slide(
    Experience.student,
    Illo.onboardingStudent,
    'Students',
    'Your timetable, homework and exams',
    'See today\'s classes, what is due and what is coming up, and keep your own to-do list in one place.',
  ),
  _Slide(
    Experience.parent,
    Illo.onboardingParent,
    'Parents',
    'Follow each of your children',
    'Switch between children to see attendance, results, fees and school notices, and apply for leave.',
  ),
  _Slide(
    Experience.teacher,
    Illo.onboardingTeacher,
    'Teachers',
    'Attendance, homework and marks',
    'Mark attendance, set homework and enter marks for the classes you teach, from your phone.',
  ),
  _Slide(
    Experience.management,
    Illo.onboardingManagement,
    'School management',
    'The school at a glance',
    'Review attendance, admissions, fee collection and alerts. Each person only sees what their role allows.',
  ),
];

/// Four typographic slides, one monochrome glyph each. Shown once.
class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await ref.read(sessionProvider.notifier).completeIntro();
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(duration: Motion.slow, curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.page, 8, 8, 0),
              child: Row(
                children: [
                  BrandTile(color: t.brandDefault, size: 28),
                  const SizedBox(width: 10),
                  Text('SchoolSync', style: context.text.titleMedium),
                  const Spacer(),
                  Opacity(opacity: _isLast ? 0 : 1, child: IgnorePointer(ignoring: _isLast, child: GhostButton(label: 'Skip', onPressed: _finish))),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gaps.xxl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(child: IllustrationView(s.illo, width: 280, accent: s.role == Experience.management ? null : t.roleTint(s.role))),
                        const SizedBox(height: Gaps.xl),
                        Text(s.audience, style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
                        const SizedBox(height: 6),
                        Text(s.title, style: context.text.displaySmall),
                        const SizedBox(height: Gaps.md),
                        Text(s.body, style: context.text.bodyLarge?.copyWith(color: t.textSecondary)),
                        const SizedBox(height: Gaps.xl),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.xxl, 0, Gaps.xxl, Gaps.xl),
              child: Row(
                children: [
                  Semantics(
                    label: 'Page ${_index + 1} of ${_slides.length}',
                    child: Row(
                      children: [
                        for (var i = 0; i < _slides.length; i++)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: i == _index ? t.brand.solid : t.borderStrong),
                          ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  SizedBox(width: 140, child: PrimaryButton(label: _isLast ? 'Get started' : 'Next', loading: _finishing, onPressed: _next)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
