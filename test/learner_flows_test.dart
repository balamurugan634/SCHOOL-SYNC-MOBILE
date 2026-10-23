import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/features/announcements/announcement_detail_screen.dart';
import 'package:schoolsync/features/events/event_detail_screen.dart';
import 'package:schoolsync/features/fees/pay_screen.dart';
import 'package:schoolsync/features/homework/homework_detail_screen.dart';
import 'package:schoolsync/features/leave/leave_form_screen.dart';
import 'package:schoolsync/features/meetings/meeting_request_screen.dart';
import 'package:schoolsync/features/tasks/tasks_screen.dart';

import 'support/fake_api.dart';
import 'support/fonts.dart';
import 'support/learner_harness.dart';

/// The write flows end to end through the real screens: type, tap, and check what went over the wire.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  late FakeApi api;
  late GoRouter router;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  /// Opens [screen] as a pushed route (so `context.pop()` works) as the given role.
  Future<void> open(WidgetTester tester, String role, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await appAround(api, loadMe(role), screen, onRouter: (r) => router = r));
    await tester.pump();
    unawaited(router.push('/screen'));
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  setUp(() => api = FakeApi()..fallback = serveFixtures);

  testWidgets('student submits homework with a written answer', (tester) async {
    final detail = Map<String, dynamic>.of(fixture('homework_detail') as Json)
      ..['id'] = 'h1'
      ..['status'] = 'published'
      ..['dueAt'] = DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String()
      ..['learner'] = {'studentId': 's', 'status': 'pending', 'submission': null};
    api.on('GET /homework/h1', detail);
    api.on('GET /homework/h1/submission', {'title': 'Not submitted', 'code': 'NOT_SUBMITTED', 'status': 404}, status: 404);
    await open(tester, 'student', const HomeworkDetailScreen(homeworkId: 'h1'));
    expect(find.text('Submit your work'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Answer: 42');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await settle(tester);

    final sent = api.find('POST', '/homework/h1/submit')!;
    expect((sent.body as Map)['text'], 'Answer: 42');
    expect(find.byType(InfoBanner), findsNothing, reason: 'no error shown after a successful submit');
    await leave(tester);
  });

  testWidgets('a rejected submission shows the API message and keeps what was typed', (tester) async {
    final detail = Map<String, dynamic>.of(fixture('homework_detail') as Json)
      ..['id'] = 'h1'
      ..['status'] = 'published'
      ..['dueAt'] = DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String()
      ..['learner'] = {'studentId': 's', 'status': 'pending', 'submission': null};
    api.on('GET /homework/h1', detail);
    api.on('GET /homework/h1/submission', {'title': 'Not submitted', 'code': 'NOT_SUBMITTED', 'status': 404}, status: 404);
    api.on('POST /homework/h1/submit', {'title': 'Homework is closed', 'code': 'HOMEWORK_CLOSED', 'status': 409}, status: 409);
    await open(tester, 'student', const HomeworkDetailScreen(homeworkId: 'h1'));
    await tester.enterText(find.byType(TextField), 'late answer');
    await tester.ensureVisible(find.text('Submit'));
    await tester.tap(find.text('Submit'));
    await settle(tester);
    expect(find.text('Homework is closed'), findsOneWidget);
    expect(find.text('late answer'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('adding a task from the sheet posts it', (tester) async {
    await open(tester, 'student', const TasksScreen(embedded: false));
    await tester.tap(find.text('Add task'));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, '  Read chapter 4  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Add task'));
    await settle(tester);
    final sent = api.find('POST', '/tasks')!;
    expect((sent.body as Map)['title'], 'Read chapter 4');
    expect((sent.body as Map)['priority'], 'normal');
    await leave(tester);
  });

  testWidgets('a parent gives consent for the trip for their child', (tester) async {
    Map<String, dynamic> event(String? response) => {
      ...(fixture('event_consent') as Json),
      'id': 'e1',
      'children': [{'studentId': 'child-1', 'studentName': 'Ishaan Bose', 'response': response, 'note': null}],
    };
    String? answered;
    api.onFn('GET /events/e1', (_) => (200, event(answered)));
    api.onFn('POST /events/e1/respond', (r) {
      answered = (r.body as Map)['response'] as String;
      return (200, {'studentId': 'child-1', 'studentName': 'Ishaan Bose', 'response': answered, 'note': null, 'respondedAt': '2026-10-21T10:00:00.000Z'});
    });
    await open(tester, 'parent', const EventDetailScreen(id: 'e1'));
    expect(find.text('Give permission'), findsOneWidget);
    await tester.ensureVisible(find.text('Give permission'));
    await tester.tap(find.text('Give permission'));
    await settle(tester);
    final sent = api.find('POST', '/events/e1/respond')!;
    expect((sent.body as Map)['response'], 'consent_given');
    expect((sent.body as Map)['studentId'], 'child-1');
    expect(find.text('Permission given'), findsWidgets, reason: 'the screen reloads and shows the saved answer');
    await leave(tester);
  });

  testWidgets('acknowledging an announcement', (tester) async {
    final a = Map<String, dynamic>.of(((fixture('announcements') as Json)['data'] as List)[3] as Json)
      ..['id'] = 'a1'
      ..['requiresAck'] = true
      ..['acknowledged'] = false;
    api.on('GET /announcements/a1', a);
    await open(tester, 'parent', const AnnouncementDetailScreen(id: 'a1'));
    await tester.ensureVisible(find.text('I have read this'));
    await tester.tap(find.text('I have read this'));
    await settle(tester);
    expect(api.count('POST', '/announcements/a1/ack'), 1);
    await leave(tester);
  });

  testWidgets('a parent applies for leave for their child', (tester) async {
    await open(tester, 'parent', const LeaveFormScreen());
    await tester.enterText(find.widgetWithText(TextField, 'Reason'), 'Fever and a doctor visit');
    await tester.ensureVisible(find.text('Send request'));
    await tester.tap(find.text('Send request'));
    await settle(tester);
    final sent = api.find('POST', '/leave')!;
    final body = sent.body as Map;
    expect(body['reason'], 'Fever and a doctor visit');
    expect(body['studentId'], isNotNull, reason: 'a parent always names the child');
    expect(body['leaveType'], isNotNull);
    await leave(tester);
  });

  testWidgets('leave needs a reason before anything is sent', (tester) async {
    await open(tester, 'parent', const LeaveFormScreen());
    await tester.ensureVisible(find.text('Send request'));
    await tester.tap(find.text('Send request'));
    await settle(tester);
    expect(api.count('POST', '/leave'), 0);
    await leave(tester);
  });

  testWidgets('a parent requests a meeting with the class teacher', (tester) async {
    await open(tester, 'parent', const MeetingRequestScreen());
    await tester.tap(find.text('Sunita Verma'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'What would you like to discuss?'), 'Progress in English');
    await tester.scrollUntilVisible(find.text('Send request'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Send request'));
    await settle(tester);
    final body = api.find('POST', '/meetings')!.body as Map;
    expect(body['topic'], 'Progress in English');
    expect(body['staffId'], isNotNull);
    expect(body['studentId'], isNotNull);
    await leave(tester);
  });

  testWidgets('paying a fee on the mock gateway: start, complete, then the receipt', (tester) async {
    api.on('GET /fees/invoices/i1', {...(fixture('invoice_detail') as Json), 'id': 'i1'});
    api.on('GET /payments/p-new', {...((fixture('payments') as Json)['data'][0] as Map).cast<String, dynamic>(), 'id': 'p-new', 'status': 'created'});
    await open(tester, 'parent', const PayScreen(invoiceId: 'i1'));
    expect(find.text('Pay ₹15,600'), findsOneWidget);
    await tester.tap(find.text('Pay ₹15,600'));
    await settle(tester);
    final started = api.find('POST', '/fees/invoices/i1/pay')!;
    expect((started.body as Map)['amountMinor'], 1560000);
    expect(find.text('Complete test payment'), findsOneWidget);

    api.on('GET /payments/p-new', {...((fixture('payments') as Json)['data'][0] as Map).cast<String, dynamic>(), 'id': 'p-new', 'status': 'success'});
    await tester.tap(find.text('Complete test payment'));
    await settle(tester);
    expect(api.count('POST', '/payments/p-new/mock-complete'), 1);
    expect(find.text('View receipt'), findsOneWidget);
    await tester.tap(find.text('View receipt'));
    await settle(tester);
    expect(find.textContaining('receipt '), findsOneWidget, reason: 'View receipt opens the receipt route');
    await leave(tester);
  });
}
