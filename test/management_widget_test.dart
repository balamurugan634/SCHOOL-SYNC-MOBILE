import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/features/management/academics/academics_screen.dart';
import 'package:schoolsync/features/management/approvals/approval_list_screen.dart';
import 'package:schoolsync/features/management/approvals/approvals_hub_screen.dart';
import 'package:schoolsync/features/management/attendance/attendance_overview_screen.dart';
import 'package:schoolsync/features/management/finance/defaulters_screen.dart';
import 'package:schoolsync/features/management/finance/finance_screen.dart';
import 'package:schoolsync/features/management/home/management_home_providers.dart';
import 'package:schoolsync/features/management/home/management_home_screen.dart';
import 'package:schoolsync/features/management/more/management_more_screen.dart';
import 'package:schoolsync/features/management/people/people_screen.dart';

import 'management_test_support.dart';
import 'staff_test_support.dart';

/// A fake server that can be switched off (connection error) to exercise the offline paths.
class FlakyServer extends FakeServer {
  bool down = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) {
    if (down) throw DioException(requestOptions: o, type: DioExceptionType.connectionError, error: 'SocketException: offline');
    return super.fetch(o, body, cancel);
  }
}

final _storeOverride = secureStoreProvider.overrideWithValue(SecureStore(MemorySecureKv()));
const _tall = Size(390, 3600);

FakeServer _homeServer(String who) => FakeServer()
  ..on('GET /dashboard/management', fixture('mgmt_dashboard_$who'))
  ..on('GET /staff-leave', fixture('staff_leave'));

/// The student count of the captured principal dashboard (the data changes with the dev database).
int _kpiStudents() => ((fixture('mgmt_dashboard_principal')['kpis'] as Map)['students'] as num).toInt();

/// A student name that appears exactly once in the captured search result (the demo school has two Divya Sharmas).
String _uniqueName(List<dynamic> students) {
  final names = [for (final s in students) (s as Map)['name'] as String];
  return names.firstWhere((n) => names.where((x) => x == n).length == 1);
}

Map<String, dynamic> _leaveList({bool canDecide = true, String status = 'pending'}) {
  final j = fixture('student_leave');
  for (final e in j['data'] as List) {
    (e as Map)['canDecide'] = canDecide;
    e['status'] = status;
  }
  return j;
}

