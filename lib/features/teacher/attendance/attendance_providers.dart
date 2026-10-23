import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/paged.dart';
import '../../../data/json.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/staff/leave.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../data/repositories/staff/academics_repository.dart';
import '../../../data/repositories/staff/roll_call_repository.dart';
import '../../../data/repositories/staff/staff_leave_repository.dart';
import 'roll_call_draft.dart';

/// Sections (or period slots) I take attendance for today.
final attendanceTodayProvider = FutureProvider.autoDispose<AttendanceToday>((ref) => ref.watch(rollCallRepositoryProvider).today());

/// The sections I teach or lead this year (pickers on the History segment).
final attendanceSectionsProvider = FutureProvider.autoDispose<List<SectionItem>>((ref) => ref.watch(academicsRepositoryProvider).sections());

/// A section's attendance over the last 30 days: per-day counts and per-student percentages.
final sectionAttendanceSummaryProvider = FutureProvider.autoDispose.family<SectionAttendanceSummary, String>((ref, sectionId) {
  final to = DateTime.now();
  return ref.watch(rollCallRepositoryProvider).sectionSummary(sectionId, from: to.subtract(const Duration(days: 30)), to: to);
});

// ───────────────────────────── roll call ─────────────────────────────

/// Which roll call: a section, a date (`yyyy-MM-dd`, null = today) and, in period mode, a period.
typedef RollCallArgs = ({String sectionId, String? date, String? periodId});

class RollCallState {
  const RollCallState(this.draft);
  final RollCallDraft draft;
  Roster get roster => draft.roster;
}

/// Loads the roster, holds the teacher's choices, and submits. Editing never touches the network;
/// a failed submit leaves every choice in place.
class RollCallController extends AsyncNotifier<RollCallState> {
  RollCallController(this.args);
  final RollCallArgs args;

  @override
  Future<RollCallState> build() async {
    final roster = await ref.read(rollCallRepositoryProvider).roster(args.sectionId, date: args.date == null ? null : jDay(args.date), periodId: args.periodId);
    return RollCallState(RollCallDraft.fromRoster(roster));
  }

  void _edit(RollCallDraft Function(RollCallDraft d) change) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(RollCallState(change(cur.draft)));
  }

  void setStatus(String studentId, AttendanceStatus status) => _edit((d) => d.setStatus(studentId, status));
  void setRemark(String studentId, String? text) => _edit((d) => d.setRemark(studentId, text));
  void markAllPresent({bool onlyUnmarked = false}) => _edit((d) => d.markAllPresent(onlyUnmarked: onlyUnmarked));

  /// Sends the roll call. Throws the API's `AppException` on failure (the screen explains it); the draft is kept.
  Future<SubmitResult> submit() async {
    final cur = state.value;
    if (cur == null) throw StateError('The roll call is not loaded.');
    final d = cur.draft;
    final res = await ref.read(rollCallRepositoryProvider).submit(args.sectionId, entries: d.entries, date: d.roster.date, periodId: d.roster.periodId);
    ref.invalidate(attendanceTodayProvider);
    ref.invalidate(sectionAttendanceSummaryProvider(args.sectionId));
    return res;
  }
}

final rollCallProvider = AsyncNotifierProvider.autoDispose.family<RollCallController, RollCallState, RollCallArgs>(RollCallController.new);

// ───────────────────────────── corrections ─────────────────────────────

/// [mine] = requests I raised; otherwise the ones waiting for my decision.
typedef CorrectionQuery = ({String status, bool mine});

class CorrectionsNotifier extends PagedNotifier<CorrectionItem, CorrectionQuery> {
  CorrectionsNotifier(super.arg);

  @override
  Future<Paged<CorrectionItem>> fetch(int page) async {
    final p = await ref.read(rollCallRepositoryProvider).corrections(status: arg.status, mine: arg.mine, page: page, pageSize: 20);
    // "To decide" only lists what I am allowed to decide (never my own requests).
    return arg.mine ? p : Paged(p.items.where((c) => c.canDecide).toList(growable: false), p.meta);
  }
}

final correctionsProvider = AsyncNotifierProvider.autoDispose.family<CorrectionsNotifier, PagedList<CorrectionItem>, CorrectionQuery>(CorrectionsNotifier.new);

// ───────────────────────────── student leave ─────────────────────────────

/// Status filter: pending | approved | rejected.
class StudentLeaveNotifier extends PagedNotifier<StudentLeaveItem, String> {
  StudentLeaveNotifier(super.arg);

  @override
  Future<Paged<StudentLeaveItem>> fetch(int page) => ref.read(staffLeaveRepositoryProvider).studentLeave(status: arg, page: page, pageSize: 20);
}

final studentLeaveListProvider = AsyncNotifierProvider.autoDispose.family<StudentLeaveNotifier, PagedList<StudentLeaveItem>, String>(StudentLeaveNotifier.new);
