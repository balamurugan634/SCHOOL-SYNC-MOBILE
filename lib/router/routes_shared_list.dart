import 'package:go_router/go_router.dart';

import '../features/announcements/announcement_detail_screen.dart';
import '../features/announcements/announcements_screen.dart';
import '../features/attendance/attendance_screen.dart';
import '../features/events/event_detail_screen.dart';
import '../features/events/events_screen.dart';
import '../features/exams/exams_screen.dart';
import '../features/exams/report_card_screen.dart';
import '../features/exams/results_screen.dart';
import '../features/fees/fees_screen.dart';
import '../features/fees/invoice_screen.dart';
import '../features/fees/pay_screen.dart';
import '../features/fees/receipt_screen.dart';
import '../features/homework/homework_detail_screen.dart';
import '../features/homework/homework_list_screen.dart';
import '../features/leave/leave_form_screen.dart';
import '../features/leave/leave_screen.dart';
import '../features/learning/library_screen.dart';
import '../features/learning/materials_screen.dart';
import '../features/learning/syllabus_screen.dart';
import '../features/learning/transport_screen.dart';
import '../features/meetings/meeting_request_screen.dart';
import '../features/meetings/meetings_screen.dart';
import '../features/notifications/notification_settings_screen.dart';
import '../features/profile/profile_details_screen.dart';
import '../features/schedule/calendar_screen.dart';
import '../features/tasks/tasks_screen.dart';
import 'routes_shared.dart';

/// Pushed screens shared by the student and parent experiences (they read the active child from
/// `learnerStudentIdProvider`). Registered once by `app_router.dart`.
final List<RouteBase> sharedRoutes = <RouteBase>[
  GoRoute(path: SharedRoutes.homework, builder: (c, s) => const HomeworkListScreen()),
  GoRoute(path: '/homework/:id', builder: (c, s) => HomeworkDetailScreen(homeworkId: s.pathParameters['id']!)),
  GoRoute(path: SharedRoutes.attendance, builder: (c, s) => const AttendanceScreen()),
  GoRoute(path: SharedRoutes.timetable, builder: (c, s) => const CalendarScreen(initialTimetable: true)),
  GoRoute(path: SharedRoutes.calendar, builder: (c, s) => const CalendarScreen()),
  GoRoute(path: SharedRoutes.exams, builder: (c, s) => const ExamsScreen()),
  GoRoute(path: SharedRoutes.results, builder: (c, s) => const ResultsScreen()),
  GoRoute(path: '/results/:examId', builder: (c, s) => ReportCardScreen(examId: s.pathParameters['examId']!)),
  GoRoute(path: SharedRoutes.fees, builder: (c, s) => const FeesScreen()),
  GoRoute(path: '/fees/invoice/:id', builder: (c, s) => InvoiceScreen(invoiceId: s.pathParameters['id']!)),
  GoRoute(path: '/fees/receipt/:id', builder: (c, s) => ReceiptScreen(paymentId: s.pathParameters['id']!)),
  GoRoute(path: '/fees/pay/:id', builder: (c, s) => PayScreen(invoiceId: s.pathParameters['id']!)),
  GoRoute(path: SharedRoutes.announcements, builder: (c, s) => const AnnouncementsScreen()),
  GoRoute(path: '/announcements/:id', builder: (c, s) => AnnouncementDetailScreen(id: s.pathParameters['id']!)),
  GoRoute(path: SharedRoutes.events, builder: (c, s) => const EventsScreen()),
  GoRoute(path: '/events/:id', builder: (c, s) => EventDetailScreen(id: s.pathParameters['id']!)),
  GoRoute(path: SharedRoutes.meetings, builder: (c, s) => const MeetingsScreen()),
  GoRoute(path: SharedRoutes.meetingNew, builder: (c, s) => const MeetingRequestScreen()),
  GoRoute(path: SharedRoutes.leave, builder: (c, s) => const LeaveScreen()),
  GoRoute(path: SharedRoutes.leaveNew, builder: (c, s) => const LeaveFormScreen()),
  GoRoute(path: SharedRoutes.notificationSettings, builder: (c, s) => const NotificationSettingsScreen()),
  GoRoute(path: SharedRoutes.materials, builder: (c, s) => const MaterialsScreen()),
  GoRoute(path: SharedRoutes.syllabus, builder: (c, s) => const SyllabusScreen()),
  GoRoute(path: SharedRoutes.library, builder: (c, s) => const LibraryScreen()),
  GoRoute(path: SharedRoutes.transport, builder: (c, s) => const TransportScreen()),
  GoRoute(path: SharedRoutes.profileDetails, builder: (c, s) => const ProfileDetailsScreen()),
  GoRoute(path: SharedRoutes.tasks, builder: (c, s) => const TasksScreen(embedded: false)),
];
