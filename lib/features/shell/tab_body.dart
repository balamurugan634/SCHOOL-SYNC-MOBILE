import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../profile/settings_screen.dart';
import '../../router/role_modules.dart';
import 'role_nav.dart';
import 'tab_screen.dart';

/// Resolves "which screen is tab N" for the signed-in experience.
class TabBody extends ConsumerWidget {
  const TabBody({super.key, required this.index});
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final experience = ref.watch(sessionProvider.select((s) => s.me?.experience));
    if (experience == null) return const SizedBox.shrink();
    final tabs = tabsFor(experience);
    final spec = tabs[index.clamp(0, tabs.length - 1)];
    // Permission / school-feature gating applies to every tab, including feature-owned ones.
    final blocked = TabScreen.blockedView(spec, ref.watch(sessionProvider));
    if (blocked != null) return Column(children: [PageHeader(title: spec.title, subtitle: spec.subtitle), Expanded(child: blocked)]);
    // A role's feature screen wins over the default for this tab.
    final custom = spec.builder;
    if (custom != null) return custom(context);
    return switch (spec.kind) {
      TabKind.home => const HomeScreen(),
      TabKind.more => const MoreScreen(),
      TabKind.profile => const SettingsScreen(embedded: true),
      TabKind.placeholder || TabKind.feature => TabScreen(spec: spec),
    };
  }
}
