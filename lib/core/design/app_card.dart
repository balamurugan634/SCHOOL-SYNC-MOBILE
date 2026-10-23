import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

enum CardTone { surface, subtle, outlined }

/// Layered paper: surface + 1 px border + 12 dp radius + a whisper shadow (light mode only).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Gaps.lg),
    this.tone = CardTone.surface,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final CardTone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (bg, border, shadow) = switch (tone) {
      CardTone.surface => (t.surface, t.border, !t.dark),
      CardTone.subtle => (t.subtle, Colors.transparent, false),
      CardTone.outlined => (Colors.transparent, t.border, false),
    };
    final shape = RoundedRectangleBorder(borderRadius: Radii.card, side: BorderSide(color: border));
    final content = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: shadow
          ? DecoratedBox(
              decoration: BoxDecoration(borderRadius: Radii.card, boxShadow: const [BoxShadow(color: Color(0x0A1C1A17), blurRadius: 2, offset: Offset(0, 1))]),
              child: content,
            )
          : content,
    );
  }
}
