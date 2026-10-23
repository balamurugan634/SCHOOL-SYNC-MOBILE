import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../data/repositories/staff/academics_repository.dart';
import '../../workspace/staff_context.dart';

/// One day of my timetable. Each day is kept for five minutes so flipping between days is instant;
/// pull to refresh invalidates it.
final teacherDayProvider = FutureProvider.autoDispose.family<TeacherDay, DateTime>((ref, day) {
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 5), link.close);
  ref.onDispose(timer.cancel);
  return ref.watch(academicsRepositoryProvider).myDay(date: day);
});

/// The (section, subject) pairs I teach: what syllabus progress may be updated for.
final myTeachingAssignmentsProvider = FutureProvider.autoDispose<List<MyAssignment>>((ref) async {
  final staffId = ref.watch(staffIdProvider);
  if (staffId == null) return const [];
  return ref.watch(academicsRepositoryProvider).myAssignments(staffId);
});

typedef TopicsKey = ({String gradeId, String sectionId, String subjectId});

final syllabusTopicsProvider = FutureProvider.autoDispose.family<List<TopicEntry>, TopicsKey>(
  (ref, k) => ref.watch(academicsRepositoryProvider).topics(gradeId: k.gradeId, sectionId: k.sectionId, subjectId: k.subjectId),
);

/// Coverage of one subject in one section (null when the API has no row for it yet).
final syllabusCoverageProvider = FutureProvider.autoDispose.family<CoverageRow?, ({String sectionId, String subjectId})>((ref, k) async {
  final rows = await ref.watch(academicsRepositoryProvider).coverage(sectionId: k.sectionId, subjectId: k.subjectId);
  for (final r in rows) {
    if (r.sectionId == k.sectionId && r.subjectId == k.subjectId) return r;
  }
  return null;
});
