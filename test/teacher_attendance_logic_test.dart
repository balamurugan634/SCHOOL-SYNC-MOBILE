import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/network/app_exception.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/attendance.dart';
import 'package:schoolsync/data/models/staff/roll_call.dart';
import 'package:schoolsync/data/repositories/staff/roll_call_repository.dart';
import 'package:schoolsync/features/teacher/attendance/attendance_providers.dart';
import 'package:schoolsync/features/teacher/attendance/roll_call_draft.dart';
import 'package:schoolsync/features/teacher/attendance/roll_call_widgets.dart';

import 'staff_test_support.dart';

/// A small synthetic roster: s1 unmarked, s2 unmarked, s3 on approved leave (pre-filled), s4 saved absent with a remark.
Json rosterJson({bool canSubmit = true, String? blocked, bool canCorrect = false, bool submitted = false, List<Json>? students}) => {
  'sectionId': 'sec', 'sectionName': 'A', 'gradeName': 'Grade 6', 'date': '2026-10-21', 'mode': 'daily', 'periodId': null, 'periodName': null,
  'subjectId': null, 'subjectName': null, 'isWorkingDay': true, 'holiday': null, 'isFuture': false,
  'session': submitted ? {'id': 'x', 'status': 'submitted', 'takenByName': 'Sunita Verma', 'submittedAt': '2026-10-21T03:50:00.000Z', 'editableUntil': '2026-10-22T03:50:00.000Z'} : null,
  'canSubmit': canSubmit, 'blockedReason': blocked, 'canRequestCorrection': canCorrect, 'warnings': <String>[],
  'counts': {'present': 0, 'absent': 1, 'late': 0, 'leave': 1, 'half_day': 0, 'unmarked': 2},
  'students': students ?? [
    student('s1', 'Asha Rao', 1),
    student('s2', 'Bilal Khan', 2),
    student('s3', 'Chitra Nair', 3, onLeave: true, status: 'leave'),
    student('s4', 'Dev Patel', 4, status: 'absent', remarks: 'Fever', recordId: 'rec4'),
  ],
};

Json student(String id, String name, int roll, {String? status, bool onLeave = false, String? remarks, String? recordId}) => {
  'studentId': id, 'name': name, 'admissionNo': 'GV$roll', 'rollNo': roll, 'recordId': recordId, 'status': status, 'remarks': remarks, 'source': onLeave ? 'leave' : (status == null ? null : 'marked'), 'onApprovedLeave': onLeave, 'markedAt': null,
};

RollCallDraft draftOf([Json? j]) => RollCallDraft.fromRoster(Roster.fromJson(j ?? rosterJson()));

