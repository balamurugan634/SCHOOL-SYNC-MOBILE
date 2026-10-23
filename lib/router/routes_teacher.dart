import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/models/me.dart';
import '../data/json.dart' show isoDay;
import '../features/shell/role_nav.dart';
import '../features/teacher/attendance/attendance_tab.dart';
import '../features/teacher/attendance/corrections_screen.dart';
import '../features/teacher/attendance/roll_call_screen.dart';
import '../features/teacher/attendance/student_leave_screen.dart';
import '../features/teacher/classes/classes_screen.dart';
import '../features/teacher/home/teacher_home_screen.dart';
import '../features/teacher/homework/homework_detail_screen.dart';
import '../features/teacher/homework/homework_form_screen.dart';
import '../features/teacher/homework/homework_tab.dart';
import '../features/teacher/homework/submission_review_screen.dart';
import '../features/teacher/marks/marks_entry_screen.dart';
import '../features/teacher/marks/marks_list_screen.dart';
import '../features/teacher/more/syllabus_screen.dart';
import '../features/teacher/more/teacher_more_screen.dart';
import '../features/teacher/more/timetable_screen.dart';
import '../features/workspace/announcements/announcement_form_screen.dart';
import '../features/workspace/announcements/announcement_manage_screen.dart';
import '../features/workspace/announcements/announcements_screen.dart';
import '../features/workspace/me/check_in_screen.dart';
import '../features/workspace/me/my_leave_screen.dart';
import '../features/workspace/meetings/meetings_screen.dart';
import '../features/workspace/section_screen.dart';
import '../features/workspace/student_profile_screen.dart';
import 'role_module.dart';

/// Paths owned by the teacher experience. Use the helper functions to build a path with ids.
abstract final class TeacherRoutes {
  static const prefix = '/teacher';

  // classes and students
  static const sectionPattern = '/teacher/classes/:sectionId';
  static String section(String sectionId) => '/teacher/classes/$sectionId';
  static const studentPattern = '/teacher/students/:studentId';
  static String student(String studentId) => '/teacher/students/$studentId';

  // attendance
  static const rollCallPattern = '/teacher/attendance/roll/:sectionId';

  /// Roll call for [sectionId]; [date] defaults to today, [periodId] is only needed in period mode.
  static String rollCall(String sectionId, {DateTime? date, String? periodId}) {
    final q = <String, String>{if (date != null) 'date': isoDay(date), 'periodId': ?periodId};
    return Uri(path: '/teacher/attendance/roll/$sectionId', queryParameters: q.isEmpty ? null : q).toString();
  }

  static const corrections = '/teacher/attendance/corrections';
  static const studentLeave = '/teacher/attendance/leave';

  // homework
  static const homeworkNew = '/teacher/homework/new';
  static const homeworkPattern = '/teacher/homework/:homeworkId';
  static String homework(String id) => '/teacher/homework/$id';
  static const homeworkEditPattern = '/teacher/homework/:homeworkId/edit';
  static String homeworkEdit(String id) => '/teacher/homework/$id/edit';
  static const submissionPattern = '/teacher/homework/:homeworkId/review/:submissionId';
  static String submission(String homeworkId, String submissionId) => '/teacher/homework/$homeworkId/review/$submissionId';

  // marks
  static const marks = '/teacher/marks';
  static const marksSheetPattern = '/teacher/marks/:sheetId';
  static String marksSheet(String sheetId) => '/teacher/marks/$sheetId';

  // more
  static const timetable = '/teacher/timetable';
  static const syllabus = '/teacher/syllabus';
  static String syllabusFor(String sectionId) => '/teacher/syllabus?sectionId=$sectionId';
  static const announcements = '/teacher/announcements';
  static const announcementNew = '/teacher/announcements/new';
  static const announcementPattern = '/teacher/announcements/:announcementId';
  static String announcement(String id) => '/teacher/announcements/$id';
  static const announcementEditPattern = '/teacher/announcements/:announcementId/edit';
  static String announcementEdit(String id) => '/teacher/announcements/$id/edit';
  static const meetings = '/teacher/meetings';
  static const myAttendance = '/teacher/me/attendance';
  static const myLeave = '/teacher/me/leave';
}

Widget _home(BuildContext context) => const TeacherHomeScreen();
Widget _classes(BuildContext context) => const ClassesScreen();
Widget _attendance(BuildContext context) => const TeacherAttendanceTab();
Widget _homework(BuildContext context) => const TeacherHomeworkTab();
Widget _more(BuildContext context) => const TeacherMoreScreen();

