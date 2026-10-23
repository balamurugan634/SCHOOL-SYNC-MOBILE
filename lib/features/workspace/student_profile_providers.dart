import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attendance.dart';
import '../../data/models/staff/finance.dart';
import '../../data/models/staff/people.dart';
import '../../data/models/staff/teaching.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/staff/finance_repository.dart';
import '../../data/repositories/staff/people_repository.dart';
import '../../data/repositories/staff/staff_homework_repository.dart';

final studentDetailProvider = FutureProvider.autoDispose.family<StudentDetail, String>((ref, id) => ref.watch(peopleRepositoryProvider).student(id));

/// Year-to-date attendance (the same endpoint the student and parent apps use).
final studentAttendanceProvider = FutureProvider.autoDispose.family<AttendanceSummary, String>((ref, id) => ref.watch(attendanceRepositoryProvider).summary(id));

/// One homework and what this student did with it.
class StudentHomeworkLine {
  const StudentHomeworkLine(this.homework, this.row);
  final HomeworkEntry homework;

  /// null when the roster could not be read for this homework.
  final HomeworkRosterRow? row;
}

typedef StudentHomeworkArgs = ({String studentId, String sectionId});

/// The section's latest homework, with this student's state on each (the five most recent, rosters read in parallel).
final studentHomeworkProvider = FutureProvider.autoDispose.family<List<StudentHomeworkLine>, StudentHomeworkArgs>((ref, args) async {
  final repo = ref.watch(staffHomeworkRepositoryProvider);
  final page = await repo.list(mine: false, sectionId: args.sectionId, pageSize: 8);
  final recent = page.items.where((h) => !h.isDraft).take(5).toList();
  return Future.wait([
    for (final h in recent)
      () async {
        try {
          final roster = await repo.roster(h.id);
          final row = roster.rows.where((r) => r.studentId == args.studentId).firstOrNull;
          return StudentHomeworkLine(h, row);
        } catch (_) {
          return StudentHomeworkLine(h, null);
        }
      }(),
  ]);
});

/// The student's invoices (read-only).
final studentInvoicesProvider = FutureProvider.autoDispose.family<List<InvoiceLine>, String>((ref, id) => ref.watch(financeRepositoryProvider).invoicesOf(id));
