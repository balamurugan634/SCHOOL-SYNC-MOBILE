import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/staff/people.dart';
import 'package:schoolsync/features/teacher/more/syllabus_screen.dart';
import 'package:schoolsync/features/teacher/more/teacher_more_screen.dart';
import 'package:schoolsync/features/teacher/more/timetable_screen.dart';
import 'package:schoolsync/features/workspace/announcements/announcement_form_screen.dart';
import 'package:schoolsync/features/workspace/announcements/announcements_screen.dart';
import 'package:schoolsync/features/workspace/me/check_in_screen.dart';
import 'package:schoolsync/features/workspace/me/my_leave_screen.dart';
import 'package:schoolsync/features/workspace/meetings/meetings_screen.dart';

import 'staff_test_support.dart';
import 'support/fonts.dart';
import 'workspace_test_support.dart';

List<String> _sectionTitles() => jsonList(fixture('sections')['data']).map((j) => SectionItem.fromJson(j).title).toList();

Json _attendance({String? checkIn, String? checkOut, String status = 'present', bool noRecord = false}) {
  final j = fixture('staff_attendance_me');
  j['today'] = noRecord ? null : {'id': 'r1', 'staffId': 'st', 'date': '2026-10-21', 'status': status, 'checkIn': checkIn, 'checkOut': checkOut, 'note': null};
  return j;
}

