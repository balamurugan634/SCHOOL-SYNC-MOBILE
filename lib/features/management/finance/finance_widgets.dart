import 'package:flutter/material.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/finance.dart';
import '../charts/hbars.dart';
import 'finance_providers.dart';

/// Ageing buckets as horizontal bars. The amount is always printed beside its bar.
class AgingBars extends StatelessWidget {
  const AgingBars({super.key, required this.buckets, required this.currency});
  final AgingBuckets buckets;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final lines = agingLines(buckets);
    final total = lines.fold<int>(0, (a, l) => a + l.$2);
    if (total == 0) return Text('Nothing is outstanding.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary));
    return HorizontalBars(items: [for (final (label, minor) in lines) BarItem(label: label, value: minor.toDouble(), text: formatMinor(minor, currency: currency))]);
  }
}
