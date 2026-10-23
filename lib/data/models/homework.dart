import '../json.dart';

/// The learner's state for a homework item.
enum LearnerStatus {
  pending,
  submitted,
  late,
  reviewed,
  returned,
  overdue,
  notRequired;

  static LearnerStatus parse(String? v) => switch (v) {
    'submitted' => submitted,
    'late' => late,
    'reviewed' => reviewed,
    'returned' => returned,
    'overdue' => overdue,
    'not_required' => notRequired,
    _ => pending,
  };

  String get label => switch (this) {
    pending => 'To do',
    submitted => 'Submitted',
    late => 'Submitted late',
    reviewed => 'Reviewed',
    returned => 'Returned for rework',
    overdue => 'Overdue',
    notRequired => 'No submission needed',
  };

  bool get needsAction => this == pending || this == overdue || this == returned;
}

class SubmissionBrief {
  const SubmissionBrief({required this.id, required this.status, this.submittedAt, this.isLate = false, this.marks, this.feedback, this.reviewedAt});
  final String id;
  final String status;
  final DateTime? submittedAt;
  final bool isLate;
  final double? marks;
  final String? feedback;
  final DateTime? reviewedAt;

  factory SubmissionBrief.fromJson(Json j) => SubmissionBrief(
    id: jStrOr(j['id']),
    status: jStrOr(j['status']),
    submittedAt: jDate(j['submittedAt']),
    isLate: jBool(j['isLate']),
    marks: jDoubleN(j['marks']),
    feedback: jStr(j['feedback']),
    reviewedAt: jDate(j['reviewedAt']),
  );
}

class Homework {
  const Homework({
    required this.id,
    required this.title,
    required this.subjectName,
    required this.dueAt,
    required this.status,
    required this.allowSubmission,
    required this.learnerStatus,
    this.description,
    this.teacherName,
    this.attachments = const [],
    this.assignedAt,
    this.maxMarks,
    this.submission,
    this.studentId,
  });

  final String id;
  final String title;
  final String subjectName;
  final DateTime? dueAt;
  final DateTime? assignedAt;

  /// draft | published | closed
  final String status;
  final bool allowSubmission;
  final LearnerStatus learnerStatus;
  final String? description;
  final String? teacherName;
  final List<Attachment> attachments;
  final int? maxMarks;
  final SubmissionBrief? submission;
  final String? studentId;

  bool get closed => status == 'closed';
  bool get canSubmit => allowSubmission && !closed;

  factory Homework.fromJson(Json j) {
    final learner = jsonMap(j['learner']);
    final sub = learner['submission'];
    return Homework(
      id: jStrOr(j['id']),
      title: jStrOr(j['title']),
      subjectName: jStrOr(j['subjectName']),
      dueAt: jDate(j['dueAt']),
      assignedAt: jDate(j['assignedAt']),
      status: jStrOr(j['status'], 'published'),
      allowSubmission: jBool(j['allowSubmission'], true),
      learnerStatus: LearnerStatus.parse(jStr(learner['status'])),
      description: jStr(j['description']),
      teacherName: jStr(j['teacherName']),
      attachments: Attachment.list(j['attachments']),
      maxMarks: jIntN(j['maxMarks']),
      submission: sub is Map ? SubmissionBrief.fromJson(jsonMap(sub)) : null,
      studentId: jStr(learner['studentId']),
    );
  }
}

class Submission {
  const Submission({required this.id, required this.homeworkId, required this.status, this.text, this.attachments = const [], this.submittedAt, this.isLate = false, this.marks, this.feedback, this.reviewedAt});
  final String id;
  final String homeworkId;
  final String status; // submitted | late | reviewed | returned
  final String? text;
  final List<Attachment> attachments;
  final DateTime? submittedAt;
  final bool isLate;
  final double? marks;
  final String? feedback;
  final DateTime? reviewedAt;

  factory Submission.fromJson(Json j) => Submission(
    id: jStrOr(j['id']),
    homeworkId: jStrOr(j['homeworkId']),
    status: jStrOr(j['status']),
    text: jStr(j['text']),
    attachments: Attachment.list(j['attachments']),
    submittedAt: jDate(j['submittedAt']),
    isLate: jBool(j['isLate']),
    marks: jDoubleN(j['marks']),
    feedback: jStr(j['feedback']),
    reviewedAt: jDate(j['reviewedAt']),
  );
}
