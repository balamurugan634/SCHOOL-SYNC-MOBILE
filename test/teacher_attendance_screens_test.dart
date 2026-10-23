import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/site_info.dart';
import 'package:schoolsync/data/repositories/staff/academics_repository.dart';
import 'package:schoolsync/data/repositories/staff/roll_call_repository.dart';
import 'package:schoolsync/data/repositories/staff/staff_leave_repository.dart';
import 'package:schoolsync/features/auth/session.dart';
import 'package:schoolsync/features/teacher/attendance/attendance_tab.dart';
import 'package:schoolsync/features/teacher/attendance/corrections_screen.dart';
import 'package:schoolsync/features/teacher/attendance/roll_call_screen.dart';
import 'package:schoolsync/features/teacher/attendance/student_leave_screen.dart';

import 'staff_test_support.dart';
import 'teacher_attendance_logic_test.dart' show rosterJson, student;

/// Answers after a short delay, so the loading state can be observed.
class SlowServer extends FakeServer {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return super.fetch(o, body, cancel);
  }
}

class _FakeSession extends SessionController {
  _FakeSession(this.me, this.readOnly);
  final Me me;
  final bool readOnly;

  @override
  AppSession build() => AppSession(
    ready: true,
    auth: AuthStatus.signedIn,
    me: me,
    siteInfo: SiteInfo(code: 'demo', name: 'Demo School', primaryColor: '#1B6B4F', readOnly: readOnly),
  );
}

Me teacher() => Me.fromJson(jsonMap(jsonDecode(File('test/fixtures/me_teacher.json').readAsStringSync())));

/// The app around a screen: theme, a fake signed-in teacher, the fake server behind the repositories.
Widget harness(FakeServer server, Widget screen, {bool readOnly = false, double textScale = 1}) {
  final api = apiFor(server);
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(() => _FakeSession(teacher(), readOnly)),
      rollCallRepositoryProvider.overrideWithValue(RollCallRepository(api)),
      staffLeaveRepositoryProvider.overrideWithValue(StaffLeaveRepository(api)),
      academicsRepositoryProvider.overrideWithValue(AcademicsRepository(api)),
    ],
    child: MaterialApp(
      theme: buildTheme(kDefaultBrand, Brightness.light),
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen)), child: const Text('open'))),
        ),
      ),
    ),
  );
}

