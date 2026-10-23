import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/staff/roll_call.dart';
import '../../../data/repositories/staff/roll_call_repository.dart';

typedef SchoolAttendanceQuery = ({DateTime? date, int trendDays});

/// `GET /attendance/summary` for a day (null = today) with a 7 or 14 day trend.
final schoolAttendanceProvider = FutureProvider.autoDispose.family<SchoolAttendance, SchoolAttendanceQuery>(
  (ref, q) => ref.watch(rollCallRepositoryProvider).schoolSummary(date: q.date, trendDays: q.trendDays),
);

/// Classes that have not marked attendance first (they need a nudge), then by grade and section name.
List<SchoolSectionRow> sortSectionRows(List<SchoolSectionRow> rows) {
  final copy = [...rows];
  copy.sort((a, b) {
    if (a.marked != b.marked) return a.marked ? 1 : -1;
    return a.title.compareTo(b.title);
  });
  return copy;
}
