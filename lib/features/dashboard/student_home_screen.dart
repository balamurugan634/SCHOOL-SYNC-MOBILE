import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../router/routes_shared.dart';
import '../auth/session.dart';
import 'dashboard_providers.dart';
import 'home_frame.dart';
import 'student_home_widgets.dart';

/// Student Home: what is on now, the things a student does most (leave, attendance, homework, results ...), three numbers,
/// the day as a swipeable row, and only what is due soon. Everything else is one tap away in "More" or the tabs.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(studentDashboardProvider);
    Future<void> refresh() async {
      ref.invalidate(studentDashboardProvider);
      try {
        await ref.read(studentDashboardProvider.future);
      } catch (_) {}
    }

    if (!v.hasValue) {
      return v.hasError
          ? Scaffold(body: ErrorState(error: v.error!, onRetry: () => ref.invalidate(studentDashboardProvider)))
          : const HomeFrame(onRefresh: _noop, children: [_HomeSkeleton()]);
    }
    final d = v.requireValue;
    final t = context.tokens;
    final session = ref.watch(sessionProvider);
    final me = session.me;
    final info = session.siteInfo;
    final feesOn = (info?.features.fees ?? true) && (me?.canAny(const ['fees:view', 'payments:view']) ?? false);
    final day = d.day.timetable;
    final hasDay = day != null && day.isWorkingDay && day.entries.isNotEmpty;
    final openTasks = d.tasks.where((e) => !e.isHomework && !e.done).toList();

    void go(String path) => context.push(path);
    final primary = [
      QuickAction(icon: Icons.event_busy_rounded, label: 'Apply for leave', color: t.accent, onTap: () => go(SharedRoutes.leaveNew)),
      QuickAction(icon: Icons.fact_check_rounded, label: 'My attendance', color: t.chart[5], onTap: () => go(SharedRoutes.attendance)),
      QuickAction(icon: Icons.edit_note_rounded, label: 'Homework', color: t.chart[2], badge: d.day.homework.pendingCount, onTap: () => go(SharedRoutes.homework)),
      QuickAction(icon: Icons.workspace_premium_rounded, label: 'Results', color: t.chart[4], onTap: () => go(SharedRoutes.results)),
      QuickAction(icon: Icons.schedule_rounded, label: 'Timetable', color: t.brand.solid, onTap: () => go(SharedRoutes.timetable)),
      QuickAction(icon: Icons.quiz_rounded, label: 'Exams', color: t.chart[3], onTap: () => go(SharedRoutes.exams)),
      if (feesOn)
        QuickAction(icon: Icons.account_balance_wallet_rounded, label: 'Fees', color: t.roleParent, onTap: () => go(SharedRoutes.fees))
      else
        QuickAction(icon: Icons.celebration_rounded, label: 'Events', color: t.roleParent, onTap: () => go(SharedRoutes.events)),
    ];
    final more = [
      QuickAction(icon: Icons.beach_access_rounded, label: 'My leave requests', color: t.accent, onTap: () => go(SharedRoutes.leave)),
      QuickAction(icon: Icons.calendar_month_rounded, label: 'Calendar', color: t.chart[0], onTap: () => go(SharedRoutes.calendar)),
      QuickAction(icon: Icons.campaign_rounded, label: 'Announcements', color: t.chart[3], badge: d.announcements.unreadCount, onTap: () => go(SharedRoutes.announcements)),
      QuickAction(icon: Icons.celebration_rounded, label: 'Events', color: t.roleParent, onTap: () => go(SharedRoutes.events)),
      QuickAction(icon: Icons.folder_copy_rounded, label: 'Study material', color: t.chart[2], onTap: () => go(SharedRoutes.materials)),
      QuickAction(icon: Icons.account_tree_rounded, label: 'Syllabus', color: t.chart[4], onTap: () => go(SharedRoutes.syllabus)),
      if (info?.features.library ?? true) QuickAction(icon: Icons.local_library_rounded, label: 'Library', color: t.chart[5], onTap: () => go(SharedRoutes.library)),
      if (info?.features.transport ?? true) QuickAction(icon: Icons.directions_bus_rounded, label: 'School bus', color: t.brand.solid, onTap: () => go(SharedRoutes.transport)),
      if (feesOn) QuickAction(icon: Icons.account_balance_wallet_rounded, label: 'Fees', color: t.roleParent, onTap: () => go(SharedRoutes.fees)),
    ];

    return HomeFrame(
      onRefresh: refresh,
      staleSince: d.fromCache ? d.fetchedAt : null,
      error: v.hasError ? v.error : null,
      children: [
        UpNextCard(day: d.day.timetable, pendingHomework: d.day.homework.pendingCount),
        QuickActionsGrid(
          actions: [
            ...primary,
            QuickAction(icon: Icons.apps_rounded, label: 'More', color: t.textSecondary, onTap: () => showMoreActions(context, more)),
          ],
        ),
        StatsRow(attendance: d.day.attendance, today: d.day.attendanceToday, homework: d.day.homework, tasks: openTasks.length, overdueTasks: openTasks.where((e) => e.overdue).length),
        if (hasDay) TodayStrip(day: d.day.timetable),
        if (d.day.upcomingExams.isNotEmpty) ExamStrip(exams: d.day.upcomingExams),
        DueSoonCard(snapshot: d.day.homework),
        if (d.announcements.latest.isNotEmpty) LatestNoticeCard(snapshot: d.announcements),
      ],
    );
  }
}

Future<void> _noop() async {}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();
  @override
  Widget build(BuildContext context) => const SkeletonList(count: 4, padding: EdgeInsets.zero);
}
