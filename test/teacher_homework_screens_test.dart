import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/staff/teaching.dart';
import 'package:schoolsync/features/teacher/homework/homework_detail_screen.dart';
import 'package:schoolsync/features/teacher/homework/homework_form_screen.dart';
import 'package:schoolsync/features/teacher/homework/homework_tab.dart';
import 'package:schoolsync/features/teacher/homework/submission_review_screen.dart';

import 'staff_test_support.dart';
import 'teacher_homework_marks_harness.dart';

Map<String, dynamic> _assignments() => {
  'data': [
    {'id': 'a1', 'sectionId': 'sec6a', 'sectionName': 'A', 'gradeId': 'g6', 'gradeName': 'Grade 6', 'subjectId': 'eng', 'subjectName': 'English', 'staffId': 'me', 'staffName': 'Me', 'periodsPerWeek': 5},
    {'id': 'a2', 'sectionId': 'sec6a', 'sectionName': 'A', 'gradeId': 'g6', 'gradeName': 'Grade 6', 'subjectId': 'hin', 'subjectName': 'Hindi', 'staffId': 'me', 'staffName': 'Me', 'periodsPerWeek': 4},
    {'id': 'a3', 'sectionId': 'sec8b', 'sectionName': 'B', 'gradeId': 'g8', 'gradeName': 'Grade 8', 'subjectId': 'mat', 'subjectName': 'Mathematics', 'staffId': 'me', 'staffName': 'Me', 'periodsPerWeek': 6},
  ],
  'meta': {'page': 1, 'pageSize': 100, 'total': 3, 'totalPages': 1},
};

