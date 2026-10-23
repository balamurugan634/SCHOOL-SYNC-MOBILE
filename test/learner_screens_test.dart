
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/features/announcements/announcement_detail_screen.dart';
import 'package:schoolsync/features/announcements/announcements_screen.dart';
import 'package:schoolsync/features/attendance/attendance_screen.dart';
import 'package:schoolsync/features/dashboard/parent_home_screen.dart';
import 'package:schoolsync/features/dashboard/student_home_screen.dart';
import 'package:schoolsync/features/events/event_detail_screen.dart';
import 'package:schoolsync/features/events/events_screen.dart';
import 'package:schoolsync/features/exams/exams_screen.dart';
import 'package:schoolsync/features/exams/report_card_screen.dart';
import 'package:schoolsync/features/exams/results_screen.dart';
import 'package:schoolsync/features/fees/fees_screen.dart';
import 'package:schoolsync/features/fees/invoice_screen.dart';
import 'package:schoolsync/features/fees/pay_screen.dart';
import 'package:schoolsync/features/fees/receipt_screen.dart';
import 'package:schoolsync/features/homework/homework_detail_screen.dart';
import 'package:schoolsync/features/homework/homework_list_screen.dart';
import 'package:schoolsync/features/leave/leave_form_screen.dart';
import 'package:schoolsync/features/leave/leave_screen.dart';
import 'package:schoolsync/features/learner/learner_hub_screens.dart';
import 'package:schoolsync/features/learning/library_screen.dart';
import 'package:schoolsync/features/learning/materials_screen.dart';
import 'package:schoolsync/features/learning/syllabus_screen.dart';
import 'package:schoolsync/features/learning/transport_screen.dart';
import 'package:schoolsync/features/meetings/meeting_request_screen.dart';
import 'package:schoolsync/features/meetings/meetings_screen.dart';
import 'package:schoolsync/features/notifications/notification_settings_screen.dart';
import 'package:schoolsync/features/notifications/notifications_screen.dart';
import 'package:schoolsync/features/profile/profile_details_screen.dart';
import 'package:schoolsync/features/schedule/calendar_screen.dart';
import 'package:schoolsync/features/tasks/tasks_screen.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';
import 'support/learner_harness.dart';

/// Smoke tests: every Student/Parent screen is built against REAL demo-school responses, on a 360x800 phone,
/// at normal and 200% text size, in light and dark. Layout overflows and runtime exceptions fail the test.
/// (No screenshots: this is the text-only way to prove the screens build and render their data.)

/// Lets futures complete and one-shot animations finish without waiting for looping skeleton shimmers.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 14; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