Json _leaveList({bool pending = true}) => {
  'data': [
    {
      'id': 'lv1', 'staffId': 'st', 'staffName': 'Sunita Verma', 'employeeId': 'EMP1', 'designation': 'Teacher', 'leaveType': 'casual', 'fromDate': '2026-12-14', 'toDate': '2026-12-15', 'days': 2, 'reason': 'Family function',
      'status': pending ? 'pending' : 'approved', 'decidedBy': null, 'decidedByName': pending ? null : 'Dr. Raman', 'decidedAt': null, 'decisionNote': pending ? null : 'Enjoy', 'createdAt': '2026-10-21T10:00:00.000Z', 'canDecide': false, 'canCancel': pending,
    },
  ],
  'meta': {'page': 1, 'pageSize': 20, 'total': 1, 'totalPages': 1},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // flutter_test draws every font as double-width Ahem boxes; use the app's real fonts so overflow checks mean something.
  setUpAll(loadAppFonts);

  group('announcement form: audience follows the permission scope', () {
    testWidgets('a teacher can only choose the classes they lead or teach', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /academics/sections', fixture('sections'))
        ..on('POST /announcements', (fixture('managed_announcements')['data'] as List).first, status: 201);
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementFormScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Which classes?'), findsOneWidget);
      for (final title in _sectionTitles()) {
        expect(find.widgetWithText(FilterChip, title), findsOneWidget, reason: title);
      }
      expect(find.text('Everyone'), findsNothing);
      expect(find.text('Students'), findsNothing);
      expect(find.text('Parents'), findsNothing);
      expect(find.text('Select all'), findsOneWidget);
      expect(server.requests.where((r) => r.path == '/academics/grades'), isEmpty, reason: 'a teacher never needs the grade list');
      expect(server.requests.firstWhere((r) => r.path == '/academics/sections').query['mine'], true);
    });

    testWidgets('publishing without a class explains why and sends nothing', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /academics/sections', fixture('sections'));
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementFormScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Sports day');
      await tester.enterText(find.byType(TextField).at(1), 'Bring a water bottle.');
      await tester.tap(find.text('Publish now'));
      await tester.pumpAndSettle();

      expect(find.text('Choose at least one class.'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('saving a draft posts the chosen section and the message', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /academics/sections', fixture('sections'))
        ..on('POST /announcements', (fixture('managed_announcements')['data'] as List).first, status: 201);
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementFormScreen()));
      await tester.pumpAndSettle();

      final first = _sectionTitles().first;
      await tester.enterText(find.byType(TextField).at(0), '  Sports day ');
      await tester.enterText(find.byType(TextField).at(1), 'Bring a water bottle.');
      await tester.tap(find.widgetWithText(FilterChip, first));
      await tester.pump();
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      final post = server.requests.firstWhere((r) => r.method == 'POST' && r.path == '/announcements');
      final body = post.body as Map;
      expect(body['title'], 'Sports day');
      expect(body['priority'], 'normal');
      expect((body['audience'] as List).single, {'type': 'section', 'id': (fixture('sections')['data'] as List).first['id']});
      expect(body.containsKey('publishAt'), isFalse, reason: 'a draft is not scheduled');
      expect(find.textContaining('Saved as a draft'), findsOneWidget);
    });

    testWidgets('school scope can also address everyone, a user type or a grade', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /academics/sections', fixture('sections'))
        ..on('GET /academics/grades', {'data': [{'id': 'g6', 'name': 'Grade 6', 'ordinal': 6}, {'id': 'g7', 'name': 'Grade 7', 'ordinal': 7}]});
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementFormScreen(), me: meOf('principal')));
      await tester.pumpAndSettle();

      expect(find.text('Who is this for?'), findsOneWidget);
      for (final label in ['Everyone', 'Students', 'Parents', 'Staff', 'Grade 6', 'Grade 7']) {
        expect(find.widgetWithText(FilterChip, label), findsOneWidget, reason: label);
      }
      expect(server.requests.firstWhere((r) => r.path == '/academics/sections').query.containsKey('mine'), isFalse, reason: 'school scope sees every class');

      // Everyone excludes the narrower choices.
      await tester.tap(find.widgetWithText(FilterChip, 'Students'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Everyone'));
      await tester.pump();
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Everyone')).selected, isTrue);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Students')).selected, isFalse);
      await tester.tap(find.widgetWithText(FilterChip, 'Grade 6'));
      await tester.pump();
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Everyone')).selected, isFalse);
      expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Grade 6')).selected, isTrue);
    });

    testWidgets('view-only mode disables publishing and says why', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /academics/sections', fixture('sections'));
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementFormScreen(), readOnly: true));
      await tester.pumpAndSettle();
      expect(find.text('View-only mode'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish now')).onPressed, isNull);
    });

    testWidgets('API refusal of the audience shows under the audience, not as a crash', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /academics/sections', fixture('sections'))
        ..on('POST /announcements', {'title': 'You can only address sections you lead or teach', 'code': 'AUDIENCE_NOT_ALLOWED', 'status': 403}, status: 403);
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementFormScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Hello');
      await tester.enterText(find.byType(TextField).at(1), 'World');
      await tester.tap(find.widgetWithText(FilterChip, _sectionTitles().first));
      await tester.pump();
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      expect(find.text('You can only address the classes you lead or teach.'), findsWidgets);
    });

    testWidgets('fits at 200% text size without overflow', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /academics/sections', fixture('sections'));
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementFormScreen(), textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Publish now'), findsOneWidget);
      expect(find.text('Save draft'), findsOneWidget);
    });
  });

  group('announcement list', () {
    testWidgets('shows state, audience and read counts; the New button follows the permission', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /announcements/manage', fixture('managed_announcements'));
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Published'), findsWidgets);
      expect(find.textContaining('Read by'), findsWidgets);
      expect(find.text('New announcement'), findsOneWidget);
      expect(find.text('Only the ones I wrote'), findsNothing, reason: 'teachers only ever see their own');
    });

    testWidgets('empty and error states', (tester) async {
      phoneSize(tester);
      var server = FakeServer()..on('GET /announcements/manage', {'data': [], 'meta': {'page': 1, 'pageSize': 20, 'total': 0, 'totalPages': 1}});
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No announcements yet'), findsOneWidget);

      server = FakeServer()..on('GET /announcements/manage', {'title': 'Down', 'code': 'X', 'status': 500}, status: 500);
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('school-scope editors get the "only mine" switch', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /announcements/manage', fixture('managed_announcements'));
      await tester.pumpWidget(workspaceHarness(server, const AnnouncementsScreen(), me: meOf('principal')));
      await tester.pumpAndSettle();
      expect(find.text('Only the ones I wrote'), findsOneWidget);
    });
  });

  group('my attendance (check in / out)', () {
    testWidgets('not checked in: one big Check in button, and it posts', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /staff-attendance/me', _attendance(noRecord: true))
        ..on('POST /staff-attendance/check-in', {'ok': true});
      await tester.pumpWidget(workspaceHarness(server, const CheckInScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Not checked in yet'), findsOneWidget);
      expect(find.text('Check out'), findsNothing);
      expect(tester.getSize(find.widgetWithText(FilledButton, 'Check in')).height, greaterThanOrEqualTo(56));
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'POST').single.path, '/staff-attendance/check-in');
      expect(find.text('You are checked in.'), findsOneWidget);
    });

    testWidgets('checked in: Check out asks for confirmation first', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /staff-attendance/me', _attendance(checkIn: '08:17'))
        ..on('POST /staff-attendance/check-out', {'ok': true});
      await tester.pumpWidget(workspaceHarness(server, const CheckInScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Checked in at 8:17 am'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Check in'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Check out'));
      await tester.pumpAndSettle();
      expect(find.text('Check out now?'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Check out'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'POST').single.path, '/staff-attendance/check-out');
    });

    testWidgets('checked out: no buttons, time at school shown', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /staff-attendance/me', _attendance(checkIn: '08:17', checkOut: '15:30'));
      await tester.pumpWidget(workspaceHarness(server, const CheckInScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Checked out at 3:30 pm'), findsOneWidget);
      expect(find.text('You were at school for 7 h 13 min.'), findsOneWidget);
      expect(find.text('Check in'), findsNothing);
      expect(find.text('Check out'), findsNothing);
    });

    testWidgets('recorded by the office: self check-in is closed', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /staff-attendance/me', _attendance(status: 'leave'));
      await tester.pumpWidget(workspaceHarness(server, const CheckInScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Recorded by the office'), findsOneWidget);
      expect(find.textContaining('on leave today'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Check in'), findsNothing);
    });

    testWidgets('ALREADY_CHECKED_IN is explained and the state refreshes', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /staff-attendance/me', _attendance(noRecord: true))
        ..on('POST /staff-attendance/check-in', {'title': 'You already checked in today', 'code': 'ALREADY_CHECKED_IN', 'status': 409}, status: 409);
      await tester.pumpWidget(workspaceHarness(server, const CheckInScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Check in'));
      await tester.pumpAndSettle();
      expect(find.text('You already checked in today.'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'GET' && r.path == '/staff-attendance/me').length, 2, reason: 'reloaded after the refusal');
    });

    testWidgets('view-only mode disables the button; offline shows retry; 200% text fits', (tester) async {
      phoneSize(tester);
      var server = FakeServer()..on('GET /staff-attendance/me', _attendance(noRecord: true));
      await tester.pumpWidget(workspaceHarness(server, const CheckInScreen(), readOnly: true, textScale: 2));
      await tester.pumpAndSettle();
      expect(find.text('View-only mode'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Check in')).onPressed, isNull);
      expect(tester.takeException(), isNull);

      server = FakeServer()..on('GET /staff-attendance/me', {'title': 'Down', 'code': 'X', 'status': 500}, status: 500);
      await tester.pumpWidget(workspaceHarness(server, const CheckInScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('my leave', () {
    testWidgets('lists requests with the decision, balance, and cancels a pending one after confirmation', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /staff-leave', _leaveList())
        ..on('GET /staff-leave/balance', fixture('leave_balance'))
        ..on('POST /staff-leave/lv1/cancel', {'ok': true});
      await tester.pumpWidget(workspaceHarness(server, const MyLeaveScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Casual leave'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Family function'), findsOneWidget);
      await tester.tap(find.text('Cancel request'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this leave request?'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel request'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'POST').single.path, '/staff-leave/lv1/cancel');
    });

    testWidgets('a decided request shows who decided and the note, with no Cancel', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /staff-leave', _leaveList(pending: false))..on('GET /staff-leave/balance', fixture('leave_balance'));
      await tester.pumpWidget(workspaceHarness(server, const MyLeaveScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Approved'), findsOneWidget);
      expect(find.textContaining('Decided by Dr. Raman'), findsOneWidget);
      expect(find.text('Enjoy'), findsOneWidget);
      expect(find.text('Cancel request'), findsNothing);
    });

    testWidgets('the apply sheet validates before sending, and sends the right body', (tester) async {
      phoneSize(tester);
      final server = FakeServer()
        ..on('GET /staff-leave', {'data': [], 'meta': {'page': 1, 'pageSize': 20, 'total': 0, 'totalPages': 1}})
        ..on('GET /staff-leave/balance', fixture('leave_balance'))
        ..on('POST /staff-leave', {'ok': true}, status: 201);
      await tester.pumpWidget(workspaceHarness(server, const MyLeaveScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No leave requests yet'), findsOneWidget);
      await tester.tap(find.text('Apply for leave').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('Pick the first day.'), findsOneWidget);
      expect(find.text('Say why in a few words.'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('empty balance and 200% text', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /staff-leave', _leaveList())..on('GET /staff-leave/balance', fixture('leave_balance'));
      await tester.pumpWidget(workspaceHarness(server, const MyLeaveScreen(), textScale: 2));
      await tester.pumpAndSettle();
      expect(find.textContaining('No leave taken or waiting this year'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('meetings', () {
    testWidgets('requests show the actions the API allows; Confirm validates the slot', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /meetings', fixture('meetings'));
      await tester.pumpWidget(workspaceHarness(server, const MeetingsScreen()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Requests ('), findsOneWidget);
      expect(find.text('Needs your answer'), findsWidgets);
      expect(find.widgetWithText(FilledButton, 'Confirm'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Decline'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm').first);
      await tester.pumpAndSettle();
      expect(find.text('Confirm the meeting'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Online'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Length in minutes'), '400');
      await tester.tap(find.text('Confirm meeting'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a length between 5 and 180 minutes.'), findsOneWidget);
      expect(find.text('An online meeting needs a link.'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('declining needs a reason and posts it', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /meetings', fixture('meetings'));
      final meetings = (fixture('meetings')['data'] as List).cast<Map<String, dynamic>>();
      final target = meetings.firstWhere((m) => (m['availableActions'] as List).contains('decline'));
      server.on('POST /meetings/${target['id']}/decline', {'ok': true});
      await tester.pumpWidget(workspaceHarness(server, const MeetingsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Decline').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Decline request'));
      await tester.pumpAndSettle();
      expect(find.text('Say why, so the parent understands.'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('confirming sends the proposed slot; MEETING_SLOT_TAKEN is explained inside the sheet', (tester) async {
      phoneSize(tester);
      final data = fixture('meetings');
      final meetings = (data['data'] as List).cast<Map<String, dynamic>>();
      final target = meetings.firstWhere((m) => (m['availableActions'] as List).contains('confirm'));
      final proposed = DateTime.now().add(const Duration(days: 2)).toUtc();
      target['proposedAt'] = proposed.toIso8601String();
      final server = FakeServer()
        ..on('GET /meetings', data)
        ..on('POST /meetings/${target['id']}/confirm', {'title': 'Slot taken', 'code': 'MEETING_SLOT_TAKEN', 'status': 409}, status: 409);
      await tester.pumpWidget(workspaceHarness(server, const MeetingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm meeting'));
      await tester.pumpAndSettle();
      expect(find.text('You already have a meeting at that time. Pick another time.'), findsWidgets);
      expect(find.text('Confirm the meeting'), findsOneWidget, reason: 'the sheet stays open so nothing typed is lost');

      server.on('POST /meetings/${target['id']}/confirm', {'ok': true});
      await tester.tap(find.text('Confirm meeting'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm the meeting'), findsNothing);
      final body = server.requests.lastWhere((r) => r.method == 'POST').body as Map;
      expect(DateTime.parse(body['scheduledAt'] as String).difference(proposed).inSeconds.abs(), lessThan(61));
      expect(body['durationMin'], 15);
      expect(body['mode'], target['mode']);
    });

    testWidgets('empty state per tab, at 200% text', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /meetings', {'data': [], 'meta': {'page': 1, 'pageSize': 20, 'total': 0, 'totalPages': 1}});
      await tester.pumpWidget(workspaceHarness(server, const MeetingsScreen(), textScale: 2));
      await tester.pumpAndSettle();
      expect(find.text('No requests waiting'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('Nothing booked'), findsOneWidget);
    });
  });

  group('teacher More tab', () {
    testWidgets('a teacher sees every group, with the pending-request count', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /meetings', fixture('meetings'));
      await tester.pumpWidget(workspaceHarness(server, const TeacherMoreScreen()));
      await tester.pumpAndSettle();
      for (final label in ['Timetable', 'Syllabus progress', 'Marks entry', 'Announcements', 'Meetings', 'My attendance', 'My leave', 'Settings and security', 'Notifications']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.textContaining('new'), findsOneWidget);
      expect(find.text('Class teacher'), findsOneWidget);
    });

    testWidgets('rows are hidden when the permission is missing', (tester) async {
      phoneSize(tester);
      final me = withoutPermissions(meOf('teacher'), (k) => k.startsWith('meetings:') || k.startsWith('staff_leave:') || k.startsWith('marks:'));
      final server = FakeServer()..on('GET /meetings', fixture('meetings'));
      await tester.pumpWidget(workspaceHarness(server, const TeacherMoreScreen(), me: me));
      await tester.pumpAndSettle();
      expect(find.text('Meetings'), findsNothing);
      expect(find.text('My leave'), findsNothing);
      expect(find.text('Marks entry'), findsNothing);
      expect(find.text('Timetable'), findsOneWidget);
      expect(find.text('Settings and security'), findsOneWidget);
      expect(server.requests.where((r) => r.path == '/meetings'), isEmpty, reason: 'no count is fetched for a hidden row');
    });
  });

  group('timetable', () {
    testWidgets('shows the day, switches day with a fresh request', (tester) async {
      phoneSize(tester);
      final server = FakeServer()..on('GET /timetable/me', fixture('timetable_me'));
      await tester.pumpWidget(workspaceHarness(server, const TeacherTimetableScreen()));
      await tester.pumpAndSettle();
      expect(find.text('This week'), findsOneWidget);
      final first = (fixture('timetable_me')['entries'] as List).cast<Map<String, dynamic>>().firstWhere((e) => e['isBreak'] != true);
      expect(find.text('${first['subjectName']}'), findsWidgets);
      final before = server.requests.length;
      await tester.tap(find.byTooltip('Next week'));
      await tester.pumpAndSettle();
      expect(server.requests.length, before + 1);
      expect(find.text('This week'), findsNothing);
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('This week'), findsOneWidget);
    });

    testWidgets('a non-working day and a server error', (tester) async {
      phoneSize(tester);
      final off = fixture('timetable_me')..['isWorkingDay'] = false..['entries'] = [];
      var server = FakeServer()..on('GET /timetable/me', off);
      await tester.pumpWidget(workspaceHarness(server, const TeacherTimetableScreen(), textScale: 2));
      await tester.pumpAndSettle();
      expect(find.text('No school on this day'), findsOneWidget);
      expect(tester.takeException(), isNull);

      server = FakeServer()..on('GET /timetable/me', {'title': 'Down', 'code': 'X', 'status': 500}, status: 500);
      await tester.pumpWidget(workspaceHarness(server, const TeacherTimetableScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('syllabus', () {
    testWidgets('tap a topic to cycle it, then save only the change', (tester) async {
      phoneSize(tester);
      final assignments = fixture('assignments');
      final server = FakeServer()
        ..on('GET /academics/teaching-assignments', assignments)
        ..on('GET /syllabus/topics', fixture('syllabus_topics'))
        ..on('GET /syllabus/coverage', fixture('coverage'))
        ..on('PUT /syllabus/progress', {'data': []});
      await tester.pumpWidget(workspaceHarness(server, const SyllabusScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Coverage'), findsOneWidget);
      expect(find.textContaining('Save'), findsNothing);

      final topics = (fixture('syllabus_topics')['data'] as List).cast<Map<String, dynamic>>();
      final target = topics.first;
      final saved = (target['progress'] as Map?)?['status'] ?? 'not_started';
      await tester.tap(find.byTooltip(RegExp('^Mark "${RegExp.escape('${target['title']}')}" as ')));
      await tester.pumpAndSettle();
      expect(find.text('Save 1 change'), findsOneWidget);
      expect(find.textContaining('Not saved'), findsOneWidget);
      await tester.tap(find.text('Save 1 change'));
      await tester.pumpAndSettle();
      final put = server.requests.singleWhere((r) => r.method == 'PUT');
      final body = put.body as Map;
      expect((body['items'] as List).length, 1);
      expect((body['items'] as List).single['topicId'], target['id']);
      expect((body['items'] as List).single['status'], isNot(saved));
    });

    testWidgets('no assignments and no topics are explained', (tester) async {
      phoneSize(tester);
      var server = FakeServer()..on('GET /academics/teaching-assignments', {'data': [], 'meta': {'page': 1, 'pageSize': 100, 'total': 0, 'totalPages': 1}});
      await tester.pumpWidget(workspaceHarness(server, const SyllabusScreen()));
      await tester.pumpAndSettle();
      expect(find.text('No classes assigned yet'), findsOneWidget);

      server = FakeServer()
        ..on('GET /academics/teaching-assignments', fixture('assignments'))
        ..on('GET /syllabus/topics', {'data': []})
        ..on('GET /syllabus/coverage', {'data': []});
      await tester.pumpWidget(workspaceHarness(server, const SyllabusScreen(), textScale: 2));
      await tester.pumpAndSettle();
      expect(find.text('No topics yet'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
