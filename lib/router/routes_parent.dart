import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/me.dart';
import '../features/attendance/attendance_screen.dart';
import '../features/dashboard/parent_home_screen.dart';
import '../features/fees/fees_screen.dart';
import '../features/learner/learner_hub_screens.dart';
import '../features/shell/role_nav.dart';
import 'role_module.dart';

/// Paths owned by the parent experience. Add new pushed screens here (one constant per screen).
abstract final class ParentRoutes {
  static const prefix = '/parent';
}

/// Parent experience: Home, Attendance, Academics, Fees, More (child selector at the top).
///
/// To add a screen to this role:
///  1. build it under `lib/features/<area>/` (screens, widgets, providers),
///  2. add its path constant to [ParentRoutes],
///  3. add a `GoRoute` to [routes] below (pushed screens cover the bottom bar),
///  4. for a bottom-bar tab, give the tab a `builder:` that returns the feature's screen.
final parentModule = RoleModule(
  experience: Experience.parent,
  tabs: [
    TabSpec(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, title: 'Home', subtitle: '', kind: TabKind.feature, builder: (_) => const ParentHomeScreen()),
    TabSpec(
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check_rounded,
      title: 'Attendance',
      kind: TabKind.feature,
      builder: (_) => const AttendanceScreen(embedded: true),
      sensitive: false,
      subtitle: 'Presence, absences and leave for your child.',
      features: const [
        FeatureSpec(Icons.event_available_rounded, 'Daily attendance', 'Present, absent and late days, with a monthly summary.'),
        FeatureSpec(Icons.sick_outlined, 'Leave requests', 'Apply for leave and follow its approval.'),
      ],
    ),
    TabSpec(
      label: 'Academics',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      title: 'Academics',
      kind: TabKind.feature,
      builder: (_) => const ParentAcademicsScreen(),
      subtitle: 'Homework, exams and results.',
      features: const [
        FeatureSpec(Icons.assignment_outlined, 'Homework', 'What is due and how your child is progressing.'),
        FeatureSpec(Icons.event_note_rounded, 'Exams', 'Upcoming exam schedule.'),
        FeatureSpec(Icons.workspace_premium_outlined, 'Results and report cards', 'Published marks and teacher remarks.'),
      ],
      sensitive: true,
    ),
    TabSpec(
      label: 'Fees',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet_rounded,
      title: 'Fees',
      kind: TabKind.feature,
      builder: (_) => const FeesScreen(embedded: true),
      subtitle: 'Balance, dues, receipts and payments.',
      features: const [
        FeatureSpec(Icons.receipt_long_rounded, 'Fee balance and dues', 'What is due, when, and what has been paid.'),
        FeatureSpec(Icons.history_rounded, 'Receipts', 'A full payment history you can download.'),
        FeatureSpec(Icons.payments_outlined, 'Pay online', 'Pay securely when your school turns online payments on.'),
      ],
      sensitive: true,
      siteFeature: 'fees',
      anyPermission: ['fees:view', 'payments:view'],
    ),
    TabSpec(
      label: 'More',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
      title: 'More',
      subtitle: 'Everything else, plus your account.',
      kind: TabKind.feature,
      builder: (_) => const LearnerMoreScreen(),
    ),
  ],
  routes: <RouteBase>[
    // GoRoute(path: ParentRoutes.xyz, builder: (context, state) => const XyzScreen()),
  ],
);
