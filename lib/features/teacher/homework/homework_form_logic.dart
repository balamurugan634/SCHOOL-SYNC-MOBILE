import '../../../core/network/app_exception.dart' show FieldError;
import '../../../data/json.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/teaching.dart';

/// Raw values of the homework form (pure data so the rules can be unit-tested).
class HomeworkFormInput {
  const HomeworkFormInput({this.sectionId, this.subjectId, this.title = '', this.description = '', this.dueAt, this.allowSubmission = true, this.maxMarksText = ''});

  final String? sectionId;
  final String? subjectId;
  final String title;
  final String description;
  final DateTime? dueAt;
  final bool allowSubmission;
  final String maxMarksText;

  @override
  bool operator ==(Object other) =>
      other is HomeworkFormInput &&
      other.sectionId == sectionId &&
      other.subjectId == subjectId &&
      other.title.trim() == title.trim() &&
      other.description.trim() == description.trim() &&
      other.dueAt == dueAt &&
      other.allowSubmission == allowSubmission &&
      other.maxMarksText.trim() == maxMarksText.trim();

  @override
  int get hashCode => Object.hash(sectionId, subjectId, title.trim(), description.trim(), dueAt, allowSubmission, maxMarksText.trim());
}

/// One message per field (null = fine).
class HomeworkFormErrors {
  const HomeworkFormErrors({this.section, this.subject, this.title, this.description, this.due, this.maxMarks});
  final String? section;
  final String? subject;
  final String? title;
  final String? description;
  final String? due;
  final String? maxMarks;

  bool get any => [section, subject, title, description, due, maxMarks].any((e) => e != null);

  HomeworkFormErrors copyWith({String? section, String? subject, String? title, String? description, String? due, String? maxMarks}) =>
      HomeworkFormErrors(section: section ?? this.section, subject: subject ?? this.subject, title: title ?? this.title, description: description ?? this.description, due: due ?? this.due, maxMarks: maxMarks ?? this.maxMarks);
}

const homeworkMaxMarksLimit = 1000;

/// The whole number in [text], or null when it is empty / not a whole number.
int? parseMaxMarks(String text) {
  final t = text.trim();
  if (!RegExp(r'^\d{1,6}$').hasMatch(t)) return null;
  return int.parse(t);
}

/// Validates the form like the API will (title 1-200, description <= 5000, future due date, marks 1-1000).
/// [requireFutureDue] is true when creating, when publishing, or when the due date was changed.
HomeworkFormErrors validateHomeworkForm(HomeworkFormInput v, {required bool creating, required bool requireFutureDue, DateTime? now}) {
  final clock = now ?? DateTime.now();
  String? section, subject, title, description, due, maxMarks;
  if (creating) {
    if (v.sectionId == null) section = 'Choose the class this is for.';
    if (v.subjectId == null) subject = 'Choose the subject.';
  }
  final t = v.title.trim();
  if (t.isEmpty) {
    title = 'Give the homework a title.';
  } else if (t.length > 200) {
    title = 'The title can be at most 200 characters (now ${t.length}).';
  }
  if (v.description.trim().length > 5000) description = 'The description can be at most 5000 characters.';
  if (v.dueAt == null) {
    due = 'Choose when it is due.';
  } else if (requireFutureDue && !v.dueAt!.isAfter(clock)) {
    due = 'The due date must be in the future. Pick a later date and time.';
  }
  if (v.allowSubmission && v.maxMarksText.trim().isNotEmpty) {
    final m = parseMaxMarks(v.maxMarksText);
    if (m == null || m < 1 || m > homeworkMaxMarksLimit) maxMarks = 'Enter a whole number from 1 to $homeworkMaxMarksLimit, or leave it empty for no marks.';
  }
  return HomeworkFormErrors(section: section, subject: subject, title: title, description: description, due: due, maxMarks: maxMarks);
}

/// The payload for create / update. Marks are dropped when online submissions are off.
HomeworkDraft buildHomeworkDraft(HomeworkFormInput v, List<Attachment> attachments) => HomeworkDraft(
  sectionId: v.sectionId ?? '',
  subjectId: v.subjectId ?? '',
  title: v.title,
  description: v.description,
  dueAt: v.dueAt!,
  allowSubmission: v.allowSubmission,
  maxMarks: v.allowSubmission ? parseMaxMarks(v.maxMarksText) : null,
  attachments: attachments,
);

/// Maps API field errors (`errors[].path`) onto the form fields.
HomeworkFormErrors mapServerFieldErrors(List<FieldError> errors, [HomeworkFormErrors base = const HomeworkFormErrors()]) {
  var out = base;
  for (final e in errors) {
    final p = e.path.split('.').first;
    out = switch (p) {
      'title' => out.copyWith(title: e.message),
      'description' => out.copyWith(description: e.message),
      'dueAt' => out.copyWith(due: e.message),
      'maxMarks' => out.copyWith(maxMarks: e.message),
      'sectionId' => out.copyWith(section: e.message),
      'subjectId' => out.copyWith(subject: e.message),
      _ => out,
    };
  }
  return out;
}

/// The distinct sections I teach, in the order the API returned them.
List<MyAssignment> distinctSections(List<MyAssignment> all) {
  final seen = <String>{};
  return [for (final a in all) if (seen.add(a.sectionId)) a];
}

/// The subjects I teach in [sectionId].
List<MyAssignment> subjectsFor(List<MyAssignment> all, String? sectionId) {
  final seen = <String>{};
  return [for (final a in all) if (a.sectionId == sectionId && seen.add(a.subjectId)) a];
}

/// Tomorrow at 5 pm: a sensible default due time for a new homework.
DateTime defaultDueAt([DateTime? now]) {
  final n = now ?? DateTime.now();
  final d = DateTime(n.year, n.month, n.day).add(const Duration(days: 1));
  return DateTime(d.year, d.month, d.day, 17);
}
