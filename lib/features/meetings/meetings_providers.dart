import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/meetings.dart';
import '../../data/repositories/meetings_repository.dart';

class MeetingsNotifier extends PagedNotifier<Meeting, String?> {
  MeetingsNotifier(super.arg);
  @override
  Future<Paged<Meeting>> fetch(int page) => ref.read(meetingsRepositoryProvider).list(studentId: arg, page: page);
}

/// Meetings of every child (key null) or one child.
final meetingsProvider = AsyncNotifierProvider.family<MeetingsNotifier, PagedList<Meeting>, String?>(MeetingsNotifier.new);

final meetingTeachersProvider = FutureProvider.family<List<MeetingTeacher>, String>((ref, studentId) => ref.watch(meetingsRepositoryProvider).teachers(studentId));
