import 'package:flutter/material.dart';

/// 4 dp grid (design.md section 4). Scale: 4, 8, 12, 16, 20, 24, 32, 40, 56, 80.
abstract final class Gaps {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double huge = 32;
  static const double section = 32;

  /// Horizontal page padding on phones.
  static const double page = 16;
}

/// 8 (buttons, inputs, badges), 12 (cards, tables, menus), 16 (dialogs, sheets), 999 (pills, avatars).
abstract final class Radii {
  static const double sm = 8;
  static const double md = 8;
  static const double lg = 12;
  static const double xl = 16;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get field => BorderRadius.circular(md);
  static BorderRadius get badge => BorderRadius.circular(sm);
  static BorderRadius get dialog => BorderRadius.circular(xl);
  static BorderRadius get sheet => const BorderRadius.vertical(top: Radius.circular(xl));
}

/// Durations and curves (design.md section 9). Distances are at most 8 dp.
abstract final class Motion {
  /// Press feedback.
  static const Duration press = Duration(milliseconds: 80);

  /// Hover, focus, tooltips.
  static const Duration fast = Duration(milliseconds: 150);

  /// Menus, tabs, accordions.
  static const Duration base = Duration(milliseconds: 200);

  /// Dialogs, sheets, page-level.
  static const Duration slow = Duration(milliseconds: 300);

  /// Page transitions (never more than 250 ms).
  static const Duration page = Duration(milliseconds: 220);

  static const Curve standard = Cubic(.2, 0, 0, 1);
  static const Curve enter = Cubic(0, 0, .2, 1);
  static const Curve exit = Cubic(.4, 0, 1, 1);
  static const Curve emphasized = standard;

  /// Stagger step for the first dashboard load (at most 6 items).
  static const Duration stagger = Duration(milliseconds: 40);
}
