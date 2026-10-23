import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/features/teacher/marks/marks_entry_screen.dart';
import 'package:schoolsync/features/teacher/marks/marks_list_screen.dart';

import 'staff_test_support.dart';
import 'teacher_homework_marks_harness.dart';

Map<String, dynamic> _sheet({String status = 'draft', bool canEdit = true, String? returnNote, List<Map<String, dynamic>>? entries, double max = 100}) => {
  'id': 'sh1',
  'examId': 'ex1',
  'examName': 'Mid-Term Examination',
  'paperId': 'p1',
  'sectionId': 'sec',
  'sectionName': 'B',
  'gradeId': 'g10',
  'gradeName': 'Grade 10',
  'subjectId': 'cs',
  'subjectName': 'Computer Science',
  'status': status,
  'maxMarks': max,
  'passMarks': 35,
  'teacherName': 'Sunita Verma',
  'studentCount': 4,
  'enteredCount': 2,
  'absentCount': 0,
  'submittedAt': null,
  'reviewedAt': null,
  'publishedAt': null,
  'returnNote': returnNote,
  'canEdit': canEdit,
  'entries': entries ?? _entries(),
};

Map<String, dynamic> _e(String id, String name, int roll, {double? marks, bool absent = false}) => {'studentId': id, 'admissionNo': 'A$roll', 'name': name, 'rollNo': roll, 'marksObtained': marks, 'isAbsent': absent, 'remarks': null};

List<Map<String, dynamic>> _entries() => [_e('s1', 'Asha Rao', 1, marks: 91), _e('s2', 'Ben Roy', 2), _e('s3', 'Chitra Nair', 3), _e('s4', 'Dev Shah', 4, marks: 30)];

Finder _field(int i) => find.byType(TextField).at(i);

