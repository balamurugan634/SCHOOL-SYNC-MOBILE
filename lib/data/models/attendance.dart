import '../json.dart';

enum AttendanceStatus {
  present,
  absent,
  late,
  leave,
  halfDay;

  static AttendanceStatus? parse(String? v) => switch (v) {
    'present' => present,
    'absent' => absent,
    'late' => late,
    'leave' => leave,
    'half_day' => halfDay,
    _ => null,
  };

  String get apiValue => this == halfDay ? 'half_day' : name;

  String get label => switch (this) {
    present => 'Present',
    absent => 'Absent',
    late => 'Late',
    leave => 'On leave',
    halfDay => 'Half day',
  };
}

class AttendanceCounts {
  const AttendanceCounts({this.present = 0, this.absent = 0, this.late = 0, this.leave = 0, this.halfDay = 0, this.total = 0, this.percentage = 0});
  final int present, absent, late, leave, halfDay, total;
  final double percentage;

  factory AttendanceCounts.fromJson(Json j) => AttendanceCounts(
    present: jInt(j['present']),
    absent: jInt(j['absent']),
    late: jInt(j['late']),
    leave: jInt(j['leave']),
    halfDay: jInt(j['half_day']),
    total: jInt(j['total']),
    percentage: jDouble(j['percentage']),
  );
}

class AttendanceMonth {
  const AttendanceMonth({required this.month, required this.counts});
  final String month; // 2026-09
  final AttendanceCounts counts;
  factory AttendanceMonth.fromJson(Json j) => AttendanceMonth(month: jStrOr(j['month']), counts: AttendanceCounts.fromJson(j));
}

class AttendanceSummary {
  const AttendanceSummary({required this.studentId, required this.studentName, required this.from, required this.to, required this.totals, required this.months, required this.thresholdPercent, required this.isShort});

  final String studentId;
  final String studentName;
  final DateTime? from;
  final DateTime? to;
  final AttendanceCounts totals;
  final List<AttendanceMonth> months;
  final double thresholdPercent;
  final bool isShort;

  factory AttendanceSummary.fromJson(Json j) {
    final shortage = jsonMap(j['shortage']);
    return AttendanceSummary(
      studentId: jStrOr(j['studentId']),
      studentName: jStrOr(j['studentName']),
      from: jDay(j['from']),
      to: jDay(j['to']),
      totals: AttendanceCounts.fromJson(jsonMap(j['totals'])),
      months: jsonList(j['months']).map(AttendanceMonth.fromJson).toList(growable: false),
      thresholdPercent: jDouble(shortage['thresholdPercent'], 75),
      isShort: jBool(shortage['isShort']),
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({required this.id, required this.date, required this.status, this.remarks, this.periodName, this.subjectName, this.correctionPending = false});
  final String id;
  final DateTime date;
  final AttendanceStatus status;
  final String? remarks;
  final String? periodName;
  final String? subjectName;
  final bool correctionPending;

  factory AttendanceRecord.fromJson(Json j) => AttendanceRecord(
    id: jStrOr(j['id']),
    date: jDay(j['date']) ?? DateTime.now(),
    status: AttendanceStatus.parse(jStr(j['status'])) ?? AttendanceStatus.present,
    remarks: jStr(j['remarks']),
    periodName: jStr(j['periodName']),
    subjectName: jStr(j['subjectName']),
    correctionPending: jBool(j['correctionPending']),
  );
}
