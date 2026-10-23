import '../json.dart';
import 'announcements.dart';
import 'attendance.dart';
import 'homework.dart';
import 'meetings.dart';
import 'schedule.dart';
import 'tasks.dart';

class DashboardExam {
  const DashboardExam({required this.examName, required this.subject, this.date, this.startTime, this.endTime, this.room});
  final String examName;
  final String subject;
  final DateTime? date;
  final String? startTime;
  final String? endTime;
  final String? room;
  factory DashboardExam.fromJson(Json j) => DashboardExam(examName: jStrOr(j['examName']), subject: jStrOr(j['subject']), date: jDay(j['date']), startTime: jStr(j['startTime']), endTime: jStr(j['endTime']), room: jStr(j['room']));
}

class PublishedResultRef {
  const PublishedResultRef({required this.examId, required this.examName, this.publishedAt});
  final String examId;
  final String examName;
  final DateTime? publishedAt;
  factory PublishedResultRef.fromJson(Json j) => PublishedResultRef(examId: jStrOr(j['examId']), examName: jStrOr(j['examName']), publishedAt: jDate(j['publishedAt']));
}

class HomeworkSnapshot {
  const HomeworkSnapshot({this.pendingCount = 0, this.overdueCount = 0, this.items = const []});
  final int pendingCount;
  final int overdueCount;
  final List<Homework> items;
  factory HomeworkSnapshot.fromJson(Json j) => HomeworkSnapshot(pendingCount: jInt(j['pendingCount']), overdueCount: jInt(j['overdueCount']), items: jsonList(j['items']).map(Homework.fromJson).toList(growable: false));
}

class AnnouncementsSnapshot {
  const AnnouncementsSnapshot({this.unreadCount = 0, this.pendingAckCount = 0, this.latest = const []});
  final int unreadCount;
  final int pendingAckCount;
  final List<Announcement> latest;
  factory AnnouncementsSnapshot.fromJson(Json j) => AnnouncementsSnapshot(unreadCount: jInt(j['unreadCount']), pendingAckCount: jInt(j['pendingAckCount']), latest: jsonList(j['latest']).map(Announcement.fromJson).toList(growable: false));
}

class StudentRef {
  const StudentRef({required this.id, required this.name, this.admissionNo, this.grade, this.section});
  final String id;
  final String name;
  final String? admissionNo;
  final String? grade;
  final String? section;
  String get classLabel => [grade, section].whereType<String>().where((s) => s.isNotEmpty).join(' - ');
  factory StudentRef.fromJson(Json j) => StudentRef(id: jStrOr(j['id']), name: jStrOr(j['name']), admissionNo: jStr(j['admissionNo']), grade: jStr(j['grade']), section: jStr(j['section']));
}

/// The day of one student: what both the student home and a parent's selected child show.
class ChildDay {
  const ChildDay({
    required this.student,
    required this.timetable,
    required this.homework,
    required this.upcomingExams,
    required this.publishedResults,
    this.attendance,
    this.attendanceToday,
  });

  final StudentRef student;
  final AttendanceSummary? attendance;
  final AttendanceStatus? attendanceToday;
  final TimetableDay? timetable;
  final HomeworkSnapshot homework;
  final List<DashboardExam> upcomingExams;
  final List<PublishedResultRef> publishedResults;

  factory ChildDay.fromJson(Json j) {
    final att = j['attendance'];
    final tt = j['timetable'];
    return ChildDay(
      student: StudentRef.fromJson(jsonMap(j['student'])),
      attendance: att is Map ? AttendanceSummary.fromJson(jsonMap(att)) : null,
      attendanceToday: AttendanceStatus.parse(jStr(j['attendanceToday'])),
      timetable: tt is Map ? TimetableDay.fromJson(jsonMap(tt)) : null,
      homework: HomeworkSnapshot.fromJson(jsonMap(j['homework'])),
      upcomingExams: jsonList(j['upcomingExams']).map(DashboardExam.fromJson).toList(growable: false),
      publishedResults: jsonList(j['publishedResults']).map(PublishedResultRef.fromJson).toList(growable: false),
    );
  }
}

class StudentDashboard {
  const StudentDashboard({required this.day, required this.tasks, required this.announcements, required this.calendar, required this.unreadNotifications, required this.fetchedAt, this.fromCache = false});
  final ChildDay day;
  final List<TaskFeedItem> tasks;
  final AnnouncementsSnapshot announcements;
  final List<CalendarItem> calendar;
  final int unreadNotifications;
  final DateTime fetchedAt;

