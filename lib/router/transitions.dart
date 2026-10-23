import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/design/design.dart';

/// Material "fade through" for every gate / onboarding step (220 ms; design.md section 9).
/// Skipped entirely when the system asks for reduced motion.
CustomTransitionPage<T> fadeThroughPage<T>({required LocalKey key, required Widget child}) => CustomTransitionPage<T>(
  key: key,
  child: child,
  transitionDuration: Motion.page,
  reverseTransitionDuration: const Duration(milliseconds: 180),
  transitionsBuilder: (context, animation, secondary, child) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return FadeThroughTransition(animation: animation, secondaryAnimation: secondary, fillColor: context.tokens.bg, child: child);
  },
);

/// Steps in a flow use the same transition; kept as a separate name for call-site clarity.
CustomTransitionPage<T> sharedAxisPage<T>({required LocalKey key, required Widget child}) => fadeThroughPage<T>(key: key, child: child);
