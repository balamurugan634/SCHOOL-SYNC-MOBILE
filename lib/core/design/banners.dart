import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

enum BannerTone { info, warning, danger, success }

/// An inline message (errors, subscription notices, warnings): tint background, matching text.
class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.message, this.title, this.tone = BannerTone.info, this.icon, this.onDismiss, this.action, this.onAction});

  final String message;
  final String? title;
  final BannerTone tone;
  final IconData? icon;
  final VoidCallback? onDismiss;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final (p, ic) = switch (tone) {
      BannerTone.info => (t.brandPalette, Icons.info_outline_rounded),
      BannerTone.warning => (t.warningPalette, Icons.warning_amber_rounded),
      BannerTone.danger => (t.dangerPalette, Icons.error_outline_rounded),
      BannerTone.success => (t.successPalette, Icons.check_circle_outline_rounded),
    };
    final fg = tone == BannerTone.info ? t.text : p.fg;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(Radii.lg)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon ?? ic, color: p.fg, size: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 1, right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) Text(title!, style: context.text.titleSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
                    Text(message, style: context.text.bodySmall?.copyWith(color: fg, fontSize: 14, height: 20 / 14)),
                    if (action != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: GestureDetector(onTap: onAction, child: Text(action!, style: context.text.labelMedium?.copyWith(color: p.fg, decoration: TextDecoration.underline))),
                      ),
                  ],
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(onPressed: onDismiss, visualDensity: VisualDensity.compact, icon: Icon(Icons.close_rounded, color: p.fg, size: 18), tooltip: 'Dismiss'),
          ],
        ),
      ),
    );
  }
}
