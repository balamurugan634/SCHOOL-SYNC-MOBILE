import '../../../data/models/staff/leave.dart';

/// Where the person stands today, decided from their own attendance record.
enum CheckInPhase {
  /// No record yet: the Check in button is on.
  notCheckedIn,

  /// Checked in, not out: the Check out button is on.
  checkedIn,

  /// Both times are recorded.
  checkedOut,

  /// The office recorded a status (for example Absent or Leave) without a check-in; self check-in is closed (`ALREADY_MARKED`).
  recordedByOffice,
}

CheckInPhase checkInPhase(MyStaffAttendance a) {
  final today = a.today;
  if (today == null) return CheckInPhase.notCheckedIn;
  if (today.checkIn == null) return CheckInPhase.recordedByOffice;
  if (today.checkOut == null) return CheckInPhase.checkedIn;
  return CheckInPhase.checkedOut;
}

/// "7 h 23 min" between two `HH:mm` times of one day, or null when either is missing / the order is wrong.
String? workedDuration(String? checkIn, String? checkOut) {
  int? minutes(String? s) {
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(s ?? '');
    return m == null ? null : int.parse(m.group(1)!) * 60 + int.parse(m.group(2)!);
  }

  final a = minutes(checkIn), b = minutes(checkOut);
  if (a == null || b == null || b < a) return null;
  final d = b - a;
  final h = d ~/ 60, m = d % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
