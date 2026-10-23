import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../auth/session.dart';

/// Shows [child] only when the person holds one of [anyPermission] (empty = no check) and the school has the
/// optional module [siteFeature] (`fees`, `transport`, `library`) switched on. Otherwise a calm explanation.
/// Hiding is not security: the API still enforces every call.
class FeatureGate extends ConsumerWidget {
  const FeatureGate({super.key, required this.label, required this.child, this.anyPermission = const [], this.siteFeature});

  final String label;
  final List<String> anyPermission;
  final String? siteFeature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final info = session.siteInfo;
    final featureOn = siteFeature == null || info == null || switch (siteFeature) { 'fees' => info.features.fees, 'transport' => info.features.transport, 'library' => info.features.library, _ => true };
    if (!featureOn) {
      return EmptyState(icon: Icons.toggle_off_outlined, title: '$label is not turned on', message: '${info.displayName} has not enabled this yet.');
    }
    if (anyPermission.isNotEmpty && !me.canAny(anyPermission)) {
      return EmptyState(icon: Icons.lock_outline_rounded, title: 'No access', message: 'Your role does not include ${label.toLowerCase()}. Ask your school office if you think this is a mistake.');
    }
    return child;
  }
}
