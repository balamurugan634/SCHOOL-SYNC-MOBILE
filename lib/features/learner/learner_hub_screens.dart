import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../router/routes.dart';
import '../../router/routes_shared.dart';
import '../auth/session.dart';
import '../exams/exams_screen.dart';
import '../exams/results_screen.dart';
import '../homework/homework_list_screen.dart';
import '../notifications/notifications_providers.dart';
import '../shell/tab_screen.dart';
import 'learner_context.dart';
import 'screen_frame.dart';

class _Link {
  const _Link(this.icon, this.title, this.subtitle, this.path);
  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
}

class _Links extends StatelessWidget {
  const _Links(this.links);
  final List<_Link> links;

  @override
  Widget build(BuildContext context) => RowGroup(children: [for (final l in links) ListRow(title: l.title, subtitle: l.subtitle, leading: l.icon, onTap: () => context.push(l.path))]);
}

/// Student "Learning" tab: study links and school-life links, gated by the school's features.
class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(sessionProvider.select((s) => s.siteInfo));
    final me = ref.watch(sessionProvider.select((s) => s.me));
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: PageHeader(title: 'Learning', subtitle: 'Study materials, syllabus and results.')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.huge),
          sliver: SliverList.list(
            children: [
              const GroupLabel('Study'),
              const _Links([
                _Link(Icons.assignment_outlined, 'Homework', 'Everything set by your teachers', SharedRoutes.homework),
                _Link(Icons.workspace_premium_outlined, 'Results and report cards', 'Published marks and grades', SharedRoutes.results),
                _Link(Icons.event_note_outlined, 'Exam schedule', 'Dates, times and rooms', SharedRoutes.exams),
                _Link(Icons.folder_copy_outlined, 'Study materials', 'Notes and links from teachers', SharedRoutes.materials),
                _Link(Icons.timeline_rounded, 'Syllabus progress', 'What has been covered', SharedRoutes.syllabus),
              ]),
              const GroupLabel('School life'),
              _Links([
                const _Link(Icons.fact_check_outlined, 'Attendance', 'Your presence and absences', SharedRoutes.attendance),
                const _Link(Icons.campaign_outlined, 'Announcements', 'Notices from the school', SharedRoutes.announcements),
                const _Link(Icons.event_outlined, 'Events', 'Trips, sports days and holidays', SharedRoutes.events),
                const _Link(Icons.event_busy_outlined, 'Leave', 'Apply and track leave', SharedRoutes.leave),
                if (info?.features.library ?? true) const _Link(Icons.local_library_outlined, 'Library', 'Books you have borrowed', SharedRoutes.library),
                if ((info?.features.transport ?? true)) const _Link(Icons.directions_bus_outlined, 'School bus', 'Your route and timings', SharedRoutes.transport),
                if ((info?.features.fees ?? true) && (me?.canAny(const ['fees:view', 'payments:view']) ?? false)) const _Link(Icons.account_balance_wallet_outlined, 'Fees and receipts', 'Invoices and payments', SharedRoutes.fees),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// "My school" links shown at the top of the student Profile tab.
class MySchoolLinks extends ConsumerWidget {
  const MySchoolLinks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsUnreadProvider).value ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GroupLabel('My school'),
        RowGroup(
          children: [
            ListRow(title: 'My details', subtitle: 'Contact details and emergency contacts', leading: Icons.badge_outlined, onTap: () => context.push(SharedRoutes.profileDetails)),
            ListRow(title: 'Notifications', subtitle: unread > 0 ? '$unread unread' : 'Your inbox', leading: Icons.notifications_none_rounded, onTap: () => context.push(Routes.notifications)),
            ListRow(title: 'Leave', subtitle: 'Apply and track leave', leading: Icons.event_busy_outlined, onTap: () => context.push(SharedRoutes.leave)),
          ],
        ),
      ],
    );
  }
}

/// Parent "Academics" tab: homework, exams and results for the selected child, plus quick links.
class ParentAcademicsScreen extends ConsumerStatefulWidget {
  const ParentAcademicsScreen({super.key});

  @override
  ConsumerState<ParentAcademicsScreen> createState() => _ParentAcademicsScreenState();
}

enum _Part { homework, exams, results }

class _ParentAcademicsScreenState extends ConsumerState<ParentAcademicsScreen> {
  _Part _part = _Part.homework;

