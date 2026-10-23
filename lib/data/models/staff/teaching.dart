import '../../json.dart';

// ───────────────────────────── timetable (teacher view) ─────────────────────────────

/// One period of a teacher's day, with the section it is for (so roll call is one tap away).
class TeacherPeriod {
  const TeacherPeriod({
    required this.periodId,
    required this.periodName,
    required this.ordinal,
    required this.startTime,
    required this.endTime,
    required this.isBreak,
    this.sectionId,
    this.sectionName,
    this.subjectName,
    this.teacherName,
    this.room,
    this.substituted = false,
    this.substituteTeacherName,
    this.originalTeacherName,
    this.relation,
    this.state,
  });

  final String periodId;
  final String periodName;
  final int ordinal;
  final String startTime;
  final String endTime;
  final bool isBreak;
  final String? sectionId;
  final String? sectionName;
  final String? subjectName;
  final String? teacherName;
  final String? room;
  final bool substituted;
  final String? substituteTeacherName;

  /// The teacher whose lesson is being covered (set when [substituted]).
  final String? originalTeacherName;

  /// `own` I teach it, `covering` I am the substitute, `covered` someone covers my class (I am free).
  final String? relation;

  /// `past` | `current` | `upcoming` (today only).
  final String? state;

  bool get isCurrent => state == 'current';
  bool get isFree => relation == 'covered';
  bool get isCovering => relation == 'covering';

  factory TeacherPeriod.fromJson(Json j) {
    final sub = jsonMap(j['substitution']);
    return TeacherPeriod(
      periodId: jStrOr(j['periodId']),
      periodName: jStrOr(j['periodName']),
      ordinal: jInt(j['ordinal']),
      startTime: jStrOr(j['startTime']),
      endTime: jStrOr(j['endTime']),
      isBreak: jBool(j['isBreak']),
      sectionId: jStr(j['sectionId']),
      sectionName: jStr(j['sectionName']),
      subjectName: jStr(j['subjectName']),
      teacherName: jStr(j['teacherName']),
      room: jStr(j['room']),
      substituted: jBool(j['substituted']),
      substituteTeacherName: jStr(sub['substituteTeacherName']),
      originalTeacherName: jStr(sub['originalTeacherName']),
      relation: jStr(j['relation']),
      state: jStr(j['state']),
    );
  }
}

class TeacherDay {
  const TeacherDay({required this.date, required this.dayOfWeek, required this.isWorkingDay, this.entries = const [], this.current, this.next, this.now});
  final DateTime date;

  /// 1 = Monday .. 7 = Sunday.
  final int dayOfWeek;
  final bool isWorkingDay;
  final List<TeacherPeriod> entries;
  final TeacherPeriod? current;
  final TeacherPeriod? next;
  final String? now;

  factory TeacherDay.fromJson(Json j) => TeacherDay(
    date: jDay(j['date']) ?? DateTime.now(),
    dayOfWeek: jInt(j['dayOfWeek'], 1),
    isWorkingDay: jBool(j['isWorkingDay'], true),
    entries: jsonList(j['entries']).map(TeacherPeriod.fromJson).toList(growable: false),
    current: j['current'] is Map ? TeacherPeriod.fromJson(jsonMap(j['current'])) : null,
    next: j['next'] is Map ? TeacherPeriod.fromJson(jsonMap(j['next'])) : null,
    now: jStr(j['now']),
  );
}

// ───────────────────────────── homework (staff view) ─────────────────────────────

class HomeworkStats {
  const HomeworkStats({this.totalStudents = 0, this.submitted = 0, this.late = 0, this.reviewed = 0, this.returned = 0, this.missing = 0});
  final int totalStudents;
  final int submitted;
  final int late;
  final int reviewed;
  final int returned;
  final int missing;

  /// Submitted or late: waiting for my review.
  int get toReview => submitted + late;
  int get handedIn => submitted + late + reviewed + returned;

  factory HomeworkStats.fromJson(Object? v) {
    final j = jsonMap(v);
    return HomeworkStats(totalStudents: jInt(j['totalStudents']), submitted: jInt(j['submitted']), late: jInt(j['late']), reviewed: jInt(j['reviewed']), returned: jInt(j['returned']), missing: jInt(j['missing']));
  }
}

class HomeworkEntry {
  const HomeworkEntry({
    required this.id,
    required this.sectionId,
    required this.sectionName,
    required this.gradeName,
    required this.subjectId,
    required this.subjectName,
    required this.title,
    this.description,
    this.attachments = const [],
    required this.dueAt,
    this.assignedAt,
    this.allowSubmission = true,
    this.maxMarks,
    required this.status,
    this.stats,
    this.teacherName,
  });

