import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/attendance.dart';
import '../../data/repositories/attendance_repository.dart';
import '../learner/learner_context.dart';

/// Running attendance for the student (or the selected child) over the academic year.
final attendanceSummaryProvider = FutureProvider<AttendanceSummary?>((ref) async {
  final id = ref.watch(learnerStudentIdProvider);
  if (id == null) return null;
  return ref.watch(attendanceRepositoryProvider).summary(id);
});

typedef RecordsQuery = ({String studentId, AttendanceStatus? status});

class AttendanceRecordsNotifier extends CursorNotifier<AttendanceRecord, RecordsQuery> {
  AttendanceRecordsNotifier(super.arg);

  @override
  Future<CursorPage<AttendanceRecord>> fetch(String? cursor) => ref.read(attendanceRepositoryProvider).records(arg.studentId, cursor: cursor, status: arg.status);
}

final attendanceRecordsProvider = AsyncNotifierProvider.family<AttendanceRecordsNotifier, CursorList<AttendanceRecord>, RecordsQuery>(AttendanceRecordsNotifier.new);
