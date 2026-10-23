import 'package:flutter/material.dart';

import 'tokens.dart';

/// Solid brand call-to-action (48 dp) with a built-in loading state.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.loading = false, this.icon, this.trailingIcon});

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final IconData? trailingIcon;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    return Listener(
      onPointerDown: (_) => setState(() => _down = true),
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down && enabled ? .98 : 1,
        duration: Motion.press,
        child: FilledButton(
          onPressed: enabled ? widget.onPressed : null,
          // Loading keeps the label's width: the spinner replaces the text in place.
          child: Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: widget.loading ? 0 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[Icon(widget.icon, size: 18), const SizedBox(width: 8)],
                    Flexible(child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (widget.trailingIcon != null) ...[const SizedBox(width: 8), Icon(widget.trailingIcon, size: 18)],
                  ],
                ),
              ),
              if (widget.loading) SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Theme.of(context).colorScheme.onPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Surface + 1 px border secondary action.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

/// Quiet text action ("Skip", "Not now").
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(foregroundColor: color),
    child: Text(label),
  );
}
