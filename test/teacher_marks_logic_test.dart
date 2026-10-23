import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/data/models/staff/marks.dart';
import 'package:schoolsync/features/teacher/marks/marks_logic.dart';

import 'staff_test_support.dart';

MarkRowData _r(String id, {String text = '', bool absent = false, String remarks = ''}) => MarkRowData(studentId: id, name: 'Student $id', text: text, absent: absent, remarks: remarks);

void main() {
  group('formatting and parsing', () {
    test('fmtMark drops needless decimals', () {
      expect(fmtMark(55), '55');
      expect(fmtMark(55.5), '55.5');
      expect(fmtMark(55.25), '55.25');
      expect(fmtMark(55.0), '55');
      expect(fmtMark(0), '0');
    });

    test('parseMarkText accepts digits with up to two decimals only', () {
      expect(parseMarkText('12'), 12);
      expect(parseMarkText(' 12.5 '), 12.5);
      expect(parseMarkText('12.'), 12);
      expect(parseMarkText('0'), 0);
      expect(parseMarkText(''), isNull);
      expect(parseMarkText('abc'), isNull);
      expect(parseMarkText('12.345'), isNull);
      expect(parseMarkText('-1'), isNull);
      expect(parseMarkText('1e3'), isNull);
    });
  });

  group('markError', () {
    test('empty is fine (not entered yet)', () => expect(markError('', 100), isNull));
    test('within 0..max is fine, including the maximum itself', () {
      expect(markError('0', 100), isNull);
      expect(markError('100', 100), isNull);
      expect(markError('99.99', 100), isNull);
    });
    test('above the maximum says by how much the limit is', () => expect(markError('101', 100), 'Cannot be more than 100.'));
    test('fractional maximum is shown naturally', () => expect(markError('21', 20.5), 'Cannot be more than 20.5.'));
    test('not a number', () {
      expect(markError('12.345', 100), contains('up to 2 decimals'));
      expect(markError('x', 100), contains('Numbers only'));
    });
  });

  group('markProgress', () {
    test('counts entered, absent and missing', () {
      final p = markProgress([_r('1', text: '50'), _r('2', absent: true), _r('3'), _r('4', text: '  '), _r('5', text: '0')], 100);
      expect(p.total, 5);
      expect(p.entered, 2, reason: 'zero is a valid mark');
      expect(p.absent, 1);
      expect(p.done, 3);
      expect(p.missing.map((e) => e.studentId), ['3', '4']);
      expect(p.complete, isFalse);
      expect(p.fraction, closeTo(0.6, 1e-9));
    });

    test('an absent student with leftover text is still counted absent', () {
      final p = markProgress([_r('1', text: '50', absent: true)], 100);
      expect(p.absent, 1);
      expect(p.entered, 0);
      expect(p.complete, isTrue);
    });

    test('marks above the maximum block completion', () {
      final p = markProgress([_r('1', text: '101'), _r('2', text: '5')], 100);
      expect(p.invalid.map((e) => e.studentId), ['1']);
      expect(p.complete, isFalse);
      expect(p.entered, 1);
    });

    test('everything entered or absent is complete', () => expect(markProgress([_r('1', text: '40'), _r('2', absent: true)], 100).complete, isTrue));
    test('empty sheet has zero fraction and is complete', () {
      final p = markProgress(const [], 100);
      expect(p.fraction, 0);
      expect(p.complete, isTrue);
    });
  });

  group('changedMarkInputs (what a draft save sends)', () {
    final baseline = {
      '1': _r('1', text: '55'),
      '2': _r('2', absent: true),
      '3': _r('3'),
    };

    test('unchanged rows are not sent; "55" equals "55.0"', () {
      expect(changedMarkInputs([_r('1', text: '55.0'), _r('2', absent: true), _r('3')], baseline, 100), isEmpty);
    });

    test('a changed mark, a new mark and a flipped absent flag are sent', () {
      final out = changedMarkInputs([_r('1', text: '60'), _r('2', text: '30'), _r('3', absent: true)], baseline, 100);
      expect(out.map((e) => e.toJson()), [
        {'studentId': '1', 'isAbsent': false, 'marksObtained': 60.0},
        {'studentId': '2', 'isAbsent': false, 'marksObtained': 30.0},
        {'studentId': '3', 'isAbsent': true, 'marksObtained': null},
      ]);
    });

    test('clearing a saved mark sends null (so it can be re-entered)', () {
      final out = changedMarkInputs([_r('1')], baseline, 100);
      expect(out.single.toJson(), {'studentId': '1', 'isAbsent': false, 'marksObtained': null});
    });

    test('invalid marks are never sent', () => expect(changedMarkInputs([_r('3', text: '500')], baseline, 100), isEmpty));

    test('a remark change alone is sent; blank remarks are not serialised', () {
      final out = changedMarkInputs([_r('1', text: '55', remarks: ' late paper ')], baseline, 100);
      expect(out.single.toJson()['remarks'], 'late paper');
      expect(changedMarkInputs([_r('1', text: '55', remarks: '  ')], baseline, 100), isEmpty);
    });

    test('a student missing from the baseline is treated as new', () {
      expect(changedMarkInputs([_r('9', text: '10')], baseline, 100), hasLength(1));
    });
  });

  group('wording', () {
    test('namesSummary', () {
      expect(namesSummary(['Asha']), 'Asha');
      expect(namesSummary(['Asha', 'Ben']), 'Asha and Ben');
      expect(namesSummary(['A', 'B', 'C']), 'A, B and C');
      expect(namesSummary([for (var i = 1; i <= 9; i++) 'S$i']), 'S1, S2, S3, S4, S5, S6 and 3 more');
    });

    test('read-only reasons by sheet state', () {
      MarkSheet sheet(String status) => MarkSheet.fromJson({'id': 'x', 'status': status, 'maxMarks': 100});
      expect(marksReadOnlyReason(sheet('draft'), canEdit: true), isNull);
      expect(marksReadOnlyReason(sheet('submitted'), canEdit: false), contains('submitted for review'));
      expect(marksReadOnlyReason(sheet('approved'), canEdit: false), contains('approved'));
      expect(marksReadOnlyReason(sheet('published'), canEdit: false), contains('published'));
      expect(marksReadOnlyReason(sheet('draft'), canEdit: false), contains('not be open'));
    });
  });

  test('row data from a real sheet entry', () {
    final d = MarkSheetDetail.fromJson(fixture('sheet_detail'));
    final rows = [for (final e in d.entries) MarkRowData.fromEntry(e)];
    expect(rows.first.text, isNotEmpty);
    final p = markProgress(rows, d.sheet.maxMarks);
    expect(p.entered, rows.length);
    expect(changedMarkInputs(rows, {for (final r in rows) r.studentId: r}, d.sheet.maxMarks), isEmpty);
  });
}