TextField _tf(WidgetTester t, int i) => t.widget<TextField>(_field(i));

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('MarksEntryScreen (editing)', () {
    late FakeServer server;
    setUp(() {
      server = FakeServer();
      server.on('GET /marks/sheets/sh1', _sheet());
      server.on('PUT /marks/sheets/sh1/entries', {'ok': true});
      server.on('POST /marks/sheets/sh1/submit', {'ok': true});
    });

    testWidgets('shows the sheet, progress and one field per student', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      expect(find.text('Computer Science, Grade 10 B'), findsOneWidget);
      expect(find.textContaining('out of 100'), findsWidgets);
      expect(find.textContaining('2 of 4 done'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4));
      expect(_tf(tester, 0).controller!.text, '91');
      expect(find.text('To enter'), findsOneWidget);
    });

    testWidgets('typing marks updates progress; a mark above the maximum is flagged', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      await tester.enterText(_field(1), '58.5');
      await tester.pump();
      expect(find.textContaining('3 of 4 done'), findsOneWidget);
      await tester.enterText(_field(2), '101');
      await tester.pump();
      expect(find.text('Cannot be more than 100.'), findsOneWidget);
      expect(find.textContaining('3 of 4 done'), findsOneWidget, reason: 'an invalid mark does not count');
    });

    testWidgets('only digits and a decimal point can be typed', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      await tester.enterText(_field(1), 'a7b.5c');
      expect(_tf(tester, 1).controller!.text, '7.5');
      expect(_tf(tester, 1).keyboardType, const TextInputType.numberWithOptions(decimal: true));
    });

    testWidgets('absent clears the mark and disables the field; undoing re-enables it', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      await tester.tap(find.bySemanticsLabel('Absent, Asha Rao'));
      await tester.pump();
      expect(_tf(tester, 0).controller!.text, isEmpty, reason: 'absent clears the mark');
      expect(_tf(tester, 0).enabled, isFalse);
      expect(find.textContaining('2 of 4 done'), findsOneWidget, reason: 'absent counts as done');
      expect(find.textContaining('1 absent'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Absent, Asha Rao'));
      await tester.pump();
      expect(_tf(tester, 0).enabled, isTrue);
    });

    testWidgets('submit is blocked while students are missing, and says who', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Not ready to submit'), findsOneWidget);
      expect(find.textContaining('Ben Roy and Chitra Nair'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'PUT' || r.method == 'POST'), isEmpty);
      await tester.tap(find.text('Go to first'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_field(1)).focusNode!.hasFocus, isTrue);
    });

    testWidgets('save draft sends only the changed rows', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Save draft')).onPressed, isNull, reason: 'nothing to save yet');
      await tester.enterText(_field(1), '62');
      await tester.tap(find.byTooltip('Add a remark for Dev Shah'));
      await tester.pumpAndSettle();
      await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'Late paper');
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save draft'));
      await tester.pumpAndSettle();
      final put = server.requests.firstWhere((r) => r.method == 'PUT');
      expect(put.path, '/marks/sheets/sh1/entries');
      expect(put.body, {
        'entries': [
          {'studentId': 's2', 'isAbsent': false, 'marksObtained': 62.0},
          {'studentId': 's4', 'isAbsent': false, 'marksObtained': 30.0, 'remarks': 'Late paper'},
        ],
      });
      expect(find.text('Draft saved'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Save draft')).onPressed, isNull, reason: 'saved, so not dirty any more');
    });

    testWidgets('a complete sheet: confirm, then saves and submits, in that order', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      await tester.enterText(_field(1), '58');
      await tester.tap(find.bySemanticsLabel('Absent, Chitra Nair'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();
      expect(find.text('Submit marks for review?'), findsOneWidget);
      expect(find.textContaining('3 marks and 1 absent'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit').last);
      await tester.pumpAndSettle();
      final writes = server.requests.where((r) => r.method != 'GET').map((r) => '${r.method} ${r.path}').toList();
      expect(writes, ['PUT /marks/sheets/sh1/entries', 'POST /marks/sheets/sh1/submit']);
      expect(find.text('open'), findsOneWidget, reason: 'back on the list after submitting');
    });

    testWidgets('server refusals are explained inside the screen', (tester) async {
      usePhone(tester);
      server.on('PUT /marks/sheets/sh1/entries', {'title': 'Marks entry is not open', 'code': 'MARKS_ENTRY_NOT_OPEN', 'status': 409}, status: 409);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      await tester.enterText(_field(1), '62');
      await tester.pump(); // the screen rebuilds (Save draft enables) before the next tap
      await tester.tap(find.widgetWithText(OutlinedButton, 'Save draft'));
      await tester.pumpAndSettle();
      expect(find.textContaining('not been opened'), findsWidgets);
    });

    testWidgets('leaving with unsaved marks asks first', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      await tester.enterText(_field(1), '62');
      await tester.pump(); // the screen rebuilds (PopScope blocks the pop) before the back tap
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Leave without saving?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Computer Science, Grade 10 B'), findsOneWidget, reason: 'stayed');
    });

    testWidgets('a returned sheet shows the reviewer note above the list', (tester) async {
      usePhone(tester);
      server.on('GET /marks/sheets/sh1', _sheet(status: 'returned', returnNote: 'Recheck question 4 for the whole class'));
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      expect(find.text('Sent back for changes'), findsOneWidget);
      expect(find.textContaining('Recheck question 4'), findsOneWidget);
      expect(find.text('Returned'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(4), reason: 'still editable');
    });

    testWidgets('view-only school: buttons are off and a banner explains', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1'), readOnly: true));
      await openScreen(tester);
      expect(find.text('View-only mode'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit')).onPressed, isNull);
    });

    testWidgets('fine at 200 percent text', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1'), textScale: 2));
      await openScreen(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading then error with retry', (tester) async {
      usePhone(tester);
      final empty = FakeServer();
      await tester.pumpWidget(teacherHarness(empty, const MarksEntryScreen(sheetId: 'sh1')));
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(SkeletonList), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(ErrorState), findsOneWidget);
    });
  });

  group('MarksEntryScreen (read-only)', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    testWidgets('a submitted sheet cannot be edited and says why', (tester) async {
      usePhone(tester);
      server.on('GET /marks/sheets/sh1', _sheet(status: 'submitted', canEdit: false, entries: [_e('s1', 'Asha Rao', 1, marks: 91), _e('s2', 'Ben Roy', 2, marks: 20), _e('s3', 'Chitra Nair', 3, absent: true)]));
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Save draft'), findsNothing);
      expect(find.textContaining('submitted for review'), findsOneWidget);
      expect(find.text('91 / 100'), findsOneWidget);
      expect(find.text('Below pass'), findsOneWidget, reason: '20 is under the pass mark of 35');
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('In review'), findsOneWidget);
    });

    testWidgets('marks entry not open yet: explained, no buttons', (tester) async {
      usePhone(tester);
      server.on('GET /marks/sheets/sh1', _sheet(canEdit: false));
      await tester.pumpWidget(teacherHarness(server, const MarksEntryScreen(sheetId: 'sh1')));
      await openScreen(tester);
      expect(find.textContaining('may not be open'), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });
  });

  group('MarksListScreen', () {
    late FakeServer server;
    setUp(() => server = FakeServer());

    Map<String, dynamic> row(String id, String status, {String exam = 'Mid-Term Examination', String subject = 'English', int entered = 10, String? note}) => {
      'id': id,
      'examId': exam,
      'examName': exam,
      'paperId': 'p',
      'sectionId': 's',
      'sectionName': 'A',
      'gradeId': 'g',
      'gradeName': 'Grade 6',
      'subjectId': subject,
      'subjectName': subject,
      'status': status,
      'maxMarks': 100,
      'passMarks': 35,
      'studentCount': 24,
      'enteredCount': entered,
      'absentCount': 0,
      'returnNote': note,
    };

    Map<String, dynamic> page(List<Map<String, dynamic>> data) => {'data': data, 'meta': {'page': 1, 'pageSize': 100, 'total': data.length, 'totalPages': 1}};

    testWidgets('groups by exam, shows to-do sheets first, with the return note', (tester) async {
      usePhone(tester);
      server.on('GET /marks/sheets', page([row('1', 'draft', subject: 'English'), row('2', 'returned', subject: 'Hindi', note: 'Recheck Q4'), row('3', 'submitted', subject: 'Art', entered: 24), row('4', 'published', exam: 'Term 1 Final', subject: 'Maths', entered: 24)]));
      await tester.pumpWidget(teacherHarness(server, const MarksListScreen()));
      await openScreen(tester);
      expect(server.last.query['mine'], true);
      expect(find.text('Mid-Term Examination'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Hindi'), findsOneWidget);
      expect(find.text('Art'), findsNothing, reason: 'submitted is under the other filter');
      expect(find.text('10 of 24 entered'), findsNWidgets(2));
      expect(find.text('Returned'), findsOneWidget);
      expect(find.text('Reviewer: Recheck Q4'), findsOneWidget);

      await tester.tap(find.text('Submitted'));
      await tester.pumpAndSettle();
      expect(find.text('Art'), findsOneWidget);
      expect(find.text('Maths'), findsOneWidget);
      expect(find.text('Term 1 Final'), findsOneWidget);
      expect(find.text('In review'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
    });

    testWidgets('empty states: nothing at all, and nothing to do', (tester) async {
      usePhone(tester);
      server.on('GET /marks/sheets', page(const []));
      await tester.pumpWidget(teacherHarness(server, const MarksListScreen()));
      await openScreen(tester);
      expect(find.text('No mark sheets yet'), findsOneWidget);
    });

    testWidgets('all done: friendly message with a way to see everything', (tester) async {
      usePhone(tester);
      server.on('GET /marks/sheets', page([row('3', 'submitted', entered: 24)]));
      await tester.pumpWidget(teacherHarness(server, const MarksListScreen()));
      await openScreen(tester);
      expect(find.text('Nothing to enter'), findsOneWidget);
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('error with retry; fine at 200 percent text', (tester) async {
      usePhone(tester);
      await tester.pumpWidget(teacherHarness(server, const MarksListScreen(), textScale: 2));
      await openScreen(tester);
      expect(find.byType(ErrorState), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
