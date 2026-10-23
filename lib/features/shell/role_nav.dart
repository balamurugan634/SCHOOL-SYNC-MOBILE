import 'package:flutter/material.dart';

import '../../data/models/me.dart';
import '../../data/models/site_info.dart';

class FeatureSpec {
  const FeatureSpec(this.icon, this.title, this.description, {this.rows = 2});
  final IconData icon;
  final String title;
  final String description;
  final int rows;
}

/// One bottom-navigation tab of a role experience.
class TabSpec {
  const TabSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.subtitle,
    this.features = const [],
    this.sensitive = false,
    this.anyPermission = const [],
    this.siteFeature,
    this.kind = TabKind.placeholder,
    this.builder,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final String subtitle;
  final List<FeatureSpec> features;

  /// Screen capture is blocked while this tab is showing.
  final bool sensitive;

  /// The tab is usable when the user holds at least one of these (empty = always).
  final List<String> anyPermission;

  /// Needs `SiteInfo.features.<name>` to be on (`fees`, `transport`, `library`).
  final String? siteFeature;
  final TabKind kind;

  /// A feature-owned screen for this tab. When null the tab shows a placeholder.
  final Widget Function(BuildContext context)? builder;

  bool allowedFor(Me me) => anyPermission.isEmpty || me.canAny(anyPermission);

  bool enabledAt(SiteInfo? info) {
    if (siteFeature == null || info == null) return true;
    return switch (siteFeature) {
      'fees' => info.features.fees,
      'transport' => info.features.transport,
      'library' => info.features.library,
      _ => true,
    };
  }
}

enum TabKind { home, placeholder, more, profile, feature }

/// The default Home tab (role-aware placeholder until a role supplies its own `builder`).
const homePlaceholderTab = TabSpec(
  label: 'Home',
  icon: Icons.home_outlined,
  selectedIcon: Icons.home_rounded,
  title: 'Home',
  subtitle: '',
  kind: TabKind.home,
);

/// The shared "More" tab (account + module list).
const moreTab = TabSpec(
  label: 'More',
  icon: Icons.grid_view_outlined,
  selectedIcon: Icons.grid_view_rounded,
  title: 'More',
  subtitle: 'Everything else, plus your account.',
  kind: TabKind.more,
);

/// Bottom navigation per experience (see the product blueprint).