void main() {
  group('RollCallDraft', () {
    test('starts from what the server saved; approved leave is pre-filled and locked', () {
      final d = draftOf();
      expect(d.total, 4);
      expect(d.statusOf('s1'), isNull);
      expect(d.statusOf('s3'), AttendanceStatus.leave);
      expect(d.statusOf('s4'), AttendanceStatus.absent);
      expect(d.remarkOf('s4'), 'Fever');
      expect(d.markedCount, 2);
      expect(d.unmarkedCount, 2);
      expect(d.isComplete, isFalse);
      expect(d.isDirty, isFalse, reason: 'nothing changed yet');
    });

    test('a leave student without a saved mark is pre-filled but not dirty', () {
      final j = rosterJson(students: [student('a', 'A', 1, onLeave: true)]);
      final d = draftOf(j);
      expect(d.statusOf('a'), AttendanceStatus.leave);
      expect(d.isDirty, isFalse);
    });

    test('setStatus changes one student and marks the draft dirty; locked students cannot change', () {
      final d = draftOf().setStatus('s1', AttendanceStatus.late);
      expect(d.statusOf('s1'), AttendanceStatus.late);
      expect(d.statusOf('s2'), isNull);
      expect(d.isDirty, isTrue);
      final locked = d.setStatus('s3', AttendanceStatus.present);
      expect(locked.statusOf('s3'), AttendanceStatus.leave);
      expect(d.setStatus('nobody', AttendanceStatus.present).markedCount, d.markedCount);
    });

    test('setting a status back to what the server had is not dirty', () {
      final d = draftOf().setStatus('s4', AttendanceStatus.present).setStatus('s4', AttendanceStatus.absent);
      expect(d.isDirty, isFalse);
    });

    test('mark all present: everyone who can change, not the leave student; onlyUnmarked keeps choices', () {
      final all = draftOf().markAllPresent();
      expect(all.statusOf('s1'), AttendanceStatus.present);
      expect(all.statusOf('s2'), AttendanceStatus.present);
      expect(all.statusOf('s4'), AttendanceStatus.present);
      expect(all.statusOf('s3'), AttendanceStatus.leave);
      expect(all.isComplete, isTrue);
      final onlyNew = draftOf().markAllPresent(onlyUnmarked: true);
      expect(onlyNew.statusOf('s4'), AttendanceStatus.absent);
      expect(onlyNew.statusOf('s1'), AttendanceStatus.present);
    });

    test('hasChosenStatuses asks for confirmation only when something other than present is set', () {
      expect(draftOf().hasChosenStatuses, isTrue, reason: 's4 is absent');
      final fresh = draftOf(rosterJson(students: [student('a', 'A', 1), student('b', 'B', 2, status: 'present')]));
      expect(fresh.hasChosenStatuses, isFalse);
      expect(draftOf(rosterJson(students: [student('a', 'A', 1, onLeave: true, status: 'leave')])).hasChosenStatuses, isFalse, reason: 'locked students do not count');
    });

    test('progress and counts follow the choices', () {
      var d = draftOf();
      expect(d.progress, 0.5);
      d = d.setStatus('s1', AttendanceStatus.present).setStatus('s2', AttendanceStatus.halfDay);
      expect(d.progress, 1.0);
      final c = d.counts;
      expect((c.present, c.absent, c.late, c.leave, c.halfDay, c.unmarked), (1, 1, 0, 1, 1, 0));
      expect(d.withStatus(AttendanceStatus.halfDay).map((s) => s.name), ['Bilal Khan']);
    });

    test('entries need a complete roll call and list every student in roll order with the wire status', () {
      expect(() => draftOf().entries, throwsStateError);
      final d = draftOf().setStatus('s1', AttendanceStatus.present).setStatus('s2', AttendanceStatus.halfDay).setRemark('s2', ' left at noon ');
      final e = d.entries;
      expect(e.map((x) => x.studentId), ['s1', 's2', 's3', 's4']);
      expect(e.map((x) => x.toJson()['status']), ['present', 'half_day', 'leave', 'absent']);
      expect(e[1].toJson()['remarks'], 'left at noon');
      expect(e[3].toJson()['remarks'], 'Fever');
      expect(e[0].toJson().containsKey('remarks'), isFalse);
    });

    test('remarks: set, change, clear; a changed remark alone makes the draft dirty', () {
      var d = draftOf().setRemark('s4', 'Fever and cough');
      expect(d.isDirty, isTrue);
      d = d.setRemark('s4', 'Fever');
      expect(d.isDirty, isFalse);
      d = d.setRemark('s4', '  ');
      expect(d.remarkOf('s4'), isNull);
      expect(d.isDirty, isTrue);
    });

    test('an empty section is never complete', () {
      final d = draftOf(rosterJson(students: []));
      expect(d.total, 0);
      expect(d.isComplete, isFalse);
      expect(d.progress, 0);
    });

    test('works on a real roster payload', () {
      final d = RollCallDraft.fromRoster(Roster.fromJson(fixture('roster')));
      expect(d.total, greaterThan(0));
      expect(d.isComplete, isTrue, reason: 'the demo roll call is fully marked');
      expect(d.entries, hasLength(d.total));
    });
  });

  group('reason copy', () {
    test('every blocked reason the roster can return has plain-language text', () {
      for (final code in ['EDIT_WINDOW_CLOSED', 'NOT_A_WORKING_DAY', 'HOLIDAY', 'FUTURE_DATE', 'NOT_CLASS_TEACHER', 'NOT_YOUR_PERIOD', 'NOT_ALLOWED_TO_MARK', 'PERIOD_REQUIRED', 'PRE_MARKED_FROM_LEAVE']) {
        final text = rollCallReasonCopy(code);
        expect(text.length, greaterThan(25), reason: code);
        expect(text, isNot(contains(code)), reason: '$code must not leak');
      }
      expect(rollCallReasonCopy('EDIT_WINDOW_CLOSED'), contains('correction'));
    });
  });

  group('new models', () {
    test('today parses (and a teacher without daily classes gets an empty list)', () {
      final t = AttendanceToday.fromJson(fixture('attendance_today'));
      expect(t.items, isNotEmpty);
      expect(t.items.first.marked, isTrue);
      expect(t.pendingCount, 0);
      expect(AttendanceToday.fromJson({'date': '2026-10-21', 'items': [], 'pendingCount': 0}).items, isEmpty);
    });

    test('section summary keeps the per-day counts', () {
      final s = SectionAttendanceSummary.fromJson(fixture('section_summary'));
      expect(s.days, isNotEmpty);
      expect(s.days.first.counts.present, greaterThan(0));
      expect(s.students.first.totals.percentage, isNotNull);
    });
  });

  group('RollCallController (fake server)', () {
    late FakeServer server;
    late ProviderContainer container;
    const args = (sectionId: 'sec', date: '2026-10-21', periodId: null);

    setUp(() {
      server = FakeServer()..on('GET /attendance/sections/sec', rosterJson());
      container = ProviderContainer(overrides: [rollCallRepositoryProvider.overrideWithValue(RollCallRepository(apiFor(server)))]);
      addTearDown(container.dispose);
    });

    Future<RollCallController> load() async {
      container.listen(rollCallProvider(args), (_, _) {});
      await container.read(rollCallProvider(args).future);
      return container.read(rollCallProvider(args).notifier);
    }

    test('loads the roster for the section and date', () async {
      await load();
      expect(server.last.query['date'], '2026-10-21');
      expect(container.read(rollCallProvider(args)).value!.draft.total, 4);
    });

    test('editing never touches the network; submit PUTs every student and keeps the date', () async {
      server.on('PUT /attendance/sections/sec', {'sessionId': 's', 'firstSubmission': true, 'counts': {'present': 3, 'absent': 1, 'late': 0, 'leave': 1, 'half_day': 0, 'total': 5}, 'changed': 4, 'notifiedGuardians': 1, 'editableUntil': '2026-10-22T03:50:00.000Z'});
      final c = await load();
      c.markAllPresent();
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
      final res = await c.submit();
      expect(res.notifiedGuardians, 1);
      final put = server.requests.firstWhere((r) => r.method == 'PUT');
      final body = put.body as Map;
      expect(body['date'], '2026-10-21');
      expect((body['records'] as List).map((r) => (r as Map)['status']), ['present', 'present', 'leave', 'present']);
    });

    test('submit before everyone has a status is refused locally (nothing sent)', () async {
      final c = await load();
      await expectLater(c.submit(), throwsStateError);
      expect(server.requests.where((r) => r.method == 'PUT'), isEmpty);
    });

    test('a failed submit throws the API problem and keeps every choice', () async {
      server.on('PUT /attendance/sections/sec', {'title': 'Edit window closed', 'code': 'EDIT_WINDOW_CLOSED', 'status': 403}, status: 403);
      final c = await load();
      c.markAllPresent();
      c.setRemark('s1', 'Late bus');
      await expectLater(c.submit(), throwsA(isA<AppException>().having((e) => e.code, 'code', 'EDIT_WINDOW_CLOSED')));
      final d = container.read(rollCallProvider(args)).value!.draft;
      expect(d.statusOf('s1'), AttendanceStatus.present);
      expect(d.remarkOf('s1'), 'Late bus');
      expect(d.isDirty, isTrue);
    });

    test('INCOMPLETE_ROLL_CALL from the API is a validation error with its code', () async {
      server.on('PUT /attendance/sections/sec', {'title': 'Incomplete', 'code': 'INCOMPLETE_ROLL_CALL', 'status': 422}, status: 422);
      final c = await load();
      c.markAllPresent();
      await expectLater(c.submit(), throwsA(isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.validation)));
    });
  });
}