class _Case {
  const _Case(this.name, this.build, {this.parent = false, this.student = true});
  final String name;
  final Widget Function() build;
  final bool parent;
  final bool student;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  final cases = <_Case>[
    _Case('student home', () => const StudentHomeScreen(), parent: false),
    _Case('parent home', () => const ParentHomeScreen(), parent: true, student: false),
    _Case('homework list', () => const HomeworkListScreen(embedded: true), parent: true),
    _Case('homework detail', () => const HomeworkDetailScreen(homeworkId: 'h1'), parent: true),
    _Case('tasks', () => const TasksScreen(), parent: false),
    _Case('calendar', () => const CalendarScreen(embedded: true), parent: true),
    _Case('timetable', () => const CalendarScreen(embedded: true, initialTimetable: true), parent: true),
    _Case('attendance', () => const AttendanceScreen(embedded: true), parent: true),
    _Case('exams', () => const ExamsScreen(embedded: true), parent: true),
    _Case('results', () => const ResultsScreen(embedded: true), parent: true),
    _Case('report card', () => const ReportCardScreen(examId: 'e1'), parent: true),
    _Case('fees', () => const FeesScreen(embedded: true), parent: true),
    _Case('invoice', () => const InvoiceScreen(invoiceId: 'i1'), parent: true),
    _Case('receipt', () => const ReceiptScreen(paymentId: 'p1'), parent: true),
    _Case('pay', () => const PayScreen(invoiceId: 'i1'), parent: true, student: false),
    _Case('announcements', () => const AnnouncementsScreen(), parent: true),
    _Case('announcement detail', () => const AnnouncementDetailScreen(id: 'a1'), parent: true),
    _Case('events', () => const EventsScreen(), parent: true),
    _Case('event detail (consent)', () => const EventDetailScreen(id: 'e1'), parent: true),
    _Case('meetings', () => const MeetingsScreen(), parent: true, student: false),
    _Case('request a meeting', () => const MeetingRequestScreen(), parent: true, student: false),
    _Case('leave', () => const LeaveScreen(), parent: true),
    _Case('apply for leave', () => const LeaveFormScreen(), parent: true),
    _Case('notifications', () => const NotificationsScreen(), parent: true),
    _Case('notification settings', () => const NotificationSettingsScreen(), parent: true),
    _Case('study materials', () => const MaterialsScreen(), parent: true),
    _Case('syllabus', () => const SyllabusScreen(), parent: true),
    _Case('library', () => const LibraryScreen(), parent: true),
    _Case('transport', () => const TransportScreen(), parent: true),
    _Case('profile details', () => const ProfileDetailsScreen(), parent: true),
    _Case('learning hub', () => const LearningScreen(), parent: false),
    _Case('parent academics', () => const ParentAcademicsScreen(), parent: true, student: false),
    _Case('more hub', () => const LearnerMoreScreen(), parent: true),
  ];

  for (final c in cases) {
    for (final role in [if (c.student) 'student', if (c.parent) 'parent']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('${c.name} as $role at ${(scale * 100).round()}% text', (tester) async {
          tester.view.physicalSize = const Size(1080, 2400);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          final api = FakeApi()..fallback = serveFixtures;
          await tester.pumpWidget(await appAround(api, loadMe(role), c.build(), textScale: scale));
          await _settle(tester);
          expect(find.byType(ErrorState), findsNothing, reason: 'the screen should load from real data, requests: ${api.requests}');
          expect(find.byType(SkeletonList), findsNothing, reason: 'still loading after settling');
          // leave the tree so pending animation timers are cancelled
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }

  group('dark theme', () {
    for (final c in [cases[0], cases[1], cases[11], cases[13]]) {
      testWidgets('${c.name} builds in dark', (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final api = FakeApi()..fallback = serveFixtures;
        await tester.pumpWidget(await appAround(api, loadMe(c.name.startsWith('parent') || c.name == 'fees' ? 'parent' : 'student'), c.build(), brightness: Brightness.dark));
        await _settle(tester);
        expect(find.byType(ErrorState), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  });

  group('states', () {
    testWidgets('offline with nothing loaded: friendly message, then it works after Try again', (tester) async {
      final api = FakeApi()..fallback = serveFixtures;
      api.offline = true;
      await tester.pumpWidget(await appAround(api, loadMe('student'), const HomeworkListScreen(embedded: true)));
      await _settle(tester);
      expect(find.text('You are offline'), findsOneWidget);
      api.offline = false;
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.text('You are offline'), findsNothing);
      expect(find.byType(ErrorState), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('empty lists show an empty state, not a blank page', (tester) async {
      final api = FakeApi()
        ..fallback = (r) => (200, {'data': <Object>[], 'meta': {'page': 1, 'pageSize': 20, 'total': 0, 'totalPages': 1}, 'nextCursor': null});
      await tester.pumpWidget(await appAround(api, loadMe('student'), const NotificationsScreen()));
      await _settle(tester);
      expect(find.byType(EmptyState), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a server error is shown with Try again', (tester) async {
      final api = FakeApi()..fallback = (r) => (500, {'title': 'Boom', 'code': 'INTERNAL', 'status': 500});
      await tester.pumpWidget(await appAround(api, loadMe('parent'), const FeesScreen(embedded: true)));
      await _settle(tester);
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
