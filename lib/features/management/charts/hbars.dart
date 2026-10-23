import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// One row of [HorizontalBars].
class BarItem {
  const BarItem({required this.label, required this.value, required this.text, this.color});
  final String label;
  final double value;

  /// The exact figure, always printed (never only colour or length).
  final String text;
  final Color? color;
}

/// Ranked horizontal bars: label above, a rounded 6 px bar on a sunken track, the value as text at the end.
/// Bars share one hue (the brand colour unless [BarItem.color] is set).
class HorizontalBars extends StatelessWidget {
  const HorizontalBars({super.key, required this.items, this.max});
  final List<BarItem> items;

  /// Scale maximum; defaults to the largest value.
  final double? max;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final top = max ?? items.fold<double>(0, (a, e) => e.value > a ? e.value : a);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Column(
      children: [
        for (final i in items)
          Semantics(
            label: '${i.label}: ${i.text}',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(i.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium)),
                      const SizedBox(width: Gaps.sm),
                      Text(i.text, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: top <= 0 ? 0 : (i.value / top).clamp(0, 1).toDouble()),
                      duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
                      curve: Motion.enter,
                      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: t.sunken, color: i.color ?? t.brand.solid),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
