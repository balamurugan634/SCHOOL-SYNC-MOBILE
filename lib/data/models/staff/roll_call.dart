import '../../json.dart';
import '../attendance.dart';

// Staff-side attendance models (roll call, corrections, school overview). Learner-side summaries
// (`AttendanceSummary`, `AttendanceRecord`, `AttendanceCounts`) live in ../attendance.dart and are reused here.

/// present / absent / late / leave / half-day counts of one roll call or day.
class StatusCounts {
  const StatusCounts({this.present = 0, this.absent = 0, this.late = 0, this.leave = 0, this.halfDay = 0, this.unmarked = 0});

  final int present;
  final int absent;
  final int late;
  final int leave;
  final int halfDay;

  /// Only the roster response carries this.
  final int unmarked;

  int get marked => present + absent + late + leave + halfDay;

  int of(AttendanceStatus s) => switch (s) {
    AttendanceStatus.present => present,
    AttendanceStatus.absent => absent,
    AttendanceStatus.late => late,
    AttendanceStatus.leave => leave,
    AttendanceStatus.halfDay => halfDay,
  };

  factory StatusCounts.fromJson(Object? v) {
    final j = jsonMap(v);
    return StatusCounts(present: jInt(j['present']), absent: jInt(j['absent']), late: jInt(j['late']), leave: jInt(j['leave']), halfDay: jInt(j['half_day']), unmarked: jInt(j['unmarked']));
  }
}

class RosterStudent {
  const RosterStudent({required this.studentId, required this.name, required this.admissionNo, this.rollNo, this.recordId, this.status, this.remarks, this.source, this.onApprovedLeave = false});

  final String studentId;
  final String name;
  final String admissionNo;
  final int? rollNo;

  /// The saved attendance record: the handle for correction requests (null until marked).
  final String? recordId;

  /// null = not marked yet.
  final AttendanceStatus? status;
  final String? remarks;

  /// `marked` (saved in the session), `leave` (pre-filled from an approved leave request) or null.
  final String? source;
  final bool onApprovedLeave;

  factory RosterStudent.fromJson(Json j) => RosterStudent(
    studentId: jStrOr(j['studentId']),
    name: jStrOr(j['name']),
    admissionNo: jStrOr(j['admissionNo']),
    rollNo: jIntN(j['rollNo']),
    recordId: jStr(j['recordId']),
    status: AttendanceStatus.parse(jStr(j['status'])),
    remarks: jStr(j['remarks']),
    source: jStr(j['source']),
    onApprovedLeave: jBool(j['onApprovedLeave']),
  );
}

class RosterSession {
  const RosterSession({required this.id, required this.status, this.takenByName, this.submittedAt, this.editableUntil});
  final String id;
  final String status;
  final String? takenByName;
  final DateTime? submittedAt;

  /// Teachers may re-submit until this instant; afterwards a correction request is needed.
  final DateTime? editableUntil;

  bool get submitted => status == 'submitted';

  factory RosterSession.fromJson(Json j) => RosterSession(
    id: jStrOr(j['id']),
    status: jStrOr(j['status'], 'draft'),
    takenByName: jStr(j['takenByName']),
    submittedAt: jDate(j['submittedAt']),
    editableUntil: jDate(j['editableUntil']),
  );
}

/// `GET /attendance/sections/:id`: the roll-call roster of a section for a date (and period).
class Roster {
  const Roster({
    required this.sectionId,
    required this.sectionName,
    required this.gradeName,
    required this.date,
    this.mode = 'daily',
    this.periodId,
    this.periodName,
    this.subjectName,
    this.isWorkingDay = true,
    this.holiday,
    this.isFuture = false,
    this.session,
    this.canSubmit = false,
    this.blockedReason,
    this.canRequestCorrection = false,
    this.warnings = const [],
    this.counts = const StatusCounts(),
    this.students = const [],
  });

  final String sectionId;
  final String sectionName;
  final String gradeName;
  final DateTime date;
  final String mode;
  final String? periodId;
  final String? periodName;
  final String? subjectName;
  final bool isWorkingDay;
  final String? holiday;
  final bool isFuture;
  final RosterSession? session;
  final bool canSubmit;

  /// FUTURE_DATE | NOT_A_WORKING_DAY | HOLIDAY | EDIT_WINDOW_CLOSED | NOT_CLASS_TEACHER | NOT_YOUR_PERIOD | NOT_ALLOWED_TO_MARK | PERIOD_REQUIRED
  final String? blockedReason;
  final bool canRequestCorrection;
  final List<String> warnings;
  final StatusCounts counts;
  final List<RosterStudent> students;

