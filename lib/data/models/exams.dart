import '../json.dart';

class Exam {
  const Exam({required this.id, required this.name, required this.examType, required this.status, this.termName, this.startDate, this.endDate, this.paperCount = 0, this.passPercent});
  final String id;
  final String name;
  final String examType;
  final String status;
  final String? termName;
  final DateTime? startDate;
  final DateTime? endDate;
  final int paperCount;
  final double? passPercent;

  factory Exam.fromJson(Json j) => Exam(
    id: jStrOr(j['id']),
    name: jStrOr(j['name']),
    examType: jStrOr(j['examType'], 'other'),
    status: jStrOr(j['status']),
    termName: jStr(j['termName']),
    startDate: jDay(j['startDate']),
    endDate: jDay(j['endDate']),
    paperCount: jInt(j['paperCount']),
    passPercent: jDoubleN(j['passPercent']),
  );
}

class ExamPaper {
  const ExamPaper({required this.id, required this.subjectName, this.examDate, this.startTime, this.endTime, this.room, this.maxMarks});
  final String id;
  final String subjectName;
  final DateTime? examDate;
  final String? startTime;
  final String? endTime;
  final String? room;
  final double? maxMarks;

  factory ExamPaper.fromJson(Json j) => ExamPaper(
    id: jStrOr(j['id']),
    subjectName: jStrOr(j['subjectName']),
    examDate: jDay(j['examDate']),
    startTime: jStr(j['startTime']),
    endTime: jStr(j['endTime']),
    room: jStr(j['room']),
    maxMarks: jDoubleN(j['maxMarks']),
  );
}

class SubjectResult {
  const SubjectResult({required this.subjectName, required this.maxMarks, required this.isAbsent, this.marksObtained, this.percent, this.grade, this.passed, this.remarks});
  final String subjectName;
  final double maxMarks;
  final double? marksObtained;
  final bool isAbsent;
  final double? percent;
  final String? grade;
  final bool? passed;
  final String? remarks;

  factory SubjectResult.fromJson(Json j) => SubjectResult(
    subjectName: jStrOr(j['subjectName']),
    maxMarks: jDouble(j['maxMarks']),
    marksObtained: jDoubleN(j['marksObtained']),
    isAbsent: jBool(j['isAbsent']),
    percent: jDoubleN(j['percent']),
    grade: jStr(j['grade']),
    passed: j['passed'] is bool ? j['passed'] as bool : null,
    remarks: jStr(j['remarks']),
  );
}

/// A student's published result for one exam (also the head of a report card).
class ExamResult {
  const ExamResult({
    required this.examId,
    required this.examName,
    required this.studentId,
    required this.subjects,
    this.examType,
    this.termName,
    this.startDate,
    this.endDate,
    this.totalMarks,
    this.maxTotal,
    this.percent,
    this.grade,
    this.gradeRemark,
    this.result,
    this.rank,
    this.classSize,
    this.complete = true,
  });

  final String examId;
  final String examName;
  final String? examType;
  final String? termName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String studentId;
  final List<SubjectResult> subjects;
  final double? totalMarks;
  final double? maxTotal;
  final double? percent;
  final String? grade;
  final String? gradeRemark;
  final String? result; // pass | fail
  final int? rank;
  final int? classSize;
  final bool complete;

  bool get passed => result == 'pass';

  factory ExamResult.fromJson(Json j) => ExamResult(
    examId: jStrOr(j['examId']),
    examName: jStrOr(j['examName']),
    examType: jStr(j['examType']),
    termName: jStr(j['termName']),
    startDate: jDay(j['startDate']),
    endDate: jDay(j['endDate']),
    studentId: jStrOr(j['studentId']),
    subjects: jsonList(j['subjects']).map(SubjectResult.fromJson).toList(growable: false),
    totalMarks: jDoubleN(j['totalMarks']),
    maxTotal: jDoubleN(j['maxTotal']),
    percent: jDoubleN(j['percent']),
    grade: jStr(j['grade']),
    gradeRemark: jStr(j['gradeRemark']),
    result: jStr(j['result']),
    rank: jIntN(j['rank']),
    classSize: jIntN(j['classSize']),
    complete: jBool(j['complete'], true),
  );
}

class GradeBand {
  const GradeBand({required this.label, required this.minPercent, required this.maxPercent, this.remark});
  final String label;
  final double minPercent;
  final double maxPercent;
  final String? remark;
  factory GradeBand.fromJson(Json j) => GradeBand(label: jStrOr(j['label']), minPercent: jDouble(j['minPercent']), maxPercent: jDouble(j['maxPercent']), remark: jStr(j['remark']));
}

class ReportCard {
  const ReportCard({required this.result, this.schoolName, this.academicYear, this.attendancePercent, this.attendanceDays, this.presentDays, this.teacherRemark, this.areasToImprove, this.conduct, this.gradeScale = const []});
  final ExamResult result;
  final String? schoolName;
  final String? academicYear;
  final double? attendancePercent;
  final int? attendanceDays;
  final int? presentDays;
  final String? teacherRemark;
  final String? areasToImprove;
  final String? conduct;
  final List<GradeBand> gradeScale;

  factory ReportCard.fromJson(Json j) {
    final att = jsonMap(j['attendance']);
    final rem = j['remarks'] is Map ? jsonMap(j['remarks']) : const <String, dynamic>{};
    return ReportCard(
      result: ExamResult.fromJson(j),
      schoolName: jStr(jsonMap(j['school'])['name']),
      academicYear: jStr(j['academicYear']),
      attendancePercent: jDoubleN(att['percent']),
      attendanceDays: jIntN(att['totalDays']),
      presentDays: jIntN(att['present']),
      teacherRemark: jStr(rem['remark']),
      areasToImprove: jStr(rem['areasToImprove']),
      conduct: jStr(rem['conduct']),
      gradeScale: jsonList(j['gradeScale']).map(GradeBand.fromJson).toList(growable: false),
    );
  }
}

/// Published percent per exam, for the progress trend.
class ProgressPoint {
  const ProgressPoint({required this.examId, required this.name, required this.percent, this.date, this.grade});
  final String examId;
  final String name;
  final double percent;
  final DateTime? date;
  final String? grade;
  factory ProgressPoint.fromJson(Json j) => ProgressPoint(examId: jStrOr(j['examId']), name: jStrOr(j['name']), percent: jDouble(j['percent']), date: jDay(j['date']), grade: jStr(j['grade']));
}
