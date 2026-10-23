import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import 'dashboard_providers.dart';
import 'dashboard_widgets.dart';
import 'home_frame.dart';

/// Student Home: today's classes, homework, attendance, exams, tasks, announcements, what is coming up.
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
    return HomeFrame(
      onRefresh: refresh,
      staleSince: d.fromCache ? d.fetchedAt : null,
      error: v.hasError ? v.error : null,
      children: [
        TodayCard(day: d.day.timetable),
        HomeworkDashCard(snapshot: d.day.homework),
        AttendanceCard(summary: d.day.attendance, today: d.day.attendanceToday),
        ExamsDashCard(exams: d.day.upcomingExams, published: d.day.publishedResults),
        TasksDashCard(tasks: d.tasks, onAll: () => context.go('/tab/1')),
        AnnouncementsDashCard(snapshot: d.announcements),
        CalendarDashCard(items: d.calendar),
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
