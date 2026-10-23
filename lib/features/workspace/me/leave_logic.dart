import '../../../data/models/leave.dart' show LeaveType;

/// The API's limits for staff leave (see `LEAVE_TOO_LONG` / `LEAVE_TOO_OLD`).
const maxLeaveDays = 60;
const maxLeaveBackdateDays = 30;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Calendar days from [from] to [to], both included. The school counts only working days, which the API decides.
int calendarDays(DateTime from, DateTime to) => _day(to).difference(_day(from)).inDays + 1;

/// field -> message; empty = valid. Fields: type, from, to, reason.
Map<String, String> validateLeaveForm({required LeaveType? type, required DateTime? from, required DateTime? to, required String reason, DateTime? today}) {
  final errors = <String, String>{};
  final t = _day(today ?? DateTime.now());
  if (type == null) errors['type'] = 'Choose the kind of leave.';
  if (from == null) errors['from'] = 'Pick the first day.';
  if (to == null) errors['to'] = 'Pick the last day.';
  if (from != null && to != null) {
    if (_day(to).isBefore(_day(from))) {
      errors['to'] = 'The last day cannot be before the first day.';
    } else if (calendarDays(from, to) > maxLeaveDays) {
      errors['to'] = 'A request can cover at most $maxLeaveDays days. Split it into shorter requests.';
    }
  }
  if (from != null && _day(from).isBefore(t.subtract(const Duration(days: maxLeaveBackdateDays)))) {
    errors['from'] = 'Leave cannot start more than $maxLeaveBackdateDays days in the past.';
  }
  final r = reason.trim();
  if (r.length < 3) {
    errors['reason'] = 'Say why in a few words.';
  } else if (r.length > 1000) {
    errors['reason'] = 'Keep the reason under 1000 characters.';
  }
  return errors;
}
