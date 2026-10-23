import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../home/child_selector.dart';
import '../shell/tab_screen.dart';
import 'learner_context.dart';

/// The frame of a learner screen. As a tab ([embedded]) it shows the page header; when pushed it shows an app bar.
/// Parents get the child switcher on top so the screen is always about the right child.
class ScreenFrame extends ConsumerWidget {
  const ScreenFrame({super.key, required this.title, required this.body, this.subtitle, this.embedded = false, this.actions, this.fab, this.showChild = true, this.bottom, this.bare = false});

  final String title;
  final String? subtitle;
  final Widget body;
  final bool embedded;
  final List<Widget>? actions;
  final Widget? fab;
  final bool showChild;
  final Widget? bottom;

  /// Render only the body (used when a screen is nested inside another screen's tab).
  final bool bare;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parent = ref.watch(isParentProvider);
    final selector = showChild && parent ? const Padding(padding: EdgeInsets.only(bottom: Gaps.sm), child: ChildSelector()) : null;
    if (bare) return body;
    final content = Column(children: [?selector, Expanded(child: body)]);
    if (embedded) {
      return Stack(
        children: [
          Column(children: [PageHeader(title: title, subtitle: subtitle, trailing: actions == null ? null : Row(mainAxisSize: MainAxisSize.min, children: actions!)), Expanded(child: content)]),
          if (fab != null) Positioned(right: Gaps.page, bottom: Gaps.lg, child: fab!),
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
