import 'package:intl/intl.dart';

/// Money is integer minor units (paise/cents). Shown as `Rs 15,600` / `INR 15,600.50` style by currency.
String formatMinor(int minor, {String currency = 'INR'}) {
  final symbol = switch (currency) { 'INR' => '₹', 'USD' => '\$', 'EUR' => '€', 'GBP' => '£', _ => '$currency ' };
  final negative = minor < 0;
  final abs = minor.abs();
  final whole = abs ~/ 100, cents = abs % 100;
  final grouped = currency == 'INR' ? _indianGrouping(whole) : NumberFormat.decimalPattern('en').format(whole);
  final body = cents == 0 ? grouped : '$grouped.${cents.toString().padLeft(2, '0')}';
  return '${negative ? '-' : ''}$symbol$body';
}

String _indianGrouping(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

/// `08:30` -> `8:30 am`.
String formatClock(String? hhmm) {
  if (hhmm == null || hhmm.isEmpty) return '';
  final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(hhmm);
  if (m == null) return hhmm;
  final h = int.parse(m.group(1)!), min = m.group(2)!;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$min ${h < 12 ? 'am' : 'pm'}';
}

String formatTimeRange(String? from, String? to) {
  final a = formatClock(from), b = formatClock(to);
  if (a.isEmpty) return '';
  return b.isEmpty ? a : '$a - $b';
}

final _dayFmt = DateFormat('EEE, d MMM');
final _dayLongFmt = DateFormat('EEEE, d MMMM');
final _shortFmt = DateFormat('d MMM');
final _fullFmt = DateFormat('d MMM y');
final _timeFmt = DateFormat('h:mm a');

String fmtDay(DateTime d) => _dayFmt.format(d);
String fmtDayLong(DateTime d) => _dayLongFmt.format(d);
String fmtShort(DateTime d) => _shortFmt.format(d);
String fmtFull(DateTime d) => _fullFmt.format(d);
String fmtTime(DateTime d) => _timeFmt.format(d).toLowerCase();
String fmtDateTime(DateTime d) => '${fmtShort(d)}, ${fmtTime(d)}';

/// The app's idea of "now" for greetings and "due in 2 days" labels. Always the real clock in the app; the
/// brochure test replaces it so that screens can be rendered at one fixed, representative moment.
DateTime Function() appNow = DateTime.now;

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "Today", "Tomorrow", "Yesterday", else `Wed, 21 Oct`.
String relativeDay(DateTime d, [DateTime? now]) {
  final n = now ?? appNow();
  final today = DateTime(n.year, n.month, n.day);
  final diff = DateTime(d.year, d.month, d.day).difference(today).inDays;
  return switch (diff) { 0 => 'Today', 1 => 'Tomorrow', -1 => 'Yesterday', _ => fmtDay(d) };
}

/// "Due in 2 days", "Due today", "Overdue by 3 days".
String dueLabel(DateTime due, [DateTime? now]) {
  final n = now ?? appNow();
  final diff = DateTime(due.year, due.month, due.day).difference(DateTime(n.year, n.month, n.day)).inDays;
  if (diff == 0) return 'Due today, ${fmtTime(due)}';
  if (diff == 1) return 'Due tomorrow';
  if (diff > 1) return 'Due in $diff days';
  return 'Overdue by ${-diff} ${diff == -1 ? 'day' : 'days'}';
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

String fileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}
