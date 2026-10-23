import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/tasks.dart';
import '../../data/repositories/tasks_repository.dart';

/// Whether the feed also lists completed tasks.
class ShowDone extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

final showDoneProvider = NotifierProvider<ShowDone, bool>(ShowDone.new);

/// Personal tasks plus pending homework, soonest first.
final taskFeedProvider = FutureProvider<List<TaskFeedItem>>((ref) async {
  final includeDone = ref.watch(showDoneProvider);
  return ref.watch(tasksRepositoryProvider).feed(includeDone: includeDone);
});
