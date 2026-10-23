import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/data/models/attendance.dart';
import 'package:schoolsync/data/models/staff/comms.dart';
import 'package:schoolsync/data/models/staff/dashboards.dart';
import 'package:schoolsync/data/models/staff/finance.dart';
import 'package:schoolsync/data/models/staff/leave.dart';
import 'package:schoolsync/data/models/staff/marks.dart';
import 'package:schoolsync/data/models/staff/people.dart';
import 'package:schoolsync/data/models/staff/roll_call.dart';
import 'package:schoolsync/data/models/staff/teaching.dart';
import 'package:schoolsync/data/json.dart';

import 'staff_test_support.dart';

void main() {
  group('teacher dashboard (real payload)', () {
    final d = TeacherDashboard.fromJson(fixture('teacher_dashboard'));

    test('header, attendance and timetable', () {
      expect(d.staffName, isNotEmpty);
      expect(d.attendance.items, isNotEmpty);
      expect(d.attendance.items.first.sectionId, isNotEmpty);
      expect(d.timetable.entries, isNotEmpty);
      expect(d.timetable.entries.first.sectionId, isNotNull);
      expect(d.timetable.entries.any((e) => e.relation != null), isTrue);
    });

    test('homework, marks, leave, meetings, announcements', () {
      expect(d.toReviewCount, greaterThan(0));
      expect(d.dueSoon.first.stats, isNotNull);
      expect(d.marks.first.status, anyOf('draft', 'returned'));
      expect(d.pendingLeaveCount, isA<int>());
      expect(d.meetings.first.actions, isNotEmpty);
      expect(d.announcements.latest, isNotEmpty);
      expect(d.unreadNotifications, isA<int>());
    });
  });

  group('management dashboard (real payload)', () {
    final d = ManagementDashboard.fromJson(fixture('management_dashboard'));

    test('kpis, attendance trend and approvals', () {
      expect(d.kpis.students, greaterThan(0));
      expect(d.attendance, isNotNull);
      expect(d.attendance!.trend, isNotEmpty);
      expect(d.attendance!.totals.percentPresent, isNotNull);
      expect(d.approvals.studentLeave, isNotNull);
      expect(d.approvals.concessions, isNull, reason: 'principal cannot act on concessions');
      expect(d.approvals.anyVisible, isTrue);
      expect(d.approvals.total, greaterThan(0));
    });

    test('finance, alerts, license', () {
      expect(d.finance!.collectionRatePercent, isNotNull);
      expect(d.finance!.byMonth, isNotEmpty);
      expect(d.alerts.first.severity, anyOf('info', 'warning', 'critical'));
      expect(d.license, isNull, reason: 'only administrators get the licence block');
    });

    test('null blocks stay null', () {
      final j = fixture('management_dashboard')..['finance'] = null..['attendance'] = null..['exams'] = null;
      final n = ManagementDashboard.fromJson(j);
      expect(n.finance, isNull);
      expect(n.attendance, isNull);
      expect(n.upcomingExams, isNull);
    });
  });

  group('license', () {
    test('needs attention when near the seat limit or expiring', () {
      final base = {'state': 'active', 'readOnly': false, 'daysLeft': 200, 'seats': {'used': 10, 'licensed': 100, 'nearLimit': false, 'overBy': 0}};
      expect(LicenseInfo.fromJson(base).needsAttention, isFalse);
      expect(LicenseInfo.fromJson({...base, 'daysLeft': 12}).needsAttention, isTrue);
      expect(LicenseInfo.fromJson({...base, 'state': 'grace'}).needsAttention, isTrue);
      expect(LicenseInfo.fromJson({...base, 'seats': {'used': 99, 'licensed': 100, 'nearLimit': true, 'overBy': 0}}).needsAttention, isTrue);
    });
  });

  group('roll call', () {
    test('roster parses students, session and counts', () {
      final r = Roster.fromJson(fixture('roster'));
      expect(r.students, isNotEmpty);
      expect(r.students.first.status, isNotNull);
      expect(r.session!.submitted, isTrue);
      expect(r.session!.editableUntil, isNotNull);
      expect(r.counts.marked + r.counts.unmarked, greaterThan(0));
      expect(r.canSubmit, isTrue);
    });

    test('unmarked student and blocked reason', () {
      final j = fixture('roster');
      j['canSubmit'] = false;
      j['blockedReason'] = 'EDIT_WINDOW_CLOSED';
      j['session'] = null;
      (j['students'] as List).first['status'] = null;
      final r = Roster.fromJson(j);
      expect(r.blockedReason, 'EDIT_WINDOW_CLOSED');
      expect(r.session, isNull);
      expect(r.students.first.status, isNull);
    });

    test('RollEntry serialises the half_day wire value', () {
      expect(const RollEntry('s1', AttendanceStatus.halfDay, remarks: ' left early ').toJson(), {'studentId': 's1', 'status': 'half_day', 'remarks': 'left early'});
      expect(const RollEntry('s1', AttendanceStatus.present).toJson().containsKey('remarks'), isFalse);
    });

    test('school summary: sections, absentees, trend', () {
      final s = SchoolAttendance.fromJson(fixture('school_summary'));
      expect(s.sections, isNotEmpty);
      expect(s.sections.first.title, contains(' '));
      expect(s.absentees, isNotEmpty);
      expect(s.trend, isNotEmpty);
      expect(s.totals.activeStudents, greaterThan(0));
    });

    test('corrections', () {
      final p = Paged.parse(fixture('corrections'), CorrectionItem.fromJson);
      expect(p.items, isNotEmpty);
      final c = p.items.first;
      expect(c.pending, isTrue);
      expect(c.fromStatus, isNotNull);
      expect(c.toStatus, isNotNull);
      expect(c.canDecide, isA<bool>());
    });
  });

  group('leave', () {
    test('student leave', () {
      final p = Paged.parse(fixture('student_leave'), StudentLeaveItem.fromJson);
      expect(p.items.first.pending, isTrue);
      expect(p.items.first.days, greaterThan(0));
      expect(p.items.first.studentName, isNotEmpty);
    });

    test('staff leave and balance and my attendance', () {
      final p = Paged.parse(fixture('staff_leave'), StaffLeaveItem.fromJson);
      expect(p.items.first.staffName, isNotEmpty);
      expect(p.items.first.canDecide, isTrue);
      final b = StaffLeaveBalance.fromJson(fixture('leave_balance'));
      expect(b.totalApprovedDays, 0);
      final m = MyStaffAttendance.fromJson(fixture('staff_attendance_me'));
      expect(m.today, isNotNull);
      expect(m.checkedIn, isTrue);
      expect(m.checkedOut, isFalse);
    });
  });

  group('marks', () {
    test('sheets and detail', () {
      final sheets = Paged.parse(fixture('sheets'), MarkSheet.fromJson).items;
      expect(sheets.map((s) => s.status), contains('submitted'));
      final d = MarkSheetDetail.fromJson(fixture('sheet_detail'));
      expect(d.canEdit, isTrue);
      expect(d.sheet.isEditableStatus, isTrue);
      expect(d.entries.first.marksObtained, isNotNull);
      expect(d.sheet.maxMarks, 100);
    });

    test('MarkInput: absent students carry no marks', () {
      expect(const MarkInput(studentId: 's', marks: 40, isAbsent: true).toJson(), {'studentId': 's', 'isAbsent': true, 'marksObtained': null});
      expect(const MarkInput(studentId: 's', marks: 40.5, remarks: 'ok').toJson(), {'studentId': 's', 'isAbsent': false, 'marksObtained': 40.5, 'remarks': 'ok'});
    });
  });

  group('homework', () {
    test('list, stats and roster', () {
      final list = Paged.parse(fixture('homework_list'), HomeworkEntry.fromJson).items;
      expect(list.first.stats, isNotNull);
      expect(list.first.sectionTitle, contains(' '));
      final r = HomeworkRoster.fromJson(fixture('homework_roster'));
      expect(r.rows, isNotEmpty);
      expect(r.homework.stats!.totalStudents, greaterThan(0));
      expect(r.rows.first.status, isNotEmpty);
    });

    test('submissions', () {
      final s = Paged.parse(fixture('submissions'), SubmissionEntry.fromJson).items;
      expect(s.first.studentName, isNotEmpty);
      expect(s.map((e) => e.status), everyElement(anyOf('submitted', 'late', 'reviewed', 'returned')));
    });

    test('draft bodies: due date is UTC, marks dropped when submissions are off', () {
      final due = DateTime.utc(2026, 11, 2, 10, 30);
      final d = HomeworkDraft(sectionId: 'sec', subjectId: 'sub', title: ' Fractions ', description: ' ', dueAt: due.toLocal(), allowSubmission: false, maxMarks: 20);
      final create = d.toCreateJson(publish: true);
      expect(create['dueAt'], '2026-11-02T10:30:00.000Z');
      expect(create['title'], 'Fractions');
      expect(create.containsKey('description'), isFalse);
      expect(create['maxMarks'], isNull);
      expect(create['publish'], isTrue);
      expect(d.toUpdateJson().containsKey('sectionId'), isFalse);
      expect(d.toUpdateJson()['description'], isNull);
    });

    test('homework stats: to review = submitted + late', () {
      const s = HomeworkStats(totalStudents: 24, submitted: 4, late: 2, reviewed: 3, returned: 1, missing: 14);
      expect(s.toReview, 6);
      expect(s.handedIn, 10);
    });
  });

  group('people and structure', () {
    test('sections, assignments, students', () {
      final sections = Paged.parse(fixture('sections'), SectionItem.fromJson).items;
      expect(sections.first.title, startsWith('Grade'));
      final detail = SectionDetail.fromJson(fixture('section_detail'));
      expect(detail.teaching, isNotEmpty);
      final mine = Paged.parse(fixture('assignments'), MyAssignment.fromJson).items;
      expect(mine.first.sectionTitle, isNotEmpty);
      final students = Paged.parse(fixture('students'), StudentRow.fromJson).items;
      expect(students.first.admissionNo, isNotEmpty);
    });

    test('student detail keeps guardians and tolerates hidden fields', () {
      final d = StudentDetail.fromJson(fixture('student_detail'));
      expect(d.guardians.first.verified, isTrue);
      expect(d.guardians.first.phone, isNotNull);
      final hidden = fixture('student_detail');
      (hidden['guardians'] as List).first['phone'] = null;
      hidden['medicalNotes'] = null;
      hidden['address'] = null;
      final h = StudentDetail.fromJson(hidden);
      expect(h.guardians.first.phone, isNull);
      expect(h.address, isNull);
      expect(h.medicalNotes, isNull);
    });

    test('staff directory and admissions', () {
      final staff = Paged.parse(fixture('staff_directory'), StaffMember.fromJson).items;
      expect(staff.first.employeeId, isNotEmpty);
      final adm = Paged.parse(fixture('admissions'), AdmissionApplication.fromJson).items;
      expect(adm.first.status, 'submitted');
      expect(adm.first.guardianPhone, isNotEmpty);
    });
  });

  group('teaching', () {
    test('timetable day', () {
      final d = TeacherDay.fromJson(fixture('timetable_me'));
      expect(d.entries, isNotEmpty);
      expect(d.dayOfWeek, 4);
    });

    test('syllabus topics and coverage', () {
      final topics = jsonList(fixture('syllabus_topics')['data']).map(TopicEntry.fromJson).toList();
      expect(topics.first.status, isA<SyllabusStatus>());
      expect(topics.first.withStatus(SyllabusStatus.completed).status, SyllabusStatus.completed);
      final cov = jsonList(fixture('coverage')['data']).map(CoverageRow.fromJson).toList();
      expect(cov.first.percent, inInclusiveRange(0, 100));
      expect(SyllabusStatus.parse('weird'), SyllabusStatus.notStarted);
    });
  });

  group('communication', () {
    test('managed announcements and stats', () {
      final a = Paged.parse(fixture('managed_announcements'), ManagedAnnouncement.fromJson).items;
      expect(a.first.canManage, isTrue);
      expect(a.first.audience, isNotEmpty);
      expect(a.first.readCount, isNotNull);
      final s = AnnouncementStats.fromJson(fixture('announcement_stats'));
      expect(s.audienceSize, greaterThan(0));
      expect(s.readPercent, inInclusiveRange(0, 100));
    });

    test('announcement draft body', () {
      final d = AnnouncementDraft(title: ' Hi ', body: ' Body ', audience: const [AudienceTarget(type: 'section', id: 's1', label: 'Grade 6 A'), AudienceTarget(type: 'all', label: 'Everyone')], publishAt: DateTime.utc(2026, 11, 1, 4));
      final j = d.toJson();
      expect(j['title'], 'Hi');
      expect(j['audience'], [{'type': 'section', 'id': 's1'}, {'type': 'all'}]);
      expect(j['publishAt'], '2026-11-01T04:00:00.000Z');
      expect(j.containsKey('expiresAt'), isFalse);
    });

    test('meetings', () {
      final m = Paged.parse(fixture('meetings'), StaffMeeting.fromJson).items;
      expect(m.first.studentName, isNotEmpty);
      expect(m.any((e) => e.can('confirm')), isTrue);
      expect(m.first.when, isNotNull);
    });
  });

  group('finance', () {
    test('summary, outstanding, defaulters, collection', () {
      final s = FinanceSummary.fromJson(fixture('finance_summary'));
      expect(s.collectedMinor, greaterThan(0));
      expect(s.expensesMinor, isNotNull);
      expect(s.pendingConcessions, isA<int>());
      final o = OutstandingReport.fromJson(fixture('outstanding'));
      expect(o.rows.first.name, isNotEmpty);
      expect(o.buckets.d31to60 + o.buckets.d90plus, greaterThan(0));
      final d = Paged.parse(fixture('defaulters'), Defaulter.fromJson).items;
      expect(d.first.guardianPhone, isNotNull);
      final c = CollectionReport.fromJson(fixture('collection'));
      expect(c.series, isNotEmpty);
      expect(c.byMethod, isNotEmpty);
    });

    test('expenses hidden from the caller come back as null', () {
      final j = fixture('finance_summary')..['expensesMinor'] = null..['netPositionMinor'] = null;
      (j['pending'] as Map)['expenses'] = null;
      final s = FinanceSummary.fromJson(j);
      expect(s.expensesMinor, isNull);
      expect(s.netPositionMinor, isNull);
      expect(s.pendingExpenses, isNull);
    });

    test('approval queues', () {
      expect(Paged.parse(fixture('concessions'), ConcessionItem.fromJson).items.first.pending, isTrue);
      expect(Paged.parse(fixture('refunds'), RefundItem.fromJson).items.first.requested, isTrue);
      expect(Paged.parse(fixture('expenses'), ExpenseItem.fromJson).items.first.pending, isTrue);
    });
  });

  test('every model tolerates an empty object', () {
    expect(() => TeacherDashboard.fromJson({}), returnsNormally);
    expect(() => ManagementDashboard.fromJson({}), returnsNormally);
    expect(() => Roster.fromJson({}), returnsNormally);
    expect(() => MarkSheetDetail.fromJson({}), returnsNormally);
    expect(() => HomeworkRoster.fromJson({}), returnsNormally);
    expect(() => StudentDetail.fromJson({}), returnsNormally);
    expect(() => FinanceSummary.fromJson({}), returnsNormally);
    expect(() => StaffMeeting.fromJson({}), returnsNormally);
    expect(() => SchoolAttendance.fromJson({}), returnsNormally);
  });
}
