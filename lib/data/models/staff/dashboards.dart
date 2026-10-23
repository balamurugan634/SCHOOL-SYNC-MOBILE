import '../../json.dart';
import '../announcements.dart';
import '../schedule.dart' show CalendarItem;
import 'comms.dart';
import 'finance.dart';
import 'roll_call.dart';
import 'teaching.dart';

class MarksTodo {
  const MarksTodo({required this.sheetId, required this.examName, required this.sectionName, required this.subject, required this.status});
  final String sheetId;
  final String examName;
  final String sectionName;
  final String subject;

  /// draft | returned
  final String status;

  bool get returned => status == 'returned';

  factory MarksTodo.fromJson(Json j) => MarksTodo(sheetId: jStrOr(j['sheetId']), examName: jStrOr(j['examName']), sectionName: jStrOr(j['sectionName']), subject: jStrOr(j['subject']), status: jStrOr(j['status'], 'draft'));
}

class AnnouncementsBlock {
  const AnnouncementsBlock({this.unreadCount = 0, this.pendingAckCount = 0, this.latest = const []});
  final int unreadCount;
  final int pendingAckCount;
  final List<Announcement> latest;

  factory AnnouncementsBlock.fromJson(Object? v) {
    final j = jsonMap(v);
    return AnnouncementsBlock(unreadCount: jInt(j['unreadCount']), pendingAckCount: jInt(j['pendingAckCount']), latest: jsonList(j['latest']).map(Announcement.fromJson).toList(growable: false));
  }
}

/// `GET /dashboard/teacher`.
class TeacherDashboard {
  const TeacherDashboard({
    required this.date,
    required this.staffName,
    this.designation,
    required this.attendance,
    required this.timetable,
    this.toReviewCount = 0,
    this.dueSoon = const [],
    this.marksPending = 0,
    this.marksReturned = 0,
    this.marks = const [],
    this.pendingLeaveCount = 0,
    this.meetings = const [],
    this.announcements = const AnnouncementsBlock(),
    this.calendar = const [],
    this.unreadNotifications = 0,
  });

  final DateTime date;
  final String staffName;
  final String? designation;
  final AttendanceToday attendance;
  final TeacherDay timetable;
  final int toReviewCount;
  final List<HomeworkEntry> dueSoon;
  final int marksPending;
  final int marksReturned;
  final List<MarksTodo> marks;
  final int pendingLeaveCount;
  final List<StaffMeeting> meetings;
  final AnnouncementsBlock announcements;
  final List<CalendarItem> calendar;
  final int unreadNotifications;

  factory TeacherDashboard.fromJson(Json j) {
    final staff = jsonMap(j['staff']);
    final hw = jsonMap(j['homework']);
    final marks = jsonMap(j['marks']);
    return TeacherDashboard(
      date: jDay(j['date']) ?? DateTime.now(),
      staffName: jStrOr(staff['name']),
      designation: jStr(staff['designation']),
      attendance: AttendanceToday.fromJson(jsonMap(j['attendance'])),
      timetable: TeacherDay.fromJson(jsonMap(j['timetable'])),
      toReviewCount: jInt(hw['toReviewCount']),
      dueSoon: jsonList(hw['dueSoon']).map(HomeworkEntry.fromJson).toList(growable: false),
      marksPending: jInt(marks['pendingCount']),
      marksReturned: jInt(marks['returnedCount']),
      marks: jsonList(marks['items']).map(MarksTodo.fromJson).toList(growable: false),
      pendingLeaveCount: jInt(j['pendingLeaveCount']),
      meetings: jsonList(j['meetings']).map(StaffMeeting.fromJson).toList(growable: false),
      announcements: AnnouncementsBlock.fromJson(j['announcements']),
      calendar: jsonList(j['calendar']).map(CalendarItem.fromJson).toList(growable: false),
      unreadNotifications: jInt(jsonMap(j['notifications'])['unreadCount']),
    );
  }
}

class DashboardKpis {
  const DashboardKpis({this.students = 0, this.staff = 0, this.parents = 0, this.sections = 0, this.grades = 0});
  final int students;
  final int staff;
  final int parents;
  final int sections;
  final int grades;

  factory DashboardKpis.fromJson(Object? v) {
    final j = jsonMap(v);
    return DashboardKpis(students: jInt(j['students']), staff: jInt(j['staff']), parents: jInt(j['parents']), sections: jInt(j['sections']), grades: jInt(j['grades']));
  }
}

/// Counts waiting for a decision; each is null when the caller cannot act on that queue.
class ApprovalCounts {
  const ApprovalCounts({this.studentLeave, this.staffLeave, this.attendanceCorrections, this.markSheetsForReview, this.admissions, this.correctionRequests, this.concessions, this.refunds, this.expenses});
  final int? studentLeave;
  final int? staffLeave;
  final int? attendanceCorrections;
  final int? markSheetsForReview;
  final int? admissions;
  final int? correctionRequests;
  final int? concessions;
  final int? refunds;
  final int? expenses;

  int get total => [studentLeave, staffLeave, attendanceCorrections, markSheetsForReview, admissions, correctionRequests, concessions, refunds, expenses].fold(0, (a, b) => a + (b ?? 0));
  bool get anyVisible => [studentLeave, staffLeave, attendanceCorrections, markSheetsForReview, admissions, correctionRequests, concessions, refunds, expenses].any((e) => e != null);

