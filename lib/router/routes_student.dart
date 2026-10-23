import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/me.dart';
import '../features/dashboard/student_home_screen.dart';
import '../features/learner/learner_hub_screens.dart';
import '../features/profile/settings_screen.dart';
import '../features/schedule/calendar_screen.dart';
import '../features/shell/role_nav.dart';
import '../features/tasks/tasks_screen.dart';
import 'role_module.dart';

/// Paths owned by the student experience. Add new pushed screens here (one constant per screen).
abstract final class StudentRoutes {
  static const prefix = '/student';
}

/// Student experience: Home, My Tasks, Calendar, Learning, Profile.
///
/// To add a screen to this role:
///  1. build it under `lib/features/<area>/` (screens, widgets, providers),
///  2. add its path constant to [StudentRoutes],
///  3. add a `GoRoute` to [routes] below (pushed screens cover the bottom bar),
///  4. for a bottom-bar tab, give the tab a `builder:` that returns the feature's screen.
final studentModule = RoleModule(
  experience: Experience.student,
  tabs: [
    TabSpec(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, title: 'Home', subtitle: '', kind: TabKind.feature, builder: (_) => const StudentHomeScreen()),
    TabSpec(
      label: 'My Tasks',
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist_rounded,
      title: 'My Tasks',
      kind: TabKind.feature,
      builder: (_) => const TasksScreen(),
      subtitle: 'Homework and your own to-dos, in one list.',
      features: const [
        FeatureSpec(Icons.assignment_outlined, 'Homework', 'Assignments from your teachers with due dates, and a place to submit your work.'),
        FeatureSpec(Icons.task_alt_rounded, 'Personal to-dos', 'Add your own tasks and reminders so nothing slips.'),
      ],
    ),
    TabSpec(
      label: 'Calendar',
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month_rounded,
      title: 'Calendar',
      kind: TabKind.feature,
      builder: (_) => const CalendarScreen(embedded: true),
      subtitle: 'Timetable, exams, holidays and events.',
      features: const [
        FeatureSpec(Icons.schedule_rounded, 'Timetable', 'Your classes for each day of the week.'),
        FeatureSpec(Icons.event_rounded, 'Exams and events', 'Exam dates, school events and holidays.'),
      ],
    ),
    TabSpec(
      label: 'Learning',
      icon: Icons.auto_stories_outlined,
      selectedIcon: Icons.auto_stories_rounded,
      title: 'Learning',
      kind: TabKind.feature,
      builder: (_) => const LearningScreen(),
      subtitle: 'Study materials, syllabus and results.',
      features: const [
        FeatureSpec(Icons.folder_copy_outlined, 'Study materials', 'Notes and resources shared by your teachers.'),
        FeatureSpec(Icons.timeline_rounded, 'Syllabus progress', 'See what has been covered in each subject.'),
        FeatureSpec(Icons.workspace_premium_outlined, 'Results', 'Published marks and report cards.'),
      ],
      sensitive: true,
    ),
    TabSpec(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      title: 'Profile',
      subtitle: '',
      kind: TabKind.feature,
      builder: (_) => const SettingsScreen(embedded: true, header: MySchoolLinks()),
      sensitive: true,
    ),
  ],
  routes: <RouteBase>[
    // GoRoute(path: StudentRoutes.xyz, builder: (context, state) => const XyzScreen()),
  ],
);
