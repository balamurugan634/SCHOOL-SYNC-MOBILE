import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction, this.padding});

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(Gaps.page, Gaps.xxl, Gaps.page, Gaps.sm),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: context.text.titleMedium))),
          if (action != null) TextButton(onPressed: onAction, style: TextButton.styleFrom(visualDensity: VisualDensity.compact), child: Text(action!)),
        ],
      ),
    );
  }
}
