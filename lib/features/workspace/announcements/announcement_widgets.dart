import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/comms.dart';

/// draft / scheduled / published / expired / archived: always an icon and a label.
class AnnouncementStateChip extends StatelessWidget {
  const AnnouncementStateChip(this.a, {super.key});
  final ManagedAnnouncement a;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, label) = switch (a.state) {
      'draft' => (StatusTone.neutral, Icons.edit_outlined, 'Draft'),
      'scheduled' => (StatusTone.info, Icons.schedule_send_outlined, a.publishAt == null ? 'Scheduled' : 'Scheduled ${fmtDateTime(a.publishAt!)}'),
      'published' => (StatusTone.success, Icons.check_rounded, 'Published'),
      'expired' => (StatusTone.warning, Icons.timer_off_outlined, 'Expired'),
      'archived' => (StatusTone.neutral, Icons.inventory_2_outlined, 'Archived'),
      _ => (StatusTone.neutral, Icons.circle_outlined, a.state),
    };
    return StatusChip(label, tone: tone, icon: icon);
  }
}

class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key});
  final String priority;

  @override
  Widget build(BuildContext context) => switch (priority) {
    'urgent' => const StatusChip('Urgent', tone: StatusTone.danger, icon: Icons.priority_high_rounded),
    'important' => const StatusChip('Important', tone: StatusTone.warning, icon: Icons.label_important_outline_rounded),
    _ => const SizedBox.shrink(),
  };
}

String priorityLabel(String p) => switch (p) { 'urgent' => 'Urgent', 'important' => 'Important', _ => 'Normal' };
