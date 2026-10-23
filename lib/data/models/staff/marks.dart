import '../../json.dart';

/// A mark sheet (exam x section x subject) in the teacher's or reviewer's scope (`GET /marks/sheets`).
class MarkSheet {
  const MarkSheet({
    required this.id,
    required this.examId,
    required this.examName,
    required this.sectionId,
    required this.sectionName,
    required this.gradeName,
    required this.subjectId,
    required this.subjectName,
    required this.status,
    required this.maxMarks,
    this.passMarks,
    this.teacherName,
    this.studentCount = 0,
    this.enteredCount = 0,
    this.absentCount = 0,
    this.submittedAt,
    this.reviewedAt,
    this.publishedAt,
    this.returnNote,
  });

  final String id;
  final String examId;
  final String examName;
  final String sectionId;
  final String sectionName;
  final String gradeName;
  final String subjectId;
  final String subjectName;

  /// draft | submitted | approved | published | returned
  final String status;
  final double maxMarks;
  final double? passMarks;
  final String? teacherName;
  final int studentCount;
  final int enteredCount;
  final int absentCount;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final DateTime? publishedAt;
  final String? returnNote;

  String get sectionTitle => '$gradeName $sectionName'.trim();
  bool get isReturned => status == 'returned';
  bool get isEditableStatus => status == 'draft' || status == 'returned';

  factory MarkSheet.fromJson(Json j) => MarkSheet(
    id: jStrOr(j['id']),
    examId: jStrOr(j['examId']),
    examName: jStrOr(j['examName']),
    sectionId: jStrOr(j['sectionId']),
    sectionName: jStrOr(j['sectionName']),
    gradeName: jStrOr(j['gradeName']),
    subjectId: jStrOr(j['subjectId']),
    subjectName: jStrOr(j['subjectName']),
    status: jStrOr(j['status'], 'draft'),
    maxMarks: jDouble(j['maxMarks'], 100),
    passMarks: jDoubleN(j['passMarks']),
    teacherName: jStr(j['teacherName']),
    studentCount: jInt(j['studentCount']),
    enteredCount: jInt(j['enteredCount']),
    absentCount: jInt(j['absentCount']),
    submittedAt: jDate(j['submittedAt']),
    reviewedAt: jDate(j['reviewedAt']),
    publishedAt: jDate(j['publishedAt']),
    returnNote: jStr(j['returnNote']),
  );
}

class MarkEntry {
  const MarkEntry({required this.studentId, required this.admissionNo, required this.name, this.rollNo, this.marksObtained, this.isAbsent = false, this.remarks});
  final String studentId;
  final String admissionNo;
  final String name;
  final int? rollNo;
  final double? marksObtained;
  final bool isAbsent;
  final String? remarks;

  factory MarkEntry.fromJson(Json j) => MarkEntry(
    studentId: jStrOr(j['studentId']),
    admissionNo: jStrOr(j['admissionNo']),
    name: jStrOr(j['name']),
    rollNo: jIntN(j['rollNo']),
    marksObtained: jDoubleN(j['marksObtained']),
    isAbsent: jBool(j['isAbsent']),
    remarks: jStr(j['remarks']),
  );
}

class MarkSheetDetail {
  const MarkSheetDetail({required this.sheet, required this.canEdit, this.entries = const []});
  final MarkSheet sheet;

  /// Subject teacher + sheet draft/returned + marks entry open.
  final bool canEdit;
  final List<MarkEntry> entries;

  factory MarkSheetDetail.fromJson(Json j) => MarkSheetDetail(sheet: MarkSheet.fromJson(j), canEdit: jBool(j['canEdit']), entries: jsonList(j['entries']).map(MarkEntry.fromJson).toList(growable: false));
}

/// One student's row being saved (`PUT /marks/sheets/:id/entries`).
class MarkInput {
  const MarkInput({required this.studentId, this.marks, this.isAbsent = false, this.remarks});
  final String studentId;
  final double? marks;
  final bool isAbsent;
  final String? remarks;

  Json toJson() => {
    'studentId': studentId,
    'isAbsent': isAbsent,
    'marksObtained': isAbsent ? null : marks,
    if (remarks != null && remarks!.trim().isNotEmpty) 'remarks': remarks!.trim(),
  };
}
