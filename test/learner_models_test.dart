import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/announcements.dart';
import 'package:schoolsync/data/models/attendance.dart';
import 'package:schoolsync/data/models/events.dart';
import 'package:schoolsync/data/models/exams.dart';
import 'package:schoolsync/data/models/fees.dart';
import 'package:schoolsync/data/models/homework.dart';
import 'package:schoolsync/data/models/learner_dashboard.dart';
import 'package:schoolsync/data/models/learner_extras.dart';
import 'package:schoolsync/data/models/materials.dart';
import 'package:schoolsync/data/models/meetings.dart';
import 'package:schoolsync/data/models/notifications.dart';
import 'package:schoolsync/data/models/profile_details.dart';
import 'package:schoolsync/data/models/schedule.dart';
import 'package:schoolsync/data/models/tasks.dart';

import 'support/fake_api.dart';

/// Every model is parsed from a REAL API response recorded from the demo school (test/fixtures/api).
void main() {
  group('json helpers', () {
    test('are tolerant', () {
      expect(jInt('7'), 7);
      expect(jInt(null, 3), 3);
      expect(jDoubleN('1.5'), 1.5);
      expect(jBool('x'), false);
      expect(jDay('2026-10-21T10:00:00Z'), DateTime(2026, 10, 21));
      expect(jDate('nope'), isNull);
      expect(jsonList([1, {'a': 1}, null]), hasLength(1));
      expect(isoDay(DateTime(2026, 1, 5)), '2026-01-05');
    });

    test('Paged and CursorPage', () {
      final p = Paged.parse<int>({'data': [{'n': 1}, {'n': 2}], 'meta': {'page': 1, 'pageSize': 2, 'total': 5, 'totalPages': 3}}, (j) => j['n'] as int);
      expect(p.items, [1, 2]);
      expect(p.meta.hasMore, isTrue);
      final c = CursorPage.parse<int>({'data': [{'n': 1}], 'nextCursor': 'abc'}, (j) => j['n'] as int);
      expect(c.nextCursor, 'abc');
      expect(CursorPage.parse<int>({'data': []}, (j) => 1).nextCursor, isNull);
    });

    test('Attachment round trip', () {
      final a = Attachment.fromJson({'fileId': 'f1', 'name': 'x.pdf', 'mimeType': 'application/pdf', 'sizeBytes': 10});
      expect(Attachment.fromJson(a.toJson()).fileId, 'f1');
      expect(Attachment.list([{'name': 'no id'}]), isEmpty);
    });
  });

  group('dashboards', () {
    test('student dashboard', () {
      final d = StudentDashboard.fromJson(fixture('dashboard_student') as Json);
      expect(d.day.student.name, isNotEmpty);
      expect(d.day.timetable!.entries, isNotEmpty);
      expect(d.day.timetable!.entries.first.subjectName, isNotNull);
      expect(d.day.attendance!.totals.total, greaterThan(0));
      expect(d.day.attendanceToday, isNotNull);
      expect(d.day.upcomingExams, isNotEmpty);
      expect(d.tasks, isNotEmpty);
      expect(d.announcements.latest, isNotEmpty);
      expect(d.calendar, isNotEmpty);
      expect(d.unreadNotifications, greaterThan(0));
      expect(d.fromCache, isFalse);
    });

    test('parent dashboard', () {
      final d = ParentDashboard.fromJson(fixture('dashboard_parent') as Json);
      expect(d.children, isNotEmpty);
      expect(d.child!.student.name, isNotEmpty);
      expect(d.fees!.currency, 'INR');
      expect(d.fees!.outstandingMinor, greaterThan(0));
      expect(d.fees!.nextDueInvoiceId, isNotNull);
      expect(d.meetings, isNotEmpty);
      expect(d.selectedStudentId, d.child!.student.id);
    });

    test('cached copies are marked and keep their time', () {
      final at = DateTime(2026, 1, 1, 9);
      final d = StudentDashboard.fromJson(fixture('dashboard_student') as Json, at: at, fromCache: true);
      expect(d.fromCache, isTrue);
      expect(d.fetchedAt, at);
    });
  });

  group('schedule', () {
    test('timetable day, substitution and states', () {
      final d = TimetableDay.fromJson(fixture('timetable') as Json);
      expect(d.dayOfWeek, inInclusiveRange(1, 7));
      expect(d.entries.any((e) => e.substituted && e.substituteTeacherName != null), isTrue);
      expect(d.entries.every((e) => e.startTime.contains(':')), isTrue);
    });

    test('calendar items: kinds, ranges, occursOn', () {
      final items = jsonList((fixture('calendar') as Json)['data']).map(CalendarItem.fromJson).toList();
      expect(items, isNotEmpty);
      expect(items.map((e) => e.kind).toSet().length, greaterThan(1));
      final hw = items.firstWhere((e) => e.kind == CalendarKind.homeworkDue);
      expect(hw.occursOn(hw.date), isTrue);
      expect(hw.occursOn(hw.date.add(const Duration(days: 2))), isFalse);
      expect(CalendarKind.parse('exam_paper'), CalendarKind.exam);
    });
  });

  group('attendance', () {
    test('summary and months', () {
      final s = AttendanceSummary.fromJson(fixture('attendance_summary') as Json);
      expect(s.totals.present + s.totals.late + s.totals.absent + s.totals.leave + s.totals.halfDay, s.totals.total);
      expect(s.months, isNotEmpty);
      expect(s.thresholdPercent, 75);
      expect(s.isShort, isFalse);
    });

    test('records page with a cursor', () {
      final p = CursorPage.parse(fixture('attendance_records'), AttendanceRecord.fromJson);
      expect(p.items, isNotEmpty);
      expect(p.nextCursor, isNotNull);
      expect(AttendanceStatus.parse('half_day'), AttendanceStatus.halfDay);
      expect(AttendanceStatus.halfDay.apiValue, 'half_day');
    });
  });

  group('homework and tasks', () {
    test('list with learner states', () {
      final p = Paged.parse(fixture('homework_list'), Homework.fromJson);
      expect(p.items, isNotEmpty);
      expect(p.items.map((h) => h.learnerStatus).toSet(), containsAll([LearnerStatus.submitted, LearnerStatus.reviewed]));
      final reviewed = p.items.firstWhere((h) => h.learnerStatus == LearnerStatus.reviewed);
      expect(reviewed.submission!.status, 'reviewed');
      expect(LearnerStatus.pending.needsAction, isTrue);
      expect(LearnerStatus.reviewed.needsAction, isFalse);
    });

    test('detail and submission', () {
      final h = Homework.fromJson(fixture('homework_detail') as Json);
      // The recorded homework is closed, so it cannot take submissions; an open copy can.
      expect(h.canSubmit, isFalse);
      expect(Homework.fromJson({...(fixture('homework_detail') as Json), 'status': 'published'}).canSubmit, isTrue);
      expect(Homework.fromJson({...(fixture('homework_detail') as Json), 'status': 'published', 'allowSubmission': false}).canSubmit, isFalse);
      expect(h.dueAt, isNotNull);
      final s = Submission.fromJson(fixture('submission') as Json);
      expect(s.homeworkId, h.id);
      expect(s.text, isNotEmpty);
    });

    test('tasks and feed', () {
      final feed = jsonList((fixture('tasks_feed') as Json)['data']).map(TaskFeedItem.fromJson).toList();
      expect(feed, isNotEmpty);
      expect(feed.first.overdue, isTrue);
      expect(feed.first.priority, TaskPriority.high);
      final tasks = Paged.parse(fixture('tasks'), Task.fromJson).items;
      expect(tasks.first.status, TaskStatus.todo);
      expect(tasks.first.done, isFalse);
    });
  });

  group('exams and results', () {
    test('exams and papers', () {
      final exams = Paged.parse(fixture('exams'), Exam.fromJson).items;
      expect(exams.first.paperCount, greaterThan(0));
      final papers = jsonList((fixture('exam_papers') as Json)['data']).map(ExamPaper.fromJson).toList();
      expect(papers.first.examDate, isNotNull);
      expect(papers.first.room, isNull);
      expect(papers.first.startTime, '09:00');
    });

    test('results, progress and the report card', () {
      final r = jsonList((fixture('results') as Json)['data']).map(ExamResult.fromJson).first;
      expect(r.subjects, isNotEmpty);
      expect(r.percent, inInclusiveRange(0, 100));
      expect(r.passed, isTrue);
      final prog = jsonList((fixture('progress') as Json)['exams']).map(ProgressPoint.fromJson).toList();
      expect(prog, isNotEmpty);
      final rc = ReportCard.fromJson(fixture('report_card') as Json);
      expect(rc.result.examName, r.examName);
      expect(rc.gradeScale, isNotEmpty);
      expect(rc.teacherRemark, isNotNull);
      expect(rc.attendancePercent, isNotNull);
      expect(rc.schoolName, 'Green Valley Public School');
    });
  });

  group('fees', () {
    test('invoice list and detail', () {
      final list = Paged.parse(fixture('invoices'), Invoice.fromJson).items;
      expect(list.any((i) => i.isPaid), isTrue);
      final d = Invoice.fromJson(fixture('invoice_detail') as Json);
      expect(d.items, isNotEmpty);
      expect(d.items.fold<int>(0, (a, i) => a + i.amountMinor), greaterThan(0));
      expect(d.payable, isTrue);
      expect(d.balanceMinor, d.totalMinor - d.paidMinor);
    });

    test('payments and receipts', () {
      final p = Paged.parse(fixture('payments'), Payment.fromJson).items;
      expect(p.first.succeeded, isTrue);
      expect(p.first.methodLabel, isNotEmpty);
      final r = Receipt.fromJson(fixture('receipt') as Json);
      expect(r.receiptNo, startsWith('RCT-'));
      expect(r.items, isNotEmpty);
      expect(r.schoolName, isNotEmpty);
      expect(r.amountMinor, greaterThan(0));
    });

    test('PayOrder', () {
      final o = PayOrder.fromJson({'paymentId': 'p', 'provider': 'mock', 'orderId': 'o', 'amountMinor': 100, 'currency': 'INR', 'mock': true, 'keyId': null});
      expect(o.mock, isTrue);
      expect(o.amountMinor, 100);
    });
  });

  group('communication', () {
    test('announcements', () {
      final a = Paged.parse(fixture('announcements'), Announcement.fromJson).items;
      expect(a.any((x) => x.urgent), isTrue);
      final acked = a.firstWhere((x) => x.requiresAck);
      expect(acked.acknowledged, isTrue);
      expect(acked.needsAck, isFalse);
      final raw = (fixture('announcements') as Json)['data'] as List;
      final open = Announcement.fromJson({...(raw[3] as Json), 'acknowledged': false});
      expect(open.needsAck, isTrue);
      expect(a.first.copyWith(read: true).read, isTrue);
      final c = AnnouncementCounts.fromJson(fixture('announcement_counts') as Json);
      expect(c.unread, greaterThanOrEqualTo(0));
    });

    test('events with per-child consent', () {
      final e = SchoolEvent.fromJson(fixture('event_consent') as Json);
      expect(e.consentRequired, isTrue);
      expect(e.children, hasLength(1));
      expect(e.children.first.response, 'consent_given');
      expect(e.needsResponse, isFalse);
      final fresh = SchoolEvent.fromJson({...(fixture('event_consent') as Json), 'children': [{'studentId': 's1', 'studentName': 'A', 'response': null}]});
      expect(fresh.needsResponse, isTrue);
      expect(e.kindLabel, isNotEmpty);
      final all = jsonList((fixture('events_parent') as Json)['data']).map(SchoolEvent.fromJson).toList();
      expect(all.any((x) => x.registrationRequired), isTrue);
    });

    test('meetings', () {
      final m = Paged.parse(fixture('meetings'), Meeting.fromJson).items;
      expect(m.map((x) => x.status), containsAll(['requested', 'confirmed', 'cancelled']));
      expect(m.firstWhere((x) => x.status == 'requested').canCancel, isTrue);
      expect(m.firstWhere((x) => x.status == 'cancelled').canCancel, isFalse);
      expect(m.firstWhere((x) => x.status == 'confirmed').open, isTrue);
      expect(m.first.teacherName, isNotEmpty);
      final t = jsonList((fixture('meeting_teachers') as Json)['data']).map(MeetingTeacher.fromJson).toList();
      expect(t.any((x) => x.isClassTeacher), isTrue);
    });

    test('notifications and preferences', () {
      final n = CursorPage.parse(fixture('notifications'), AppNotification.fromJson);
      expect(n.items.first.title, isNotEmpty);
      expect(n.items.first.route, isNotNull);
      expect(n.items.first.asRead().read, isTrue);
      final prefs = jsonList((fixture('notification_prefs') as Json)['categories']).map(NotificationPref.fromJson).toList();
      expect(prefs.length, greaterThan(3));
      expect(prefs.first.copyWith(push: false).push, isFalse);
    });
  });

  group('learning and profile', () {
    test('materials and syllabus', () {
      final m = Paged.parse(fixture('materials'), StudyMaterial.fromJson).items;
      expect(m.first.fileId != null || m.first.url != null, isTrue);
      final s = jsonList((fixture('syllabus') as Json)['data']).map(SyllabusTopic.fromJson).toList();
      expect(s, isNotEmpty);
      expect(s.first.status, anyOf('not_started', 'in_progress', 'completed'));
    });

    test('library, bus and profile', () {
      final loans = jsonList((fixture('library') as Json)['data']).map(LibraryLoan.fromJson).toList();
      expect(loans.any((l) => l.overdue && l.fineMinor > 0), isTrue);
      final bus = jsonList((fixture('bus') as Json)['data']).map(BusAllocation.fromJson).toList();
      expect(bus.first.allocated, isTrue);
      expect(bus.first.routeName, isNotNull);
      final p = ProfileDetails.fromJson(fixture('profile_student') as Json);
      expect(p.displayName, isNotEmpty);
      expect(p.address, contains('Bengaluru'));
      expect(p.emergency.first.contacts, isNotEmpty);
    });
  });
}
