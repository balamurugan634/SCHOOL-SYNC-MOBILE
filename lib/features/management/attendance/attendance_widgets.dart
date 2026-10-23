import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../data/models/attendance.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../workspace/workspace.dart';
import '../charts/chart_text.dart';

/// present / absent / late / leave / half-day as icon + label + number. Wraps, so it survives large text sizes.
class CountsWrap extends StatelessWidget {
  const CountsWrap({super.key, required this.counts, this.showZero = true});
  final StatusCounts counts;
  final bool showZero;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Color colorOf(AttendanceStatus s) => switch (attendanceTone(s)) {
      StatusTone.success => t.success,
      StatusTone.warning => t.warning,
      StatusTone.danger => t.danger,
      _ => t.brand.ink,
    };
    return Semantics(
      label: attendanceCountsSummary(counts),
      excludeSemantics: true,
      child: Wrap(
        spacing: Gaps.lg,
        runSpacing: Gaps.xs,
        children: [
          for (final s in AttendanceStatus.values)
            if (showZero || counts.of(s) > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(attendanceIcon(s), size: 16, color: colorOf(s)),
                  const SizedBox(width: 4),
                  Flexible(child: Text('${s.label} ${counts.of(s)}', style: context.text.bodySmall?.copyWith(color: t.text, fontFeatures: const [FontFeature.tabularFigures()]))),
                ],
              ),
        ],
      ),
    );
  }
}
