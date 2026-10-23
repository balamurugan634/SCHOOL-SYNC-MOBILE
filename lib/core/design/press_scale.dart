import 'package:flutter/material.dart';

/// Tap target with a quiet pressed state (slight fade). No scaling or lift.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap, this.onLongPress, this.semanticLabel});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _set(true) : null,
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedOpacity(opacity: _down ? .6 : 1, duration: const Duration(milliseconds: 90), child: widget.child),
      ),
    );
  }
}
