import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/security/platform_bridge.dart';
import '../../data/models/me.dart';
import '../auth/session.dart';
import 'child_selector.dart';
import 'home_header.dart';

/// Warns (does not block) when the device looks rooted / jailbroken.
final deviceCompromisedProvider = FutureProvider<bool>((ref) => PlatformBridge.isRooted());
final rootWarningDismissedProvider = NotifierProvider<_Flag, bool>(_Flag.new);

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;
  void set() => state = true;
}

/// The staggered reveal runs on the first dashboard load only (design.md section 9).
bool _homeRevealed = false;

/// Phase 1: the role-specific home, wired to /auth/me. It shows the real facts we already have
/// and one quiet "coming online" card until the feature endpoints land.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final info = session.siteInfo;
    final compromised = ref.watch(deviceCompromisedProvider).value ?? false;
    final dismissed = ref.watch(rootWarningDismissedProvider);

    final firstLoad = !_homeRevealed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _homeRevealed = true);
    Widget stage(int i, Widget w) => firstLoad ? w.reveal(index: i) : w;

    final (facts, soon) = switch (me.experience) {
      Experience.student => _student(me),
      Experience.parent => _parent(ref, me),
      Experience.teacher => _teacher(me),
      Experience.management => _management(ref, me),
    };

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: HomeHeader(me: me, info: info)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, Gaps.huge),
          sliver: SliverList.list(
            children: [
              if (info?.readOnly ?? false) ...[
                const InfoBanner(
                  tone: BannerTone.warning,
                  icon: Icons.event_busy_rounded,
                  title: 'View-only mode',
                  message: 'Your school\'s subscription has ended. You can read information, but changes are disabled until it is renewed.',
                ),
                const SizedBox(height: Gaps.md),
              ],
              if (compromised && !dismissed) ...[
                InfoBanner(
                  tone: BannerTone.warning,
                  icon: Icons.security_rounded,
                  title: 'Security notice',
                  message: 'This device appears to be rooted or modified. Your school data may be less protected here.',
                  onDismiss: () => ref.read(rootWarningDismissedProvider.notifier).set(),
                ),
                const SizedBox(height: Gaps.md),
              ],
              if (facts != null) ...[stage(0, facts), const SizedBox(height: Gaps.md)],
              stage(1, soon),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(child: Text(label, style: context.text.bodyMedium?.copyWith(color: context.tokens.textSecondary))),
        Text(value, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      ],
    ),
  );

  // ───────────────────────────────────────────────────────── student
  (Widget?, Widget) _student(Me me) {
    final p = me.profile;
    final cls = [p.gradeName, p.sectionName].where((e) => e != null && e.isNotEmpty).join(' - ');
    return (
      Builder(builder: (context) => AppCard(child: Column(children: [_row(context, 'Class', cls.isEmpty ? 'Not assigned yet' : cls), const Divider(), _row(context, 'Signed in as', _handle(me))]))),
      const ComingSoonCard(
        title: 'Your school day',
        message: 'Today\'s classes, homework, upcoming exams and announcements will appear here.',
        points: ['Today\'s classes', 'Homework due', 'Exams and events', 'Announcements'],
      ),
    );
  }

  // ───────────────────────────────────────────────────────── parent
  (Widget?, Widget) _parent(WidgetRef ref, Me me) {
    final child = ref.watch(selectedChildProvider);
    return (
      Builder(
        builder: (context) => child == null
            ? const AppCard(child: EmptyState(icon: Icons.family_restroom_outlined, title: 'No children linked yet', message: 'The school links each child to your account after verifying you are the parent or guardian. Ask the school office if this looks wrong.', compact: true))
            : AppCard(
                child: Row(
                  children: [
                    UserAvatar(name: child.name, url: child.photoUrl, size: 48),
                    const SizedBox(width: Gaps.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(child.name, style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(child.classLabel, style: context.text.bodySmall),
                          if (child.admissionNo.isNotEmpty) Text('Admission no. ${child.admissionNo}', style: context.text.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      const ComingSoonCard(
        title: 'Your child\'s day',
        message: 'Attendance, homework, exams and school notices for the selected child will appear here.',
        points: ['Attendance', 'Homework and exams', 'Fee balance', 'Announcements'],
      ),
    );
  }

  // ───────────────────────────────────────────────────────── teacher
  (Widget?, Widget) _teacher(Me me) {
    final p = me.profile;
    return (
      Builder(
        builder: (context) => AppCard(
          child: Column(
            children: [
              _row(context, 'Sections you teach', '${p.assignedSectionIds.length}'),
              if (p.classTeacherSectionIds.isNotEmpty) ...[const Divider(), _row(context, 'Class teacher of', '${p.classTeacherSectionIds.length}')],
            ],
          ),
        ),
      ),
      const ComingSoonCard(
        title: 'Your day',
        message: 'Today\'s timetable, attendance to mark and homework to review will appear here.',
        points: ['Today\'s timetable', 'Quick attendance', 'Homework to review', 'Pending tasks'],
      ),
    );
  }

  // ───────────────────────────────────────────────────────── management
  (Widget?, Widget) _management(WidgetRef ref, Me me) {
    final fees = ref.watch(sessionProvider.select((s) => s.siteInfo?.features.fees ?? true));
    final canFees = fees && me.canAny(const ['fees:view', 'payments:view']);
    return (
      Builder(
        builder: (context) => AppCard(
          child: Column(
            children: [
              _row(context, 'Signed in as', _handle(me)),
              if (me.roles.isNotEmpty) ...[const Divider(), _row(context, 'Role', me.roles.map(_roleLabel).join(', '))],
            ],
          ),
        ),
      ),
      ComingSoonCard(
        title: 'School overview',
        message: 'Attendance today, requests waiting for approval and alerts will appear here.',
        points: ['Students, staff and classes', 'Attendance today', 'Pending requests', if (canFees) 'Fee collection', 'Alerts'],
      ),
    );
  }

  static String _handle(Me me) => me.username.contains('@') ? me.username : '@${me.username}';

  static String _roleLabel(String key) => key.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
}
