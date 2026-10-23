import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/leave.dart';
import '../../data/repositories/leave_repository.dart';

class LeaveNotifier extends PagedNotifier<LeaveRequest, String?> {
  LeaveNotifier(super.arg);
  @override
  Future<Paged<LeaveRequest>> fetch(int page) => ref.read(leaveRepositoryProvider).list(studentId: arg, page: page);
}

/// Leave requests of the student / child (key = the `studentId` query for parents, null for students).
final leaveListProvider = AsyncNotifierProvider.family<LeaveNotifier, PagedList<LeaveRequest>, String?>(LeaveNotifier.new);
