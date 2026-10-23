import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/paged.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../data/repositories/staff/academics_repository.dart';
import '../../../data/repositories/staff/staff_homework_repository.dart';
import '../../workspace/staff_context.dart';

/// The teacher's homework list for one lifecycle state (`published` = active, `draft`, `closed`).
class TeacherHomeworkListNotifier extends PagedNotifier<HomeworkEntry, String> {
  TeacherHomeworkListNotifier(super.arg);

  @override
  Future<Paged<HomeworkEntry>> fetch(int page) => ref.read(staffHomeworkRepositoryProvider).list(status: arg, sort: arg == 'published' ? 'dueAsc' : 'dueDesc', page: page, pageSize: 20);
}

final teacherHomeworkListProvider = AsyncNotifierProvider.family<TeacherHomeworkListNotifier, PagedList<HomeworkEntry>, String>(TeacherHomeworkListNotifier.new);

final teacherHomeworkProvider = FutureProvider.autoDispose.family<HomeworkEntry, String>((ref, id) => ref.watch(staffHomeworkRepositoryProvider).get(id));

/// A homework with its per-student hand-in state (the roster response embeds the homework and its stats).
final homeworkRosterProvider = FutureProvider.autoDispose.family<HomeworkRoster, String>((ref, id) => ref.watch(staffHomeworkRepositoryProvider).roster(id));

final submissionProvider = FutureProvider.autoDispose.family<SubmissionEntry, String>((ref, id) => ref.watch(staffHomeworkRepositoryProvider).submission(id));

/// What I teach: the only (section, subject) pairs homework may be set for.
final myAssignmentsProvider = FutureProvider.autoDispose<List<MyAssignment>>((ref) async {
  final staffId = ref.watch(staffIdProvider);
  if (staffId == null) return const [];
  return ref.watch(academicsRepositoryProvider).myAssignments(staffId);
});

/// Refresh everything that shows [id] (and every list) after a write.
void refreshHomework(WidgetRef ref, {String? id}) {
  ref.invalidate(teacherHomeworkListProvider);
  if (id != null) {
    ref.invalidate(homeworkRosterProvider(id));
    ref.invalidate(teacherHomeworkProvider(id));
  }
}
