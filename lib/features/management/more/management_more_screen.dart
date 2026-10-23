import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../router/routes.dart';
import '../../../router/routes_management.dart';
import '../../notifications/notifications_providers.dart';
import '../../shell/tab_screen.dart' show PageHeader;
import '../../workspace/workspace.dart';
import '../approvals/approval_kinds.dart';
import '../home/management_home_providers.dart';

/// More tab for management: account, then the school tools this role may use. Rows the role has no permission for are not shown.
class ManagementMoreScreen extends ConsumerWidget {
  const ManagementMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(staffMeProvider);
    if (me == null) return const SizedBox.shrink();
    final fees = ref.watch(feesEnabledProvider);
    final unread = ref.watch(notificationsUnreadProvider).value ?? 0;
    final counts = ref.watch(managementDashboardProvider).value?.value.approvals;
    final waiting = counts == null ? 0 : visibleQueues(counts, me, feesEnabled: fees).fold<int>(0, (a, q) => a + q.$2);
    final canApprove = approvalSpecs.any((s) => (!s.needsFees || fees) && s.canAct(me));

    final school = <Widget>[
      if (canApprove) ListRow(title: 'Approvals', subtitle: waiting > 0 ? '$waiting waiting for a decision' : 'Leave, corrections, mark sheets, fees and admissions', leading: Icons.fact_check_outlined, onTap: () => context.push(ManagementRoutes.approvals), trailing: waiting > 0 ? Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: StatusChip('$waiting', tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded)), const Icon(Icons.chevron_right_rounded)]) : null),
      if (me.canAny(const ['announcements:create', 'announcements:edit', 'announcements:publish'])) ListRow(title: 'Announcements', subtitle: 'Publish circulars and notices', leading: Icons.campaign_outlined, onTap: () => context.push(ManagementRoutes.announcements)),
      if (me.can('attendance:view')) ListRow(title: 'Attendance overview', subtitle: 'Today by class, absentees and the trend', leading: Icons.fact_check_rounded, onTap: () => context.push(ManagementRoutes.attendance)),
      if (me.can('meetings:view')) ListRow(title: 'Meetings', subtitle: 'Parent-teacher meetings', leading: Icons.handshake_outlined, onTap: () => context.push(ManagementRoutes.meetings)),
    ];
    final mine = <Widget>[
      if (me.can('staff_attendance:create')) ListRow(title: 'My attendance', subtitle: 'Check in and out', leading: Icons.login_rounded, onTap: () => context.push(ManagementRoutes.myAttendance)),
      if (me.can('staff_leave:create')) ListRow(title: 'My leave', subtitle: 'Apply for and track leave', leading: Icons.beach_access_outlined, onTap: () => context.push(ManagementRoutes.myLeave)),
    ];

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        const SliverToBoxAdapter(child: PageHeader(title: 'More', subtitle: 'Everything else, plus your account.')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.huge),
          sliver: SliverList.list(
            children: [
              AppCard(
                onTap: () => context.push(Routes.settings),
                semanticLabel: 'Your account: ${me.displayName}. Open settings',
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
                          Wrap(spacing: Gaps.xs, runSpacing: Gaps.xs, children: [RoleChip(label: me.experience.label, tint: context.tokens.roleTint(me.experience)), for (final r in me.roles.take(2)) Text(_roleLabel(r), style: context.text.bodySmall)]),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.tokens.textTertiary),
                  ],
                ),
              ),
              if (school.isNotEmpty) ...[const GroupLabel('School'), RowGroup(children: school)],
              if (mine.isNotEmpty) ...[const GroupLabel('For me'), RowGroup(children: mine)],
              const GroupLabel('Account'),
              RowGroup(
                children: [
                  ListRow(title: 'Notifications', subtitle: unread > 0 ? '$unread unread' : 'Your inbox and push settings', leading: Icons.notifications_none_rounded, onTap: () => context.push(Routes.notifications)),
                  ListRow(title: 'Settings and security', subtitle: 'Password, devices, app lock, theme', leading: Icons.settings_outlined, onTap: () => context.push(Routes.settings)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _roleLabel(String key) => key.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}
