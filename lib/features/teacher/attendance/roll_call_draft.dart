import '../../../data/models/attendance.dart';
import '../../../data/models/staff/roll_call.dart';

/// The in-progress roll call: what the teacher has chosen so far for each student, on top of the saved [roster].
/// Pure and immutable so the rules (completeness, dirty tracking, payload) are unit-tested without a widget.
class RollCallDraft {
  RollCallDraft._(this.roster, this.statuses, this.remarks);

  /// Starts from what the server has: saved statuses stay; a student on approved leave who has no mark yet is
  /// pre-filled as Leave (the API forces that status for them anyway).
  factory RollCallDraft.fromRoster(Roster roster) {
    final statuses = <String, AttendanceStatus>{};
    final remarks = <String, String>{};
    for (final s in roster.students) {
      final st = s.status ?? (s.onApprovedLeave ? AttendanceStatus.leave : null);
      if (st != null) statuses[s.studentId] = st;
      if (s.remarks != null && s.remarks!.trim().isNotEmpty) remarks[s.studentId] = s.remarks!.trim();
    }
    return RollCallDraft._(roster, statuses, remarks);
  }

  final Roster roster;
  final Map<String, AttendanceStatus> statuses;
  final Map<String, String> remarks;

  List<RosterStudent> get students => roster.students;
  int get total => students.length;

  AttendanceStatus? statusOf(String studentId) => statuses[studentId];
  String? remarkOf(String studentId) => remarks[studentId];

  /// A student on approved leave cannot be changed here: the API records them as Leave.
  bool isLocked(RosterStudent s) => s.onApprovedLeave;

  int get markedCount => students.where((s) => statuses.containsKey(s.studentId)).length;
  int get unmarkedCount => total - markedCount;
  bool get isComplete => total > 0 && unmarkedCount == 0;
  double get progress => total == 0 ? 0 : markedCount / total;

  StatusCounts get counts {
    var p = 0, a = 0, l = 0, lv = 0, hd = 0;
    for (final s in students) {
      switch (statuses[s.studentId]) {
        case AttendanceStatus.present:
          p++;
        case AttendanceStatus.absent:
          a++;
        case AttendanceStatus.late:
          l++;
        case AttendanceStatus.leave:
          lv++;
        case AttendanceStatus.halfDay:
          hd++;
        case null:
          break;
      }
    }
    return StatusCounts(present: p, absent: a, late: l, leave: lv, halfDay: hd, unmarked: unmarkedCount);
  }

  /// Students in roll order who have [status].
  List<RosterStudent> withStatus(AttendanceStatus status) => students.where((s) => statuses[s.studentId] == status).toList(growable: false);

  /// True when anything differs from what the server already has (a status or a remark).
  bool get isDirty {
    for (final s in students) {
      final original = s.status ?? (s.onApprovedLeave ? AttendanceStatus.leave : null);
      if (statuses[s.studentId] != original) return true;
      final r = (s.remarks ?? '').trim();
      if ((remarks[s.studentId] ?? '') != r) return true;
    }
    return false;
  }

  RollCallDraft setStatus(String studentId, AttendanceStatus status) {
    final s = students.where((e) => e.studentId == studentId);
    if (s.isEmpty || isLocked(s.first)) return this;
    return RollCallDraft._(roster, {...statuses, studentId: status}, remarks);
  }

  RollCallDraft setRemark(String studentId, String? text) {
    final t = (text ?? '').trim();
    final next = {...remarks};
    if (t.isEmpty) {
      next.remove(studentId);
    } else {
      next[studentId] = t;
    }
    return RollCallDraft._(roster, statuses, next);
  }

  /// Sets every student who can be changed to Present. With [onlyUnmarked] students who already have a status keep it.
  RollCallDraft markAllPresent({bool onlyUnmarked = false}) {
    final next = {...statuses};
    for (final s in students) {
      if (isLocked(s)) continue;
      if (onlyUnmarked && next.containsKey(s.studentId)) continue;
      next[s.studentId] = AttendanceStatus.present;
    }
    return RollCallDraft._(roster, next, remarks);
  }

  /// Some students already have a status the teacher chose or the server saved (so "Mark all present" should ask first).
  bool get hasChosenStatuses => students.any((s) => !isLocked(s) && statuses[s.studentId] != null && statuses[s.studentId] != AttendanceStatus.present);

  /// The payload of `PUT /attendance/sections/:id`: every student, in roll order. Throws when incomplete.
  List<RollEntry> get entries {
    if (!isComplete) throw StateError('Every student needs a status before the roll call can be submitted.');
    return [for (final s in students) RollEntry(s.studentId, statuses[s.studentId]!, remarks: remarks[s.studentId])];
  }
}
