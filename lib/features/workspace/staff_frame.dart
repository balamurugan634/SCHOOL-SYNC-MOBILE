import 'package:flutter/material.dart';

import '../../core/design/design.dart';
import '../shell/tab_screen.dart' show PageHeader;

/// Frame for staff screens. Embedded in a tab it shows the page header; pushed it shows an app bar.
/// [body] is expected to scroll on its own (use `RefreshScroll` or a `ListView`).
class StaffFrame extends StatelessWidget {
  const StaffFrame({super.key, required this.title, required this.body, this.subtitle, this.embedded = false, this.actions, this.fab, this.bottom, this.headerExtra});

  final String title;
  final String? subtitle;
  final Widget body;
  final bool embedded;
  final List<Widget>? actions;
  final Widget? fab;
  final Widget? bottom;

  /// Rendered under the header (filters, a segmented control ...).
  final Widget? headerExtra;

  @override
  Widget build(BuildContext context) {
    final content = Column(children: [?headerExtra, Expanded(child: body)]);
    if (embedded) {
      return Stack(
        children: [
          Column(
            children: [
              PageHeader(title: title, subtitle: subtitle, trailing: actions == null ? null : Row(mainAxisSize: MainAxisSize.min, children: actions!)),
              Expanded(child: content),
            ],
          ),
          ?(fab == null ? null : Positioned(right: Gaps.page, bottom: Gaps.lg, child: fab!)),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: content,
      floatingActionButton: fab,
      bottomNavigationBar: bottom,
    );
  }
}

/// A titled card with an optional action; the building block of dashboards and detail screens.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.action, this.onAction, this.trailing, this.padding = const EdgeInsets.fromLTRB(Gaps.lg, Gaps.xs, Gaps.lg, Gaps.md), this.semanticLabel});

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    semanticLabel: semanticLabel,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.sm, Gaps.sm, 0),
          // A Wrap, not a Row: at 200% text size a long action label moves under the title instead of overflowing.
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(padding: const EdgeInsets.only(right: Gaps.sm), child: Semantics(header: true, child: Text(title, style: context.text.titleMedium))),
              if (trailing != null || action != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?(trailing == null ? null : Flexible(child: trailing!)),
                    if (action != null) Flexible(child: TextButton(onPressed: onAction, style: TextButton.styleFrom(minimumSize: const Size(48, 44)), child: Text(action!, maxLines: 2, textAlign: TextAlign.center))),
                  ],
                ),
            ],
          ),
        ),
        Padding(padding: padding, child: child),
      ],
    ),
  );
}

/// A quiet one-line message inside a card ("Nothing to review").
class QuietLine extends StatelessWidget {
  const QuietLine(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gaps.xs),
      child: Row(
        children: [
          if (icon != null) ...[Icon(icon, size: 18, color: t.textTertiary), const SizedBox(width: Gaps.sm)],
          Expanded(child: Text(text, style: context.text.bodyMedium?.copyWith(color: t.textSecondary))),
        ],
      ),
    );
  }
}

/// A person (student, staff, guardian) as a list row: avatar, name, one detail line, trailing widget.
class PersonTile extends StatelessWidget {
  const PersonTile({super.key, required this.name, this.subtitle, this.trailing, this.onTap, this.photoUrl, this.leadingNumber, this.chevron = true});

  final String name;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? photoUrl;

  /// Roll number shown in the avatar's place when set.
  final int? leadingNumber;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // At large text sizes the trailing widget moves under the text instead of overflowing.
    final stacked = trailing != null && MediaQuery.textScalerOf(context).scale(14) > 14 * 1.35;
    return Semantics(
      button: onTap != null,
      label: [name, ?subtitle].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
            child: Row(
              children: [
                if (leadingNumber != null)
                  SizedBox(width: 40, child: Text('$leadingNumber', textAlign: TextAlign.center, style: context.text.labelMedium?.copyWith(color: t.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])))
                else
                  UserAvatar(name: name, url: photoUrl, size: 40),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      if (subtitle != null && subtitle!.isNotEmpty) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                      if (stacked) Padding(padding: const EdgeInsets.only(top: Gaps.xs), child: trailing),
                    ],
                  ),
                ),
                if (trailing != null && !stacked) ...[const SizedBox(width: Gaps.sm), trailing!] else if (onTap != null && chevron) Icon(Icons.chevron_right_rounded, color: t.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A thin progress bar with a text value, e.g. "18 of 24".
class MeterBar extends StatelessWidget {
  const MeterBar({super.key, required this.value, this.label, this.semanticLabel});
  final double value;
  final String? label;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      label: semanticLabel ?? label,
      value: '${(value.clamp(0, 1) * 100).round()}%',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
                duration: reduce ? Duration.zero : const Duration(milliseconds: 400),
                curve: Motion.enter,
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: t.sunken),
              ),
            ),
          ),
          if (label != null) ...[const SizedBox(width: Gaps.sm), Text(label!, style: context.text.labelSmall?.copyWith(color: t.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))],
        ],
      ),
    );
  }
}

/// Text with a status chip beside it; at large text sizes the chip moves under the text instead of overflowing.
class ChipLine extends StatelessWidget {
  const ChipLine({super.key, required this.child, required this.chip});
  final Widget child;
  final Widget chip;

  @override
  Widget build(BuildContext context) {
    final stacked = MediaQuery.textScalerOf(context).scale(14) > 14 * 1.35;
    if (stacked) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [child, const SizedBox(height: Gaps.xs), chip]);
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Expanded(child: child), const SizedBox(width: Gaps.sm), chip]);
  }
}
