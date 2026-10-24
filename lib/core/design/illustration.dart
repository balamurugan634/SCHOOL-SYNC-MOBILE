import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'oklch.dart';
import 'theme.dart';

/// The shared "Soft Geometry" illustrations (design.md section 7). The SVG files use six literal
/// hex colours; they are replaced with the active theme so every school gets its own colours.
///
///   #0E5A63 brand        #CFE6E8 brand-soft     #D1411B accent
///   #FCE7DD accent-soft  #F4F1EC paper          #1C1A17 ink
enum Illo {
  onboardingStudent('onboarding-student', 'Open books and a notebook'),
  onboardingParent('onboarding-parent', 'A family home with a calendar'),
  onboardingTeacher('onboarding-teacher', 'A register and a board'),
  onboardingManagement('onboarding-management', 'A school building and a chart'),
  signIn('sign-in', 'A door with a key'),
  emptyGeneric('empty-generic', 'An empty box'),
  emptyHomework('empty-homework', 'An empty notebook'),
  emptyEvents('empty-events', 'An empty calendar'),
  emptyNotifications('empty-notifications', 'A quiet bell'),
  noResults('no-results', 'A magnifier with nothing found'),
  errorOffline('error-offline', 'A disconnected cable'),
  firstUse('first-use', 'A sprout'),
  setupComplete('setup-complete', 'A completed checklist'),
  success('success', 'A check badge');

  const Illo(this.file, this.description);
  final String file;
  final String description;
  String get asset => 'assets/illustrations/$file.svg';
}

/// Placeholder colours exactly as authored in the SVG files.
abstract final class IlloPlaceholders {
  static const brand = '#0E5A63';
  static const brandSoft = '#CFE6E8';
  static const accent = '#D1411B';
  static const accentSoft = '#FCE7DD';
  static const paper = '#F4F1EC';
  static const ink = '#1C1A17';
}

String _hex(Color c) {
  String h(double v) => (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0').toUpperCase();
  return '#${h(c.r)}${h(c.g)}${h(c.b)}';
}

/// Substitutes the six placeholder colours in [svg] (case-insensitive, literal match).
String themeSvg(
  String svg, {
  required Color brand,
  required Color brandSoft,
  required Color accent,
  required Color accentSoft,
  required Color paper,
  required Color ink,
}) {
  // Single pass so a substituted colour is never re-substituted.
  final map = <String, String>{
    IlloPlaceholders.brand: _hex(brand),
    IlloPlaceholders.brandSoft: _hex(brandSoft),
    IlloPlaceholders.accent: _hex(accent),
    IlloPlaceholders.accentSoft: _hex(accentSoft),
    IlloPlaceholders.paper: _hex(paper),
    IlloPlaceholders.ink: _hex(ink),
  };
  final re = RegExp(map.keys.map(RegExp.escape).join('|'), caseSensitive: false);
  return svg.replaceAllMapped(re, (m) => map[m.group(0)!.toUpperCase()]!);
}

final Map<String, Future<String>> _raw = {};

/// `oklch(0.92, min(C * 0.45, 0.05), hue)` of the normalised brand (dark: 0.30), per design/README.md.
Color _brandSoft(SchoolSyncTheme t) {
  final o = Oklch.fromColor(t.brand.solid);
  return Oklch(t.dark ? .30 : .92, o.c * .45 < .05 ? o.c * .45 : .05, o.h).toColor();
}

final Map<String, String> _themed = {};

/// An illustration re-themed with the school colours. [accent] overrides the amber accent
/// (used for the role tint on onboarding heroes). [decorative] hides it from screen readers.
class IllustrationView extends StatelessWidget {
  const IllustrationView(this.illo, {super.key, this.width, this.height, this.accent, this.decorative = false});

  final Illo illo;
  final double? width;
  final double? height;
  final Color? accent;
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<String>(
      future: _raw.putIfAbsent(illo.asset, () => rootBundle.loadString(illo.asset)),
      builder: (context, snap) {
        final box = SizedBox(width: width, height: height ?? (width == null ? null : width! * .75));
        if (!snap.hasData) return box;
        final acc = accent ?? t.accent;
        final key = '${illo.file}|${t.brand.solid.toARGB32()}|${acc.toARGB32()}|${t.dark}';
        final svg = _themed.putIfAbsent(key, () => themeSvg(
          snap.data!,
          brand: t.brand.solid,
          brandSoft: _brandSoft(t),
          accent: acc,
          accentSoft: accent == null ? t.accentSoft : Color.alphaBlend(acc.withValues(alpha: t.dark ? .22 : .14), t.surface),
          paper: t.subtle,
          ink: t.text,
        ));
        return Semantics(
          label: decorative ? null : illo.description,
          image: true,
          excludeSemantics: true,
          child: SvgPicture(SvgStringLoader(svg), width: width, height: height, fit: BoxFit.contain),
        );
      },
    );
  }
}