  /// True when the server could not be reached and the last saved copy is shown.
  final bool fromCache;

  factory StudentDashboard.fromJson(Json j, {DateTime? at, bool fromCache = false}) => StudentDashboard(
    fromCache: fromCache,
    day: ChildDay.fromJson(j),
    tasks: jsonList(j['tasks']).map(TaskFeedItem.fromJson).toList(growable: false),
    announcements: AnnouncementsSnapshot.fromJson(jsonMap(j['announcements'])),
    calendar: jsonList(j['calendar']).map(CalendarItem.fromJson).toList(growable: false),
    unreadNotifications: jInt(jsonMap(j['notifications'])['unreadCount']),
    fetchedAt: at ?? DateTime.now(),
  );
}

class ChildOverview {
  const ChildOverview({required this.student, this.attendanceToday, this.attendancePercentage, this.outstandingMinor = 0, this.overdueCount = 0});
  final StudentRef student;
  final AttendanceStatus? attendanceToday;
  final double? attendancePercentage;
  final int outstandingMinor;
  final int overdueCount;
  factory ChildOverview.fromJson(Json j) => ChildOverview(student: StudentRef.fromJson(jsonMap(j['student'])), attendanceToday: AttendanceStatus.parse(jStr(j['attendanceToday'])), attendancePercentage: jDoubleN(j['attendancePercentage']), outstandingMinor: jInt(j['outstandingMinor']), overdueCount: jInt(j['overdueCount']));
}

class FeesSnapshot {
  const FeesSnapshot({required this.currency, this.outstandingMinor = 0, this.overdueMinor = 0, this.overdueCount = 0, this.nextDueTitle, this.nextDueDate, this.nextDueBalanceMinor, this.nextDueInvoiceId});
  final String currency;
  final int outstandingMinor;
  final int overdueMinor;
  final int overdueCount;
  final String? nextDueTitle;
  final DateTime? nextDueDate;
  final int? nextDueBalanceMinor;
  final String? nextDueInvoiceId;

  factory FeesSnapshot.fromJson(Json j) {
    final n = j['nextDue'] is Map ? jsonMap(j['nextDue']) : null;
    return FeesSnapshot(
      currency: jStrOr(j['currency'], 'INR'),
      outstandingMinor: jInt(j['outstandingMinor']),
      overdueMinor: jInt(j['overdueMinor']),
      overdueCount: jInt(j['overdueCount']),
      nextDueTitle: n == null ? null : jStr(n['title']),
      nextDueDate: n == null ? null : jDay(n['dueDate']),
      nextDueBalanceMinor: n == null ? null : jIntN(n['balanceMinor']),
      nextDueInvoiceId: n == null ? null : jStr(n['invoiceId']),
    );
  }
}

class ParentDashboard {
  const ParentDashboard({required this.selectedStudentId, required this.children, required this.child, required this.fees, required this.meetings, required this.pendingLeaveCount, required this.announcements, required this.calendar, required this.unreadNotifications, required this.fetchedAt, this.fromCache = false});
  final String? selectedStudentId;
  final List<ChildOverview> children;
  final ChildDay? child;
  final FeesSnapshot? fees;
  final List<Meeting> meetings;
  final int pendingLeaveCount;
  final AnnouncementsSnapshot announcements;
  final List<CalendarItem> calendar;
  final int unreadNotifications;
  final DateTime fetchedAt;
  final bool fromCache;

  factory ParentDashboard.fromJson(Json j, {DateTime? at, bool fromCache = false}) => ParentDashboard(
    fromCache: fromCache,
    selectedStudentId: jStr(j['selectedStudentId']),
    children: jsonList(j['children']).map(ChildOverview.fromJson).toList(growable: false),
    child: j['child'] is Map ? ChildDay.fromJson(jsonMap(j['child'])) : null,
    fees: j['fees'] is Map ? FeesSnapshot.fromJson(jsonMap(j['fees'])) : null,
    meetings: jsonList(j['meetings']).map(Meeting.fromJson).toList(growable: false),
    pendingLeaveCount: jInt(j['pendingLeaveCount']),
    announcements: AnnouncementsSnapshot.fromJson(jsonMap(j['announcements'])),
    calendar: jsonList(j['calendar']).map(CalendarItem.fromJson).toList(growable: false),
    unreadNotifications: jInt(jsonMap(j['notifications'])['unreadCount']),
    fetchedAt: at ?? DateTime.now(),
  );
}
