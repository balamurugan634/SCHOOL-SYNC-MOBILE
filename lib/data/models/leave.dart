import '../json.dart';

enum LeaveType {
  sick,
  casual,
  family,
  event,
  other;

  static LeaveType parse(String? v) => LeaveType.values.firstWhere((e) => e.name == v, orElse: () => other);
  String get label => switch (this) { sick => 'Sick', casual => 'Casual', family => 'Family', event => 'Event', other => 'Other' };
}

class LeaveRequest {
  const LeaveRequest({required this.id, required this.studentName, required this.leaveType, required this.fromDate, required this.toDate, required this.days, required this.reason, required this.status, required this.canCancel, this.decisionNote, this.decidedByName, this.createdAt});
  final String id;
  final String studentName;
  final LeaveType leaveType;
  final DateTime fromDate;
  final DateTime toDate;
  final int days;
  final String reason;

  /// pending | approved | rejected | cancelled
  final String status;
  final bool canCancel;
  final String? decisionNote;
  final String? decidedByName;
  final DateTime? createdAt;

  factory LeaveRequest.fromJson(Json j) {
    final from = jDay(j['fromDate']) ?? DateTime.now();
    return LeaveRequest(
      id: jStrOr(j['id']),
      studentName: jStrOr(j['studentName']),
      leaveType: LeaveType.parse(jStr(j['leaveType'])),
      fromDate: from,
      toDate: jDay(j['toDate']) ?? from,
      days: jInt(j['days'], 1),
      reason: jStrOr(j['reason']),
      status: jStrOr(j['status']),
      canCancel: jBool(j['canCancel']),
      decisionNote: jStr(j['decisionNote']),
      decidedByName: jStr(j['decidedByName']),
      createdAt: jDate(j['createdAt']),
    );
  }
}
