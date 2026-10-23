import 'package:flutter/widgets.dart';

import 'tokens.dart';

/// A 200 ms fade (+ 4 dp rise). [index] staggers by 40 ms (use only on the first dashboard load,
/// at most 6 items). Respects the system "remove animations" setting.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final delay = Motion.stagger * index.clamp(0, 5);
    final total = Motion.base + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1, curve: Motion.enter),
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 4), child: child)),
      child: child,
    );
  }
}

extension RevealX on Widget {
  Widget reveal({int index = 0}) => Reveal(index: index, child: this);
}
