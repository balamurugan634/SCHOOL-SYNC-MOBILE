import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/homework.dart';
import '../../data/repositories/homework_repository.dart';
import '../learner/learner_context.dart';

typedef HomeworkQuery = ({String? studentId, String? status});

class HomeworkListNotifier extends PagedNotifier<Homework, HomeworkQuery> {
  HomeworkListNotifier(super.arg);

  @override
  Future<Paged<Homework>> fetch(int page) => ref.read(homeworkRepositoryProvider).list(studentId: arg.studentId, learnerStatus: arg.status, page: page, pageSize: 20);
}

final homeworkListProvider = AsyncNotifierProvider.family<HomeworkListNotifier, PagedList<Homework>, HomeworkQuery>(HomeworkListNotifier.new);

/// One homework (with the learner's state). Parents pass the child's id.
final homeworkDetailProvider = FutureProvider.family<Homework, String>((ref, id) async {
  final studentId = ref.watch(learnerQueryIdProvider);
  return ref.watch(homeworkRepositoryProvider).get(id, studentId: studentId);
});

final homeworkSubmissionProvider = FutureProvider.family<Submission?, String>((ref, id) async {
  final studentId = ref.watch(learnerQueryIdProvider);
  return ref.watch(homeworkRepositoryProvider).submission(id, studentId: studentId);
});
