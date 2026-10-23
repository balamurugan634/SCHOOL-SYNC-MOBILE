import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../data/models/me.dart';
import '../../router/routes.dart';
import '../auth/session.dart';
import '../shell/tab_screen.dart';

class _Item {
  const _Item(this.icon, this.title, this.subtitle, {this.siteFeature, this.permissions = const []});
  final IconData icon;
  final String title;
  final String subtitle;
  final String? siteFeature;
  final List<String> permissions;
}

List<_Item> _itemsFor(Experience e) => switch (e) {
  Experience.parent => const [
    _Item(Icons.campaign_outlined, 'Announcements', 'Circulars and notices'),
    _Item(Icons.event_outlined, 'Calendar and events', 'Holidays, events, consent forms'),
    _Item(Icons.handshake_outlined, 'Parent-teacher meetings', 'Request and view meetings'),
    _Item(Icons.directions_bus_outlined, 'Transport', 'Route, stop and timings', siteFeature: 'transport'),
    _Item(Icons.local_library_outlined, 'Library', 'Issued books and due dates', siteFeature: 'library'),
  ],
  Experience.teacher => const [
    _Item(Icons.schedule_rounded, 'Timetable', 'Your weekly periods'),
    _Item(Icons.grading_rounded, 'Marks entry', 'Enter and review marks'),
    _Item(Icons.campaign_outlined, 'Announcements', 'Notices and class messages'),
    _Item(Icons.beach_access_outlined, 'My leave', 'Apply for and track leave'),
    _Item(Icons.handshake_outlined, 'Meetings', 'Parent-teacher meetings'),
  ],
  Experience.management => const [
    _Item(Icons.bar_chart_rounded, 'Reports', 'Attendance, results and fee reports', permissions: ['reports:view']),
    _Item(Icons.campaign_outlined, 'Announcements', 'Publish circulars and notices'),
    _Item(Icons.event_outlined, 'Calendar and events', 'Manage the school calendar'),
    _Item(Icons.directions_bus_outlined, 'Transport', 'Routes, vehicles and allocation', siteFeature: 'transport'),
    _Item(Icons.local_library_outlined, 'Library', 'Catalogue, issues and fines', siteFeature: 'library'),
    _Item(Icons.history_rounded, 'Audit log', 'Who changed what, and when', permissions: ['audit:view']),
  ],
  Experience.student => const [],
};

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final info = session.siteInfo;
    final items = _itemsFor(me.experience).where((i) {
      final siteOk = switch (i.siteFeature) {
        'transport' => info?.features.transport ?? true,
        'library' => info?.features.library ?? true,
        _ => true,
      };
      return siteOk && (i.permissions.isEmpty || me.canAny(i.permissions));
    }).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const SliverToBoxAdapter(child: PageHeader(title: 'More', subtitle: 'Everything else, plus your account.')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.huge),
          sliver: SliverList.list(
            children: [
              AppCard(
                onTap: () => context.push(Routes.settings),
                child: Row(
                  children: [
                    UserAvatar(name: me.displayName, url: me.avatarUrl, size: 52, ringColor: context.tokens.roleTint(me.experience)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(me.displayName, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          RoleChip(label: me.experience.label, tint: context.tokens.roleTint(me.experience)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
                  ],
                ),
              ),
              const _SectionLabel('Account'),
              _Group(
                children: [
                  _Row(icon: Icons.settings_outlined, title: 'Settings and security', subtitle: 'Password, devices, app lock, theme', onTap: () => context.push(Routes.settings)),
                  _Row(icon: Icons.notifications_none_rounded, title: 'Notifications', subtitle: 'Your inbox and push settings', onTap: () => context.push(Routes.notifications)),
                ],
              ),
              if (items.isNotEmpty) ...[
                const _SectionLabel('Explore'),
                _Group(
                  children: [for (final i in items) _Row(icon: i.icon, title: i.title, subtitle: i.subtitle, trailing: const StatusChip('Soon'))],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, Gaps.xl, 0, Gaps.sm),
    child: Text(text, style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary)),
  );
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (final (i, w) in children.indexed) ...[if (i > 0) const Divider(indent: 56), w],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.subtitle, this.onTap, this.trailing});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    leading: Icon(icon, size: 22, color: context.tokens.textSecondary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded)),
  );
}
