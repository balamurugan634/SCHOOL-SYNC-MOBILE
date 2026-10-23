import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/data/repositories/staff/staff_dashboard_repository.dart';
import 'package:schoolsync/core/network/app_exception.dart';
import 'package:schoolsync/data/models/attendance.dart';
import 'package:schoolsync/data/models/leave.dart' show LeaveType;
import 'package:schoolsync/data/models/staff/comms.dart';
import 'package:schoolsync/data/models/staff/marks.dart';
import 'package:schoolsync/data/models/staff/teaching.dart';
import 'package:schoolsync/data/repositories/staff/academics_repository.dart';
import 'package:schoolsync/data/repositories/staff/comms_repository.dart';
import 'package:schoolsync/data/repositories/staff/finance_repository.dart';
import 'package:schoolsync/data/repositories/staff/marks_repository.dart';
import 'package:schoolsync/data/repositories/staff/people_repository.dart';
import 'package:schoolsync/data/repositories/staff/roll_call_repository.dart';
import 'package:schoolsync/data/models/staff/roll_call.dart';
import 'package:schoolsync/data/repositories/staff/staff_homework_repository.dart';
import 'package:schoolsync/data/repositories/staff/staff_leave_repository.dart';

import 'staff_test_support.dart';

void main() {
  late FakeServer server;
  setUp(() => server = FakeServer());

  group('RollCallRepository', () {
    test('roster passes date and period; parses the response', () async {
      server.on('GET /attendance/sections/s1', fixture('roster'));
      final r = await RollCallRepository(apiFor(server)).roster('s1', date: DateTime(2026, 10, 21), periodId: 'p1');
      expect(r.students, isNotEmpty);
      expect(server.last.query, {'date': '2026-10-21', 'periodId': 'p1'});
    });

    test('submit PUTs every record with the wire status', () async {
      server.on('PUT /attendance/sections/s1', {'sessionId': 'x', 'firstSubmission': true, 'counts': {'present': 1, 'absent': 1, 'late': 0, 'leave': 0, 'half_day': 1, 'total': 3}, 'changed': 3, 'notifiedGuardians': 1, 'editableUntil': '2026-10-22T03:50:00.000Z'});
      final res = await RollCallRepository(apiFor(server)).submit('s1', date: DateTime(2026, 10, 21), entries: const [
        RollEntry('a', AttendanceStatus.present),
        RollEntry('b', AttendanceStatus.absent, remarks: 'fever'),
        RollEntry('c', AttendanceStatus.halfDay),
      ]);
      expect(res.counts.halfDay, 1);
      expect(res.total, 3);
      expect(res.notifiedGuardians, 1);
      final body = server.last.body as Map;
      expect(body['date'], '2026-10-21');
      expect((body['records'] as List).map((r) => (r as Map)['status']), ['present', 'absent', 'half_day']);
    });

    test('closed edit window surfaces as a conflict-style AppException with its code', () async {
      server.on('PUT /attendance/sections/s1', {'title': 'Edit window closed', 'code': 'EDIT_WINDOW_CLOSED', 'status': 403}, status: 403);
      await expectLater(
        RollCallRepository(apiFor(server)).submit('s1', entries: const [RollEntry('a', AttendanceStatus.present)]),
        throwsA(isA<AppException>().having((e) => e.code, 'code', 'EDIT_WINDOW_CLOSED').having((e) => e.kind, 'kind', ErrorKind.forbidden)),
      );
    });

    test('corrections: list filters, request and decide', () async {
      server.on('GET /attendance/corrections', fixture('corrections'));
      server.on('POST /attendance/records/r1/corrections', {});
      server.on('POST /attendance/corrections/c1/approve', {});
      server.on('POST /attendance/corrections/c1/reject', {});
      final repo = RollCallRepository(apiFor(server));
      final list = await repo.corrections(mine: true, status: 'pending');
      expect(list.items, isNotEmpty);
      expect(server.last.query['mine'], true);
      expect(server.last.query['status'], 'pending');
      await repo.requestCorrection('r1', to: AttendanceStatus.late, reason: ' came in late ');
      expect(server.last.body, {'toStatus': 'late', 'reason': 'came in late'});
      await repo.decideCorrection('c1', approve: true);
      expect(server.last.path, '/attendance/corrections/c1/approve');
      await repo.decideCorrection('c1', approve: false, note: 'No evidence');
      expect(server.last.path, '/attendance/corrections/c1/reject');
      expect(server.last.body, {'note': 'No evidence'});
    });

    test('school summary asks for the trend length and parses', () async {
      server.on('GET /attendance/summary', fixture('school_summary'));
      final s = await RollCallRepository(apiFor(server)).schoolSummary(trendDays: 7);
      expect(s.sections, isNotEmpty);
      expect(server.last.query['trendDays'], 7);
    });
  });

  group('AcademicsRepository', () {
    test('my sections use mine=true; management lists all', () async {
      server.on('GET /academics/sections', fixture('sections'));
      final repo = AcademicsRepository(apiFor(server));
      expect((await repo.sections()).first.title, startsWith('Grade'));
      expect(server.last.query['mine'], true);
      await repo.sections(mine: false);
      expect(server.last.query.containsKey('mine'), isFalse);
    });

    test('teaching assignments are filtered by my staff id', () async {
      server.on('GET /academics/teaching-assignments', fixture('assignments'));
      final list = await AcademicsRepository(apiFor(server)).myAssignments('staff-1');
      expect(list, isNotEmpty);
      expect(server.last.query['staffId'], 'staff-1');
    });

    test('timetable day and syllabus progress', () async {
      server.on('GET /timetable/me', fixture('timetable_me'));
      server.on('PUT /syllabus/progress', {'data': []});
      final repo = AcademicsRepository(apiFor(server));
      final day = await repo.myDay(date: DateTime(2026, 10, 22));
      expect(day.entries, isNotEmpty);
      expect(server.last.query['date'], '2026-10-22');
      await repo.setProgress('sec', {'t1': SyllabusStatus.completed, 't2': SyllabusStatus.inProgress});
      expect(server.last.body, {
        'sectionId': 'sec',
        'items': [{'topicId': 't1', 'status': 'completed'}, {'topicId': 't2', 'status': 'in_progress'}],
      });
    });
  });

  group('StaffHomeworkRepository', () {
    test('list defaults to my homework; roster parses', () async {
      server.on('GET /homework', fixture('homework_list'));
      server.on('GET /homework/h1/roster', fixture('homework_roster'));
      final repo = StaffHomeworkRepository(apiFor(server));
      final page = await repo.list(status: 'published');
      expect(page.items.first.stats, isNotNull);
      expect(server.last.query['mine'], true);
      expect(server.last.query['status'], 'published');
      final roster = await repo.roster('h1');
      expect(roster.rows, isNotEmpty);
    });

    test('create, update, publish, close, delete hit the right routes', () async {
      final created = (fixture('homework_list')['data'] as List).first;
      server.on('POST /homework', created, status: 201);
      server.on('PATCH /homework/h1', created);
      server.on('POST /homework/h1/publish', {});
      server.on('POST /homework/h1/close', {});
      server.on('DELETE /homework/h1', {});
      final repo = StaffHomeworkRepository(apiFor(server));
      final draft = HomeworkDraft(sectionId: 'sec', subjectId: 'sub', title: 'T', dueAt: DateTime.utc(2026, 11, 3), maxMarks: 10);
      await repo.create(draft, publish: false);
      expect((server.last.body as Map)['publish'], false);
      await repo.update('h1', draft);
      expect(server.last.method, 'PATCH');
      await repo.publish('h1');
      await repo.close('h1');
      await repo.delete('h1');
      expect(server.requests.map((r) => '${r.method} ${r.path}'), ['POST /homework', 'PATCH /homework/h1', 'POST /homework/h1/publish', 'POST /homework/h1/close', 'DELETE /homework/h1']);
    });

    test('review sends marks and feedback; rework needs feedback', () async {
      server.on('POST /submissions/s1/review', {});
      server.on('POST /submissions/s1/return', {});
      final repo = StaffHomeworkRepository(apiFor(server));
      await repo.review('s1', marks: 7.5, feedback: ' Good ');
      expect(server.last.body, {'marks': 7.5, 'feedback': 'Good'});
      await repo.review('s1', feedback: 'Only words');
      expect((server.last.body as Map).containsKey('marks'), isFalse);
      await repo.returnForRework('s1', feedback: 'Redo question 3');
      expect(server.last.body, {'feedback': 'Redo question 3'});
    });

    test('MARKS_EXCEED_MAX is a validation error with a code', () async {
      server.on('POST /submissions/s1/review', {'title': 'Marks cannot exceed 10', 'code': 'MARKS_EXCEED_MAX', 'status': 422}, status: 422);
      await expectLater(StaffHomeworkRepository(apiFor(server)).review('s1', marks: 11), throwsA(isA<AppException>().having((e) => e.code, 'code', 'MARKS_EXCEED_MAX')));
    });
  });

  group('MarksRepository', () {
    test('sheets, detail, save draft, submit', () async {
      server.on('GET /marks/sheets', fixture('sheets'));
      server.on('GET /marks/sheets/m1', fixture('sheet_detail'));
      server.on('PUT /marks/sheets/m1/entries', {});
      server.on('POST /marks/sheets/m1/submit', {});
      final repo = MarksRepository(apiFor(server));
      final sheets = await repo.sheets(mine: true);
      expect(sheets.items, isNotEmpty);
      expect(server.last.query['mine'], true);
      final detail = await repo.sheet('m1');
      expect(detail.entries, isNotEmpty);
      await repo.saveEntries('m1', const [MarkInput(studentId: 'a', marks: 55), MarkInput(studentId: 'b', isAbsent: true)]);
      expect(server.last.body, {
        'entries': [
          {'studentId': 'a', 'isAbsent': false, 'marksObtained': 55.0},
          {'studentId': 'b', 'isAbsent': true, 'marksObtained': null},
        ],
      });
      await repo.submit('m1');
      expect(server.last.path, '/marks/sheets/m1/submit');
    });

    test('review: approve with optional note, return with note', () async {
      server.on('POST /marks/sheets/m1/approve', {});
      server.on('POST /marks/sheets/m1/return', {});
      final repo = MarksRepository(apiFor(server));
      await repo.approve('m1');
      expect(server.last.body, <String, dynamic>{});
      await repo.returnSheet('m1', note: ' Recheck Q4 ');
      expect(server.last.body, {'note': 'Recheck Q4'});
    });
  });

  group('CommsRepository', () {
    test('create announcement posts the audience and attachments; scheduling uses UTC', () async {
      server.on('POST /announcements', (fixture('managed_announcements')['data'] as List).first, status: 201);
      server.on('POST /announcements/a1/publish', {});
      server.on('POST /announcements/a1/schedule', {});
      final repo = CommsRepository(apiFor(server));
      await repo.createAnnouncement(const AnnouncementDraft(title: 'Hello', body: 'World', priority: 'important', audience: [AudienceTarget(type: 'section', id: 's1', label: 'A')]));
      final body = server.last.body as Map;
      expect(body['priority'], 'important');
      expect(body['audience'], [{'type': 'section', 'id': 's1'}]);
      await repo.publishAnnouncement('a1');
      await repo.scheduleAnnouncement('a1', DateTime.utc(2026, 12, 1, 3, 30));
      expect(server.last.body, {'publishAt': '2026-12-01T03:30:00.000Z'});
    });

    test('managed list and stats', () async {
      server.on('GET /announcements/manage', fixture('managed_announcements'));
      server.on('GET /announcements/a1/stats', fixture('announcement_stats'));
      final repo = CommsRepository(apiFor(server));
      expect((await repo.managed(state: 'draft', mine: true)).items, isNotEmpty);
      expect(server.last.query['state'], 'draft');
      expect((await repo.stats('a1')).audienceSize, greaterThan(0));
    });

    test('meeting actions', () async {
      for (final a in ['confirm', 'decline', 'reschedule', 'complete', 'cancel']) {
        server.on('POST /meetings/m1/$a', {});
      }
      final repo = CommsRepository(apiFor(server));
      final at = DateTime.utc(2026, 11, 5, 9);
      await repo.confirmMeeting('m1', at: at, mode: 'online', locationOrLink: ' https://meet.example/x ');
      expect(server.last.body, {'scheduledAt': '2026-11-05T09:00:00.000Z', 'durationMin': 15, 'mode': 'online', 'locationOrLink': 'https://meet.example/x'});
      await repo.declineMeeting('m1', reason: 'Not available');
      expect(server.last.body, {'reason': 'Not available'});
      await repo.rescheduleMeeting('m1', at: at);
      expect((server.last.body as Map)['scheduledAt'], '2026-11-05T09:00:00.000Z');
      await repo.completeMeeting('m1', outcomeNotes: 'Discussed progress');
      expect(server.last.body, {'outcomeNotes': 'Discussed progress'});
      await repo.cancelMeeting('m1');
      expect(server.last.body, <String, dynamic>{});
    });
  });

  group('StaffLeaveRepository', () {
    test('student leave list and decision with a note', () async {
      server.on('GET /leave', fixture('student_leave'));
      server.on('POST /leave/l1/reject', {});
      final repo = StaffLeaveRepository(apiFor(server));
      expect((await repo.studentLeave(status: 'pending')).items, isNotEmpty);
      await repo.decideStudentLeave('l1', approve: false, note: 'Exam week');
      expect(server.last.path, '/leave/l1/reject');
      expect(server.last.body, {'note': 'Exam week'});
    });

    test('apply for staff leave sends a date-only range', () async {
      server.on('POST /staff-leave', {}, status: 201);
      await StaffLeaveRepository(apiFor(server)).applyStaffLeave(type: LeaveType.casual, from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 3), reason: ' Family function ');
      expect(server.last.body, {'leaveType': 'casual', 'fromDate': '2026-11-02', 'toDate': '2026-11-03', 'reason': 'Family function'});
    });

    test('LEAVE_OVERLAP comes through as a conflict', () async {
      server.on('POST /staff-leave', {'title': 'Overlap', 'code': 'LEAVE_OVERLAP', 'status': 409}, status: 409);
      await expectLater(
        StaffLeaveRepository(apiFor(server)).applyStaffLeave(type: LeaveType.sick, from: DateTime(2026, 11, 2), to: DateTime(2026, 11, 2), reason: 'Fever'),
        throwsA(isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.conflict)),
      );
    });

    test('check in / out and my attendance', () async {
      server.on('GET /staff-attendance/me', fixture('staff_attendance_me'));
      server.on('POST /staff-attendance/check-in', {});
      server.on('POST /staff-attendance/check-out', {});
      final repo = StaffLeaveRepository(apiFor(server));
      expect((await repo.myAttendance()).checkedIn, isTrue);
      await repo.checkIn();
      await repo.checkOut();
      expect(server.requests.map((r) => r.path), ['/staff-attendance/me', '/staff-attendance/check-in', '/staff-attendance/check-out']);
    });
  });

  group('FinanceRepository', () {
    test('402 on a write is a subscription-expired exception', () async {
      server.on('POST /expenses/e1/approve', {'title': 'Subscription ended', 'code': 'SUBSCRIPTION_EXPIRED', 'status': 402}, status: 402);
      await expectLater(FinanceRepository(apiFor(server)).decideExpense('e1', approve: true), throwsA(isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.subscriptionExpired)));
    });

    test('reports and queues', () async {
      server.on('GET /finance/summary', fixture('finance_summary'));
      server.on('GET /fees/reports/outstanding', fixture('outstanding'));
      server.on('GET /fees/reports/defaulters', fixture('defaulters'));
      server.on('GET /fees/reports/collection', fixture('collection'));
      server.on('GET /fees/concessions', fixture('concessions'));
      server.on('GET /payments/refunds', fixture('refunds'));
      server.on('GET /expenses', fixture('expenses'));
      server.on('POST /fees/concessions/c1/approve', {});
      server.on('POST /payments/refunds/r1/reject', {});
      final repo = FinanceRepository(apiFor(server));
      expect((await repo.summary()).collectedMinor, greaterThan(0));
      expect((await repo.outstanding()).rows, isNotEmpty);
      expect(server.last.query['groupBy'], 'grade');
      expect((await repo.defaulters()).items, isNotEmpty);
      expect((await repo.collection()).series, isNotEmpty);
      expect((await repo.concessions()).items, isNotEmpty);
      expect((await repo.refunds()).items, isNotEmpty);
      expect(server.last.query['status'], 'requested');
      expect((await repo.expenses()).items, isNotEmpty);
      await repo.decideConcession('c1', approve: true);
      await repo.decideRefund('r1', approve: false, note: 'Duplicate request');
      expect(server.last.path, '/payments/refunds/r1/reject');
      expect(server.last.body, {'note': 'Duplicate request'});
    });
  });

  group('PeopleRepository', () {
    test('student search trims the query', () async {
      server.on('GET /students', fixture('students'));
      server.on('GET /students/st1', fixture('student_detail'));
      final repo = PeopleRepository(apiFor(server));
      await repo.students(q: '  sharma ', sectionId: 'sec');
      expect(server.last.query['q'], 'sharma');
      expect(server.last.query['sectionId'], 'sec');
      await repo.students(q: '   ');
      expect(server.last.query.containsKey('q'), isFalse);
      expect((await repo.student('st1')).guardians, isNotEmpty);
    });

    test('staff directory, admissions and status change', () async {
      server.on('GET /staff', fixture('staff_directory'));
      server.on('GET /admissions', fixture('admissions'));
      server.on('POST /admissions/a1/status', {});
      final repo = PeopleRepository(apiFor(server));
      expect((await repo.staff()).items, isNotEmpty);
      expect((await repo.admissions(status: 'submitted')).items, isNotEmpty);
      await repo.setAdmissionStatus('a1', 'rejected', note: 'No seats');
      expect(server.last.body, {'status': 'rejected', 'note': 'No seats'});
    });

    test('403 for a student outside my scope', () async {
      server.on('GET /students/x', {'title': 'Forbidden', 'code': 'FORBIDDEN', 'status': 403}, status: 403);
      await expectLater(PeopleRepository(apiFor(server)).student('x'), throwsA(isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.forbidden)));
    });
  });

  group('StaffDashboardRepository', () {
    ProviderContainer containerFor(FakeServer server) => ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(apiFor(server)),
      secureStoreProvider.overrideWithValue(SecureStore(MemorySecureKv())),
    ]);

    test('a good load is remembered; when the network drops the saved copy is served and marked as cached', () async {
      final flaky = _Flaky()..on('GET /dashboard/teacher', fixture('teacher_dashboard'));
      final c = containerFor(flaky);
      addTearDown(c.dispose);
      final repo = c.read(staffDashboardRepositoryProvider);
      final live = await repo.teacher('u1');
      expect(live.fromCache, isFalse);
      flaky.down = true;
      final cached = await repo.teacher('u1');
      expect(cached.fromCache, isTrue);
      expect(cached.at, isNotNull);
      expect(cached.value.staffName, live.value.staffName);
      await expectLater(repo.teacher('someone-else'), throwsA(isA<AppException>().having((e) => e.isNetwork, 'offline', true)), reason: 'nothing saved for another user: the failure is shown');
    });

    test('a refusal or a server error is never papered over with old data', () async {
      final flaky = _Flaky()..on('GET /dashboard/management', fixture('management_dashboard'));
      final c = containerFor(flaky);
      addTearDown(c.dispose);
      final repo = c.read(staffDashboardRepositoryProvider);
      await repo.management('u1');
      flaky.on('GET /dashboard/management', {'title': 'Forbidden', 'code': 'FORBIDDEN', 'status': 403}, status: 403);
      await expectLater(repo.management('u1'), throwsA(isA<AppException>().having((e) => e.kind, 'kind', ErrorKind.forbidden)));
    });
  });
}

class _Flaky extends FakeServer {
  bool down = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) {
    if (down) throw DioException(requestOptions: o, type: DioExceptionType.connectionError, error: 'SocketException: offline');
    return super.fetch(o, body, cancel);
  }
}