  factory ApprovalCounts.fromJson(Object? v) {
    final j = jsonMap(v);
    return ApprovalCounts(
      studentLeave: jIntN(j['studentLeave']),
      staffLeave: jIntN(j['staffLeave']),
      attendanceCorrections: jIntN(j['attendanceCorrections']),
      markSheetsForReview: jIntN(j['markSheetsForReview']),
      admissions: jIntN(j['admissions']),
      correctionRequests: jIntN(j['correctionRequests']),
      concessions: jIntN(j['concessions']),
      refunds: jIntN(j['refunds']),
      expenses: jIntN(j['expenses']),
    );
  }
}

class DashboardAlert {
  const DashboardAlert({required this.key, required this.severity, required this.message, this.count, this.route});
  final String key;

  /// info | warning | critical
  final String severity;
  final String message;
  final int? count;
  final String? route;
  factory DashboardAlert.fromJson(Json j) => DashboardAlert(key: jStrOr(j['key']), severity: jStrOr(j['severity'], 'info'), message: jStrOr(j['message']), count: jIntN(j['count']), route: jStr(j['route']));
}

class GradeEnrollment {
  const GradeEnrollment({required this.grade, this.students = 0});
  final String grade;
  final int students;
  factory GradeEnrollment.fromJson(Json j) => GradeEnrollment(grade: jStrOr(j['grade']), students: jInt(j['students']));
}

class UpcomingExam {
  const UpcomingExam({required this.examId, required this.name, this.startDate, required this.status});
  final String examId;
  final String name;
  final DateTime? startDate;
  final String status;
  factory UpcomingExam.fromJson(Json j) => UpcomingExam(examId: jStrOr(j['examId']), name: jStrOr(j['name']), startDate: jDay(j['startDate']), status: jStrOr(j['status']));
}

class LicenseInfo {
  const LicenseInfo({required this.state, this.readOnly = false, this.endsOn, this.graceEndsOn, this.daysLeft, this.seatsUsed = 0, this.seatsLicensed, this.nearLimit = false, this.overBy = 0});

  /// unlicensed | trial | active | grace | expired | cancelled
  final String state;
  final bool readOnly;
  final DateTime? endsOn;
  final DateTime? graceEndsOn;
  final int? daysLeft;
  final int seatsUsed;
  final int? seatsLicensed;
  final bool nearLimit;
  final int overBy;

  /// Worth telling an administrator about.
  bool get needsAttention => readOnly || nearLimit || overBy > 0 || state == 'grace' || state == 'expired' || state == 'cancelled' || (daysLeft != null && daysLeft! <= 30);

  factory LicenseInfo.fromJson(Json j) {
    final seats = jsonMap(j['seats']);
    return LicenseInfo(
      state: jStrOr(j['state'], 'active'),
      readOnly: jBool(j['readOnly']),
      endsOn: jDay(j['endsOn']),
      graceEndsOn: jDay(j['graceEndsOn']),
      daysLeft: jIntN(j['daysLeft']),
      seatsUsed: jInt(seats['used']),
      seatsLicensed: jIntN(seats['licensed']),
      nearLimit: jBool(seats['nearLimit']),
      overBy: jInt(seats['overBy']),
    );
  }
}

/// `GET /dashboard/management`. Blocks the caller may not see are null.
class ManagementDashboard {
  const ManagementDashboard({
    required this.date,
    this.kpis = const DashboardKpis(),
    this.attendance,
    this.approvals = const ApprovalCounts(),
    this.finance,
    this.upcomingExams,
    this.examsUnderReview = 0,
    this.enrollmentByGrade = const [],
    this.license,
    this.alerts = const [],
    this.announcements = const AnnouncementsBlock(),
    this.unreadNotifications = 0,
  });

  final DateTime date;
  final DashboardKpis kpis;
  final SchoolAttendance? attendance;
  final ApprovalCounts approvals;
  final FinanceSummary? finance;
  final List<UpcomingExam>? upcomingExams;
  final int examsUnderReview;
  final List<GradeEnrollment> enrollmentByGrade;
  final LicenseInfo? license;
  final List<DashboardAlert> alerts;
  final AnnouncementsBlock announcements;
  final int unreadNotifications;

  factory ManagementDashboard.fromJson(Json j) {
    final exams = j['exams'] is Map ? jsonMap(j['exams']) : null;
    return ManagementDashboard(
      date: jDay(j['date']) ?? DateTime.now(),
      kpis: DashboardKpis.fromJson(j['kpis']),
      attendance: j['attendance'] is Map ? SchoolAttendance.fromJson(jsonMap(j['attendance'])) : null,
      approvals: ApprovalCounts.fromJson(j['approvals']),
      finance: j['finance'] is Map ? FinanceSummary.fromJson(jsonMap(j['finance'])) : null,
      upcomingExams: exams == null ? null : jsonList(exams['upcoming']).map(UpcomingExam.fromJson).toList(growable: false),
      examsUnderReview: exams == null ? 0 : jInt(exams['underReviewCount']),
      enrollmentByGrade: jsonList(j['enrollmentByGrade']).map(GradeEnrollment.fromJson).toList(growable: false),
      license: j['license'] is Map ? LicenseInfo.fromJson(jsonMap(j['license'])) : null,
      alerts: jsonList(j['alerts']).map(DashboardAlert.fromJson).toList(growable: false),
      announcements: AnnouncementsBlock.fromJson(j['announcements']),
      unreadNotifications: jInt(jsonMap(j['notifications'])['unreadCount']),
    );
  }
}
