import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

class NavDestination {
  const NavDestination({required this.label, required this.icon, required this.selectedIcon, this.badge});
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final int? badge;
}

/// Flat bottom bar: hairline top border, tint indicator, brand icon + label when active.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.destinations, required this.index, required this.onSelected});

  final List<NavDestination> destinations;
  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: context.tokens.border))),
      child: NavigationBar(
        selectedIndex: index,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          if (i != index) HapticFeedback.selectionClick();
          onSelected(i);
        },
        destinations: [
          for (final d in destinations)
            NavigationDestination(label: d.label, tooltip: d.label, icon: _icon(d.icon, d.badge), selectedIcon: _icon(d.selectedIcon, d.badge)),
        ],
      ),
    );
  }

  Widget _icon(IconData icon, int? badge) => badge == null || badge <= 0 ? Icon(icon) : Badge.count(count: badge, child: Icon(icon));
}
