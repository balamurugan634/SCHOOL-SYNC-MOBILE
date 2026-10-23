import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/dashboards.dart';
import '../../../data/repositories/staff/staff_dashboard_repository.dart';
import '../../auth/session.dart';
import '../../home/home_header.dart';
import '../../workspace/workspace.dart';
import 'home_blocks.dart';
import 'teacher_home_providers.dart';

/// The staggered reveal runs on the first dashboard load only (design.md section 9).
bool _homeRevealed = false;

/// Home for teachers: attendance still to mark (one tap into the roll call), today's timetable with the current period
/// highlighted, what is waiting (homework to review, marks to enter, student leave), meetings and announcements.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final value = ref.watch(teacherDashboardProvider);

    Future<void> refresh() async {
      ref.invalidate(teacherDashboardProvider);
      try {
        await ref.read(teacherDashboardProvider.future);
      } catch (_) {}
    }

    final children = <Widget>[HomeHeader(me: me, info: session.siteInfo)];
    if (value.hasValue) {
      children.add(_Blocks(loaded: value.requireValue, stale: value.hasError ? value.error : null, onRetry: refresh));
    } else if (value.hasError) {
      children.add(SizedBox(height: 420, child: ErrorState(error: value.error!, onRetry: () => ref.invalidate(teacherDashboardProvider))));
    } else {
      children.add(const Padding(padding: EdgeInsets.only(top: Gaps.lg), child: _HomeSkeleton()));
    }

    return RefreshOnFocus(
      onRefresh: () => ref.invalidate(teacherDashboardProvider),
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.zero, children: children),
      ),
    );
  }
}

class _Blocks extends ConsumerWidget {
  const _Blocks({required this.loaded, required this.onRetry, this.stale});
  final Loaded<TeacherDashboard> loaded;
  final Object? stale;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = loaded.value;
    final readOnly = ref.watch(readOnlyProvider);
    final canMarks = ref.can('marks:view');
    final canHomework = ref.can('homework:view');
    final canMeetings = ref.can('meetings:view');
    final firstLoad = !_homeRevealed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _homeRevealed = true);
    var n = 0;
    Widget stage(Widget w) {
      final i = n++;
      return Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: firstLoad ? w.reveal(index: i) : w);
    }

    final hasTodo = d.toReviewCount > 0 || d.marksPending > 0 || d.pendingLeaveCount > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, Gaps.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (readOnly)
            const Padding(
              padding: EdgeInsets.only(bottom: Gaps.md),
              child: InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, title: 'View-only mode', message: 'Your school\'s subscription has ended. You can read information, but changes are disabled until it is renewed.'),
            ),
          if (loaded.fromCache)
            Padding(
              padding: const EdgeInsets.only(bottom: Gaps.md),
              child: InfoBanner(tone: BannerTone.warning, icon: Icons.cloud_off_rounded, message: 'You are offline. Showing your day as it was saved ${loaded.at == null ? 'earlier' : 'at ${fmtDateTime(loaded.at!)}'}.', action: 'Try again', onAction: onRetry),
            )
          else if (stale != null)
            Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, icon: Icons.sync_problem_rounded, message: 'Could not refresh. Showing what was loaded last.', action: 'Try again', onAction: onRetry)),
          if (ref.can('attendance:create') || d.attendance.items.isNotEmpty) stage(AttendanceDueCard(attendance: d.attendance)),
          stage(TodayTimetableCard(day: d.timetable)),
          if (hasTodo || canMarks || canHomework) stage(TodoCard(d: d, canMarks: canMarks, canHomework: canHomework)),
          if (canHomework) stage(DueSoonCard(items: d.dueSoon)),
          if (canMeetings) stage(MeetingsCard(meetings: d.meetings)),
          stage(TeacherAnnouncementsCard(block: d.announcements)),
          if (d.calendar.isNotEmpty) stage(ComingUpCard(items: d.calendar)),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: Gaps.page),
        child: Row(children: [Expanded(child: StatTile(label: 'To mark')), SizedBox(width: Gaps.md), Expanded(child: StatTile(label: 'To review'))]),
      ),
      SizedBox(height: Gaps.md),
      SkeletonList(count: 3),
    ],
  );
}