  String get title => '$gradeName $sectionName'.trim();
  bool get alreadySubmitted => session?.submitted ?? false;

  factory Roster.fromJson(Json j) => Roster(
    sectionId: jStrOr(j['sectionId']),
    sectionName: jStrOr(j['sectionName']),
    gradeName: jStrOr(j['gradeName']),
    date: jDay(j['date']) ?? DateTime.now(),
    mode: jStrOr(j['mode'], 'daily'),
    periodId: jStr(j['periodId']),
    periodName: jStr(j['periodName']),
    subjectName: jStr(j['subjectName']),
    isWorkingDay: jBool(j['isWorkingDay'], true),
    holiday: jStr(j['holiday']),
    isFuture: jBool(j['isFuture']),
    session: j['session'] is Map ? RosterSession.fromJson(jsonMap(j['session'])) : null,
    canSubmit: jBool(j['canSubmit']),
    blockedReason: jStr(j['blockedReason']),
    canRequestCorrection: jBool(j['canRequestCorrection']),
    warnings: [for (final w in (j['warnings'] is List ? j['warnings'] as List : const [])) '$w'],
    counts: StatusCounts.fromJson(j['counts']),
    students: jsonList(j['students']).map(RosterStudent.fromJson).toList(growable: false),
  );
}

/// One line of a roll call being submitted.
class RollEntry {
  const RollEntry(this.studentId, this.status, {this.remarks});
  final String studentId;
  final AttendanceStatus status;
  final String? remarks;

  Json toJson() => {'studentId': studentId, 'status': status.apiValue, if (remarks != null && remarks!.trim().isNotEmpty) 'remarks': remarks!.trim()};
}

class SubmitResult {
  const SubmitResult({required this.firstSubmission, this.counts = const StatusCounts(), this.total = 0, this.changed = 0, this.notifiedGuardians = 0, this.editableUntil});
  final bool firstSubmission;
  final StatusCounts counts;
  final int total;
  final int changed;
  final int notifiedGuardians;
  final DateTime? editableUntil;

  factory SubmitResult.fromJson(Json j) => SubmitResult(
    firstSubmission: jBool(j['firstSubmission'], true),
    counts: StatusCounts.fromJson(j['counts']),
    total: jInt(jsonMap(j['counts'])['total']),
    changed: jInt(j['changed']),
    notifiedGuardians: jInt(j['notifiedGuardians']),
    editableUntil: jDate(j['editableUntil']),
  );
}

/// A request to change an already submitted attendance record.
class CorrectionItem {
  const CorrectionItem({
    required this.id,
    required this.recordId,
    required this.studentId,
    required this.studentName,
    required this.admissionNo,
    this.rollNo,
    required this.sectionId,
    required this.sectionName,
    required this.date,
    this.fromStatus,
    this.toStatus,
    required this.reason,
    this.requestedByName,
    required this.status,
    this.decidedByName,
    this.decidedAt,
    this.decisionNote,
    this.createdAt,
    this.canDecide = false,
  });

  final String id;
  final String recordId;
  final String studentId;
  final String studentName;
  final String admissionNo;
  final int? rollNo;
  final String sectionId;
  final String sectionName;
  final DateTime date;
  final AttendanceStatus? fromStatus;
  final AttendanceStatus? toStatus;
  final String reason;
  final String? requestedByName;

  /// pending | approved | rejected
  final String status;
  final String? decidedByName;
  final DateTime? decidedAt;
  final String? decisionNote;
  final DateTime? createdAt;
  final bool canDecide;

  bool get pending => status == 'pending';

  factory CorrectionItem.fromJson(Json j) => CorrectionItem(
    id: jStrOr(j['id']),
    recordId: jStrOr(j['recordId']),
    studentId: jStrOr(j['studentId']),
    studentName: jStrOr(j['studentName']),
    admissionNo: jStrOr(j['admissionNo']),
    rollNo: jIntN(j['rollNo']),
    sectionId: jStrOr(j['sectionId']),
    sectionName: jStrOr(j['sectionName']),
    date: jDay(j['date']) ?? DateTime.now(),
    fromStatus: AttendanceStatus.parse(jStr(j['fromStatus'])),
    toStatus: AttendanceStatus.parse(jStr(j['toStatus'])),
    reason: jStrOr(j['reason']),
    requestedByName: jStr(j['requestedByName']),
    status: jStrOr(j['status'], 'pending'),
    decidedByName: jStr(j['decidedByName']),
    decidedAt: jDate(j['decidedAt']),
    decisionNote: jStr(j['decisionNote']),
    createdAt: jDate(j['createdAt']),
    canDecide: jBool(j['canDecide']),
  );
}

