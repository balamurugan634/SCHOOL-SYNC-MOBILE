import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';

/// A money amount in the serif figure style. Long amounts shrink to fit instead of wrapping or being cut.
class MoneyFigure extends StatelessWidget {
  const MoneyFigure(this.minor, {super.key, required this.currency, this.size = 24, this.color});
  final int minor;
  final String currency;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = formatMinor(minor, currency: currency);
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(text, maxLines: 1, style: figureStyle(context, size: size, color: color))),
    );
  }
}

/// Label above a [MoneyFigure], for a two-column grid of facts.
class MoneyFact extends StatelessWidget {
  const MoneyFact({super.key, required this.label, required this.minor, required this.currency, this.color, this.caption, this.size = 24});
  final String label;
  final int minor;
  final String currency;
  final Color? color;
  final String? caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.text.labelSmall?.copyWith(color: t.textSecondary)),
        const SizedBox(height: 2),
        MoneyFigure(minor, currency: currency, size: size, color: color),
        if (caption != null) Text(caption!, style: context.text.labelSmall?.copyWith(color: t.textTertiary)),
      ],
    );
  }
}