  @override
  Widget build(BuildContext context) {
    return ScreenFrame(
      title: 'Academics',
      subtitle: 'Homework, exams and results.',
      embedded: true,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<_Part>(
                showSelectedIcon: false,
                segments: const [ButtonSegment(value: _Part.homework, label: Text('Homework')), ButtonSegment(value: _Part.exams, label: Text('Exams')), ButtonSegment(value: _Part.results, label: Text('Results'))],
                selected: {_part},
                onSelectionChanged: (s) => setState(() => _part = s.first),
              ),
            ),
          ),
          Expanded(
            child: switch (_part) {
              _Part.homework => const HomeworkListScreen(bare: true),
              _Part.exams => const ExamsScreen(bare: true),
              _Part.results => const ResultsScreen(bare: true),
            },
          ),
          const _QuickLinks(),
        ],
      ),
    );
  }
}

class _QuickLinks extends StatelessWidget {
  const _QuickLinks();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xs, Gaps.page, Gaps.sm),
    child: Row(
      children: [
        Expanded(child: OutlinedButton(onPressed: () => context.push(SharedRoutes.timetable), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)), child: const Text('Timetable'))),
        const SizedBox(width: Gaps.sm),
        Expanded(child: OutlinedButton(onPressed: () => context.push(SharedRoutes.materials), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)), child: const Text('Materials'))),
        const SizedBox(width: Gaps.sm),
        Expanded(child: OutlinedButton(onPressed: () => context.push(SharedRoutes.syllabus), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)), child: const Text('Syllabus'))),
      ],
    ),
  );
}

/// The More tab for students and parents: account, notifications and everything else, with real destinations.
class LearnerMoreScreen extends ConsumerWidget {
  const LearnerMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider.select((s) => s.me));
    final info = ref.watch(sessionProvider.select((s) => s.siteInfo));
    final isParent = ref.watch(isParentProvider);
    final unread = ref.watch(notificationsUnreadProvider).value ?? 0;
    if (me == null) return const SizedBox.shrink();
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: PageHeader(title: 'More', subtitle: 'Everything else, plus your account.')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.huge),
          sliver: SliverList.list(
            children: [
              AppCard(
                onTap: () => context.push(Routes.settings),
                child: Row(
                  children: [
                    UserAvatar(name: me.displayName, url: me.avatarUrl, size: 52, ringColor: context.tokens.roleTint(me.experience)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(me.displayName, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), RoleChip(label: me.experience.label, tint: context.tokens.roleTint(me.experience))])),
                    Icon(Icons.chevron_right_rounded, color: context.tokens.textTertiary),
                  ],
                ),
              ),
              const GroupLabel('Account'),
              RowGroup(
                children: [
                  ListRow(title: 'Notifications', subtitle: unread > 0 ? '$unread unread' : 'Your inbox and push settings', leading: Icons.notifications_none_rounded, onTap: () => context.push(Routes.notifications)),
                  ListRow(title: 'My details', subtitle: 'Contact details and photo', leading: Icons.badge_outlined, onTap: () => context.push(SharedRoutes.profileDetails)),
                  ListRow(title: 'Settings and security', subtitle: 'Password, devices, app lock, theme', leading: Icons.settings_outlined, onTap: () => context.push(Routes.settings)),
                ],
              ),
              const GroupLabel('School'),
              RowGroup(
                children: [
                  ListRow(title: 'Announcements', subtitle: 'Circulars and notices', leading: Icons.campaign_outlined, onTap: () => context.push(SharedRoutes.announcements)),
                  ListRow(title: 'Events and holidays', subtitle: 'Registrations and permission forms', leading: Icons.event_outlined, onTap: () => context.push(SharedRoutes.events)),
                  ListRow(title: 'Calendar and timetable', subtitle: 'Classes, exams and deadlines', leading: Icons.calendar_month_outlined, onTap: () => context.push(SharedRoutes.calendar)),
                  if (isParent) ListRow(title: 'Meetings with teachers', subtitle: 'Request and track meetings', leading: Icons.handshake_outlined, onTap: () => context.push(SharedRoutes.meetings)),
                  ListRow(title: 'Leave', subtitle: isParent ? 'Apply for leave for your child' : 'Apply and track leave', leading: Icons.event_busy_outlined, onTap: () => context.push(SharedRoutes.leave)),
                  ListRow(title: 'Study materials', subtitle: 'Notes and links from teachers', leading: Icons.folder_copy_outlined, onTap: () => context.push(SharedRoutes.materials)),
                  if (info?.features.library ?? true) ListRow(title: 'Library', subtitle: 'Books on loan and fines', leading: Icons.local_library_outlined, onTap: () => context.push(SharedRoutes.library)),
                  if (info?.features.transport ?? true) ListRow(title: 'School bus', subtitle: 'Route, stop and timings', leading: Icons.directions_bus_outlined, onTap: () => context.push(SharedRoutes.transport)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
