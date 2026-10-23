import 'package:flutter/material.dart';

import '../../../core/design/design.dart';

/// A read-only bottom sheet for a request that is already decided (or that I cannot decide).
Future<void> showDetailSheet(BuildContext context, {required String title, required Widget child}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.xl),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: _titleStyle(context))),
        const SizedBox(height: Gaps.md),
        child,
        const SizedBox(height: Gaps.sm),
        SecondaryButton(label: 'Close', onPressed: () => Navigator.pop(context)),
      ],
    ),
  ),
);

TextStyle? _titleStyle(BuildContext context) => context.text.titleLarge;
