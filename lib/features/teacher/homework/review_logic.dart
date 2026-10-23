import '../../../data/models/staff/teaching.dart';
import '../marks/marks_logic.dart';

/// Problems with a review before sending. [maxMarks] null = the homework carries no marks.
({String? marks, String? feedback, String? general}) validateReview({required String marksText, required String feedback, required int? maxMarks, bool requireFeedback = false}) {
  String? marks, fb, general;
  final hasMarks = marksText.trim().isNotEmpty;
  if (hasMarks) {
    marks = maxMarks == null ? 'This homework has no marks. Give feedback instead.' : markError(marksText, maxMarks.toDouble());
  }
  if (feedback.trim().length > 2000) fb = 'Feedback can be at most 2000 characters.';
  if (requireFeedback && feedback.trim().isEmpty) fb = 'Say what needs to be redone so the student knows.';
  if (!requireFeedback && !hasMarks && feedback.trim().isEmpty) general = 'Give marks or write feedback before saving.';
  return (marks: marks, feedback: fb, general: general);
}

/// Other hand-ins still waiting for review (submitted or late), excluding [currentId].
List<HomeworkRosterRow> nextToReview(HomeworkRoster roster, String currentId) => [
  for (final r in roster.rows)
    if (r.submission != null && r.submission!.id != currentId && (r.status == 'submitted' || r.status == 'late')) r,
];
