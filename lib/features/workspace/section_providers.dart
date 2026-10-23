import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/staff/people.dart';
import '../../data/models/staff/roll_call.dart';
import '../../data/models/staff/teaching.dart';
import '../../data/repositories/staff/academics_repository.dart';
import '../../data/repositories/staff/people_repository.dart';
import '../../data/repositories/staff/roll_call_repository.dart';

final sectionDetailProvider = FutureProvider.autoDispose.family<SectionDetail, String>((ref, id) => ref.watch(academicsRepositoryProvider).section(id));

/// Every student of the section (a section never exceeds the API's page size of 100).
final sectionStudentsProvider = FutureProvider.autoDispose.family<List<StudentRow>, String>((ref, id) async {
  final page = await ref.watch(peopleRepositoryProvider).students(sectionId: id, pageSize: 100);
  return page.items;
});

/// Syllabus coverage per subject for the section.
final sectionCoverageProvider = FutureProvider.autoDispose.family<List<CoverageRow>, String>((ref, id) => ref.watch(academicsRepositoryProvider).coverage(sectionId: id));

/// Attendance over the last 30 days: totals and a percentage per student.
final sectionAttendanceProvider = FutureProvider.autoDispose.family<SectionAttendanceSummary, String>((ref, id) {
  final to = DateTime.now();
  return ref.watch(rollCallRepositoryProvider).sectionSummary(id, from: to.subtract(const Duration(days: 30)), to: to);
});
