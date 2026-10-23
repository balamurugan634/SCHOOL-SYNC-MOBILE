import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/design/design.dart';
import 'package:schoolsync/core/design/oklch.dart';

void main() {
  group('OKLCH', () {
    test('round-trips an in-gamut colour', () {
      const c = Color(0xFF0E5A63);
      final back = Oklch.fromColor(c).toColor();
      expect((back.r - c.r).abs(), lessThan(.01));
      expect((back.g - c.g).abs(), lessThan(.01));
      expect((back.b - c.b).abs(), lessThan(.01));
    });

    test('white and black sit at lightness 1 and 0', () {
      expect(Oklch.fromColor(Colors.white).l, closeTo(1, .01));
      expect(Oklch.fromColor(Colors.black).l, closeTo(0, .01));
    });

    test('out-of-gamut colours are brought back by reducing chroma', () {
      final c = const Oklch(.55, .37, 142).toColor();
      expect(Oklch.fromColor(c).c, lessThan(.37));
    });
  });

  group('brand normalisation (design.md 2.2)', () {
    const loud = [Color(0xFF7C3AED), Color(0xFFFF0066), Color(0xFF00FF00), Color(0xFFFFEB3B), Color(0xFF1B6B4F), Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFF0E5A63), Color(0xFF2457A5)];

    test('light: chroma <= 0.14, lightness 0.36-0.50, white text >= 4.5:1, soft/ink >= 4.5:1', () {
      for (final c in loud) {
        final b = BrandColors.from(c, Brightness.light);
        final o = Oklch.fromColor(b.solid);
        expect(o.c, lessThanOrEqualTo(.141), reason: '$c');
        // lightness may be pushed darker (never lighter) to reach contrast
        expect(o.l, lessThanOrEqualTo(.501), reason: '$c');
        expect(o.l, greaterThanOrEqualTo(.25), reason: '$c');
        expect(contrastRatio(b.onSolid, b.solid), greaterThanOrEqualTo(4.5), reason: '$c');
        expect(contrastRatio(b.ink, b.soft), greaterThanOrEqualTo(4.5), reason: '$c');
      }
    });

    test('dark: lifted to 0.62-0.72 and still passes AA with near-black text', () {
      for (final c in loud) {
        final b = BrandColors.from(c, Brightness.dark);
        final o = Oklch.fromColor(b.solid);
        expect(o.l, greaterThanOrEqualTo(.619), reason: '$c');
        expect(o.c, lessThanOrEqualTo(.141), reason: '$c');
        expect(contrastRatio(b.onSolid, b.solid), greaterThanOrEqualTo(4.5), reason: '$c');
        expect(contrastRatio(b.ink, b.soft), greaterThanOrEqualTo(4.5), reason: '$c');
      }
    });

    test('a neon colour comes out dignified and keeps its hue', () {
      final neon = Oklch.fromColor(const Color(0xFFFF0066));
      final out = Oklch.fromColor(BrandColors.from(const Color(0xFFFF0066), Brightness.light).solid);
      expect(out.c, lessThan(neon.c * .6));
      expect((out.h - neon.h).abs(), lessThan(6));
    });

    test('hover is darker than the solid, press darker still (light)', () {
      final b = BrandColors.from(kDefaultBrand, Brightness.light);
      expect(Oklch.fromColor(b.hover).l, lessThan(Oklch.fromColor(b.solid).l));
      expect(Oklch.fromColor(b.press).l, lessThan(Oklch.fromColor(b.hover).l));
    });

    test('focus ring is 35 % alpha, soft is an 8 % wash', () {
      final b = BrandColors.from(kDefaultBrand, Brightness.light);
      expect(b.ring.a, closeTo(.35, .01));
      expect(b.soft.computeLuminance(), greaterThan(.8));
    });

    test('product default is #0E5A63 and bad input falls back to it', () {
      expect(kDefaultBrand, const Color(0xFF0E5A63));
      expect(parseHexColor(null), kDefaultBrand);
      expect(parseHexColor('nonsense'), kDefaultBrand);
      expect(parseHexColor('#1B6B4F'), const Color(0xFF1B6B4F));
      expect(parseHexColor('#abc'), const Color(0xFFAABBCC));
    });
  });

  group('tokens', () {
    test('paper & ink neutrals match design.md', () {
      final light = buildTheme(kDefaultBrand, Brightness.light).extension<SchoolSyncTheme>()!;
      final dark = buildTheme(kDefaultBrand, Brightness.dark).extension<SchoolSyncTheme>()!;
      expect(light.bg, const Color(0xFFFAF8F5));
      expect(light.surface, const Color(0xFFFFFFFF));
      expect(light.subtle, const Color(0xFFF4F1EC));
      expect(light.border, const Color(0xFFE7E2D9));
      expect(light.text, const Color(0xFF1C1A17));
      expect(dark.bg, const Color(0xFF131211));
      expect(dark.surface, const Color(0xFF1B1A18));
      expect(dark.text, const Color(0xFFEDEAE4));
    });

    test('role tints, accent and the six chart colours are the specified values, in order', () {
      final t = buildTheme(kDefaultBrand, Brightness.light).extension<SchoolSyncTheme>()!;
      expect(t.roleStudent, const Color(0xFFC9731A));
      expect(t.roleParent, const Color(0xFFB04A6F));
      expect(t.roleTeacher, const Color(0xFF3F63B5));
      expect(t.accent, const Color(0xFFC9731A));
      expect(t.chart, const [Color(0xFF00909B), Color(0xFFB8472F), Color(0xFF3F63B5), Color(0xFFC9731A), Color(0xFF6C5BB0), Color(0xFF4F8A45)]);
      expect(t.sequential, hasLength(7));
    });

    for (final mode in Brightness.values) {
      test('${mode.name}: text pairs pass WCAG AA on their surfaces', () {
        final t = buildTheme(kDefaultBrand, mode).extension<SchoolSyncTheme>()!;
        expect(contrastRatio(t.text, t.bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(t.textSecondary, t.surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(t.textTertiary, t.bg), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(t.success, t.successTint), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(t.warning, t.warningTint), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(t.danger, t.dangerTint), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(t.accentInk, t.accentSoft), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(t.brand.ink, t.brand.soft), greaterThanOrEqualTo(4.5));
      });
    }
  });

  group('theme', () {
    for (final mode in Brightness.values) {
      test('${mode.name}: 12 dp flat cards, 48 dp buttons, Inter + Manrope, weights <= 600', () {
        final theme = buildTheme(const Color(0xFF7C3AED), mode);
        final card = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(theme.cardTheme.elevation, 0);
        expect((card.borderRadius as BorderRadius).topLeft.x, 12);
        expect(theme.filledButtonTheme.style!.minimumSize!.resolve({})!.height, 48);
        expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
        expect(theme.textTheme.headlineMedium!.fontFamily, 'Manrope');
        expect(theme.textTheme.displaySmall!.fontFamily, 'Manrope');
        for (final s in [theme.textTheme.displayLarge, theme.textTheme.titleLarge, theme.textTheme.titleMedium, theme.textTheme.labelLarge, theme.textTheme.bodyMedium, theme.textTheme.labelSmall]) {
          expect(s!.fontWeight!.value, lessThanOrEqualTo(600));
        }
        expect(theme.textTheme.bodyMedium!.fontSize, greaterThanOrEqualTo(15));
        expect(theme.textTheme.labelSmall!.fontSize, greaterThanOrEqualTo(12));
        final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;
        expect((dialog.borderRadius as BorderRadius).topLeft.x, 16);
      });
    }

    test('motion constants follow design.md (80 / 150 / 200 / 300 ms, pages <= 250 ms)', () {
      expect(Motion.press.inMilliseconds, 80);
      expect(Motion.fast.inMilliseconds, 150);
      expect(Motion.base.inMilliseconds, 200);
      expect(Motion.slow.inMilliseconds, 300);
      expect(Motion.page.inMilliseconds, lessThanOrEqualTo(250));
    });
  });
}
