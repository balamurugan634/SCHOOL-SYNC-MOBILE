import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

enum StatusTone { success, warning, danger, info, neutral, brand, accent }

/// Badge: 20 dp high, 12 sp text, tint background + matching text.
class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.tone = StatusTone.neutral, this.icon, this.dense = true});

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = switch (tone) {
      StatusTone.success => t.successPalette,
      StatusTone.warning => t.warningPalette,
      StatusTone.danger => t.dangerPalette,
      StatusTone.info || StatusTone.brand => t.brandPalette,
      StatusTone.accent => t.accentPalette,
      StatusTone.neutral => t.neutralPalette,
    };
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(color: p.bg, borderRadius: Radii.badge),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: p.fg), const SizedBox(width: 4)],
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelSmall?.copyWith(color: p.fg, height: 1))),
        ],
      ),
    );
  }
}

/// Role chip: a small dot in the role's tint plus the role name (design.md section 2.3).
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.label, required this.tint});
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: t.subtle, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.border)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: tint, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: context.text.labelSmall?.copyWith(color: t.textSecondary, height: 1)),
        ],
      ),
    );
  }
}
