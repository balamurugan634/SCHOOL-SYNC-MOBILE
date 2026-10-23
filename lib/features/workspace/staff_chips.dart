import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../../data/models/attendance.dart';

/// Attendance mapping from design.md 2.4: present = success, late = warning, absent = danger,
/// leave = info, half-day = warning. Always an icon and a label, never colour alone.
StatusTone attendanceTone(AttendanceStatus? s) => switch (s) {
  AttendanceStatus.present => StatusTone.success,
  AttendanceStatus.late || AttendanceStatus.halfDay => StatusTone.warning,
  AttendanceStatus.absent => StatusTone.danger,
  AttendanceStatus.leave => StatusTone.info,
  null => StatusTone.neutral,
};

IconData attendanceIcon(AttendanceStatus? s) => switch (s) {
  AttendanceStatus.present => Icons.check_rounded,
  AttendanceStatus.absent => Icons.close_rounded,
  AttendanceStatus.late => Icons.schedule_rounded,
  AttendanceStatus.leave => Icons.event_busy_rounded,
  AttendanceStatus.halfDay => Icons.timelapse_rounded,
  null => Icons.remove_rounded,
};

/// One-letter form for dense places (roll call rows already show the full label too).
String attendanceShort(AttendanceStatus? s) => switch (s) {
  AttendanceStatus.present => 'P',
  AttendanceStatus.absent => 'A',
  AttendanceStatus.late => 'L',
  AttendanceStatus.leave => 'Lv',
  AttendanceStatus.halfDay => 'HD',
  null => '-',
};

class AttendanceChip extends StatelessWidget {
  const AttendanceChip(this.status, {super.key, this.emptyLabel = 'Not marked'});
  final AttendanceStatus? status;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) => StatusChip(status?.label ?? emptyLabel, tone: attendanceTone(status), icon: attendanceIcon(status));
}

/// pending / approved / rejected / cancelled (leave, corrections, expenses, concessions ...).
class DecisionChip extends StatelessWidget {
  const DecisionChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, label) = switch (status) {
      'pending' || 'requested' || 'submitted' => (StatusTone.warning, Icons.hourglass_empty_rounded, 'Pending'),
      'approved' || 'accepted' => (StatusTone.success, Icons.check_rounded, 'Approved'),
      'processed' => (StatusTone.success, Icons.check_rounded, 'Processed'),
      'published' => (StatusTone.success, Icons.check_rounded, 'Published'),
      'rejected' => (StatusTone.danger, Icons.close_rounded, 'Rejected'),
      'returned' => (StatusTone.warning, Icons.undo_rounded, 'Returned'),
      'cancelled' => (StatusTone.neutral, Icons.block_rounded, 'Cancelled'),
      'under_review' => (StatusTone.info, Icons.visibility_outlined, 'Under review'),
      'waitlisted' => (StatusTone.info, Icons.format_list_numbered_rounded, 'Waitlisted'),
      'enrolled' => (StatusTone.success, Icons.school_outlined, 'Enrolled'),
      'draft' => (StatusTone.neutral, Icons.edit_outlined, 'Draft'),
      _ => (StatusTone.neutral, Icons.circle_outlined, status.isEmpty ? 'Unknown' : '${status[0].toUpperCase()}${status.substring(1).replaceAll('_', ' ')}'),
    };
    return StatusChip(label, tone: tone, icon: icon);
  }
}