  final String id;
  final String sectionId;
  final String sectionName;
  final String gradeName;
  final String subjectId;
  final String subjectName;
  final String title;
  final String? description;
  final List<Attachment> attachments;
  final DateTime dueAt;
  final DateTime? assignedAt;
  final bool allowSubmission;
  final int? maxMarks;

  /// draft | published | closed
  final String status;
  final HomeworkStats? stats;
  final String? teacherName;

  bool get isDraft => status == 'draft';
  bool get isClosed => status == 'closed';
  bool get isPublished => status == 'published';
  String get sectionTitle => '$gradeName $sectionName'.trim();

  factory HomeworkEntry.fromJson(Json j) => HomeworkEntry(
    id: jStrOr(j['id']),
    sectionId: jStrOr(j['sectionId']),
    sectionName: jStrOr(j['sectionName']),
    gradeName: jStrOr(j['gradeName']),
    subjectId: jStrOr(j['subjectId']),
    subjectName: jStrOr(j['subjectName']),
    title: jStrOr(j['title']),
    description: jStr(j['description']),
    attachments: Attachment.list(j['attachments']),
    dueAt: jDate(j['dueAt']) ?? DateTime.now(),
    assignedAt: jDate(j['assignedAt']),
    allowSubmission: jBool(j['allowSubmission'], true),
    maxMarks: jIntN(j['maxMarks']),
    status: jStrOr(j['status'], 'draft'),
    stats: j['stats'] is Map ? HomeworkStats.fromJson(j['stats']) : null,
    teacherName: jStr(j['teacherName']),
  );
}

/// What the teacher fills in to create / edit homework.
class HomeworkDraft {
  const HomeworkDraft({required this.sectionId, required this.subjectId, required this.title, this.description, required this.dueAt, this.allowSubmission = true, this.maxMarks, this.attachments = const []});
  final String sectionId;
  final String subjectId;
  final String title;
  final String? description;
  final DateTime dueAt;
  final bool allowSubmission;
  final int? maxMarks;
  final List<Attachment> attachments;

  Json toCreateJson({required bool publish}) => {
    'sectionId': sectionId,
    'subjectId': subjectId,
    'title': title.trim(),
    if (description != null && description!.trim().isNotEmpty) 'description': description!.trim(),
    'attachments': [for (final a in attachments) a.toJson()],
    'dueAt': dueAt.toUtc().toIso8601String(),
    'allowSubmission': allowSubmission,
    'maxMarks': allowSubmission ? maxMarks : null,
    'publish': publish,
  };

  /// PATCH body (section and subject cannot change after creation).
  Json toUpdateJson() => {
    'title': title.trim(),
    'description': (description == null || description!.trim().isEmpty) ? null : description!.trim(),
    'attachments': [for (final a in attachments) a.toJson()],
    'dueAt': dueAt.toUtc().toIso8601String(),
    'allowSubmission': allowSubmission,
    'maxMarks': allowSubmission ? maxMarks : null,
  };
}

class SubmissionBriefRow {
  const SubmissionBriefRow({required this.id, required this.status, this.submittedAt, this.isLate = false, this.marks, this.feedback, this.reviewedAt});
  final String id;
  final String status;
  final DateTime? submittedAt;
  final bool isLate;
  final double? marks;
  final String? feedback;
  final DateTime? reviewedAt;

  factory SubmissionBriefRow.fromJson(Json j) => SubmissionBriefRow(id: jStrOr(j['id']), status: jStrOr(j['status']), submittedAt: jDate(j['submittedAt']), isLate: jBool(j['isLate']), marks: jDoubleN(j['marks']), feedback: jStr(j['feedback']), reviewedAt: jDate(j['reviewedAt']));
}

class HomeworkRosterRow {
  const HomeworkRosterRow({required this.studentId, required this.name, required this.admissionNo, this.rollNo, required this.status, this.submission});
  final String studentId;
  final String name;
  final String admissionNo;
  final int? rollNo;

  /// missing | submitted | late | reviewed | returned
  final String status;
  final SubmissionBriefRow? submission;

  factory HomeworkRosterRow.fromJson(Json j) => HomeworkRosterRow(
    studentId: jStrOr(j['studentId']),
    name: jStrOr(j['name']),
    admissionNo: jStrOr(j['admissionNo']),
    rollNo: jIntN(j['rollNo']),
    status: jStrOr(j['status'], 'missing'),
    submission: j['submission'] is Map ? SubmissionBriefRow.fromJson(jsonMap(j['submission'])) : null,
  );
}

class HomeworkRoster {
  const HomeworkRoster({required this.homework, required this.rows});
  final HomeworkEntry homework;
  final List<HomeworkRosterRow> rows;

