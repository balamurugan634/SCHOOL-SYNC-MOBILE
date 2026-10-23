import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// Mark-sheet workflow state, always icon + label.
class SheetStatusChip extends StatelessWidget {
  const SheetStatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (tone, icon, label) = switch (status) {
      'draft' => (StatusTone.neutral, Icons.edit_outlined, 'To enter'),
      'returned' => (StatusTone.warning, Icons.undo_rounded, 'Returned'),
      'submitted' => (StatusTone.info, Icons.hourglass_empty_rounded, 'In review'),
      'approved' => (StatusTone.success, Icons.check_rounded, 'Approved'),
      'published' => (StatusTone.success, Icons.public_rounded, 'Published'),
      _ => (StatusTone.neutral, Icons.circle_outlined, status),
    };
    return StatusChip(label, tone: tone, icon: icon);
  }
}
