import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/paged.dart';
import '../../../data/json.dart';
import '../../../data/repositories/staff/finance_repository.dart';
import '../../../data/repositories/staff/marks_repository.dart';
import '../../../data/repositories/staff/people_repository.dart';
import '../../../data/repositories/staff/roll_call_repository.dart';
import '../../../data/repositories/staff/staff_leave_repository.dart';
import '../../../router/routes_management.dart';

typedef ApprovalQuery = ({String kind, String status});

/// One queue (leave, corrections, mark sheets, concessions, refunds, expenses, admissions) filtered by status.
/// Items are the repository models for that kind; the list screen picks the row and the decision sheet from the type.
class ApprovalFeed extends PagedNotifier<Object, ApprovalQuery> {
  ApprovalFeed(super.arg);

  @override
  Future<Paged<Object>> fetch(int page) async {
    const size = 20;
    final s = arg.status;
    Paged<Object> wrap<T extends Object>(Paged<T> p) => Paged<Object>(p.items, p.meta);
    return switch (arg.kind) {
      ApprovalKind.studentLeave => wrap(await ref.read(staffLeaveRepositoryProvider).studentLeave(status: s, page: page, pageSize: size)),
      ApprovalKind.staffLeave => wrap(await ref.read(staffLeaveRepositoryProvider).staffLeave(status: s, page: page, pageSize: size)),
      ApprovalKind.attendance => wrap(await ref.read(rollCallRepositoryProvider).corrections(status: s, page: page, pageSize: size)),
      ApprovalKind.marks => wrap(await ref.read(marksRepositoryProvider).sheets(status: s, page: page, pageSize: size)),
      ApprovalKind.concessions => wrap(await ref.read(financeRepositoryProvider).concessions(status: s, page: page, pageSize: size)),
      ApprovalKind.refunds => wrap(await ref.read(financeRepositoryProvider).refunds(status: s, page: page, pageSize: size)),
      ApprovalKind.expenses => wrap(await ref.read(financeRepositoryProvider).expenses(status: s, page: page, pageSize: size)),
      ApprovalKind.admissions => wrap(await ref.read(peopleRepositoryProvider).admissions(status: s, page: page, pageSize: size)),
      _ => const Paged<Object>([], PageMeta()),
    };
  }
}

final approvalFeedProvider = AsyncNotifierProvider.family<ApprovalFeed, PagedList<Object>, ApprovalQuery>(ApprovalFeed.new);