Map<String, dynamic> _hw({String status = 'draft', String id = 'hw1', String title = 'Fractions practice', Map<String, dynamic>? stats}) => {
  'id': id,
  'sectionId': 'sec6a',
  'sectionName': 'A',
  'gradeName': 'Grade 6',
  'subjectId': 'eng',
  'subjectName': 'English',
  'title': title,
  'description': 'Do questions 1 to 5',
  'attachments': <Object?>[],
  'assignedAt': '2026-10-20T10:00:00.000Z',
  'dueAt': DateTime.now().add(const Duration(days: 3)).toUtc().toIso8601String(),
  'allowSubmission': true,
  'maxMarks': 20,
  'status': status,
  'stats': stats ?? {'totalStudents': 24, 'submitted': 4, 'late': 2, 'reviewed': 3, 'returned': 1, 'missing': 14},
};

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('HomeworkFormScreen (create)', () {
    late FakeServer server;
    setUp(() {
      server = FakeServer();
      server.on('GET /academics/teaching-assignments', _assignments());
    });

    testWidgets('class and subject pickers offer only what I teach', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      expect(server.requests.where((r) => r.path == '/academics/teaching-assignments').single.query['staffId'], isNotNull);

      await tester.tap(find.text('Class'));
      await tester.pumpAndSettle();
      expect(find.text('Grade 6 A'), findsWidgets);
      expect(find.text('Grade 8 B'), findsWidgets);
      expect(find.text('Grade 7 B'), findsNothing, reason: 'not one of my classes');
      await tester.tap(find.text('Grade 6 A').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Subject'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsWidgets);
      expect(find.text('Hindi'), findsWidgets);
      expect(find.text('Mathematics'), findsNothing, reason: 'I teach maths only in Grade 8 B');
    });

    testWidgets('a single class and subject are preselected', (tester) async {
      usePhone(tester);
      server.on('GET /academics/teaching-assignments', {'data': [(_assignments()['data'] as List).first], 'meta': {'page': 1, 'pageSize': 100, 'total': 1, 'totalPages': 1}});
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      expect(find.text('Grade 6 A'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('saving without a title shows the problem and sends nothing', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      await tester.tap(find.text('Save as draft'));
      await tester.pumpAndSettle();
      expect(find.text('Choose the class this is for.'), findsOneWidget);
      expect(find.text('Give the homework a title.'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('marks field disappears when online submissions are switched off', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      expect(find.text('Maximum marks (optional)'), findsOneWidget);
      await tester.tap(find.text('Allow online submissions'));
      await tester.pumpAndSettle();
      expect(find.text('Maximum marks (optional)'), findsNothing);
    });

    testWidgets('save as draft posts the form and opens the new homework', (tester) async {
      usePhone(tester);
      server.on('POST /homework', _hw(id: 'new1'), status: 201);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      await tester.tap(find.text('Class'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grade 8 B').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), '  Algebra worksheet ');
      await tester.enterText(find.widgetWithText(TextField, 'Maximum marks (optional)'), '15');
      await tester.tap(find.text('Save as draft'));
      await tester.pumpAndSettle();

      final post = server.requests.firstWhere((r) => r.method == 'POST' && r.path == '/homework');
      final body = post.body as Map;
      expect(body['title'], 'Algebra worksheet');
      expect(body['sectionId'], 'sec8b');
      expect(body['subjectId'], 'mat', reason: 'the only subject I teach in that class is preselected');
      expect(body['maxMarks'], 15);
      expect(body['publish'], false);
      expect(body['allowSubmission'], true);
      expect((body['dueAt'] as String).endsWith('Z'), isTrue);
      expect(find.text('DETAIL new1'), findsOneWidget, reason: 'goes to the new homework');
    });

    testWidgets('publish asks for confirmation first; cancelling sends nothing', (tester) async {
      usePhone(tester);
      server.on('POST /homework', _hw(id: 'new2', status: 'published'), status: 201);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      await tester.tap(find.text('Class'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grade 8 B').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Quiz prep');
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(find.text('Publish this homework?'), findsOneWidget);
      expect(find.textContaining('notified'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);

      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Publish')));
      await tester.pumpAndSettle();
      expect((server.requests.firstWhere((r) => r.method == 'POST').body as Map)['publish'], true);
    });

    testWidgets('a field error from the API lands on the field', (tester) async {
      usePhone(tester);
      server.on('POST /homework', {'title': 'Validation failed', 'code': 'VALIDATION_ERROR', 'status': 422, 'errors': [{'path': 'title', 'message': 'Title is already used today'}]}, status: 422);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      await tester.tap(find.text('Class'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Grade 8 B').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Dup');
      await tester.tap(find.text('Save as draft'));
      await tester.pumpAndSettle();
      expect(find.text('Title is already used today'), findsWidgets);
    });

    testWidgets('leaving with unsaved text asks first', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Half done');
      await tester.pump(); // the form rebuilds (PopScope blocks the pop) before the back tap
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Discard your changes?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('a teacher with no classes is told why', (tester) async {
      usePhone(tester);
      server.on('GET /academics/teaching-assignments', {'data': <Object?>[], 'meta': {'page': 1, 'pageSize': 100, 'total': 0, 'totalPages': 1}});
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen()));
      await openScreen(tester);
      expect(find.text('No classes assigned yet'), findsOneWidget);
    });

    testWidgets('view-only school: nothing is sent and a banner explains', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen(), readOnly: true));
      await openScreen(tester);
      expect(find.text('View-only mode'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Publish')).onPressed, isNull);
    });
  });

  group('HomeworkFormScreen (edit)', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    testWidgets('class and subject are locked; saving uses PATCH without them', (tester) async {
      usePhone(tester);
      server.on('GET /homework/hw1', _hw());
      server.on('PATCH /homework/hw1', _hw());
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.textContaining('cannot be changed'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Title'), 'Fractions practice 2');
      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();
      final patch = server.requests.firstWhere((r) => r.method == 'PATCH');
      expect(patch.path, '/homework/hw1');
      expect((patch.body as Map)['title'], 'Fractions practice 2');
      expect((patch.body as Map).containsKey('sectionId'), isFalse);
      expect(server.requests.where((r) => r.path.endsWith('/publish')), isEmpty);
    });

    testWidgets('a published homework offers Save changes only', (tester) async {
      usePhone(tester);
      server.on('GET /homework/hw1', _hw(status: 'published'));
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);
    });

    testWidgets('a closed homework cannot be edited', (tester) async {
      usePhone(tester);
      server.on('GET /homework/hw1', _hw(status: 'closed'));
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      expect(find.text('This homework is closed'), findsOneWidget);
      expect(find.text('Save changes'), findsNothing);
      expect(tester.widget<TextField>(find.widgetWithText(TextField, 'Title')).enabled, isFalse);
    });

    testWidgets('load failure offers retry', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const HomeworkFormScreen(homeworkId: 'gone')));
      await openScreen(tester);
      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('TeacherHomeworkDetailScreen', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    Map<String, dynamic> roster({String status = 'published'}) => {
      'homework': _hw(status: status),
      'data': [
        {'studentId': 's1', 'name': 'Asha Rao', 'admissionNo': 'A1', 'rollNo': 1, 'status': 'submitted', 'submission': {'id': 'sub1', 'status': 'submitted', 'submittedAt': '2026-10-21T04:00:00.000Z', 'isLate': false}},
        {'studentId': 's2', 'name': 'Ben Roy', 'admissionNo': 'A2', 'rollNo': 2, 'status': 'missing', 'submission': null},
        {'studentId': 's3', 'name': 'Chitra Nair', 'admissionNo': 'A3', 'rollNo': 3, 'status': 'reviewed', 'submission': {'id': 'sub3', 'status': 'reviewed', 'submittedAt': '2026-10-21T05:00:00.000Z', 'isLate': false, 'marks': 17.5}},
      ],
    };

    testWidgets('shows stats, the roster and filters it', (tester) async {
      usePhone(tester);
      server.on('GET /homework/hw1/roster', roster());
      await tester.pumpWidget(teacherHarness(server, const TeacherHomeworkDetailScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      expect(find.text('Fractions practice'), findsOneWidget);
      expect(find.textContaining('of 24 handed in'), findsWidgets);
      expect(find.text('Asha Rao'), findsOneWidget);
      expect(find.text('To review'), findsWidgets);
      expect(find.text('Reviewed, 17.5/20'), findsOneWidget);

      await tester.tap(find.text('Missing 1'));
      await tester.pumpAndSettle();
      expect(find.text('Ben Roy'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
    });

    testWidgets('tapping a hand-in opens its review; a missing student does nothing', (tester) async {
      usePhone(tester);
      server.on('GET /homework/hw1/roster', roster());
      await tester.pumpWidget(teacherHarness(server, const TeacherHomeworkDetailScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      await tester.tap(find.text('Ben Roy'));
      await tester.pumpAndSettle();
      expect(find.text('REVIEW sub1'), findsNothing);
      await tester.tap(find.text('Asha Rao'));
      await tester.pumpAndSettle();
      expect(find.text('REVIEW sub1'), findsOneWidget);
    });

    testWidgets('closing needs confirmation, then calls the API', (tester) async {
      usePhone(tester);
      server.on('GET /homework/hw1/roster', roster());
      server.on('POST /homework/hw1/close', {'ok': true});
      await tester.pumpWidget(teacherHarness(server, const TeacherHomeworkDetailScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      await tester.tap(find.text('Close homework'));
      await tester.pumpAndSettle();
      expect(find.text('Close this homework?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Close homework'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'POST' && r.path == '/homework/hw1/close'), hasLength(1));
    });

    testWidgets('a draft offers Publish and no hand-in list', (tester) async {
      usePhone(tester);
      server.on('GET /homework/hw1/roster', roster(status: 'draft'));
      await tester.pumpWidget(teacherHarness(server, const TeacherHomeworkDetailScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      expect(find.widgetWithText(FilledButton, 'Publish'), findsOneWidget);
      expect(find.textContaining('Hand-ins appear here'), findsOneWidget);
      expect(find.text('Asha Rao'), findsNothing);
    });

    testWidgets('deleting a homework that has hand-ins is disabled in the menu', (tester) async {
      usePhone(tester);
      server.on('GET /homework/hw1/roster', roster());
      await tester.pumpWidget(teacherHarness(server, const TeacherHomeworkDetailScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Close it instead'), findsOneWidget);
    });

    testWidgets('server says it has submissions: the teacher is told to close instead', (tester) async {
      usePhone(tester);
      final noHandIns = roster(status: 'draft');
      ((noHandIns['homework'] as Map)['stats'] as Map<String, dynamic>).addAll({'submitted': 0, 'late': 0, 'reviewed': 0, 'returned': 0, 'missing': 24});
      server.on('GET /homework/hw1/roster', noHandIns);
      server.on('DELETE /homework/hw1', {'title': 'Has submissions', 'code': 'HOMEWORK_HAS_SUBMISSIONS', 'status': 409}, status: 409);
      await tester.pumpWidget(teacherHarness(server, const TeacherHomeworkDetailScreen(homeworkId: 'hw1')));
      await openScreen(tester);
      await tester.tap(find.byTooltip('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, 'Delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Close it instead'), findsOneWidget);
    });

    testWidgets('error with retry', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const TeacherHomeworkDetailScreen(homeworkId: 'nope')));
      await openScreen(tester);
      expect(find.byType(ErrorState), findsOneWidget);
    });
  });

  group('SubmissionReviewScreen', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    Map<String, dynamic> sub({String status = 'submitted', double? marks, String? feedback}) => {
      'id': 'sub1',
      'homeworkId': 'hw1',
      'studentId': 's1',
      'studentName': 'Asha Rao',
      'rollNo': 1,
      'text': 'Here are my answers',
      'attachments': <Object?>[],
      'submittedAt': '2026-10-21T04:00:00.000Z',
      'status': status,
      'isLate': false,
      'marks': marks,
      'feedback': feedback,
    };

    Map<String, dynamic> roster() => {
      'homework': _hw(status: 'published'),
      'data': [
        {'studentId': 's1', 'name': 'Asha Rao', 'admissionNo': 'A1', 'rollNo': 1, 'status': 'submitted', 'submission': {'id': 'sub1', 'status': 'submitted'}},
        {'studentId': 's2', 'name': 'Ben Roy', 'admissionNo': 'A2', 'rollNo': 2, 'status': 'late', 'submission': {'id': 'sub2', 'status': 'late'}},
      ],
    };

    testWidgets('marks above the maximum are refused before anything is sent', (tester) async {
      usePhone(tester);
      server.on('GET /submissions/sub1', sub());
      server.on('GET /homework/hw1/roster', roster());
      await tester.pumpWidget(teacherHarness(server, const SubmissionReviewScreen(homeworkId: 'hw1', submissionId: 'sub1')));
      await openScreen(tester);
      expect(find.text('Here are my answers'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Marks (out of 20)'), '25');
      await tester.pump();
      expect(find.text('Cannot be more than 20.'), findsOneWidget);
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('empty review is refused; a saved review posts marks and offers the next one', (tester) async {
      usePhone(tester);
      server.on('GET /submissions/sub1', sub());
      server.on('GET /homework/hw1/roster', roster());
      server.on('POST /submissions/sub1/review', sub(status: 'reviewed', marks: 17.5));
      await tester.pumpWidget(teacherHarness(server, const SubmissionReviewScreen(homeworkId: 'hw1', submissionId: 'sub1')));
      await openScreen(tester);
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(find.text('Give marks or write feedback before saving.'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Marks (out of 20)'), '17.5');
      await tester.tap(find.widgetWithText(TextField, 'Feedback for the student'));
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, 'Feedback for the student'), 'Well done');
      await tester.pump();
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      final post = server.requests.firstWhere((r) => r.method == 'POST');
      expect(post.body, {'marks': 17.5, 'feedback': 'Well done'});
      expect(find.text('Saved for Asha Rao'), findsOneWidget);
      expect(find.text('Next to review (1 left)'), findsOneWidget);
    });

    testWidgets('returning for rework needs feedback and a confirmation', (tester) async {
      usePhone(tester);
      server.on('GET /submissions/sub1', sub());
      server.on('GET /homework/hw1/roster', roster());
      server.on('POST /submissions/sub1/return', sub(status: 'returned'));
      await tester.pumpWidget(teacherHarness(server, const SubmissionReviewScreen(homeworkId: 'hw1', submissionId: 'sub1')));
      await openScreen(tester);
      await tester.tap(find.text('Return for rework'));
      await tester.pumpAndSettle();
      expect(find.text('Say what needs to be redone so the student knows.'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'Feedback for the student'), 'Redo question 3');
      await tester.tap(find.text('Return for rework'));
      await tester.pumpAndSettle();
      expect(find.text('Return for rework?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Return to student'));
      await tester.pumpAndSettle();
      expect(server.requests.firstWhere((r) => r.method == 'POST').body, {'feedback': 'Redo question 3'});
    });

    testWidgets('a returned submission is read-only and says it is waiting', (tester) async {
      usePhone(tester);
      server.on('GET /submissions/sub1', sub(status: 'returned', feedback: 'Redo Q3'));
      server.on('GET /homework/hw1/roster', roster());
      await tester.pumpWidget(teacherHarness(server, const SubmissionReviewScreen(homeworkId: 'hw1', submissionId: 'sub1')));
      await openScreen(tester);
      expect(find.text('Returned for rework'), findsWidgets);
      expect(find.textContaining('Waiting for Asha Rao'), findsOneWidget);
      expect(find.text('Save review'), findsNothing);
    });

    testWidgets('a homework without marks hides the marks field', (tester) async {
      usePhone(tester);
      final r = roster();
      (r['homework'] as Map<String, dynamic>)['maxMarks'] = null;
      server.on('GET /submissions/sub1', sub());
      server.on('GET /homework/hw1/roster', r);
      await tester.pumpWidget(teacherHarness(server, const SubmissionReviewScreen(homeworkId: 'hw1', submissionId: 'sub1')));
      await openScreen(tester);
      expect(find.widgetWithText(TextField, 'Marks (out of 20)'), findsNothing);
      expect(find.textContaining('carries no marks'), findsOneWidget);
    });

    testWidgets('a stale state error (already returned) is explained', (tester) async {
      usePhone(tester);
      server.on('GET /submissions/sub1', sub());
      server.on('GET /homework/hw1/roster', roster());
      server.on('POST /submissions/sub1/review', {'title': 'Waiting for the student', 'code': 'INVALID_STATE', 'status': 409}, status: 409);
      await tester.pumpWidget(teacherHarness(server, const SubmissionReviewScreen(homeworkId: 'hw1', submissionId: 'sub1')));
      await openScreen(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Feedback for the student'), 'ok');
      await tester.tap(find.text('Save review'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not possible in the current state'), findsOneWidget);
    });
  });

  group('TeacherHomeworkTab', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    Map<String, dynamic> page(List<Map<String, dynamic>> items) => {'data': items, 'meta': {'page': 1, 'pageSize': 20, 'total': items.length, 'totalPages': 1}};

    testWidgets('lists active homework with the hand-in meter and what needs review', (tester) async {
      usePhone(tester);
      server.on('GET /homework', page([_hw(status: 'published')]));
      await tester.pumpWidget(teacherHarness(server, const Scaffold(body: TeacherHomeworkTab())));
      await openScreen(tester);
      expect(find.text('Fractions practice'), findsOneWidget);
      expect(find.text('Grade 6 A  ·  English'), findsOneWidget);
      expect(find.text('10 of 24 handed in'), findsOneWidget);
      expect(find.text('6 to review'), findsOneWidget);
      expect(find.text('New homework'), findsOneWidget);
      expect(server.last.query['status'], 'published');
      expect(server.last.query['mine'], true);
    });

    testWidgets('empty state and switching to drafts', (tester) async {
      usePhone(tester);
      server.on('GET /homework', page(const []));
      await tester.pumpWidget(teacherHarness(server, const Scaffold(body: TeacherHomeworkTab())));
      await openScreen(tester);
      expect(find.text('No active homework'), findsOneWidget);
      await tester.tap(find.text('Drafts'));
      await tester.pumpAndSettle();
      expect(find.text('No drafts'), findsOneWidget);
      expect(server.last.query['status'], 'draft');
    });

    testWidgets('error with retry', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const Scaffold(body: TeacherHomeworkTab())));
      await openScreen(tester);
      expect(find.byType(ErrorState), findsOneWidget);
    });

    testWidgets('fine at 200 percent text', (tester) async {
      usePhone(tester);
      server.on('GET /homework', page([_hw(status: 'published')]));
      await tester.pumpWidget(teacherHarness(server, const Scaffold(body: TeacherHomeworkTab()), textScale: 2));
      await openScreen(tester);
      expect(tester.takeException(), isNull);
    });

    test('model sanity: stats helpers', () {
      expect(HomeworkEntry.fromJson(_hw()).stats!.toReview, 6);
      expect(jsonList([_hw()]), hasLength(1));
    });
  });
}
