import '../../core/network/app_exception.dart';

/// Plain-language text for API problem codes that a teacher or office user can hit.
/// Unknown codes fall back to the API's own `detail` / `title`, which are already written for people.
const _copy = <String, String>{
  // roll call
  'EDIT_WINDOW_CLOSED': 'The time allowed to change this roll call has passed. Open the student and ask for a correction instead; the class teacher or the office will decide.',
  'NOT_A_WORKING_DAY': 'That date is not a school working day, so attendance cannot be taken for it.',
  'HOLIDAY': 'That date is a holiday, so attendance cannot be taken for it.',
  'FUTURE_DATE': 'Attendance cannot be recorded for a date that has not happened yet.',
  'INCOMPLETE_ROLL_CALL': 'Every student needs a status before the roll call can be submitted. Mark the remaining students, or use "Mark all present" first.',
  'NOT_CLASS_TEACHER': 'Only the class teacher can take daily attendance for this section.',
  'NOT_YOUR_PERIOD': 'This period is not on your timetable, so you cannot mark it.',
  'NOT_ALLOWED_TO_MARK': 'Your role does not allow marking attendance for this section.',
  'PERIOD_REQUIRED': 'This school takes attendance period by period. Open the roll call from one of your periods.',
  'OUTSIDE_ACADEMIC_YEAR': 'That date is outside the current academic year.',
  'EMPTY_SECTION': 'This section has no active students yet.',
  'STUDENT_NOT_IN_SECTION': 'A student on this list no longer belongs to the section. Pull to refresh and try again.',
  'CORRECTION_PENDING': 'A correction for this record is already waiting for a decision.',
  'NO_CHANGE': 'The record already has that status.',
  'SELF_APPROVAL': 'You cannot decide your own request. Someone else needs to approve it.',
  'ALREADY_DECIDED': 'Someone has already decided this. Pull to refresh to see the result.',
  'NOTE_REQUIRED': 'Please add a short note explaining the decision.',
  // leave
  'LEAVE_OVERLAP': 'You already have a leave request covering some of these dates.',
  'LEAVE_TOO_LONG': 'That leave is longer than a single request may cover. Split it into shorter requests.',
  'LEAVE_TOO_OLD': 'Leave cannot start that far in the past.',
  'NO_WORKING_DAYS': 'The dates you chose contain no school days.',
  'NOT_PENDING': 'This request has already been decided or withdrawn.',
  'ALREADY_CHECKED_IN': 'You already checked in today.',
  'ALREADY_CHECKED_OUT': 'You already checked out today.',
  'NOT_CHECKED_IN': 'Check in first, then check out.',
  'ALREADY_MARKED': 'The office has already recorded your attendance for today.',
  // homework
  'DUE_DATE_PAST': 'The due date must be in the future. Pick a later date and time.',
  'HOMEWORK_CLOSED': 'This homework is closed, so it can no longer be changed.',
  'HOMEWORK_HAS_SUBMISSIONS': 'Students have already handed work in, so it cannot be deleted. Close it instead.',
  'NOT_TEACHING_SUBJECT': 'You are not assigned to teach this subject in this class.',
  'MARKS_EXCEED_MAX': 'The marks are higher than the maximum for this work.',
  'EMPTY_REVIEW': 'Give marks or write feedback before saving the review.',
  'SUBMISSION_LOCKED': 'This submission has already been reviewed and can no longer be changed.',
  'INVALID_STATE': 'That is not possible in the current state. Pull to refresh and try again.',
  // marks
  'MARKS_ENTRY_NOT_OPEN': 'Marks entry has not been opened for this exam yet.',
  'NOT_SUBJECT_TEACHER': 'Only the subject teacher of this class can enter or submit these marks.',
  'INVALID_SHEET_STATE': 'This mark sheet has already moved on, so it cannot be changed here.',
  'DUPLICATE_ENTRY': 'A student appears more than once in the entries.',
  // announcements, meetings
  'AUDIENCE_NOT_ALLOWED': 'You can only address the classes you lead or teach.',
  'AUDIENCE_EMPTY': 'Choose who this announcement is for.',
  'ANNOUNCEMENT_NOT_EDITABLE': 'A published announcement cannot be edited. Archive it and post a new one.',
  'ANNOUNCEMENT_NOT_DRAFT': 'Only a draft can be published or scheduled.',
  'SCHEDULED_AT_IN_PAST': 'Pick a time in the future.',
  'MEETING_SLOT_TAKEN': 'You already have a meeting at that time. Pick another time.',
  'MEETING_LINK_REQUIRED': 'An online meeting needs a link.',
  'MEETING_INVALID_STATE': 'That meeting has already changed. Pull to refresh to see its current state.',
  // finance
  'REFUND_EXCEEDS_PAYMENT': 'That refund is more than what is left on the payment.',
  'FEATURE_DISABLED': 'This part of SchoolSync is not turned on for your school.',
  // people
  'INVALID_TRANSITION': 'The application cannot move to that status from where it is.',
  'ADMISSION_NOT_ACCEPTED': 'Only an accepted application can be enrolled.',
  'ALREADY_ENROLLED': 'This application has already been enrolled.',
  'FORBIDDEN': 'Your role does not allow this.',
};

/// A sentence to show a person for [e]. Keeps the API's wording when it is better than ours.
String friendlyError(Object error) {
  final e = AppException.from(error);
  final byCode = _copy[e.code];
  if (byCode != null) return byCode;
  return switch (e.kind) {
    ErrorKind.network || ErrorKind.timeout => 'You are offline. Check your connection and try again.',
    ErrorKind.subscriptionExpired => 'Your school is in view-only mode, so changes are switched off until the subscription is renewed.',
    ErrorKind.forbidden => 'Your role does not allow this.',
    ErrorKind.notFound => 'That no longer exists, or it is outside your access.',
    ErrorKind.rateLimited => 'Too many requests. Wait a moment and try again.',
    ErrorKind.server => 'The server had a problem. Please try again in a moment.',
    _ => e.displayMessage,
  };
}

/// Does the code mean "someone else got there first": the screen should refresh rather than retry?
bool isStaleStateError(Object error) {
  final c = AppException.from(error).code;
  return const {'ALREADY_DECIDED', 'NOT_PENDING', 'INVALID_STATE', 'MEETING_INVALID_STATE', 'INVALID_SHEET_STATE'}.contains(c);
}
