import 'package:intl/intl.dart';

import '../../../data/models/staff/dashboards.dart';
import '../../../data/models/staff/finance.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../core/util/format.dart';

String _pct(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)}%';

/// "Average 95.4%, lowest 94.8% on Tue, highest 96.6% on Wed." (empty trend -> a plain sentence).
String attendanceTrendSummary(List<TrendPoint> points) {
  final p = [for (final e in points) if (e.percentPresent != null) e];
  if (p.isEmpty) return 'No attendance has been recorded for this period yet.';
  final avg = p.fold<double>(0, (a, e) => a + e.percentPresent!) / p.length;
  final low = p.reduce((a, b) => a.percentPresent! <= b.percentPresent! ? a : b);
  final high = p.reduce((a, b) => a.percentPresent! >= b.percentPresent! ? a : b);
  final day = DateFormat('EEE');
  if (p.length == 1) return 'Only one day so far: ${_pct(p.first.percentPresent!)} present on ${day.format(p.first.date)}.';
  return 'Average ${_pct(double.parse(avg.toStringAsFixed(1)))} present over ${p.length} days, lowest ${_pct(low.percentPresent!)} on ${day.format(low.date)}, highest ${_pct(high.percentPresent!)} on ${day.format(high.date)}.';
}

/// "Collected most in Sep (₹25,60,378); total ₹66,80,798 over 5 months."
String monthlyMoneySummary(List<MonthMoney> months, String currency) {
  if (months.isEmpty) return 'No payments have been recorded in this period.';
  final best = months.reduce((a, b) => a.collectedMinor >= b.collectedMinor ? a : b);
  final total = months.fold<int>(0, (a, e) => a + e.collectedMinor);
  return 'Collected most in ${monthLabel(best.month)} (${formatMinor(best.collectedMinor, currency: currency)}); ${formatMinor(total, currency: currency)} over ${months.length} ${months.length == 1 ? 'month' : 'months'}.';
}

/// `2026-09` -> `Sep`.
String monthLabel(String yearMonth) {
  final m = RegExp(r'^(\d{4})-(\d{2})').firstMatch(yearMonth);
  if (m == null) return yearMonth;
  return DateFormat('MMM').format(DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!)));
}

/// "179 present, 5 absent, 5 late, 0 on leave, 3 half-day" for screen readers.
String attendanceCountsSummary(StatusCounts c) => '${c.present} present, ${c.absent} absent, ${c.late} late, ${c.leave} on leave, ${c.halfDay} half-day';

/// A short phrase for the licence banner. Null when nothing needs attention.
({String title, String message, bool critical})? licenseNotice(LicenseInfo? l) {
  if (l == null || !l.needsAttention) return null;
  final seats = l.seatsLicensed == null ? '' : ' ${l.seatsUsed} of ${l.seatsLicensed} student seats are in use.';
  if (l.state == 'expired' || l.state == 'cancelled' || l.readOnly) {
    return (title: 'Subscription ended', message: 'Your school is in view-only mode. Staff can read information but not change it until the subscription is renewed.$seats', critical: true);
  }
  if (l.state == 'grace') {
    final by = l.graceEndsOn == null ? '' : ' Renew by ${fmtFull(l.graceEndsOn!)} to avoid view-only mode.';
    return (title: 'Subscription period has ended', message: 'You are in the grace period.$by$seats', critical: false);
  }
  if (l.overBy > 0) {
    return (title: 'More students than licensed seats', message: '${l.seatsUsed} students are enrolled for ${l.seatsLicensed} licensed seats (${l.overBy} over).', critical: false);
  }
  if (l.nearLimit) {
    return (title: 'Student seats are almost used up', message: '${l.seatsUsed} of ${l.seatsLicensed} student seats are in use.', critical: false);
  }
  final d = l.daysLeft ?? 0;
  return (title: 'Subscription ends soon', message: 'The subscription ends in ${plural(d, 'day')}.', critical: false);
}
