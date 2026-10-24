import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'oklch.dart';
import 'tokens.dart';

/// Inter: interface. Manrope: display, titles and big figures. Weights 400 / 500 / 600 only.
const String kFontSans = 'Inter';
const String kFontDisplay = 'Manrope';

/// Manrope is a variable font: the family alone would render its default (light) weight, so every display style pins the axis.
const List<FontVariation> kDisplayWeight = [FontVariation('wght', 600)];
const String kFontFamily = kFontSans;

/// Product default brand (deep teal) for a school without a colour.
const Color kDefaultBrand = Color(0xFF0E5A63);

/// Parses `#RGB`, `#RRGGBB` or `#AARRGGBB`; falls back to [fallback].
Color parseHexColor(String? hex, {Color fallback = kDefaultBrand}) {
  if (hex == null) return fallback;
  var h = hex.trim().replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return fallback;
  final v = int.tryParse(h, radix: 16);
  return v == null ? fallback : Color(v);
}

double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

const Color _lightSurface = Color(0xFFFFFFFF);
const Color _darkSurface = Color(0xFF1B1A18);
const Color _darkInk = Color(0xFF131211);

/// The school's colour, normalised so any choice looks dignified (design.md section 2.2):
/// OKLCH chroma <= 0.14, lightness 0.36-0.50 (dark mode 0.62-0.72), white (dark mode: near-black)
/// text on it >= 4.5:1.
class BrandColors {
  const BrandColors({required this.solid, required this.onSolid, required this.hover, required this.press, required this.soft, required this.ink, required this.ring});

  final Color solid;
  final Color onSolid;
  final Color hover;
  final Color press;

  /// 8 % over the surface (14 % in dark): selected rows, active nav.
  final Color soft;

  /// Text on [soft], >= 4.5:1.
  final Color ink;

  /// Focus ring, 35 % alpha.
  final Color ring;

  /// Alias used by older call sites.
  Color get tint => soft;
  Color get focusRing => ring;

  factory BrandColors.from(Color school, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final o = Oklch.fromColor(school.withValues(alpha: 1));
    final surface = dark ? _darkSurface : _lightSurface;
    final onSolid = dark ? _darkInk : Colors.white;
    final c = math.min(o.c, 0.14);
    var l = o.l.clamp(dark ? .62 : .36, dark ? .72 : .50).toDouble();
    Color at(double lightness, [double? chroma]) => Oklch(lightness.clamp(0.0, 1.0), chroma ?? c, o.h).toColor();

    var solid = at(l);
    var guard = 0;
    while (contrastRatio(onSolid, solid) < 4.5 && guard++ < 40) {
      l += dark ? .01 : -.01;
      solid = at(l);
    }
    final soft = Color.alphaBlend(solid.withValues(alpha: dark ? .14 : .08), surface);
    var ink = solid;
    var il = l;
    guard = 0;
    while (contrastRatio(ink, soft) < 4.5 && guard++ < 40) {
      il += dark ? .01 : -.01;
      ink = at(il);
    }
    return BrandColors(
      solid: solid,
      onSolid: onSolid,
      hover: at(dark ? math.min(l * 1.06, .95) : l * .94),
      press: at(dark ? math.min(l * 1.10, .97) : l * .90),
      soft: soft,
      ink: ink,
      ring: solid.withValues(alpha: .35),
    );
  }
}

/// Everything Material's `ColorScheme` lacks: paper neutrals, ink levels, accent, role tints,
/// status colours and the validated chart palette (design.md sections 2.1 - 2.5).
@immutable
class SchoolSyncTheme extends ThemeExtension<SchoolSyncTheme> {
  const SchoolSyncTheme({
    required this.dark,
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.subtle,
    required this.sunken,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.inkDisabled,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.roleStudent,
    required this.roleParent,
    required this.roleTeacher,
    required this.chart,
    required this.sequential,
    required this.divergingNegative,
    required this.divergingNeutral,
    required this.divergingPositive,
    required this.brand,
  });

  final bool dark;
  final Color bg, surface, surfaceRaised, subtle, sunken, border, borderStrong;

  /// `--ink`, `--ink-2`, `--ink-3`, `--ink-disabled`.
  final Color text, textSecondary, textTertiary, inkDisabled;
  final Color success, successTint, warning, warningTint, danger, dangerTint;
  final Color accent, accentInk, accentSoft;
  final Color roleStudent, roleParent, roleTeacher;

  /// `--chart-1..6`: categorical, fixed order, never cycled.
  final List<Color> chart;

