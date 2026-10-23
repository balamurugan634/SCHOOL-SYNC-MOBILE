import 'package:flutter/material.dart';

import 'app_card.dart';
import 'theme.dart';
import 'tokens.dart';

/// A 56+ dp list row: leading icon (plain, monochrome), title, optional subtitle, trailing widget or chevron.
class ListRow extends StatelessWidget {
  const ListRow({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap, this.chevron = true, this.titleMaxLines = 2, this.dense = false});

  final String title;
  final String? subtitle;
  final IconData? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;
  final int titleMaxLines;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // At large text sizes a trailing chip no longer fits beside the title: it moves under the text instead of overflowing.
    final stacked = trailing != null && MediaQuery.textScalerOf(context).scale(14) > 14 * 1.35;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: dense ? 48 : 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
          child: Row(
            children: [
              if (leading != null) ...[Icon(leading, size: 22, color: t.textSecondary), const SizedBox(width: Gaps.md)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, maxLines: titleMaxLines, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    if (subtitle != null && subtitle!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall)),
                    if (stacked) Padding(padding: const EdgeInsets.only(top: Gaps.xs), child: trailing),
                  ],
                ),
              ),
              if (trailing != null && !stacked) ...[const SizedBox(width: Gaps.sm), trailing!],
              if (onTap != null && chevron && (trailing == null || stacked)) Icon(Icons.chevron_right_rounded, color: t.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rows inside one card, separated by hairlines.
class RowGroup extends StatelessWidget {
  const RowGroup({super.key, required this.children, this.padding = EdgeInsets.zero});
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: padding,
    child: Column(children: [for (final (i, w) in children.indexed) ...[if (i > 0) const Divider(), w]]),
  );
}

/// `label ......... value`, for facts and receipts.
class FactRow extends StatelessWidget {
  const FactRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(label, style: context.text.bodyMedium?.copyWith(color: t.textSecondary))),
          const SizedBox(width: Gaps.md),
          Expanded(flex: 5, child: Text(value, textAlign: TextAlign.end, style: context.text.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w600 : FontWeight.w500, color: valueColor, fontFeatures: const [FontFeature.tabularFigures()]))),
        ],
      ),
    );
  }
}

/// Horizontal single-select filter chips.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({super.key, required this.options, required this.selected, required this.onSelected, required this.labelOf, this.padding = const EdgeInsets.symmetric(horizontal: Gaps.page)});

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: Gaps.sm),
        itemBuilder: (_, i) {
          final o = options[i];
          final sel = o == selected;
          return Semantics(
            selected: sel,
            button: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelected(o),
              child: AnimatedContainer(
                duration: Motion.fast,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: sel ? t.brand.soft : t.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: sel ? t.brand.solid.withValues(alpha: .5) : t.borderStrong)),
                child: Text(labelOf(o), style: context.text.labelMedium?.copyWith(color: sel ? t.brand.ink : t.textSecondary, fontWeight: sel ? FontWeight.w600 : FontWeight.w500)),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Small label above a group, sentence case.
class GroupLabel extends StatelessWidget {
  const GroupLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Gaps.xl, 4, Gaps.sm),
    child: Row(children: [Expanded(child: Text(text, style: context.text.titleMedium)), ?trailing]),
  );
}
