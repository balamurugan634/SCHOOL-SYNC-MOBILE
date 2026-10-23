import 'package:flutter/material.dart';

import '../../core/design/design.dart';

/// Shared layout for the permission primers: explain the value first, ask second.
class PrimerScaffold extends StatelessWidget {
  const PrimerScaffold({
    super.key,
    required this.step,
    required this.total,
    required this.icon,
    required this.title,
    required this.body,
    required this.bullets,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.loading = false,
    this.footnote,
  });

  final int step;
  final int total;
  final IconData icon;
  final String title;
  final String body;
  final List<(IconData, String)> bullets;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback? onSecondary;
  final bool loading;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.xxl, Gaps.lg, Gaps.xxl, 0),
              child: Row(
                children: [
                  Text('Step $step of $total', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
                  const Spacer(),
                  for (var i = 1; i <= total; i++)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: i == step ? t.brand.solid : t.borderStrong),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(Gaps.xxl, Gaps.huge, Gaps.xxl, Gaps.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 40, color: t.brand.solid),
                    const SizedBox(height: Gaps.xl),
                    Text(title, style: context.text.headlineLarge),
                    const SizedBox(height: Gaps.md),
                    Text(body, style: context.text.bodyLarge?.copyWith(color: t.textSecondary)),
                    const SizedBox(height: Gaps.xl),
                    for (final b in bullets)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Gaps.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(b.$1, size: 20, color: t.textSecondary),
                            const SizedBox(width: Gaps.md),
                            Expanded(child: Text(b.$2, style: context.text.bodyMedium)),
                          ],
                        ),
                      ),
                    if (footnote != null) ...[
                      const SizedBox(height: Gaps.sm),
                      Text(footnote!, style: context.text.bodySmall),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Gaps.xxl, Gaps.sm, Gaps.xxl, Gaps.lg),
              child: Column(
                children: [
                  PrimaryButton(label: primaryLabel, loading: loading, onPressed: onPrimary),
                  const SizedBox(height: Gaps.xs),
                  GhostButton(label: secondaryLabel, onPressed: loading ? null : onSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
