import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../workspace/staff_frame.dart' show MeterBar;

/// draft / published / closed, always icon + label.
class HomeworkStateChip extends StatelessWidget {
  const HomeworkStateChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, label) = switch (status) {
      'draft' => (StatusTone.neutral, Icons.edit_outlined, 'Draft'),
      'published' => (StatusTone.brand, Icons.send_outlined, 'Published'),
      'closed' => (StatusTone.neutral, Icons.lock_outline_rounded, 'Closed'),
      _ => (StatusTone.neutral, Icons.circle_outlined, status),
    };
    return StatusChip(label, tone: tone, icon: icon);
  }
}

/// A student's hand-in state in the roster (missing / submitted / late / reviewed / returned).
class RosterStatusChip extends StatelessWidget {
  const RosterStatusChip(this.status, {super.key, this.marks, this.maxMarks});
  final String status;
  final double? marks;
  final int? maxMarks;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, label) = switch (status) {
      'missing' => (StatusTone.warning, Icons.remove_circle_outline_rounded, 'Missing'),
      'submitted' => (StatusTone.info, Icons.rate_review_outlined, 'To review'),
      'late' => (StatusTone.warning, Icons.schedule_rounded, 'Late, to review'),
      'reviewed' => (StatusTone.success, Icons.check_rounded, marks == null ? 'Reviewed' : 'Reviewed, ${_fmt(marks!)}${maxMarks == null ? '' : '/$maxMarks'}'),
      'returned' => (StatusTone.neutral, Icons.undo_rounded, 'Returned'),
      _ => (StatusTone.neutral, Icons.circle_outlined, status),
    };
    return StatusChip(label, tone: tone, icon: icon);
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}

/// A progress bar with its text underneath (never beside it), so a long label can wrap at any text size.
class LabelledMeter extends StatelessWidget {
  const LabelledMeter({super.key, required this.value, required this.label});
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MeterBar(value: value, semanticLabel: label),
      const SizedBox(height: 4),
      Text(label, style: context.text.bodySmall),
    ],
  );
}
