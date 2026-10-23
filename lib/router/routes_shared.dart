/// Paths of pushed screens shared by the student and parent experiences (and reusable by other roles).
///
/// The `GoRoute`s are registered in [sharedRoutes] (see `routes_shared_list.dart`). Screens read the active child
/// through `learnerStudentIdProvider` so the same screen serves a student and a parent.
abstract final class SharedRoutes {
  static const homework = '/homework';
  static String homeworkDetail(String id) => '/homework/$id';
  static const attendance = '/attendance';
  static const timetable = '/timetable';
  static const calendar = '/calendar';
  static const exams = '/exams';
  static const results = '/results';
  static String reportCard(String examId) => '/results/$examId';
  static const fees = '/fees';
  static String invoice(String id) => '/fees/invoice/$id';
  static String receipt(String paymentId) => '/fees/receipt/$paymentId';
  static String pay(String invoiceId) => '/fees/pay/$invoiceId';
  static const announcements = '/announcements';
  static String announcementDetail(String id) => '/announcements/$id';
  static const events = '/events';
  static String eventDetail(String id) => '/events/$id';
  static const meetings = '/meetings';
  static const meetingNew = '/meetings/new';
  static const leave = '/leave';
  static const leaveNew = '/leave/new';
  static const notificationSettings = '/notifications/settings';
  static const materials = '/materials';
  static const syllabus = '/syllabus';
  static const library = '/library';
  static const transport = '/transport';
  static const profileDetails = '/profile/details';
  static const tasks = '/tasks';
}