void main() {
  group('Home', () {
    testWidgets('principal: KPIs, alerts, approvals, attendance, fees, exams, grades, announcements', (tester) async {
      await pumpScreen(tester, const ManagementHomeScreen(), me: 'principal', server: _homeServer('principal'), size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Students'), findsWidgets);
      expect(find.text('${_kpiStudents()}'), findsOneWidget);
      expect(find.text('Alerts'), findsOneWidget);
      expect(find.textContaining('not marked attendance today'), findsOneWidget);
      expect(find.text('Warning'), findsWidgets, reason: 'severity is a word as well as a colour');
      expect(find.text('Needs your approval'), findsOneWidget);
      expect(find.text('Student leave'), findsOneWidget);
      expect(find.text('Mark sheets'), findsOneWidget);
      expect(find.text('Fee concessions'), findsNothing, reason: 'the API sent null for queues the principal cannot act on');
      expect(find.text('Attendance today'), findsOneWidget);
      expect(find.textContaining('Average'), findsWidgets, reason: 'trend text summary');
      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('Exams'), findsOneWidget);
      expect(find.text('Students by grade'), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.textContaining('Subscription'), findsNothing, reason: 'no licence banner for a healthy licence / non-admin');
    });

    testWidgets('accounts: blocks the API returned as null are hidden, not disabled', (tester) async {
      await pumpScreen(tester, const ManagementHomeScreen(), me: 'mgmt_me_accounts', server: _homeServer('accounts'), size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Attendance today'), findsNothing);
      expect(find.text('Exams'), findsNothing);
      expect(find.text('Alerts'), findsNothing, reason: 'accounts has no alerts');
      expect(find.text('Fees'), findsOneWidget);
      expect(find.text('Needs your approval'), findsOneWidget);
      expect(find.text('Fee concessions'), findsOneWidget);
      expect(find.text('Refunds'), findsOneWidget);
      expect(find.text('Expenses'), findsWidgets);
      expect(find.text('Student leave'), findsNothing);
    });

    testWidgets('fees module off: no fee card and no fee queues', (tester) async {
      await pumpScreen(tester, const ManagementHomeScreen(), me: 'mgmt_me_accounts', server: _homeServer('accounts'), fees: false, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Fees'), findsNothing);
      expect(find.text('Needs your approval'), findsNothing);
    });

    testWidgets('administrator: licence trouble is explained', (tester) async {
      final dash = fixture('mgmt_dashboard_admin');
      (dash['license'] as Map)['daysLeft'] = 12;
      final server = FakeServer()..on('GET /dashboard/management', dash);
      await pumpScreen(tester, const ManagementHomeScreen(), me: 'management', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Subscription ends soon'), findsOneWidget);
      expect(find.textContaining('12 days'), findsOneWidget);
    });

    testWidgets('view-only school shows the subscription banner', (tester) async {
      await pumpScreen(tester, const ManagementHomeScreen(), me: 'principal', server: _homeServer('principal'), readOnly: true, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('View-only mode'), findsOneWidget);
    });

    testWidgets('loading shows a skeleton, an error offers Try again, and retrying works', (tester) async {
      final server = FakeServer()..on('GET /dashboard/management', {'title': 'Boom', 'code': 'INTERNAL', 'status': 500}, status: 500);
      await pumpScreen(tester, const ManagementHomeScreen(), me: 'principal', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Try again'), findsOneWidget);
      server.on('GET /dashboard/management', fixture('mgmt_dashboard_principal'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Needs your approval'), findsOneWidget);
    });

    testWidgets('offline after a good load: the saved copy is shown with an "as of" note', (tester) async {
      final server = FlakyServer()..on('GET /dashboard/management', fixture('mgmt_dashboard_principal'));
      await pumpScreen(tester, const ManagementHomeScreen(), me: 'principal', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.textContaining('You are offline'), findsNothing);
      server.down = true;
      ProviderScope.containerOf(tester.element(find.byType(ManagementHomeScreen))).invalidate(managementDashboardProvider);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.textContaining('You are offline. Showing the overview saved'), findsOneWidget);
      expect(find.text('${_kpiStudents()}'), findsOneWidget, reason: 'the cached overview is still on screen');
    });

    testWidgets('survives 200% text scale without overflow', (tester) async {
      await pumpScreen(tester, const ManagementHomeScreen(), me: 'principal', server: _homeServer('principal'), size: const Size(360, 3600), textScale: 2, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Needs your approval'), findsOneWidget);
    });
  });

  group('Approvals', () {
    testWidgets('hub lists only the queues with counts and the role can open', (tester) async {
      await pumpScreen(tester, const ApprovalsHubScreen(), me: 'mgmt_me_office', server: _homeServer('office'), overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Student leave'), findsOneWidget);
      expect(find.text('Admissions'), findsOneWidget);
      expect(find.text('Staff leave'), findsNothing);
      expect(find.text('Refunds'), findsNothing);
    });

    testWidgets('approve: choose, confirm, then the decision is sent and the list refreshes', (tester) async {
      final server = FakeServer()..on('GET /leave', _leaveList());
      final leave = (server.routes['GET /leave']!.$2 as Map)['data'] as List;
      final id = (leave.first as Map)['id'];
      server.on('POST /leave/$id/approve', {});
      await pumpScreen(tester, const ApprovalListScreen(kind: 'student-leave'), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.tap(find.text((leave.first as Map)['studentName'] as String));
      await tester.pumpAndSettle();
      expect(find.text('Reason'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm approve'), findsOneWidget, reason: 'a second step names the consequence');
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty, reason: 'nothing is sent until confirmed');
      await tester.tap(find.text('Confirm approve'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'POST' && r.path == '/leave/$id/approve'), hasLength(1));
      expect(find.text('Reason'), findsNothing, reason: 'the sheet closed');
      expect(find.descendant(of: find.byType(SnackBar), matching: find.text('Approved')), findsOneWidget, reason: 'confirmation snackbar');
      expect(server.requests.where((r) => r.method == 'GET' && r.path == '/leave').length, greaterThan(1), reason: 'list was refreshed');
    });

    testWidgets('reject needs a note, then sends it', (tester) async {
      final server = FakeServer()..on('GET /leave', _leaveList());
      final first = ((server.routes['GET /leave']!.$2 as Map)['data'] as List).first as Map;
      server.on('POST /leave/${first['id']}/reject', {});
      await pumpScreen(tester, const ApprovalListScreen(kind: 'student-leave'), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.tap(find.text(first['studentName'] as String));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Add a short note'), findsOneWidget);
      expect(find.text('Confirm reject'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Exam week');
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm reject'));
      await tester.pumpAndSettle();
      final post = server.requests.singleWhere((r) => r.method == 'POST');
      expect(post.path, '/leave/${first['id']}/reject');
      expect(post.body, {'note': 'Exam week'});
    });

    testWidgets('someone else already decided: the message explains and the list refreshes', (tester) async {
      final server = FakeServer()..on('GET /leave', _leaveList());
      final first = ((server.routes['GET /leave']!.$2 as Map)['data'] as List).first as Map;
      server.on('POST /leave/${first['id']}/approve', {'title': 'Already decided', 'code': 'ALREADY_DECIDED', 'status': 409}, status: 409);
      await pumpScreen(tester, const ApprovalListScreen(kind: 'student-leave'), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.tap(find.text(first['studentName'] as String));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm approve'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Someone has already decided this'), findsOneWidget);
      expect(find.text('Confirm approve'), findsNothing, reason: 'back to choosing');
      expect(server.requests.where((r) => r.method == 'GET' && r.path == '/leave').length, greaterThan(1));
    });

    testWidgets('view-only school: decision buttons are disabled with an explanation', (tester) async {
      final server = FakeServer()..on('GET /leave', _leaveList());
      final first = ((server.routes['GET /leave']!.$2 as Map)['data'] as List).first as Map;
      await pumpScreen(tester, const ApprovalListScreen(kind: 'student-leave'), me: 'principal', server: server, readOnly: true, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.tap(find.text(first['studentName'] as String));
      await tester.pumpAndSettle();
      expect(find.textContaining('view-only mode'), findsWidgets);
      final approve = tester.widget<FilledButton>(find.ancestor(of: find.text('Approve'), matching: find.byType(FilledButton)));
      expect(approve.onPressed, isNull);
    });

    testWidgets('a request already decided opens read-only (no buttons)', (tester) async {
      final server = FakeServer()..on('GET /leave', _leaveList(status: 'approved'));
      final first = ((server.routes['GET /leave']!.$2 as Map)['data'] as List).first as Map;
      await pumpScreen(tester, const ApprovalListScreen(kind: 'student-leave'), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.tap(find.text(first['studentName'] as String).first);
      await tester.pumpAndSettle();
      expect(find.text('Reason'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
    });

    testWidgets('mark sheets: return needs a note of 3+ characters', (tester) async {
      final server = FakeServer()..on('GET /marks/sheets', fixture('mgmt_sheets_submitted'));
      final first = ((server.routes['GET /marks/sheets']!.$2 as Map)['data'] as List).first as Map;
      server.on('POST /marks/sheets/${first['id']}/return', {});
      await pumpScreen(tester, const ApprovalListScreen(kind: 'marks'), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining(first['subjectName'] as String).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ab');
      await tester.tap(find.text('Return'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Add a short note'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Recheck Q4');
      await tester.tap(find.text('Return'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm return'));
      await tester.pumpAndSettle();
      expect(server.requests.singleWhere((r) => r.method == 'POST').body, {'note': 'Recheck Q4'});
    });

    testWidgets('a role without the permission sees No access; an unknown kind is explained', (tester) async {
      await pumpScreen(tester, const ApprovalListScreen(kind: 'staff-leave'), me: 'mgmt_me_office', overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('No access'), findsOneWidget);
      await pumpScreen(tester, const ApprovalListScreen(kind: 'bogus'), me: 'principal', overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('That list does not exist'), findsOneWidget);
    });

    testWidgets('empty queue shows a calm empty state; viewers without approve rights are told', (tester) async {
      final server = FakeServer()..on('GET /expenses', {'data': [], 'meta': {'page': 1, 'pageSize': 20, 'total': 0, 'totalPages': 1}});
      await pumpScreen(tester, const ApprovalListScreen(kind: 'expenses'), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('No expenses to approve'), findsOneWidget);
      expect(find.textContaining('your role cannot decide'), findsOneWidget);
    });
  });

  group('People', () {
    FakeServer peopleServer() => FakeServer()
      ..on('GET /academics/grades', fixture('mgmt_grades'))
      ..on('GET /students', fixture('mgmt_students_q'))
      ..on('GET /staff', fixture('staff_directory'));

    testWidgets('empty query prompts, short input does not search, a real query lists students (debounced)', (tester) async {
      final server = peopleServer();
      await pumpScreen(tester, const ManagementPeopleScreen(), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Find a student'), findsOneWidget);
      expect(find.text('All grades'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 's');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Find a student'), findsOneWidget);
      expect(server.requests.where((r) => r.path == '/students'), isEmpty);
      await tester.enterText(find.byType(TextField), 'sh');
      await tester.enterText(find.byType(TextField), 'sharma');
      await tester.pump(const Duration(milliseconds: 100));
      expect(server.requests.where((r) => r.path == '/students'), isEmpty, reason: 'still debouncing');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final students = server.requests.where((r) => r.path == '/students').toList();
      expect(students, hasLength(1));
      expect(students.single.query['q'], 'sharma');
      final first = _uniqueName(fixture('mgmt_students_q')['data'] as List);
      expect(find.text(first), findsOneWidget);
    });

    testWidgets('no match shows a no-results state with Clear search', (tester) async {
      final server = peopleServer()..on('GET /students', {'data': [], 'meta': {'page': 1, 'pageSize': 25, 'total': 0, 'totalPages': 1}});
      await pumpScreen(tester, const ManagementPeopleScreen(), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('No students found'), findsOneWidget);
      await tester.tap(find.text('Clear search'));
      await tester.pumpAndSettle();
      expect(find.text('Find a student'), findsOneWidget);
    });

    testWidgets('a failing search shows an error with retry', (tester) async {
      final server = peopleServer()..on('GET /students', {'title': 'Boom', 'code': 'INTERNAL', 'status': 500}, status: 500);
      await pumpScreen(tester, const ManagementPeopleScreen(), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sharma');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(find.text('Try again'), findsOneWidget);
      server.on('GET /students', fixture('mgmt_students_q'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      final first = _uniqueName(fixture('mgmt_students_q')['data'] as List);
      expect(find.text(first), findsOneWidget);
    });

    testWidgets('staff directory: names with a call button; admissions open the decision flow', (tester) async {
      final server = peopleServer()..on('GET /admissions', fixture('admissions'));
      await pumpScreen(tester, const ManagementPeopleScreen(), me: 'principal', server: server, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Staff'));
      await tester.pumpAndSettle();
      final first = ((fixture('staff_directory')['data'] as List).first as Map)['name'] as String;
      expect(find.text(first), findsOneWidget);
      expect(find.byTooltip('Call $first'), findsOneWidget);
      await tester.tap(find.text('Admissions'));
      await tester.pumpAndSettle();
      final app = (fixture('admissions')['data'] as List).first as Map;
      await tester.tap(find.text(app['name'] as String));
      await tester.pumpAndSettle();
      expect(find.text('Application'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget, reason: 'the principal holds admissions:approve');
      expect(find.text('Start review'), findsNothing, reason: 'starting a review needs admissions:edit');
    });

    testWidgets('accounts: students only (no staff or admissions segments)', (tester) async {
      await pumpScreen(tester, const ManagementPeopleScreen(), me: 'mgmt_me_accounts', server: peopleServer(), overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Staff'), findsNothing);
      expect(find.text('Admissions'), findsNothing);
      expect(find.text('Find a student'), findsOneWidget);
    });
  });

  group('Finance', () {
    testWidgets('fees module off: explained, nothing fetched', (tester) async {
      final server = FakeServer();
      await pumpScreen(tester, const ManagementFinanceScreen(), me: 'principal', server: server, fees: false, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Finance is not turned on'), findsOneWidget);
    });

    testWidgets('no fee permission: No access', (tester) async {
      await pumpScreen(tester, const ManagementFinanceScreen(), me: 'mgmt_me_office', overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('No access'), findsOneWidget);
    });

    testWidgets('summary, approvals (link only for those who can decide) and follow-up lists', (tester) async {
      final server = FakeServer()
        ..on('GET /finance/summary', fixture('finance_summary'))
        ..on('GET /fees/reports/outstanding', fixture('outstanding'));
      await pumpScreen(tester, const ManagementFinanceScreen(), me: 'mgmt_me_accounts', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Collected'), findsWidgets, reason: 'the figure and the chart legend');
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Waiting for approval'), findsOneWidget);
      expect(find.text('Refund requests'), findsOneWidget);
      expect(find.text('What is owed, by age'), findsOneWidget);
      expect(find.text('Defaulters'), findsOneWidget);
      expect(find.text('Collected by month'), findsOneWidget);
    });

    testWidgets('expenses hidden by the API are not shown', (tester) async {
      final summary = fixture('finance_summary')..['expensesMinor'] = null..['netPositionMinor'] = null;
      (summary['pending'] as Map)['expenses'] = null;
      for (final m in summary['byMonth'] as List) {
        (m as Map)['expensesMinor'] = null;
      }
      final server = FakeServer()
        ..on('GET /finance/summary', summary)
        ..on('GET /fees/reports/outstanding', fixture('outstanding'));
      await pumpScreen(tester, const ManagementFinanceScreen(), me: 'principal', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Expenses'), findsNothing);
    });

    testWidgets('defaulters: a guardian with no phone has a disabled call button', (tester) async {
      final j = fixture('defaulters');
      ((j['data'] as List)[1] as Map)['guardianPhone'] = null;
      final server = FakeServer()..on('GET /fees/reports/defaulters', j);
      await pumpScreen(tester, const DefaultersScreen(), me: 'mgmt_me_accounts', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      final first = (j['data'] as List).first as Map;
      expect(find.text(first['studentName'] as String), findsOneWidget);
      expect(find.byTooltip('No phone number on record'), findsOneWidget);
      final call = tester.widget<IconButton>(find.ancestor(of: find.byTooltip('No phone number on record'), matching: find.byType(IconButton)));
      expect(call.onPressed, isNull);
      expect(find.byTooltip('Call ${first['guardianName']}'), findsOneWidget);
    });
  });

  group('Attendance overview, Academics, More', () {
    testWidgets('attendance overview: totals, unmarked classes first, absentees, trend', (tester) async {
      final j = fixture('school_summary');
      final server = FakeServer()..on('GET /attendance/summary', j);
      await pumpScreen(tester, const AttendanceOverviewScreen(), me: 'principal', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.textContaining('present,'), findsWidgets);
      expect(find.text('Trend'), findsOneWidget);
      expect(find.text('Classes'), findsOneWidget);
      expect(find.textContaining('Absent'), findsWidgets);
      final first = (j['absentees'] as List).first as Map;
      expect(find.text(first['name'] as String), findsOneWidget);
      expect(server.last.query['trendDays'], 7);
      await tester.tap(find.text('14 days'));
      await tester.pumpAndSettle();
      expect(server.last.query['trendDays'], 14);
    });

    testWidgets('attendance overview: a holiday is explained', (tester) async {
      final j = fixture('school_summary')..['holiday'] = 'Diwali'..['isWorkingDay'] = false;
      final server = FakeServer()..on('GET /attendance/summary', j);
      await pumpScreen(tester, const AttendanceOverviewScreen(), me: 'principal', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Holiday'), findsOneWidget);
      expect(find.textContaining('Diwali'), findsOneWidget);
    });

    testWidgets('academics: classes by grade, mark sheets waiting, coverage', (tester) async {
      final server = _homeServer('principal')
        ..on('GET /academics/sections', fixture('mgmt_sections_all'))
        ..on('GET /syllabus/coverage', fixture('mgmt_coverage'));
      await pumpScreen(tester, const ManagementAcademicsScreen(), me: 'principal', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Classes'), findsWidgets);
      expect(find.text('Mark sheets to review'), findsOneWidget);
      expect(find.text('Syllabus coverage'), findsOneWidget);
      expect(find.text('Attendance today'), findsOneWidget);
    });

    testWidgets('academics: a forbidden coverage call hides that block instead of showing an error', (tester) async {
      final server = _homeServer('accounts')
        ..on('GET /academics/sections', fixture('mgmt_sections_all'))
        ..on('GET /syllabus/coverage', {'title': 'Forbidden', 'code': 'FORBIDDEN', 'status': 403}, status: 403);
      await pumpScreen(tester, const ManagementAcademicsScreen(), me: 'mgmt_me_accounts', server: server, size: _tall, overrides: [_storeOverride]);
      await tester.pumpAndSettle();
      expect(find.text('Syllabus coverage'), findsNothing);
      expect(find.text('No access'), findsNothing);
      expect(find.text('Classes'), findsWidgets);
    });

    testWidgets('more: rows follow the role; approvals show the waiting count', (tester) async {
      await pumpScreen(tester, const ManagementMoreScreen(), me: 'mgmt_me_office', server: _homeServer('office'), size: _tall, overrides: [_storeOverride, managementDashboardProvider.overrideWith((ref) async => throw StateError('not loaded'))]);
      await tester.pumpAndSettle();
      expect(find.text('Approvals'), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('Attendance overview'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Settings and security'), findsOneWidget);
    });

    testWidgets('more: accounts has no attendance overview, announcements or meetings', (tester) async {
      await pumpScreen(tester, const ManagementMoreScreen(), me: 'mgmt_me_accounts', server: _homeServer('accounts'), size: _tall, overrides: [_storeOverride, managementDashboardProvider.overrideWith((ref) async => throw StateError('not loaded'))]);
      await tester.pumpAndSettle();
      expect(find.text('Attendance overview'), findsNothing);
      expect(find.text('Announcements'), findsNothing);
      expect(find.text('Meetings'), findsNothing);
      expect(find.text('Approvals'), findsOneWidget, reason: 'accounts approves concessions, refunds and expenses');
    });
  });
}