/// A section (or period slot) a teacher takes attendance for today.
class AttendanceTodayItem {
  const AttendanceTodayItem({required this.sectionId, required this.sectionName, this.periodId, this.periodName, this.subjectName, this.strength = 0, this.marked = false, this.counts});
  final String sectionId;
  final String sectionName;
  final String? periodId;
  final String? periodName;
  final String? subjectName;
  final int strength;
  final bool marked;
  final StatusCounts? counts;

  factory AttendanceTodayItem.fromJson(Json j) => AttendanceTodayItem(
    sectionId: jStrOr(j['sectionId']),
    sectionName: jStrOr(j['sectionName']),
    periodId: jStr(j['periodId']),
    periodName: jStr(j['periodName']),
    subjectName: jStr(j['subjectName']),
    strength: jInt(j['strength']),
    marked: jBool(j['marked']),
    counts: j['counts'] is Map ? StatusCounts.fromJson(j['counts']) : null,
  );
}

/// `attendance` block of the teacher dashboard (shape of `GET /attendance/today`).
class AttendanceToday {
  const AttendanceToday({required this.date, this.mode = 'daily', this.isWorkingDay = true, this.holiday, this.items = const [], this.pendingCount = 0});
  final DateTime date;
  final String mode;
  final bool isWorkingDay;
  final String? holiday;
  final List<AttendanceTodayItem> items;
  final int pendingCount;

  factory AttendanceToday.fromJson(Json j) => AttendanceToday(
    date: jDay(j['date']) ?? DateTime.now(),
    mode: jStrOr(j['mode'], 'daily'),
    isWorkingDay: jBool(j['isWorkingDay'], true),
    holiday: jStr(j['holiday']),
    items: jsonList(j['items']).map(AttendanceTodayItem.fromJson).toList(growable: false),
    pendingCount: jInt(j['pendingCount']),
  );
}

// ───────────────────────────── school-wide (management) ─────────────────────────────

class SchoolTotals {
  const SchoolTotals({this.counts = const StatusCounts(), this.activeStudents = 0, this.markedStudents = 0, this.unmarkedStudents = 0, this.percentPresent});
  final StatusCounts counts;
  final int activeStudents;
  final int markedStudents;
  final int unmarkedStudents;
  final double? percentPresent;

  factory SchoolTotals.fromJson(Object? v) {
    final j = jsonMap(v);
    return SchoolTotals(counts: StatusCounts.fromJson(j), activeStudents: jInt(j['activeStudents']), markedStudents: jInt(j['markedStudents']), unmarkedStudents: jInt(j['unmarkedStudents']), percentPresent: jDoubleN(j['percentPresent']));
  }
}

class TrendPoint {
  const TrendPoint({required this.date, required this.counts, this.percentPresent});
  final DateTime date;
  final StatusCounts counts;
  final double? percentPresent;

  factory TrendPoint.fromJson(Json j) => TrendPoint(date: jDay(j['date']) ?? DateTime.now(), counts: StatusCounts.fromJson(j), percentPresent: jDoubleN(j['percentPresent']));
}

class SchoolSectionRow {
  const SchoolSectionRow({required this.sectionId, required this.name, required this.gradeName, this.classTeacherName, this.strength = 0, this.marked = false, this.percentPresent, this.counts = const StatusCounts()});
  final String sectionId;
  final String name;
  final String gradeName;
  final String? classTeacherName;
  final int strength;
  final bool marked;
  final double? percentPresent;
  final StatusCounts counts;

  String get title => '$gradeName $name'.trim();

  factory SchoolSectionRow.fromJson(Json j) => SchoolSectionRow(
    sectionId: jStrOr(j['sectionId']),
    name: jStrOr(j['name']),
    gradeName: jStrOr(j['gradeName']),
    classTeacherName: jStr(j['classTeacherName']),
    strength: jInt(j['strength']),
    marked: jBool(j['marked']),
    percentPresent: jDoubleN(j['percentPresent']),
    counts: StatusCounts.fromJson(j),
  );
}

class Absentee {
  const Absentee({required this.studentId, required this.name, required this.admissionNo, this.rollNo, required this.sectionName, this.remarks});
  final String studentId;
  final String name;
  final String admissionNo;
  final int? rollNo;
  final String sectionName;
  final String? remarks;

