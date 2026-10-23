import '../../json.dart';
import '../leave.dart' show LeaveType;

/// A student leave request as a decision-maker sees it (`GET /leave`).
class StudentLeaveItem {
  const StudentLeaveItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.admissionNo = '',
    this.sectionName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    this.days = 1,
    required this.reason,
    this.attachmentFileId,
    required this.status,
    this.requestedByName,
    this.decidedByName,
    this.decidedAt,
    this.decisionNote,
    this.createdAt,
    this.canDecide = false,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String admissionNo;
  final String? sectionName;
  final LeaveType leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final int days;
  final String reason;
  final String? attachmentFileId;

  /// pending | approved | rejected | cancelled
  final String status;
  final String? requestedByName;
  final String? decidedByName;
  final DateTime? decidedAt;
  final String? decisionNote;
  final DateTime? createdAt;
  final bool canDecide;

  bool get pending => status == 'pending';

  factory StudentLeaveItem.fromJson(Json j) {
    final from = jDay(j['fromDate']) ?? DateTime.now();
    return StudentLeaveItem(
      id: jStrOr(j['id']),
      studentId: jStrOr(j['studentId']),
      studentName: jStrOr(j['studentName']),
      admissionNo: jStrOr(j['admissionNo']),
      sectionName: jStr(j['sectionName']),
      leaveType: LeaveType.parse(jStr(j['leaveType'])),
      fromDate: from,
      toDate: jDay(j['toDate']) ?? from,
      days: jInt(j['days'], 1),
      reason: jStrOr(j['reason']),
      attachmentFileId: jStr(j['attachmentFileId']),
      status: jStrOr(j['status'], 'pending'),
      requestedByName: jStr(j['requestedByName']),
      decidedByName: jStr(j['decidedByName']),
      decidedAt: jDate(j['decidedAt']),
      decisionNote: jStr(j['decisionNote']),
      createdAt: jDate(j['createdAt']),
      canDecide: jBool(j['canDecide']),
    );
  }
}

/// A staff leave request (`GET /staff-leave`).
class StaffLeaveItem {
  const StaffLeaveItem({
    required this.id,
    required this.staffId,
    required this.staffName,
    this.employeeId = '',
    this.designation,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    this.days = 1,
    required this.reason,
    required this.status,
    this.decidedByName,
    this.decidedAt,
    this.decisionNote,
    this.createdAt,
    this.canDecide = false,
    this.canCancel = false,
  });

  final String id;
  final String staffId;
  final String staffName;
  final String employeeId;
  final String? designation;
  final LeaveType leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final int days;
  final String reason;
  final String status;
  final String? decidedByName;
  final DateTime? decidedAt;
  final String? decisionNote;
  final DateTime? createdAt;
  final bool canDecide;
  final bool canCancel;

  bool get pending => status == 'pending';

  factory StaffLeaveItem.fromJson(Json j) {
    final from = jDay(j['fromDate']) ?? DateTime.now();
    return StaffLeaveItem(
      id: jStrOr(j['id']),
      staffId: jStrOr(j['staffId']),
      staffName: jStrOr(j['staffName']),
      employeeId: jStrOr(j['employeeId']),
      designation: jStr(j['designation']),
      leaveType: LeaveType.parse(jStr(j['leaveType'])),
      fromDate: from,
      toDate: jDay(j['toDate']) ?? from,
      days: jInt(j['days'], 1),
      reason: jStrOr(j['reason']),
      status: jStrOr(j['status'], 'pending'),
      decidedByName: jStr(j['decidedByName']),
      decidedAt: jDate(j['decidedAt']),
      decisionNote: jStr(j['decisionNote']),
      createdAt: jDate(j['createdAt']),
      canDecide: jBool(j['canDecide']),
      canCancel: jBool(j['canCancel']),
    );
  }
}

class LeaveBalanceLine {
  const LeaveBalanceLine({required this.leaveType, this.approvedDays = 0, this.pendingDays = 0});
  final LeaveType leaveType;
  final int approvedDays;
  final int pendingDays;
  factory LeaveBalanceLine.fromJson(Json j) => LeaveBalanceLine(leaveType: LeaveType.parse(jStr(j['leaveType'])), approvedDays: jInt(j['approvedDays']), pendingDays: jInt(j['pendingDays']));
}

class StaffLeaveBalance {
  const StaffLeaveBalance({this.academicYear, this.lines = const [], this.totalApprovedDays = 0, this.totalPendingDays = 0});
  final String? academicYear;
  final List<LeaveBalanceLine> lines;
  final int totalApprovedDays;
  final int totalPendingDays;

  factory StaffLeaveBalance.fromJson(Json j) => StaffLeaveBalance(
    academicYear: jStr(j['academicYear']),
    lines: jsonList(j['byType']).map(LeaveBalanceLine.fromJson).toList(growable: false),
    totalApprovedDays: jInt(j['totalApprovedDays']),
    totalPendingDays: jInt(j['totalPendingDays']),
  );
}

/// One day of the signed-in staff member's own attendance (`GET /staff-attendance/me`).
class StaffDayRecord {
  const StaffDayRecord({required this.id, required this.date, required this.status, this.checkIn, this.checkOut, this.note});
  final String id;
  final DateTime date;
  final String status;
  final String? checkIn;
  final String? checkOut;
  final String? note;

  factory StaffDayRecord.fromJson(Json j) => StaffDayRecord(id: jStrOr(j['id']), date: jDay(j['date']) ?? DateTime.now(), status: jStrOr(j['status']), checkIn: jStr(j['checkIn']), checkOut: jStr(j['checkOut']), note: jStr(j['note']));
}

class MyStaffAttendance {
  const MyStaffAttendance({this.today, this.records = const [], this.present = 0, this.total = 0, this.percentage});
  final StaffDayRecord? today;
  final List<StaffDayRecord> records;
  final int present;
  final int total;
  final double? percentage;

  bool get checkedIn => today?.checkIn != null;
  bool get checkedOut => today?.checkOut != null;

  factory MyStaffAttendance.fromJson(Json j) {
    final t = jsonMap(j['totals']);
    return MyStaffAttendance(
      today: j['today'] is Map ? StaffDayRecord.fromJson(jsonMap(j['today'])) : null,
      records: jsonList(j['records']).map(StaffDayRecord.fromJson).toList(growable: false),
      present: jInt(t['present']) + jInt(t['late']),
      total: jInt(t['total']),
      percentage: jDoubleN(t['percentage']),
    );
  }
}