  /// `--seq-1..7`: one teal hue, light to dark (reversed in dark mode).
  final List<Color> sequential;
  final Color divergingNegative, divergingNeutral, divergingPositive;
  final BrandColors brand;

  /// The product teal for the SchoolSync mark itself (never re-themed per school).
  Color get brandDefault => dark ? const Color(0xFF5AA5AE) : kDefaultBrand;

  Color get info => brand.ink;
  Color get infoTint => brand.soft;

  static SchoolSyncTheme of(Brightness b, BrandColors brand) {
    final dark = b == Brightness.dark;
    return dark
        ? SchoolSyncTheme(
            dark: true,
            bg: const Color(0xFF131211),
            surface: const Color(0xFF1B1A18),
            surfaceRaised: const Color(0xFF222120),
            subtle: const Color(0xFF1F1E1C),
            sunken: const Color(0xFF161513),
            border: const Color(0xFF2E2C29),
            borderStrong: const Color(0xFF403D39),
            text: const Color(0xFFEDEAE4),
            textSecondary: const Color(0xFFB8B2A7),
            textTertiary: const Color(0xFF8F897E),
            inkDisabled: const Color(0xFF5F5A52),
            success: const Color(0xFF5CC48E),
            successTint: const Color(0xFF12261C),
            warning: const Color(0xFFE5B34D),
            warningTint: const Color(0xFF2B2110),
            danger: const Color(0xFFF2879A),
            dangerTint: const Color(0xFF2D1319),
            accent: const Color(0xFFFF7F5A),
            accentInk: const Color(0xFFFF7F5A),
            accentSoft: const Color(0xFF2E1812),
            roleStudent: const Color(0xFFFF7F5A),
            roleParent: const Color(0xFFD27A98),
            roleTeacher: const Color(0xFF7C9BE0),
            chart: const [Color(0xFF00909B), Color(0xFFD0583F), Color(0xFF5C80D6), Color(0xFFC77B2C), Color(0xFF8B7BDB), Color(0xFF5F9E52)],
            sequential: _seq.reversed.toList(),
            divergingNegative: const Color(0xFFD0583F),
            divergingNeutral: const Color(0xFF2E2C29),
            divergingPositive: const Color(0xFF00909B),
            brand: brand,
          )
        : SchoolSyncTheme(
            dark: false,
            bg: const Color(0xFFFAF8F5),
            surface: const Color(0xFFFFFFFF),
            surfaceRaised: const Color(0xFFFFFFFF),
            subtle: const Color(0xFFF4F1EC),
            sunken: const Color(0xFFEEEAE3),
            border: const Color(0xFFE7E2D9),
            borderStrong: const Color(0xFFD3CCC0),
            text: const Color(0xFF1C1A17),
            textSecondary: const Color(0xFF4F4A42),
            textTertiary: const Color(0xFF6F695F),
            inkDisabled: const Color(0xFFA39C90),
            success: const Color(0xFF2A7448),
            successTint: const Color(0xFFE6F3EA),
            warning: const Color(0xFF9A6200),
            warningTint: const Color(0xFFFBF0D9),
            danger: const Color(0xFFB3203E),
            dangerTint: const Color(0xFFFBE8EC),
            accent: const Color(0xFFD1411B),
            accentInk: const Color(0xFFA93310),
            accentSoft: const Color(0xFFFCE7DD),
            roleStudent: const Color(0xFFD1411B),
            roleParent: const Color(0xFFB04A6F),
            roleTeacher: const Color(0xFF3F63B5),
            chart: const [Color(0xFF00909B), Color(0xFFB8472F), Color(0xFF3F63B5), Color(0xFFC9731A), Color(0xFF6C5BB0), Color(0xFF4F8A45)],
            sequential: _seq,
            divergingNegative: const Color(0xFFB8472F),
            divergingNeutral: const Color(0xFFE7E2D9),
            divergingPositive: const Color(0xFF00909B),
            brand: brand,
          );
  }

  static const List<Color> _seq = [Color(0xFFE4F1F2), Color(0xFFBFDDE0), Color(0xFF8FC3C9), Color(0xFF5AA5AE), Color(0xFF2C8791), Color(0xFF11666F), Color(0xFF0A4A52)];

  @override
  SchoolSyncTheme copyWith() => this;

  @override
  SchoolSyncTheme lerp(ThemeExtension<SchoolSyncTheme>? other, double t) => other is SchoolSyncTheme && t > .5 ? other : this;
}

/// Older name kept for call sites.
typedef AppTokens = SchoolSyncTheme;

extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  SchoolSyncTheme get tokens => Theme.of(this).extension<SchoolSyncTheme>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

/// Foreground / soft background pair used by badges and banners.
class StatusPalette {
  const StatusPalette(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

extension StatusX on SchoolSyncTheme {
  StatusPalette get successPalette => StatusPalette(success, successTint);
  StatusPalette get warningPalette => StatusPalette(warning, warningTint);
  StatusPalette get dangerPalette => StatusPalette(danger, dangerTint);
  StatusPalette get brandPalette => StatusPalette(brand.ink, brand.soft);
  StatusPalette get accentPalette => StatusPalette(accentInk, accentSoft);
  StatusPalette get neutralPalette => StatusPalette(textSecondary, subtle);
}

/// Big figures: Manrope, lining + tabular numerals.
TextStyle figureStyle(BuildContext context, {double size = 32, Color? color}) => TextStyle(
  fontFamily: kFontDisplay,
  fontVariations: kDisplayWeight,
  fontSize: size,
  height: (size + 6) / size,
  fontWeight: FontWeight.w600,
  color: color ?? context.tokens.text,
  letterSpacing: size >= 24 ? -0.02 * size : 0,
  fontFeatures: const [FontFeature.tabularFigures()],
);

TextTheme _textTheme(SchoolSyncTheme t) {
  TextStyle sans(double size, double height, FontWeight w, {Color? color}) => TextStyle(fontFamily: kFontSans, fontSize: size, height: height / size, fontWeight: w, color: color ?? t.text, letterSpacing: 0);
  TextStyle serif(double size, double height) => TextStyle(
    fontFamily: kFontDisplay,
    fontVariations: kDisplayWeight,
    fontSize: size,
    height: height / size,
    fontWeight: FontWeight.w600,
    color: t.text,
    letterSpacing: size >= 24 ? -0.02 * size : 0,
  );
  return TextTheme(
    displayLarge: serif(40, 44),
    displayMedium: serif(36, 42),
    displaySmall: serif(32, 38),
    headlineLarge: serif(28, 34),
    headlineMedium: serif(24, 30),
    headlineSmall: serif(20, 26),
    titleLarge: serif(20, 26),
    titleMedium: sans(16, 24, FontWeight.w600),
    titleSmall: sans(15, 22, FontWeight.w500),
    bodyLarge: sans(16, 24, FontWeight.w400),
    bodyMedium: sans(15, 22, FontWeight.w400),
    bodySmall: sans(13, 18, FontWeight.w400, color: t.textSecondary),
    labelLarge: sans(15, 20, FontWeight.w500),
    labelMedium: sans(13, 16, FontWeight.w500),
    labelSmall: sans(12, 16, FontWeight.w500),
  );
}

/// Page transition: 220 ms Material "fade through" (design.md section 9).
class FadeThroughBuilder extends PageTransitionsBuilder {
  const FadeThroughBuilder();

  @override
  Duration get transitionDuration => Motion.page;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return FadeThroughTransition(animation: animation, secondaryAnimation: secondaryAnimation, fillColor: context.tokens.bg, child: child);
  }
}

ColorScheme buildColorScheme(Color school, Brightness brightness) {
  final b = BrandColors.from(school, brightness);
  final t = SchoolSyncTheme.of(brightness, b);
  return ColorScheme(
    brightness: brightness,
    primary: b.solid,
    onPrimary: b.onSolid,
    primaryContainer: b.soft,
    onPrimaryContainer: b.ink,
    secondary: b.solid,
    onSecondary: b.onSolid,
    secondaryContainer: b.soft,
    onSecondaryContainer: b.ink,
    tertiary: t.accent,
    onTertiary: Colors.white,
    tertiaryContainer: t.accentSoft,
    onTertiaryContainer: t.accentInk,
    error: t.danger,
    onError: brightness == Brightness.dark ? _darkInk : Colors.white,
    errorContainer: t.dangerTint,
    onErrorContainer: t.danger,
    surface: t.surface,
    onSurface: t.text,
    onSurfaceVariant: t.textSecondary,
    surfaceDim: t.sunken,
    surfaceBright: t.surface,
    surfaceContainerLowest: t.surface,
    surfaceContainerLow: t.surface,
    surfaceContainer: t.surface,
    surfaceContainerHigh: t.subtle,
    surfaceContainerHighest: t.subtle,
    outline: t.borderStrong,
    outlineVariant: t.border,
    shadow: const Color(0xFF1C1A17),
    scrim: const Color(0xFF1C1A17),
    inverseSurface: t.text,
    onInverseSurface: t.surface,
    inversePrimary: b.solid,
    surfaceTint: Colors.transparent,
  );
}

ThemeData buildTheme(Color school, Brightness brightness) {
  final b = BrandColors.from(school, brightness);
  final t = SchoolSyncTheme.of(brightness, b);
  final scheme = buildColorScheme(school, brightness);
  final text = _textTheme(t);
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: Radii.field, borderSide: BorderSide(color: c, width: w));
  const scrim = Color(0x661C1A17); // rgba(28,26,23,.40)

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: kFontSans,
    textTheme: text,
    primaryTextTheme: text,
    scaffoldBackgroundColor: t.bg,
    canvasColor: t.bg,
    splashFactory: InkRipple.splashFactory,
    splashColor: b.solid.withValues(alpha: .08),
    highlightColor: b.solid.withValues(alpha: .05),
    extensions: [t],
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeThroughBuilder(), TargetPlatform.iOS: FadeThroughBuilder()},
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t.bg,
      foregroundColor: t.text,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 56,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: t.textSecondary, size: 22),
      shape: Border(bottom: BorderSide(color: t.border)),
    ),
    cardTheme: CardThemeData(
      color: t.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: Radii.card, side: BorderSide(color: t.border)),
    ),
    dividerTheme: DividerThemeData(color: t.border, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(t.borderStrong),
      enabledBorder: border(t.borderStrong),
      disabledBorder: border(t.border),
      focusedBorder: border(b.solid, 2),
      errorBorder: border(t.danger),
      focusedErrorBorder: border(t.danger, 2),
      labelStyle: text.bodyMedium?.copyWith(color: t.textSecondary),
      floatingLabelStyle: text.labelMedium?.copyWith(color: b.ink),
      hintStyle: text.bodyMedium?.copyWith(color: t.textTertiary),
      helperStyle: text.labelSmall?.copyWith(color: t.textSecondary),
      errorStyle: text.labelSmall?.copyWith(color: t.danger),
      prefixIconColor: t.textTertiary,
      suffixIconColor: t.textTertiary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: Radii.field)),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
        elevation: const WidgetStatePropertyAll(0),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        backgroundColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return t.subtle;
          if (s.contains(WidgetState.pressed)) return b.press;
          if (s.contains(WidgetState.hovered)) return b.hover;
          return b.solid;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? t.inkDisabled : b.onSolid),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: Radii.field),
        side: BorderSide(color: t.borderStrong),
        foregroundColor: t.text,
        backgroundColor: t.surface,
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 44),
        shape: RoundedRectangleBorder(borderRadius: Radii.field),
        foregroundColor: b.ink,
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: t.textSecondary)),
    navigationBarTheme: NavigationBarThemeData(
      height: 64,
      elevation: 0,
      backgroundColor: t.surface,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: b.soft,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.lg)),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => text.labelSmall?.copyWith(color: s.contains(WidgetState.selected) ? b.ink : t.textSecondary, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500),
      ),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(size: 22, color: s.contains(WidgetState.selected) ? b.ink : t.textSecondary)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      backgroundColor: t.text,
      contentTextStyle: text.bodyMedium?.copyWith(color: t.surface),
      actionTextColor: brightness == Brightness.dark ? b.solid : Colors.white,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: t.surfaceRaised,
      modalBarrierColor: scrim,
      shape: RoundedRectangleBorder(borderRadius: Radii.sheet),
      showDragHandle: true,
      dragHandleColor: t.borderStrong,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shadowColor: const Color(0x241C1A17),
      barrierColor: scrim,
      shape: RoundedRectangleBorder(borderRadius: Radii.dialog),
      titleTextStyle: text.headlineSmall,
      contentTextStyle: text.bodyMedium?.copyWith(color: t.textSecondary),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md)),
      titleTextStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      subtitleTextStyle: text.bodySmall,
      iconColor: t.textSecondary,
      minTileHeight: 56,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? b.onSolid : t.surface),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? b.solid : t.borderStrong),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: Radii.field)),
        side: WidgetStateProperty.all(BorderSide(color: t.borderStrong)),
        backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? b.soft : t.surface),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? b.ink : t.textSecondary),
        textStyle: WidgetStateProperty.all(text.labelMedium),
      ),
    ),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: Radii.badge), side: BorderSide(color: t.border), labelStyle: text.labelSmall),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: b.solid, circularTrackColor: Colors.transparent, linearTrackColor: t.sunken),
  );
}
