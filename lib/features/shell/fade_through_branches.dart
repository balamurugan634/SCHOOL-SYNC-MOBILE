import 'package:flutter/material.dart';

/// Keeps every tab alive (scroll positions and state survive) and cross-fades between them (120 ms).
class FadeThroughBranches extends StatefulWidget {
  const FadeThroughBranches({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  State<FadeThroughBranches> createState() => _FadeThroughBranchesState();
}

class _FadeThroughBranchesState extends State<FadeThroughBranches> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 140), value: 1);

  @override
  void didUpdateWidget(FadeThroughBranches old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          i == widget.index
              ? FadeTransition(opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut), child: widget.children[i])
              : Offstage(child: TickerMode(enabled: false, child: widget.children[i])),
      ],
    );
  }
}
