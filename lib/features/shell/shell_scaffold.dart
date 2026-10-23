import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity.dart';
import '../../core/design/design.dart';
import '../../data/models/me.dart';
import '../auth/session.dart';
import '../onboarding/tour_dialog.dart';
import '../security/secure_scope.dart';
import '../../router/role_modules.dart';

/// The role-aware frame: bottom navigation for the user's experience,
/// an offline banner and screen-capture protection on sensitive tabs.
class ShellScaffold extends ConsumerStatefulWidget {
  const ShellScaffold({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  ConsumerState<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends ConsumerState<ShellScaffold> {
  bool _tourOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
  }

  /// The welcome tour: a small dialog over the real home, once per user.
  Future<void> _maybeShowTour() async {
    if (!mounted || _tourOpen) return;
    final s = ref.read(sessionProvider);
    final me = s.me;
    if (me == null || s.tourSeen || s.locked) return;
    _tourOpen = true;
    await showDialog<void>(context: context, barrierDismissible: false, builder: (_) => TourDialog(me: me));
    _tourOpen = false;
    await ref.read(sessionProvider.notifier).completeTour();
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    ref.listen<bool>(sessionProvider.select((s) => s.tourSeen), (_, seen) {
      if (!seen) WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTour());
    });
    final experience = ref.watch(sessionProvider.select((s) => s.me?.experience)) ?? Experience.student;
    final offlineProfile = ref.watch(sessionProvider.select((s) => s.offlineProfile));
    final online = ref.watch(onlineProvider);
    final tabs = tabsFor(experience);
    final index = shell.currentIndex.clamp(0, tabs.length - 1);

    return SecureScope(
      secure: tabs[index].sensitive,
      child: Scaffold(
        body: Column(
          children: [
            if (!online || offlineProfile) const SafeArea(bottom: false, child: OfflineBanner(visible: true)),
            Expanded(
              child: MediaQuery.removePadding(context: context, removeTop: !online || offlineProfile, child: shell),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          index: index,
          destinations: [for (final t in tabs) NavDestination(label: t.label, icon: t.icon, selectedIcon: t.selectedIcon)],
          onSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      ),
    );
  }
}
