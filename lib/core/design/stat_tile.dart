import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'app_card.dart';
import 'theme.dart';

/// Label (12, secondary) / value (24, 600, tabular) / optional caption. No icon tile.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, this.value, this.caption, this.onTap});

  final String label;
  final String? value;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      onTap: onTap,
      child: Skeletonizer(
        enabled: value == null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: context.text.labelSmall?.copyWith(color: t.textSecondary, fontWeight: FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(value ?? '0000', style: figureStyle(context, size: 32)),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(caption!, style: context.text.labelSmall?.copyWith(color: t.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