  factory Absentee.fromJson(Json j) => Absentee(
    studentId: jStrOr(j['studentId']),
    name: jStrOr(j['name']),
    admissionNo: jStrOr(j['admissionNo']),
    rollNo: jIntN(j['rollNo']),
    sectionName: jStrOr(j['sectionName']),
    remarks: jStr(j['remarks']),
  );
}

/// `GET /attendance/summary`; also the `attendance` block of the management dashboard (no sections / absentees there).
class SchoolAttendance {
  const SchoolAttendance({
    required this.date,
    this.mode = 'daily',
    this.isWorkingDay = true,
    this.holiday,
    this.totals = const SchoolTotals(),
    this.sectionsTotal = 0,
    this.sectionsMarked = 0,
    this.sections = const [],
    this.absentees = const [],
    this.absenteesTotal = 0,
    this.trend = const [],
  });

  final DateTime date;
  final String mode;
  final bool isWorkingDay;
  final String? holiday;
  final SchoolTotals totals;
  final int sectionsTotal;
  final int sectionsMarked;
  final List<SchoolSectionRow> sections;
  final List<Absentee> absentees;
  final int absenteesTotal;
  final List<TrendPoint> trend;

  factory SchoolAttendance.fromJson(Json j) => SchoolAttendance(
    date: jDay(j['date']) ?? DateTime.now(),
    mode: jStrOr(j['mode'], 'daily'),
    isWorkingDay: jBool(j['isWorkingDay'], true),
    holiday: jStr(j['holiday']),
    totals: SchoolTotals.fromJson(j['totals']),
    sectionsTotal: jInt(j['sectionsTotal']),
    sectionsMarked: jInt(j['sectionsMarked']),
    sections: jsonList(j['sections']).map(SchoolSectionRow.fromJson).toList(growable: false),
    absentees: jsonList(j['absentees']).map(Absentee.fromJson).toList(growable: false),
    absenteesTotal: jInt(j['absenteesTotal']),
    trend: jsonList(j['trend']).map(TrendPoint.fromJson).toList(growable: false),
  );
}

/// One student's row of a section summary (`GET /attendance/sections/:id/summary`).
class SectionStudentAttendance {
  const SectionStudentAttendance({required this.studentId, required this.name, required this.admissionNo, this.rollNo, required this.totals, this.isShort = false});
  final String studentId;
  final String name;
  final String admissionNo;
  final int? rollNo;
  final AttendanceCounts totals;
  final bool isShort;

  factory SectionStudentAttendance.fromJson(Json j) => SectionStudentAttendance(
    studentId: jStrOr(j['studentId']),
    name: jStrOr(j['name']),
    admissionNo: jStrOr(j['admissionNo']),
    rollNo: jIntN(j['rollNo']),
    totals: AttendanceCounts.fromJson(j),
    isShort: jBool(j['isShort']),
  );
}

/// One school day of a section's attendance (`days` of the section summary).
class SectionDayCount {
  const SectionDayCount({required this.date, this.counts = const StatusCounts(), this.percentage});
  final DateTime date;
  final StatusCounts counts;
  final double? percentage;

  factory SectionDayCount.fromJson(Json j) => SectionDayCount(date: jDay(j['date']) ?? DateTime.now(), counts: StatusCounts.fromJson(j), percentage: jDoubleN(j['percentage']));
}

class SectionAttendanceSummary {
  const SectionAttendanceSummary({required this.sectionId, required this.from, required this.to, this.strength = 0, this.totals = const AttendanceCounts(), this.students = const [], this.days = const []});
  final String sectionId;
  final DateTime from;
  final DateTime to;
  final int strength;
  final AttendanceCounts totals;
  final List<SectionStudentAttendance> students;

  /// Days that have a submitted roll call, in the order the API returns them (oldest first).
  final List<SectionDayCount> days;

  factory SectionAttendanceSummary.fromJson(Json j) => SectionAttendanceSummary(
    sectionId: jStrOr(j['sectionId']),
    from: jDay(j['from']) ?? DateTime.now(),
    to: jDay(j['to']) ?? DateTime.now(),
    strength: jInt(j['strength']),
    totals: AttendanceCounts.fromJson(jsonMap(j['totals'])),
    students: jsonList(j['students']).map(SectionStudentAttendance.fromJson).toList(growable: false),
    days: jsonList(j['days']).map(SectionDayCount.fromJson).toList(growable: false),
  );
}
