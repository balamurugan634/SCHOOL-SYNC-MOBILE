import 'package:flutter/widgets.dart';

/// How much bottom padding a sheet needs so its fields clear the keyboard.
///
/// The textbook answer is `MediaQuery.viewInsets.bottom`. On some phones (edge-to-edge with `adjustResize`) Android has
/// ALREADY shrunk the window by the keyboard AND still reports the keyboard height, so using the raw value counts the
/// keyboard twice and squeezes a form into a sliver. This subtracts the part of the keyboard the window has already given up.
abstract final class KeyboardInset {
  static double _fullHeight = 0;
  static bool _tracking = false;

  /// Remembers the window height while the keyboard is closed. Call once at start-up.
  static void track() {
    if (_tracking) return;
    _tracking = true;
    WidgetsBinding.instance.addObserver(_Observer());
    _measure();
  }

  static void _measure() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final v = views.first;
    if (v.viewInsets.bottom <= 0) _fullHeight = v.physicalSize.height / v.devicePixelRatio;
  }

  /// Bottom padding to apply inside a keyboard-aware sheet (logical px). Rebuilds when the keyboard moves.
  static double of(BuildContext context) {
    MediaQuery.viewInsetsOf(context); // subscribe to keyboard changes
    final v = View.of(context);
    final dpr = v.devicePixelRatio;
    final height = v.physicalSize.height / dpr;
    final inset = v.viewInsets.bottom / dpr;
    if (inset <= 0) {
      _fullHeight = height;
      return 0;
    }
    return compute(inset: inset, height: height, fullHeight: _fullHeight);
  }

  /// [inset] is the reported keyboard height, [height] the current window height, [fullHeight] the window height with
  /// the keyboard closed (0 when unknown). Pure so it can be tested.
  static double compute({required double inset, required double height, required double fullHeight}) {
    if (inset <= 0) return 0;
    final consumed = fullHeight > height ? fullHeight - height : 0.0;
    return (inset - consumed).clamp(0.0, inset);
  }
}

class _Observer with WidgetsBindingObserver {
  @override
  void didChangeMetrics() => KeyboardInset._measure();
}