  factory HomeworkRoster.fromJson(Json j) => HomeworkRoster(homework: HomeworkEntry.fromJson(jsonMap(j['homework'])), rows: jsonList(j['data']).map(HomeworkRosterRow.fromJson).toList(growable: false));
}

/// A student's hand-in, as a teacher sees it (`GET /submissions`).
class SubmissionEntry {
  const SubmissionEntry({required this.id, required this.homeworkId, required this.studentId, required this.studentName, this.rollNo, this.text, this.attachments = const [], this.submittedAt, required this.status, this.isLate = false, this.marks, this.feedback, this.reviewedAt});
  final String id;
  final String homeworkId;
  final String studentId;
  final String studentName;
  final int? rollNo;
  final String? text;
  final List<Attachment> attachments;
  final DateTime? submittedAt;

  /// submitted | late | reviewed | returned
  final String status;
  final bool isLate;
  final double? marks;
  final String? feedback;
  final DateTime? reviewedAt;

  bool get locked => status == 'reviewed';

  factory SubmissionEntry.fromJson(Json j) => SubmissionEntry(
    id: jStrOr(j['id']),
    homeworkId: jStrOr(j['homeworkId']),
    studentId: jStrOr(j['studentId']),
    studentName: jStrOr(j['studentName']),
    rollNo: jIntN(j['rollNo']),
    text: jStr(j['text']),
    attachments: Attachment.list(j['attachments']),
    submittedAt: jDate(j['submittedAt']),
    status: jStrOr(j['status'], 'submitted'),
    isLate: jBool(j['isLate']),
    marks: jDoubleN(j['marks']),
    feedback: jStr(j['feedback']),
    reviewedAt: jDate(j['reviewedAt']),
  );
}

// ───────────────────────────── syllabus ─────────────────────────────

enum SyllabusStatus {
  notStarted('not_started', 'Not started'),
  inProgress('in_progress', 'In progress'),
  completed('completed', 'Completed');

  const SyllabusStatus(this.api, this.label);
  final String api;
  final String label;
  static SyllabusStatus parse(Object? v) => SyllabusStatus.values.firstWhere((s) => s.api == v, orElse: () => notStarted);
}

class TopicEntry {
  const TopicEntry({required this.id, required this.subjectId, required this.subjectName, required this.title, this.ordinal = 0, this.termName, this.plannedHours, this.status = SyllabusStatus.notStarted});
  final String id;
  final String subjectId;
  final String subjectName;
  final String title;
  final int ordinal;
  final String? termName;
  final int? plannedHours;
  final SyllabusStatus status;

  TopicEntry withStatus(SyllabusStatus s) => TopicEntry(id: id, subjectId: subjectId, subjectName: subjectName, title: title, ordinal: ordinal, termName: termName, plannedHours: plannedHours, status: s);

  factory TopicEntry.fromJson(Json j) => TopicEntry(
    id: jStrOr(j['id']),
    subjectId: jStrOr(j['subjectId']),
    subjectName: jStrOr(j['subjectName']),
    title: jStrOr(j['title']),
    ordinal: jInt(j['ordinal']),
    termName: jStr(j['termName']),
    plannedHours: jIntN(j['plannedHours']),
    status: SyllabusStatus.parse(jsonMap(j['progress'])['status']),
  );
}

/// Coverage of one subject in one section (`GET /syllabus/coverage`).
class CoverageRow {
  const CoverageRow({required this.sectionId, required this.sectionName, required this.gradeId, required this.gradeName, required this.subjectId, required this.subjectName, this.totalTopics = 0, this.completed = 0, this.inProgress = 0, this.notStarted = 0, this.percent = 0});
  final String sectionId;
  final String sectionName;
  final String gradeId;
  final String gradeName;
  final String subjectId;
  final String subjectName;
  final int totalTopics;
  final int completed;
  final int inProgress;
  final int notStarted;
  final double percent;

  String get sectionTitle => '$gradeName $sectionName'.trim();

  factory CoverageRow.fromJson(Json j) => CoverageRow(
    sectionId: jStrOr(j['sectionId']),
    sectionName: jStrOr(j['sectionName']),
    gradeId: jStrOr(j['gradeId']),
    gradeName: jStrOr(j['gradeName']),
    subjectId: jStrOr(j['subjectId']),
    subjectName: jStrOr(j['subjectName']),
    totalTopics: jInt(j['totalTopics']),
    completed: jInt(j['completed']),
    inProgress: jInt(j['inProgress']),
    notStarted: jInt(j['notStarted']),
    percent: jDouble(j['percent']),
  );
}
