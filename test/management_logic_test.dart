import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/data/models/me.dart';
import 'package:schoolsync/data/models/staff/dashboards.dart';
import 'package:schoolsync/data/models/staff/finance.dart';
import 'package:schoolsync/data/models/staff/people.dart';
import 'package:schoolsync/data/models/staff/roll_call.dart';
import 'package:schoolsync/data/json.dart';
import 'package:schoolsync/data/models/staff/teaching.dart';
import 'package:schoolsync/features/management/academics/academics_providers.dart';
import 'package:schoolsync/features/management/approvals/approval_kinds.dart';
import 'package:schoolsync/features/management/attendance/attendance_providers.dart';
import 'package:schoolsync/features/management/charts/chart_text.dart';
import 'package:schoolsync/features/management/finance/finance_providers.dart';
import 'package:schoolsync/features/management/people/people_providers.dart';
import 'package:schoolsync/router/routes_management.dart';

import 'management_test_support.dart';
import 'staff_test_support.dart';

ManagementDashboard dash(String who) => ManagementDashboard.fromJson(fixture('mgmt_dashboard_$who'));

void main() {
  group('approval kinds', () {
    test('every ApprovalKind constant has a spec, in the same order as the routes file', () {
      expect([for (final s in approvalSpecs) s.kind], ApprovalKind.all);
      for (final k in ApprovalKind.all) {
        expect(approvalSpecFor(k), isNotNull, reason: k);
      }
      expect(approvalSpecFor('nonsense'), isNull);
    });

    test('paths round-trip through the routes helper', () {
      expect(ManagementRoutes.approval(ApprovalKind.studentLeave), '/management/approvals/student-leave');
      expect(ManagementRoutes.approval(ApprovalKind.marks), '/management/approvals/marks');
    });

    test('every queue names its permission pair and a default status filter', () {
      for (final s in approvalSpecs) {
        expect(s.actPermission, endsWith(':approve'), reason: s.kind);
        expect(s.viewAny, isNotEmpty, reason: s.kind);
        expect(s.statuses, isNotEmpty, reason: s.kind);
      }
      expect(approvalSpecFor(ApprovalKind.marks)!.statuses.first.$1, 'submitted');
      expect(approvalSpecFor(ApprovalKind.refunds)!.statuses.first.$1, 'requested');
      expect(approvalSpecFor(ApprovalKind.admissions)!.statuses.first.$1, 'submitted');
    });

    test('fee queues exist only when the school has fees', () {
      for (final k in [ApprovalKind.concessions, ApprovalKind.refunds, ApprovalKind.expenses]) {
        expect(approvalSpecFor(k)!.needsFees, isTrue, reason: k);
      }
      expect(approvalSpecFor(ApprovalKind.studentLeave)!.needsFees, isFalse);
    });
  });

  group('approvals visibility (null counts are hidden)', () {
    List<String> kinds(String who, Me me, {bool fees = true}) => [for (final (s, _) in visibleQueues(dash(who).approvals, me, feesEnabled: fees)) s.kind];

    test('principal: leave, corrections, marks, admissions; no fee queues', () {
      final k = kinds('principal', meFixture('principal'));
      expect(k, [ApprovalKind.studentLeave, ApprovalKind.staffLeave, ApprovalKind.attendance, ApprovalKind.marks, ApprovalKind.admissions]);
    });

    test('office: student leave and admissions only', () {
      expect(kinds('office', meFixture('mgmt_me_office')), [ApprovalKind.studentLeave, ApprovalKind.admissions]);
    });

    test('accounts: the three fee queues only, and none when fees are off', () {
      final me = meFixture('mgmt_me_accounts');
      expect(kinds('accounts', me), [ApprovalKind.concessions, ApprovalKind.refunds, ApprovalKind.expenses]);
      expect(kinds('accounts', me, fees: false), isEmpty);
    });

    test('administrator sees every queue', () {
      expect(kinds('admin', meFixture('management')), ApprovalKind.all);
    });

    test('a count the API sent is still hidden without the permission to open the queue', () {
      final me = meFixture('mgmt_me_accounts');
      expect(visibleQueues(dash('admin').approvals, me, feesEnabled: true).map((q) => q.$1.kind), [ApprovalKind.concessions, ApprovalKind.refunds, ApprovalKind.expenses]);
    });

    test('actions follow the approve permission, viewing follows view or approve', () {
      final principal = meFixture('principal');
      expect(approvalSpecFor(ApprovalKind.marks)!.canAct(principal), isTrue);
      expect(approvalSpecFor(ApprovalKind.expenses)!.canAct(principal), isFalse);
      expect(approvalSpecFor(ApprovalKind.expenses)!.canView(principal), isTrue, reason: 'principal holds expenses:view');
      expect(approvalSpecFor(ApprovalKind.concessions)!.canView(principal), isTrue, reason: 'principal holds fees:view');
      expect(canOpenApproval(approvalSpecFor(ApprovalKind.concessions)!, principal, feesEnabled: false), isFalse);
      final office = meFixture('mgmt_me_office');
      expect(approvalSpecFor(ApprovalKind.staffLeave)!.canView(office), isFalse);
    });

    test('totals count only non-null queues', () {
      expect(dash('accounts').approvals.total, 5);
      expect(dash('accounts').approvals.anyVisible, isTrue);
      expect(const ApprovalCounts().anyVisible, isFalse);
    });
  });

  group('alert routes', () {
    test('known server routes map to app screens; unknown ones are not links', () {
      expect(appRouteForAlert('/attendance'), ManagementRoutes.attendance);
      expect(appRouteForAlert('/leave'), ManagementRoutes.approval(ApprovalKind.studentLeave));
      expect(appRouteForAlert('/staff-leave/123'), ManagementRoutes.approval(ApprovalKind.staffLeave));
      expect(appRouteForAlert('/admissions'), ManagementRoutes.approval(ApprovalKind.admissions));
      expect(appRouteForAlert('/fees/reports/defaulters'), '/tab/3');
      expect(appRouteForAlert('/transport/vehicles'), isNull);
      expect(appRouteForAlert('/settings/license'), isNull);
      expect(appRouteForAlert(null), isNull);
      expect(appRouteForAlert('attendance'), isNull);
    });

    test('the real alerts of the dev school', () {
      final routes = {for (final a in dash('principal').alerts) a.key: appRouteForAlert(a.route)};
      expect(routes['attendance_unmarked'], ManagementRoutes.attendance);
      expect(routes['insurance_expiring'], isNull);
    });
  });

  group('admission moves', () {
    List<String> to(String from, {bool edit = true, bool approve = true}) => [for (final m in admissionMoves(from, canEdit: edit, canApprove: approve)) m.to];

    test('mirror the API transition table', () {
      expect(to('submitted'), ['under_review', 'rejected']);
      expect(to('under_review'), ['waitlisted', 'accepted', 'rejected']);
      expect(to('waitlisted'), ['under_review', 'accepted', 'rejected']);
      expect(to('accepted'), ['rejected']);
      expect(to('rejected'), ['under_review']);
      expect(to('enrolled'), isEmpty);
    });

    test('starting a review needs admissions:edit, every other move needs admissions:approve', () {
      expect(to('submitted', edit: false), ['rejected']);
      expect(to('submitted', approve: false), ['under_review']);
      expect(to('under_review', approve: false), isEmpty);
      expect(to('waitlisted', edit: true, approve: false), isEmpty, reason: 'reopening review from the waiting list is an approval');
    });

    test('rejecting needs a reason and is styled as destructive', () {
      final reject = admissionMoves('under_review', canEdit: true, canApprove: true).firstWhere((m) => m.to == 'rejected');
      expect(reject.noteRequired, isTrue);
      expect(reject.destructive, isTrue);
      expect(admissionMoves('under_review', canEdit: true, canApprove: true).firstWhere((m) => m.to == 'accepted').noteRequired, isFalse);
    });
  });

  group('charts: text summaries', () {
    test('attendance trend sentence names the average and the extremes', () {
      final points = [
        for (final (d, p) in [('2026-10-19', 95.2), ('2026-10-20', 94.8), ('2026-10-21', 96.6)]) TrendPoint(date: DateTime.parse(d), counts: const StatusCounts(), percentPresent: p),
      ];
      final s = attendanceTrendSummary(points);
      expect(s, contains('Average 95.5% present over 3 days'));
      expect(s, contains('lowest 94.8% on Tue'));
      expect(s, contains('highest 96.6% on Wed'));
    });

    test('trend summary with nothing or one day', () {
      expect(attendanceTrendSummary(const []), contains('No attendance'));
      final one = attendanceTrendSummary([TrendPoint(date: DateTime(2026, 10, 21), counts: const StatusCounts(), percentPresent: 96)]);
      expect(one, contains('Only one day'));
      expect(attendanceTrendSummary([TrendPoint(date: DateTime(2026, 10, 21), counts: const StatusCounts())]), contains('No attendance'));
    });

    test('the real 7-day trend summarises', () {
      final s = attendanceTrendSummary(dash('principal').attendance!.trend);
      expect(s, startsWith('Average'));
      expect(s, contains('lowest'));
    });

    test('monthly money summary names the best month and the total', () {
      const months = [MonthMoney(month: '2026-08', collectedMinor: 0), MonthMoney(month: '2026-09', collectedMinor: 25603780), MonthMoney(month: '2026-10', collectedMinor: 4510000)];
      final s = monthlyMoneySummary(months, 'INR');
      expect(s, contains('Collected most in Sep (₹2,56,037.80)'));
      expect(s, contains('over 3 months'));
      expect(monthlyMoneySummary(const [], 'INR'), contains('No payments'));
    });

    test('counts sentence for screen readers', () {
      expect(attendanceCountsSummary(const StatusCounts(present: 179, absent: 5, late: 5, halfDay: 3)), '179 present, 5 absent, 5 late, 0 on leave, 3 half-day');
    });

    test('month labels', () {
      expect(monthLabel('2026-09'), 'Sep');
      expect(monthLabel('weird'), 'weird');
    });
  });

  group('licence notice (administrators only)', () {
    LicenseInfo lic({String state = 'active', bool readOnly = false, int? daysLeft = 200, int used = 240, int? licensed = 500, bool near = false, int over = 0, DateTime? grace}) =>
        LicenseInfo(state: state, readOnly: readOnly, daysLeft: daysLeft, seatsUsed: used, seatsLicensed: licensed, nearLimit: near, overBy: over, graceEndsOn: grace);

    test('nothing to say when the licence is healthy', () {
      expect(licenseNotice(null), isNull);
      expect(licenseNotice(lic()), isNull);
      expect(licenseNotice(dash('admin').license), isNull, reason: 'dev school: 161 days left, 240 of 500 seats');
    });

    test('explains read-only, grace, seats and days left', () {
      expect(licenseNotice(lic(state: 'expired', readOnly: true))!.critical, isTrue);
      expect(licenseNotice(lic(state: 'expired', readOnly: true))!.message, contains('view-only'));
      expect(licenseNotice(lic(state: 'grace', grace: DateTime(2027, 4, 30)))!.message, contains('30 Apr 2027'));
      expect(licenseNotice(lic(near: true, used: 480))!.title, contains('almost used up'));
      expect(licenseNotice(lic(over: 12, used: 512))!.message, contains('12 over'));
      expect(licenseNotice(lic(daysLeft: 12))!.message, 'The subscription ends in 12 days.');
      expect(licenseNotice(lic(daysLeft: 1))!.message, 'The subscription ends in 1 day.');
    });
  });

  group('lists and grouping', () {
    test('attendance sections: unmarked first, then by name', () {
      const rows = [
        SchoolSectionRow(sectionId: '1', name: 'B', gradeName: 'Grade 7', marked: true),
        SchoolSectionRow(sectionId: '2', name: 'A', gradeName: 'Grade 8', marked: false),
        SchoolSectionRow(sectionId: '3', name: 'A', gradeName: 'Grade 6', marked: true),
        SchoolSectionRow(sectionId: '4', name: 'B', gradeName: 'Grade 6', marked: false),
      ];
      expect([for (final r in sortSectionRows(rows)) r.sectionId], ['4', '2', '3', '1']);
      expect(rows.first.sectionId, '1', reason: 'input is not mutated');
    });

    test('sections group by grade in school order', () {
      final sections = Paged.parse(fixture('mgmt_sections_all'), SectionItem.fromJson).items;
      final groups = groupSectionsByGrade(sections);
      expect(groups.map((g) => g.$1), orderedEquals([...groups.map((g) => g.$1)]));
      final ordinals = [for (final g in groups) g.$2.first.gradeOrdinal];
      expect(ordinals, [...ordinals]..sort());
      for (final g in groups) {
        expect([for (final s in g.$2) s.name], [...g.$2.map((s) => s.name)]..sort());
      }
    });

    test('coverage aggregates per grade and subject, lowest first, weighted by topics', () {
      const rows = [
        CoverageRow(sectionId: 'a', sectionName: 'A', gradeId: 'g', gradeName: 'Grade 6', subjectId: 's', subjectName: 'Math', totalTopics: 10, completed: 8, percent: 80),
        CoverageRow(sectionId: 'b', sectionName: 'B', gradeId: 'g', gradeName: 'Grade 6', subjectId: 's', subjectName: 'Math', totalTopics: 10, completed: 2, percent: 20),
        CoverageRow(sectionId: 'a', sectionName: 'A', gradeId: 'g', gradeName: 'Grade 6', subjectId: 't', subjectName: 'Art', totalTopics: 8, completed: 1, percent: 12.5),
      ];
      final agg = aggregateCoverage(rows);
      expect(agg.map((e) => e.subjectName), ['Art', 'Math']);
      expect(agg.last.percent, 50);
      expect(agg.last.sections, 2);
      expect(aggregateCoverage([for (final j in (fixture('mgmt_coverage')['data'] as List)) CoverageRow.fromJson((j as Map).cast())]), isNotEmpty);
    });

    test('student search only goes to the API for 2+ characters or a grade', () {
      expect(studentQueryActive((q: '', gradeId: null)), isFalse);
      expect(studentQueryActive((q: 's', gradeId: null)), isFalse);
      expect(studentQueryActive((q: ' s ', gradeId: null)), isFalse);
      expect(studentQueryActive((q: 'sh', gradeId: null)), isTrue);
      expect(studentQueryActive((q: '', gradeId: 'g1')), isTrue);
    });

    test('finance labels', () {
      expect(paymentMethodLabel('upi'), 'UPI');
      expect(paymentMethodLabel('bank_transfer'), 'Bank transfer');
      expect(paymentMethodLabel('wallet'), 'Wallet');
      final lines = agingLines(const AgingBuckets(notDue: 1, d1to30: 2, d31to60: 3, d61to90: 4, d90plus: 5));
      expect(lines.map((l) => l.$2), [1, 2, 3, 4, 5]);
      expect(lines.first.$1, 'Not due yet');
    });
  });

  group('real dashboards of the four management users parse', () {
    test('administrator has a licence block and every approval count', () {
      final d = dash('admin');
      expect(d.license, isNotNull);
      expect(d.license!.seatsLicensed, 500);
      expect(d.finance, isNotNull);
      expect(d.attendance, isNotNull);
      expect(d.approvals.concessions, isNotNull);
    });

    test('office: no finance but a licence block (settings:view); accounts: no attendance, no exams, no licence', () {
      final o = dash('office');
      expect(o.finance, isNull);
      expect(o.license, isNotNull);
      expect(o.approvals.staffLeave, isNull);
      final a = dash('accounts');
      expect(a.attendance, isNull);
      expect(a.upcomingExams, isNull);
      expect(a.license, isNull);
      expect(a.finance!.expensesMinor, isNotNull);
      expect(a.kpis.students, greaterThan(0));
    });

    test('14-day summary, staff detail and workload', () {
      final s = SchoolAttendance.fromJson(fixture('mgmt_summary14'));
      expect(s.trend, isNotEmpty);
      final d = StaffDetail.fromJson(fixture('mgmt_staff_detail'));
      expect(d.member.name, isNotEmpty);
      expect(d.joinDate, isNotNull);
      final w = StaffWorkload.fromJson(fixture('mgmt_staff_workload'));
      expect(w.periodsPerWeek, greaterThan(0));
      expect(w.assignments, isNotEmpty);
    });
  });
}
