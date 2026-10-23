import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/paged.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/leave.dart';
import '../../../data/repositories/staff/staff_leave_repository.dart';

/// My own attendance (today + the last 30 days).
final myStaffAttendanceProvider = FutureProvider.autoDispose<MyStaffAttendance>((ref) => ref.watch(staffLeaveRepositoryProvider).myAttendance());

final staffLeaveBalanceProvider = FutureProvider.autoDispose<StaffLeaveBalance>((ref) => ref.watch(staffLeaveRepositoryProvider).balance());

/// My staff leave requests, newest / pending first (as the API orders them).
class MyLeaveNotifier extends PagedNotifier<StaffLeaveItem, int> {
  MyLeaveNotifier(super.arg);

  @override
  Future<Paged<StaffLeaveItem>> fetch(int page) => ref.read(staffLeaveRepositoryProvider).staffLeave(page: page, pageSize: 20);
}

final myLeaveProvider = AsyncNotifierProvider.autoDispose.family<MyLeaveNotifier, PagedList<StaffLeaveItem>, int>(MyLeaveNotifier.new);