/// Teacher experience: Home, Classes, Attendance, Homework, More.
///
/// Tab content is built by the feature screens (each handles its own permission / feature gating with `FeatureGate`).
/// Pushed routes cover the bottom bar.
final teacherModule = RoleModule(
  experience: Experience.teacher,
  tabs: const [
    TabSpec(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, title: 'Home', subtitle: '', kind: TabKind.home, builder: _home),
    TabSpec(
      label: 'Classes',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      title: 'My Classes',
      subtitle: 'The sections you teach, with their students.',
      kind: TabKind.feature,
      builder: _classes,
    ),
    TabSpec(
      label: 'Attendance',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check_rounded,
      title: 'Attendance',
      subtitle: 'Mark attendance in seconds.',
      anyPermission: ['attendance:create', 'attendance:view'],
      kind: TabKind.feature,
      builder: _attendance,
    ),
    TabSpec(
      label: 'Homework',
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment_rounded,
      title: 'Homework',
      subtitle: 'Set work, then review submissions.',
      anyPermission: ['homework:view', 'homework:create'],
      kind: TabKind.feature,
      builder: _homework,
    ),
    TabSpec(label: 'More', icon: Icons.grid_view_outlined, selectedIcon: Icons.grid_view_rounded, title: 'More', subtitle: 'Everything else, plus your account.', kind: TabKind.more, builder: _more),
  ],
  routes: <RouteBase>[
    GoRoute(path: TeacherRoutes.sectionPattern, builder: (c, s) => SectionScreen(sectionId: s.pathParameters['sectionId']!)),
    GoRoute(path: TeacherRoutes.studentPattern, builder: (c, s) => StudentProfileScreen(studentId: s.pathParameters['studentId']!)),
    GoRoute(
      path: TeacherRoutes.rollCallPattern,
      builder: (c, s) => RollCallScreen(sectionId: s.pathParameters['sectionId']!, date: DateTime.tryParse(s.uri.queryParameters['date'] ?? ''), periodId: s.uri.queryParameters['periodId']),
    ),
    GoRoute(path: TeacherRoutes.corrections, builder: (c, s) => const CorrectionsScreen()),
    GoRoute(path: TeacherRoutes.studentLeave, builder: (c, s) => const StudentLeaveScreen()),
    // `/teacher/homework/new` must be registered before `/teacher/homework/:homeworkId`.
    GoRoute(path: TeacherRoutes.homeworkNew, builder: (c, s) => const HomeworkFormScreen()),
    GoRoute(path: TeacherRoutes.homeworkPattern, builder: (c, s) => TeacherHomeworkDetailScreen(homeworkId: s.pathParameters['homeworkId']!)),
    GoRoute(path: TeacherRoutes.homeworkEditPattern, builder: (c, s) => HomeworkFormScreen(homeworkId: s.pathParameters['homeworkId'])),
    GoRoute(path: TeacherRoutes.submissionPattern, builder: (c, s) => SubmissionReviewScreen(homeworkId: s.pathParameters['homeworkId']!, submissionId: s.pathParameters['submissionId']!)),
    GoRoute(path: TeacherRoutes.marks, builder: (c, s) => const MarksListScreen()),
    GoRoute(path: TeacherRoutes.marksSheetPattern, builder: (c, s) => MarksEntryScreen(sheetId: s.pathParameters['sheetId']!)),
    GoRoute(path: TeacherRoutes.timetable, builder: (c, s) => const TeacherTimetableScreen()),
    GoRoute(path: TeacherRoutes.syllabus, builder: (c, s) => SyllabusScreen(sectionId: s.uri.queryParameters['sectionId'])),
    GoRoute(path: TeacherRoutes.announcements, builder: (c, s) => const AnnouncementsScreen()),
    // `/new` before `/:announcementId`.
    GoRoute(path: TeacherRoutes.announcementNew, builder: (c, s) => const AnnouncementFormScreen()),
    GoRoute(path: TeacherRoutes.announcementPattern, builder: (c, s) => AnnouncementManageScreen(announcementId: s.pathParameters['announcementId']!)),
    GoRoute(path: TeacherRoutes.announcementEditPattern, builder: (c, s) => AnnouncementFormScreen(announcementId: s.pathParameters['announcementId'])),
    GoRoute(path: TeacherRoutes.meetings, builder: (c, s) => const MeetingsScreen()),
    GoRoute(path: TeacherRoutes.myAttendance, builder: (c, s) => const CheckInScreen()),
    GoRoute(path: TeacherRoutes.myLeave, builder: (c, s) => const MyLeaveScreen()),
  ],
);
