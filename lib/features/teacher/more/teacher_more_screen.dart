import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../router/routes.dart';
import '../../../router/routes_teacher.dart';
import '../../shell/tab_screen.dart' show PageHeader;
import '../../workspace/meetings/meeting_providers.dart';
import '../../workspace/workspace.dart';

class _Row {
  const _Row(this.icon, this.title, this.subtitle, this.path, {this.anyPermission = const [], this.pendingMeetings = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final String path;
  final List<String> anyPermission;
  final bool pendingMeetings;
}

const _teaching = [
  _Row(Icons.schedule_rounded, 'Timetable', 'Your week, with covers', TeacherRoutes.timetable, anyPermission: ['timetable:view']),
  _Row(Icons.menu_book_outlined, 'Syllabus progress', 'Mark topics as started or completed', TeacherRoutes.syllabus, anyPermission: ['syllabus:view', 'syllabus:edit']),
  _Row(Icons.grading_rounded, 'Marks entry', 'Enter and submit marks', TeacherRoutes.marks, anyPermission: ['marks:view', 'marks:create', 'marks:edit']),
  _Row(Icons.campaign_outlined, 'Announcements', 'Write to your classes', TeacherRoutes.announcements, anyPermission: ['announcements:create', 'announcements:edit', 'announcements:view']),
];

const _people = [
  _Row(Icons.handshake_outlined, 'Meetings', 'Parent-teacher requests and bookings', TeacherRoutes.meetings, anyPermission: ['meetings:view'], pendingMeetings: true),
  _Row(Icons.how_to_reg_outlined, 'My attendance', 'Check in and out', TeacherRoutes.myAttendance, anyPermission: ['staff_attendance:create', 'staff_attendance:view']),
  _Row(Icons.beach_access_outlined, 'My leave', 'Apply for leave and see decisions', TeacherRoutes.myLeave, anyPermission: ['staff_leave:view', 'staff_leave:create']),
];

/// The teacher's "More" tab: account, then everything that is not on the bottom bar.
class TeacherMoreScreen extends ConsumerWidget {
  const TeacherMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(staffMeProvider);
    if (me == null) return const SizedBox.shrink();
    final t = context.tokens;
    final pending = me.can('meetings:view') ? (ref.watch(pendingMeetingRequestsProvider).value ?? 0) : 0;

    Widget rowOf(_Row r) => ListRow(
      leading: r.icon,
      title: r.title,
      subtitle: r.pendingMeetings && pending > 0 ? '${_requests(pending)} waiting for your answer' : r.subtitle,
      onTap: () => context.push(r.path),
      trailing: r.pendingMeetings && pending > 0 ? StatusChip('$pending new', tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded) : null,
    );

    List<Widget> group(String label, List<_Row> rows) {
      final visible = rows.where((r) => r.anyPermission.isEmpty || me.canAny(r.anyPermission)).toList();
      if (visible.isEmpty) return const [];
      return [GroupLabel(label), RowGroup(children: [for (final r in visible) rowOf(r)])];
    }

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(pendingMeetingRequestsProvider.future),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(child: PageHeader(title: 'More', subtitle: 'Everything else, plus your account.')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.md, Gaps.page, Gaps.huge),
            sliver: SliverList.list(
              children: [
                AppCard(
                  onTap: () => context.push(Routes.settings),
                  semanticLabel: 'Your account: ${me.displayName}. Open settings.',
                  child: Row(
                    children: [
                      UserAvatar(name: me.displayName, url: me.avatarUrl, size: 52, ringColor: t.roleTint(me.experience)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(me.displayName, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Wrap(spacing: 6, runSpacing: 4, children: [RoleChip(label: me.experience.label, tint: t.roleTint(me.experience)), if (me.profile.classTeacherSectionIds.isNotEmpty) const StatusChip('Class teacher', tone: StatusTone.neutral)]),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: t.textTertiary),
                    ],
                  ),
                ),
                ...group('Teaching', _teaching),
                ...group('People and time', _people),
                const GroupLabel('Account'),
                RowGroup(
                  children: [
                    ListRow(leading: Icons.settings_outlined, title: 'Settings and security', subtitle: 'Password, devices, app lock, theme', onTap: () => context.push(Routes.settings)),
                    ListRow(leading: Icons.notifications_none_rounded, title: 'Notifications', subtitle: 'Your inbox and push settings', onTap: () => context.push(Routes.notifications)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _requests(int n) => n == 1 ? '1 request' : '$n requests';
}
