import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/me.dart';
import '../features/management/academics/academics_screen.dart';
import '../features/management/approvals/approval_list_screen.dart';
import '../features/management/approvals/approvals_hub_screen.dart';
import '../features/management/attendance/attendance_overview_screen.dart';
import '../features/management/finance/collection_screen.dart';
import '../features/management/finance/defaulters_screen.dart';
import '../features/management/finance/finance_screen.dart';
import '../features/management/finance/outstanding_screen.dart';
import '../features/management/home/management_home_screen.dart';
import '../features/management/more/management_more_screen.dart';
import '../features/management/people/people_screen.dart';
import '../features/management/people/staff_profile_screen.dart';
import '../features/shell/role_nav.dart';
import '../features/workspace/announcements/announcement_form_screen.dart';
import '../features/workspace/announcements/announcement_manage_screen.dart';
import '../features/workspace/announcements/announcements_screen.dart';
import '../features/workspace/me/check_in_screen.dart';
import '../features/workspace/me/my_leave_screen.dart';
import '../features/workspace/meetings/meetings_screen.dart';
import '../features/workspace/section_screen.dart';
import '../features/workspace/student_profile_screen.dart';
import 'role_module.dart';

/// Kinds of approval queue (the `:kind` of [ManagementRoutes.approvalPattern]).
abstract final class ApprovalKind {
  static const studentLeave = 'student-leave';
  static const staffLeave = 'staff-leave';
  static const attendance = 'attendance';
  static const marks = 'marks';
  static const concessions = 'concessions';
  static const refunds = 'refunds';
  static const expenses = 'expenses';
  static const admissions = 'admissions';
  static const all = [studentLeave, staffLeave, attendance, marks, concessions, refunds, expenses, admissions];
}

/// Paths owned by the management experience. Use the helper functions to build a path with ids.
abstract final class ManagementRoutes {
  static const prefix = '/management';

  static const approvals = '/management/approvals';
  static const approvalPattern = '/management/approvals/:kind';
  static String approval(String kind) => '/management/approvals/$kind';

  static const attendance = '/management/attendance';

  static const sectionPattern = '/management/sections/:sectionId';
  static String section(String sectionId) => '/management/sections/$sectionId';
  static const studentPattern = '/management/students/:studentId';
  static String student(String studentId) => '/management/students/$studentId';
  static const staffPattern = '/management/staff/:staffId';
  static String staffMember(String staffId) => '/management/staff/$staffId';

  static const defaulters = '/management/finance/defaulters';
  static const outstanding = '/management/finance/outstanding';
  static const collection = '/management/finance/collection';

  static const announcements = '/management/announcements';
  static const announcementNew = '/management/announcements/new';
  static const announcementPattern = '/management/announcements/:announcementId';
  static String announcement(String id) => '/management/announcements/$id';
  static const announcementEditPattern = '/management/announcements/:announcementId/edit';
  static String announcementEdit(String id) => '/management/announcements/$id/edit';

  static const meetings = '/management/meetings';
  static const myAttendance = '/management/me/attendance';
  static const myLeave = '/management/me/leave';
}

Widget _home(BuildContext context) => const ManagementHomeScreen();
Widget _academics(BuildContext context) => const ManagementAcademicsScreen();
Widget _people(BuildContext context) => const ManagementPeopleScreen();
Widget _finance(BuildContext context) => const ManagementFinanceScreen();
Widget _more(BuildContext context) => const ManagementMoreScreen();

/// Management experience (principal, administrator, accounts, HR ...): Home, Academics, People, Finance, More.
///
/// Every block is permission-gated (hidden, not disabled, when the API returns null or the permission is missing);
/// the API remains the authority. Announcements, meetings and "my attendance / leave" reuse the workspace screens.
final managementModule = RoleModule(
  experience: Experience.management,
  tabs: const [
    TabSpec(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, title: 'Home', subtitle: '', kind: TabKind.home, builder: _home),
    TabSpec(
      label: 'Academics',
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      title: 'Academics',
      subtitle: 'Classes, attendance and exams.',
      anyPermission: ['academics:view', 'exams:view', 'timetable:view', 'attendance:view'],
      kind: TabKind.feature,
      builder: _academics,
    ),
    TabSpec(
      label: 'People',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      title: 'People',
      subtitle: 'Students and staff.',
      anyPermission: ['students:view', 'guardians:view', 'staff:view', 'admissions:view'],
      kind: TabKind.feature,
      builder: _people,
    ),
    TabSpec(
      label: 'Finance',
      icon: Icons.account_balance_outlined,
      selectedIcon: Icons.account_balance_rounded,
      title: 'Finance',
      subtitle: 'Collection, dues and expenses.',
      sensitive: true,
      siteFeature: 'fees',
      anyPermission: ['fees:view', 'payments:view', 'expenses:view'],
      kind: TabKind.feature,
      builder: _finance,
    ),
    TabSpec(label: 'More', icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, title: 'More', subtitle: 'Everything else, plus your account.', kind: TabKind.more, builder: _more),
  ],
  routes: <RouteBase>[
    GoRoute(path: ManagementRoutes.approvals, builder: (c, s) => const ApprovalsHubScreen()),
    GoRoute(path: ManagementRoutes.approvalPattern, builder: (c, s) => ApprovalListScreen(kind: s.pathParameters['kind']!)),
    GoRoute(path: ManagementRoutes.attendance, builder: (c, s) => const AttendanceOverviewScreen()),
    GoRoute(path: ManagementRoutes.sectionPattern, builder: (c, s) => SectionScreen(sectionId: s.pathParameters['sectionId']!)),
    GoRoute(path: ManagementRoutes.studentPattern, builder: (c, s) => StudentProfileScreen(studentId: s.pathParameters['studentId']!)),
    GoRoute(path: ManagementRoutes.staffPattern, builder: (c, s) => StaffProfileScreen(staffId: s.pathParameters['staffId']!)),
    GoRoute(path: ManagementRoutes.defaulters, builder: (c, s) => const DefaultersScreen()),
    GoRoute(path: ManagementRoutes.outstanding, builder: (c, s) => const OutstandingScreen()),
    GoRoute(path: ManagementRoutes.collection, builder: (c, s) => const CollectionScreen()),
    GoRoute(path: ManagementRoutes.announcements, builder: (c, s) => const AnnouncementsScreen()),
    GoRoute(path: ManagementRoutes.announcementNew, builder: (c, s) => const AnnouncementFormScreen()),
    GoRoute(path: ManagementRoutes.announcementPattern, builder: (c, s) => AnnouncementManageScreen(announcementId: s.pathParameters['announcementId']!)),
    GoRoute(path: ManagementRoutes.announcementEditPattern, builder: (c, s) => AnnouncementFormScreen(announcementId: s.pathParameters['announcementId'])),
    GoRoute(path: ManagementRoutes.meetings, builder: (c, s) => const MeetingsScreen()),
    GoRoute(path: ManagementRoutes.myAttendance, builder: (c, s) => const CheckInScreen()),
    GoRoute(path: ManagementRoutes.myLeave, builder: (c, s) => const MyLeaveScreen()),
  ],
);