Future<void> open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('RollCallScreen', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    testWidgets('loading, then mark all present, then submit with a confirmation', (tester) async {
      server = SlowServer();
      server.on('GET /attendance/sections/sec', rosterJson());
      server.on('PUT /attendance/sections/sec', {'sessionId': 's', 'firstSubmission': true, 'counts': {'present': 3, 'absent': 1, 'late': 0, 'leave': 1, 'half_day': 0, 'total': 5}, 'changed': 4, 'notifiedGuardians': 1, 'editableUntil': '2026-10-22T03:50:00.000Z'});
      await tester.pumpWidget(harness(server, RollCallScreen(sectionId: 'sec', date: DateTime(2026, 10, 21))));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100)); // the route is open, the roster has not arrived
      expect(find.byType(SkeletonList), findsOneWidget);
      await tester.pumpAndSettle();

      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('Chitra Nair'), findsOneWidget);
      expect(find.text('On approved leave'), findsOneWidget);
      expect(find.text('2 of 4 marked'), findsOneWidget);
      // submit is disabled until everyone has a status, and says why
      expect(find.textContaining('2 students still need a status'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit roll call')).onPressed, isNull);

      await tester.tap(find.text('Mark all present'));
      await tester.pumpAndSettle();
      // s4 was saved as absent: the app asks before overwriting it
      expect(find.text('Mark everyone present?'), findsOneWidget);
      await tester.tap(find.text('Mark all present').last);
      await tester.pumpAndSettle();
      expect(find.text('4 of 4 marked'), findsOneWidget);
      expect(find.textContaining('still need a status'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Submit roll call'));
      await tester.pumpAndSettle();
      expect(find.text('Submit this roll call?'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty, reason: 'nothing is sent before the confirmation');
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      final put = server.requests.singleWhere((r) => r.method == 'PUT');
      expect(((put.body as Map)['records'] as List).map((r) => (r as Map)['status']), ['present', 'present', 'leave', 'present']);
      expect(find.byType(RollCallScreen), findsNothing, reason: 'the screen closes after a successful submit');
      expect(find.textContaining('Roll call submitted: 3 present'), findsOneWidget);
      expect(find.textContaining('1 guardian notified'), findsOneWidget);
    });

    testWidgets('present and absent buttons set a status; the more sheet sets late with a remark', (tester) async {
      server.on('GET /attendance/sections/sec', rosterJson());
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec')));
      await open(tester);

      await tester.tap(find.byTooltip('Present').first);
      await tester.pumpAndSettle();
      expect(find.text('3 of 4 marked'), findsOneWidget);
      expect(find.text('Present 1'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('More options for Bilal Khan: late, leave, half day, remark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Late'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bus delayed');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text('4 of 4 marked'), findsOneWidget);
      expect(find.text('Late 1'), findsOneWidget);
      expect(find.text('Bus delayed'), findsOneWidget);
    });

    testWidgets('a closed roll call opens read-only with the reason in plain words and offers corrections', (tester) async {
      server.on('GET /attendance/sections/sec', rosterJson(canSubmit: false, blocked: 'EDIT_WINDOW_CLOSED', canCorrect: true, submitted: true, students: [student('s1', 'Asha Rao', 1, status: 'present', recordId: 'r1'), student('s2', 'Bilal Khan', 2, status: 'absent', recordId: 'r2')]));
      server.on('POST /attendance/records/r2/corrections', {});
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec')));
      await open(tester);

      expect(find.text('Read-only'), findsOneWidget);
      expect(find.textContaining('The time allowed to change this roll call has passed'), findsOneWidget);
      expect(find.textContaining('Submitted by Sunita Verma'), findsOneWidget);
      expect(find.text('Submit roll call'), findsNothing);
      expect(find.text('Mark all present'), findsNothing);
      expect(find.byTooltip('Request a correction for Bilal Khan'), findsOneWidget);

      await tester.tap(find.byTooltip('Request a correction for Bilal Khan'));
      await tester.pumpAndSettle();
      expect(find.text('Request a correction'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the status it should be.'), findsOneWidget);
      await tester.tap(find.text('Present').last);
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Say why, in at least a few words.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Reason'), 'Was at school, marked by mistake');
      await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
      await tester.pumpAndSettle();
      final post = server.requests.singleWhere((r) => r.method == 'POST');
      expect(post.body, {'toStatus': 'present', 'reason': 'Was at school, marked by mistake'});
      expect(find.textContaining('Correction requested'), findsOneWidget);
    });

    for (final c in const {
      'NOT_CLASS_TEACHER': 'Only the class teacher can take daily attendance',
      'FUTURE_DATE': 'has not happened yet',
      'NOT_A_WORKING_DAY': 'not a school working day',
      'HOLIDAY': 'is a holiday',
      'PERIOD_REQUIRED': 'period by period',
    }.entries) {
      testWidgets('blocked reason ${c.key} is explained', (tester) async {
        server.on('GET /attendance/sections/sec', rosterJson(canSubmit: false, blocked: c.key));
        await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec')));
        await open(tester);
        expect(find.textContaining(c.value), findsOneWidget);
        expect(find.text('Submit roll call'), findsNothing);
      });
    }

    testWidgets('when the server refuses the submit, the roll call stays intact and the reason is shown', (tester) async {
      server.on('GET /attendance/sections/sec', rosterJson());
      server.on('PUT /attendance/sections/sec', {'title': 'Edit window closed', 'code': 'EDIT_WINDOW_CLOSED', 'status': 403}, status: 403);
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec')));
      await open(tester);
      await tester.tap(find.text('Mark all present'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark all present').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit roll call'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(find.byType(RollCallScreen), findsOneWidget, reason: 'stays on the roll call');
      expect(find.text('Not submitted'), findsOneWidget);
      expect(find.textContaining('The time allowed to change this roll call has passed'), findsWidgets);
      expect(find.text('Reload roll call'), findsOneWidget);
      expect(find.text('4 of 4 marked'), findsOneWidget, reason: 'every choice is kept');
    });

    testWidgets('leaving with unsubmitted changes asks first', (tester) async {
      server.on('GET /attendance/sections/sec', rosterJson());
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec')));
      await open(tester);
      await tester.tap(find.byTooltip('Present').first);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leave without submitting?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(RollCallScreen), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard changes'));
      await tester.pumpAndSettle();
      expect(find.byType(RollCallScreen), findsNothing);
    });

    testWidgets('view-only school: submitting sends nothing and says why', (tester) async {
      server.on('GET /attendance/sections/sec', rosterJson());
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec'), readOnly: true));
      await open(tester);
      expect(find.text('View-only mode'), findsOneWidget);
      await tester.tap(find.text('Mark all present'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark all present').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit roll call'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(find.textContaining('view-only mode'), findsWidgets);
    });

    testWidgets('load failure shows a retry', (tester) async {
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec'))); // 404 from the fake server
      await open(tester);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('an empty section says so', (tester) async {
      server.on('GET /attendance/sections/sec', rosterJson(students: []));
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec')));
      await open(tester);
      expect(find.text('No students in this class yet'), findsOneWidget);
    });

    testWidgets('200% text scale does not overflow (list, sheets, bottom bar)', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      server.on('GET /attendance/sections/sec', rosterJson());
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec'), textScale: 2));
      await open(tester);
      expect(tester.takeException(), isNull);
      // the header is tall at 200%: scroll down to the students, open the more sheet and the submit sheet
      await tester.scrollUntilVisible(find.text('Asha Rao'), 200, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Late, leave, half day or a remark').first);
      await tester.pumpAndSettle();
      expect(find.text('Half day'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('200% text scale', () {
    testWidgets('submit sheet and bottom bar', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final server = FakeServer()..on('GET /attendance/sections/sec', rosterJson(students: [student('s1', 'Asha Rao', 1, status: 'present'), student('s2', 'Bilal Khan Mohammed Abdul Rahman', 2, status: 'absent', remarks: 'Fever and a very long remark that keeps going')]));
      await tester.pumpWidget(harness(server, const RollCallScreen(sectionId: 'sec'), textScale: 2));
      await open(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit roll call'));
      await tester.pumpAndSettle();
      expect(find.text('Submit this roll call?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Today, History and Requests', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final server = FakeServer()
        ..on('GET /attendance/today', fixture('attendance_today'))
        ..on('GET /academics/sections', fixture('sections'))
        ..on('GET /attendance/sections/01a15f30-0fad-768a-9b1c-2e9284c11a7a/summary', fixture('section_summary'))
        ..on('GET /attendance/corrections', {'data': [], 'meta': {'page': 1, 'pageSize': 20, 'total': 0, 'totalPages': 1}})
        ..on('GET /leave', fixture('student_leave'));
      await tester.pumpWidget(harness(server, const Scaffold(body: TeacherAttendanceTab()), textScale: 2));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // At 200% the segment chips no longer fit side by side; the row scrolls sideways.
      await tester.drag(find.byType(FilterChips<int>), const Offset(-300, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('TeacherAttendanceTab', () {
    testWidgets('Today lists my sections with their state and opens nothing until tapped; History and Requests load on demand', (tester) async {
      final server = FakeServer()
        ..on('GET /attendance/today', {
          'date': '2026-10-21', 'mode': 'daily', 'isWorkingDay': true, 'holiday': null, 'role': 'teacher', 'pendingCount': 1, 'children': [], 'school': null,
          'items': [
            {'sectionId': 'a', 'sectionName': 'Grade 6-A', 'periodId': null, 'periodName': null, 'subjectName': null, 'strength': 24, 'marked': true, 'sessionStatus': 'submitted', 'counts': {'present': 21, 'absent': 1, 'late': 2, 'leave': 0, 'half_day': 0}},
            {'sectionId': 'b', 'sectionName': 'Grade 7-B', 'periodId': null, 'periodName': null, 'subjectName': null, 'strength': 20, 'marked': false, 'sessionStatus': null, 'counts': null},
          ],
        })
        ..on('GET /academics/sections', fixture('sections'))
        ..on('GET /attendance/sections/01a15f30-0fad-768a-9b1c-2e9284c11a7a/summary', fixture('section_summary'))
        ..on('GET /attendance/corrections', {'data': [], 'meta': {'page': 1, 'pageSize': 20, 'total': 0, 'totalPages': 1}})
        ..on('GET /leave', fixture('student_leave'));
      await tester.pumpWidget(harness(server, const Scaffold(body: TeacherAttendanceTab())));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('1 not yet marked'), findsOneWidget);
      expect(find.text('1 of 2 marked'), findsOneWidget);
      expect(find.text('Marked'), findsOneWidget);
      expect(find.text('Not yet marked'), findsOneWidget);
      expect(find.text('Present 21'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Take attendance'), findsOneWidget);
      expect(server.requests.where((r) => r.path.contains('/summary')), isEmpty, reason: 'History has not been opened yet');

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Earlier roll calls'), findsOneWidget);
      expect(find.textContaining('Class average'), findsOneWidget);

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Student leave'), findsOneWidget);
      expect(find.text('Attendance corrections'), findsOneWidget);
    });

    testWidgets('no classes to mark gives an explanation; a holiday is announced', (tester) async {
      final server = FakeServer()..on('GET /attendance/today', {'date': '2026-10-21', 'mode': 'daily', 'isWorkingDay': false, 'holiday': 'Diwali', 'role': 'teacher', 'items': [], 'pendingCount': 0, 'children': [], 'school': null});
      await tester.pumpWidget(harness(server, const Scaffold(body: TeacherAttendanceTab())));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Holiday: Diwali'), findsOneWidget);
      expect(find.text('No attendance to take today'), findsOneWidget);
    });

    testWidgets('error with retry', (tester) async {
      await tester.pumpWidget(harness(FakeServer(), const Scaffold(body: TeacherAttendanceTab())));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('CorrectionsScreen', () {
    Json item({String id = 'c1', bool canDecide = true, String status = 'pending'}) => {
      'id': id, 'recordId': 'r', 'studentId': 's', 'studentName': 'Dev Patel', 'admissionNo': 'GV4', 'rollNo': 4, 'sectionId': 'sec', 'sectionName': 'Grade 6 A', 'date': '2026-10-15',
      'fromStatus': 'absent', 'toStatus': 'present', 'reason': 'Was in school, marked by mistake', 'requestedBy': 'u', 'requestedByName': 'Rajesh Kulkarni', 'status': status,
      'decidedBy': null, 'decidedByName': null, 'decidedAt': null, 'decisionNote': null, 'createdAt': '2026-10-16T05:00:00.000Z', 'canDecide': canDecide,
    };
    Json page(List<Json> items) => {'data': items, 'meta': {'page': 1, 'pageSize': 20, 'total': items.length, 'totalPages': 1}};

    testWidgets('reject needs a note, then confirms, then sends it', (tester) async {
      final server = FakeServer()
        ..on('GET /attendance/corrections', page([item(), item(id: 'c2', canDecide: false)]))
        ..on('POST /attendance/corrections/c1/reject', {});
      await tester.pumpWidget(harness(server, const CorrectionsScreen()));
      await open(tester);
      expect(find.text('Dev Patel'), findsOneWidget, reason: 'only what I may decide is listed under To decide');
      await tester.tap(find.text('Dev Patel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Add a short note saying why'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'No evidence he was present');
      await tester.tap(find.text('Reject'));
      await tester.pumpAndSettle();
      expect(find.textContaining('The record stays as it is'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.text('Confirm reject'));
      await tester.pumpAndSettle();
      expect(server.requests.singleWhere((r) => r.method == 'POST').body, {'note': 'No evidence he was present'});
    });

    testWidgets('ALREADY_DECIDED is explained inside the sheet', (tester) async {
      final server = FakeServer()
        ..on('GET /attendance/corrections', page([item()]))
        ..on('POST /attendance/corrections/c1/approve', {'title': 'Decided', 'code': 'ALREADY_DECIDED', 'status': 409}, status: 409);
      await tester.pumpWidget(harness(server, const CorrectionsScreen()));
      await open(tester);
      await tester.tap(find.text('Dev Patel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm approve'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Someone has already decided this'), findsOneWidget);
    });

    testWidgets('empty state under To decide', (tester) async {
      final server = FakeServer()..on('GET /attendance/corrections', page([]));
      await tester.pumpWidget(harness(server, const CorrectionsScreen()));
      await open(tester);
      expect(find.text('Nothing to decide'), findsOneWidget);
    });
  });

  group('StudentLeaveScreen', () {
    Json leave({bool canDecide = true, String status = 'pending'}) => {
      'id': 'l1', 'studentId': 's', 'studentName': 'Siddharth Iyer', 'admissionNo': 'GV79', 'sectionId': 'sec', 'sectionName': 'Grade 7-B', 'leaveType': 'event', 'fromDate': '2026-10-22', 'toDate': '2026-10-23', 'days': 2,
      'reason': 'Inter-school quiz', 'attachmentFileId': null, 'status': status, 'requestedBy': 'u', 'requestedByName': 'Dhruv Iyer', 'decidedBy': null, 'decidedByName': null, 'decidedAt': null, 'decisionNote': null, 'createdAt': '2026-10-21T15:59:08.348Z', 'canDecide': canDecide, 'canCancel': false,
    };
    Json page(List<Json> items) => {'data': items, 'meta': {'page': 1, 'pageSize': 20, 'total': items.length, 'totalPages': 1}};

    testWidgets('approve with a note after a confirmation', (tester) async {
      final server = FakeServer()
        ..on('GET /leave', page([leave()]))
        ..on('POST /leave/l1/approve', {});
      await tester.pumpWidget(harness(server, const StudentLeaveScreen()));
      await open(tester);
      expect(find.text('Siddharth Iyer'), findsOneWidget);
      expect(find.text('2 days'), findsOneWidget);
      await tester.tap(find.text('Siddharth Iyer'));
      await tester.pumpAndSettle();
      expect(find.text('Inter-school quiz'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'Approved, good luck');
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm approve'));
      await tester.pumpAndSettle();
      expect(server.requests.singleWhere((r) => r.method == 'POST').body, {'note': 'Approved, good luck'});
      expect(find.text('Decision saved.'), findsOneWidget);
    });

    testWidgets('a request I cannot decide opens read-only', (tester) async {
      final server = FakeServer()..on('GET /leave', page([leave(canDecide: false)]));
      await tester.pumpWidget(harness(server, const StudentLeaveScreen()));
      await open(tester);
      await tester.tap(find.text('Siddharth Iyer'));
      await tester.pumpAndSettle();
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      final empty = FakeServer()..on('GET /leave', page([]));
      await tester.pumpWidget(harness(empty, const StudentLeaveScreen()));
      await open(tester);
      expect(find.text('No leave waiting for you'), findsOneWidget);
    });

    testWidgets('error state with retry', (tester) async {
      await tester.pumpWidget(harness(FakeServer(), const StudentLeaveScreen()));
      await open(tester);
      expect(find.text('Try again'), findsOneWidget);
    });
  });
}
