import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/network/app_exception.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/staff/people.dart';
import 'package:schoolsync/data/models/staff/teaching.dart';
import 'package:schoolsync/features/teacher/homework/homework_form_logic.dart';
import 'package:schoolsync/features/teacher/homework/homework_tab.dart' show homeworkDueText;
import 'package:schoolsync/features/teacher/homework/review_logic.dart';

import 'staff_test_support.dart';

final _now = DateTime(2026, 10, 21, 10);
final _tomorrow = DateTime(2026, 10, 22, 17);

HomeworkFormInput _ok({String title = 'Fractions', DateTime? due, bool allow = true, String marks = '20', String desc = ''}) =>
    HomeworkFormInput(sectionId: 'sec', subjectId: 'sub', title: title, description: desc, dueAt: due ?? _tomorrow, allowSubmission: allow, maxMarksText: marks);

MyAssignment _a(String sec, String subj, {String grade = 'Grade 6', String name = 'A', String subjName = 'English'}) =>
    MyAssignment(sectionId: sec, sectionName: name, gradeId: 'g$sec', gradeName: grade, subjectId: subj, subjectName: subjName);

void main() {
  group('validateHomeworkForm', () {
    test('a complete form is valid', () {
      expect(validateHomeworkForm(_ok(), creating: true, requireFutureDue: true, now: _now).any, isFalse);
    });

    test('class and subject are required when creating, not when editing', () {
      const empty = HomeworkFormInput(title: 'x', dueAt: null);
      final create = validateHomeworkForm(empty, creating: true, requireFutureDue: true, now: _now);
      expect(create.section, isNotNull);
      expect(create.subject, isNotNull);
      final edit = validateHomeworkForm(HomeworkFormInput(title: 'x', dueAt: _tomorrow), creating: false, requireFutureDue: false, now: _now);
      expect(edit.section, isNull);
      expect(edit.subject, isNull);
    });

    test('title is required and limited to 200 characters', () {
      expect(validateHomeworkForm(_ok(title: '   '), creating: true, requireFutureDue: true, now: _now).title, isNotNull);
      expect(validateHomeworkForm(_ok(title: 'a' * 200), creating: true, requireFutureDue: true, now: _now).title, isNull);
      expect(validateHomeworkForm(_ok(title: 'a' * 201), creating: true, requireFutureDue: true, now: _now).title, contains('200'));
    });

    test('description is limited to 5000 characters', () {
      expect(validateHomeworkForm(_ok(desc: 'a' * 5001), creating: true, requireFutureDue: true, now: _now).description, isNotNull);
    });

    test('due date: must be in the future when required, a past date is fine for an unchanged edit', () {
      final past = DateTime(2026, 10, 20, 9);
      expect(validateHomeworkForm(_ok(due: past), creating: true, requireFutureDue: true, now: _now).due, contains('future'));
      expect(validateHomeworkForm(_ok(due: past), creating: false, requireFutureDue: false, now: _now).due, isNull);
      expect(validateHomeworkForm(_ok(due: _now), creating: true, requireFutureDue: true, now: _now).due, isNotNull, reason: 'exactly now is not in the future');
      expect(validateHomeworkForm(const HomeworkFormInput(sectionId: 's', subjectId: 'x', title: 't'), creating: true, requireFutureDue: true, now: _now).due, isNotNull);
    });

    test('max marks must be a whole number from 1 to 1000, or empty', () {
      for (final bad in ['0', '1001', '12.5', 'abc', '-3']) {
        expect(validateHomeworkForm(_ok(marks: bad), creating: true, requireFutureDue: true, now: _now).maxMarks, isNotNull, reason: bad);
      }
      for (final good in ['', ' ', '1', '20', '1000']) {
        expect(validateHomeworkForm(_ok(marks: good), creating: true, requireFutureDue: true, now: _now).maxMarks, isNull, reason: '"$good"');
      }
    });

    test('marks are ignored (not validated, not sent) when online submissions are off', () {
      final v = _ok(allow: false, marks: 'abc');
      expect(validateHomeworkForm(v, creating: true, requireFutureDue: true, now: _now).maxMarks, isNull);
      final draft = buildHomeworkDraft(v, const []);
      expect(draft.toCreateJson(publish: false)['maxMarks'], isNull);
      expect(draft.toCreateJson(publish: false)['allowSubmission'], isFalse);
    });
  });

  group('buildHomeworkDraft', () {
    test('trims text, parses marks, keeps attachments, sends UTC', () {
      final due = DateTime.utc(2026, 11, 2, 10, 30).toLocal();
      final draft = buildHomeworkDraft(HomeworkFormInput(sectionId: 'sec', subjectId: 'sub', title: '  Fractions  ', description: ' Do Q1-5 ', dueAt: due, maxMarksText: ' 20 '), const [Attachment(fileId: 'f1', name: 'sheet.pdf')]);
      final j = draft.toCreateJson(publish: true);
      expect(j['title'], 'Fractions');
      expect(j['description'], 'Do Q1-5');
      expect(j['maxMarks'], 20);
      expect(j['dueAt'], '2026-11-02T10:30:00.000Z');
      expect(j['publish'], isTrue);
      expect(j['attachments'], [{'fileId': 'f1', 'name': 'sheet.pdf'}]);
    });
  });

  group('server field errors', () {
    test('map onto the form fields', () {
      final e = mapServerFieldErrors(const [FieldError(path: 'title', message: 'Too long'), FieldError(path: 'dueAt', message: 'Must be in the future'), FieldError(path: 'attachments.0.fileId', message: 'bad')]);
      expect(e.title, 'Too long');
      expect(e.due, 'Must be in the future');
      expect(e.maxMarks, isNull);
      expect(e.any, isTrue);
    });
  });

  group('pickers limited to what I teach', () {
    final mine = [_a('s1', 'eng'), _a('s1', 'hin', subjName: 'Hindi'), _a('s2', 'eng', name: 'B'), _a('s1', 'eng')];

    test('distinct sections keep order', () => expect(distinctSections(mine).map((e) => e.sectionId), ['s1', 's2']));

    test('subjects are the ones taught in the chosen class only', () {
      expect(subjectsFor(mine, 's1').map((e) => e.subjectId), ['eng', 'hin']);
      expect(subjectsFor(mine, 's2').map((e) => e.subjectId), ['eng']);
      expect(subjectsFor(mine, null), isEmpty);
      expect(subjectsFor(mine, 'other'), isEmpty);
    });

    test('real assignments of the demo teacher parse and group', () {
      final real = Paged.parse(fixture('assignments'), MyAssignment.fromJson).items;
      expect(distinctSections(real), isNotEmpty);
      for (final s in distinctSections(real)) {
        expect(subjectsFor(real, s.sectionId), isNotEmpty);
      }
    });
  });

  test('default due is tomorrow at 5 pm', () {
    final d = defaultDueAt(DateTime(2026, 10, 31, 23, 59));
    expect(d, DateTime(2026, 11, 1, 17));
  });

  test('form input equality ignores surrounding whitespace (unsaved-changes guard)', () {
    expect(_ok(title: 'Hi '), _ok(title: ' Hi'));
    expect(_ok(title: 'Hi') == _ok(title: 'Ho'), isFalse);
    expect(_ok(marks: '5') == _ok(marks: '6'), isFalse);
  });

  group('review', () {
    test('marks are checked against the homework maximum', () {
      expect(validateReview(marksText: '12', feedback: '', maxMarks: 10).marks, contains('10'));
      expect(validateReview(marksText: '9.5', feedback: '', maxMarks: 10).marks, isNull);
      expect(validateReview(marksText: '10', feedback: '', maxMarks: 10).general, isNull);
      expect(validateReview(marksText: '1.234', feedback: '', maxMarks: 10).marks, isNotNull);
    });

    test('marks on a homework without marks are refused with an explanation', () {
      expect(validateReview(marksText: '5', feedback: 'ok', maxMarks: null).marks, contains('no marks'));
    });

    test('needs marks or feedback to save; feedback to return', () {
      expect(validateReview(marksText: '', feedback: '  ', maxMarks: 10).general, isNotNull);
      expect(validateReview(marksText: '', feedback: 'Nice', maxMarks: 10).general, isNull);
      expect(validateReview(marksText: '', feedback: '', maxMarks: 10, requireFeedback: true).feedback, isNotNull);
      expect(validateReview(marksText: '', feedback: 'Redo Q3', maxMarks: 10, requireFeedback: true).feedback, isNull);
      expect(validateReview(marksText: '', feedback: 'a' * 2001, maxMarks: 10).feedback, isNotNull);
    });

    test('next to review: other submitted or late hand-ins only', () {
      HomeworkRosterRow row(String id, String status) => HomeworkRosterRow(studentId: 's$id', name: 'N$id', admissionNo: 'A$id', status: status, submission: status == 'missing' ? null : SubmissionBriefRow(id: id, status: status));
      final roster = HomeworkRoster(
        homework: HomeworkEntry.fromJson(const {'id': 'h', 'status': 'published'}),
        rows: [row('1', 'submitted'), row('2', 'late'), row('3', 'reviewed'), row('4', 'missing'), row('5', 'returned'), row('6', 'submitted')],
      );
      expect(nextToReview(roster, '1').map((r) => r.submission!.id), ['2', '6']);
      expect(nextToReview(roster, '9').map((r) => r.submission!.id), ['1', '2', '6']);
    });
  });

  test('due text: future due dates use the countdown, past ones say so', () {
    expect(homeworkDueText(DateTime(2026, 10, 24, 17), now: _now), 'Due in 3 days');
    expect(homeworkDueText(DateTime(2026, 10, 20, 17), now: _now), startsWith('Due date passed'));
  });

  test('roster filter counts on a real roster', () {
    final r = HomeworkRoster.fromJson(fixture('homework_roster'));
    expect(r.rows.where((x) => x.status == 'missing').length, greaterThan(0));
  });
}
