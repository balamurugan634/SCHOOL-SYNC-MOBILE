import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/comms.dart';
import '../workspace.dart';
import 'meeting_providers.dart';
import 'meeting_sheets.dart';

/// Parent-teacher meetings from the teacher / office side: answer requests, then manage what is booked.
class MeetingsScreen extends ConsumerStatefulWidget {
  const MeetingsScreen({super.key});

  @override
  ConsumerState<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends ConsumerState<MeetingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  String _past = 'completed';

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    ref.invalidate(meetingsProvider);
    ref.invalidate(pendingMeetingRequestsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(pendingMeetingRequestsProvider).value ?? 0;
    return FeatureGate(
      label: 'Meetings',
      anyPermission: const ['meetings:view'],
      child: StaffFrame(
        title: 'Meetings',
        headerExtra: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: pending > 0 ? 'Requests ($pending)' : 'Requests'),
            const Tab(text: 'Upcoming'),
            const Tab(text: 'Past'),
          ],
        ),
        body: TabBarView(
          controller: _tabs,
          children: [
            _MeetingList(status: 'requested', onChanged: _reload, emptyTitle: 'No requests waiting', emptyMessage: 'When a parent asks to meet, it shows up here for you to confirm or decline.'),
            _MeetingList(status: 'confirmed', onChanged: _reload, emptyTitle: 'Nothing booked', emptyMessage: 'Confirmed meetings appear here, soonest first.'),
            Column(
              children: [
                const SizedBox(height: Gaps.sm),
                FilterChips<String>(options: const ['completed', 'declined', 'cancelled'], selected: _past, onSelected: (s) => setState(() => _past = s), labelOf: (s) => switch (s) { 'completed' => 'Completed', 'declined' => 'Declined', _ => 'Cancelled' }),
                const SizedBox(height: Gaps.sm),
                Expanded(child: _MeetingList(key: ValueKey(_past), status: _past, onChanged: _reload, emptyTitle: 'Nothing here', emptyMessage: 'Meetings that are $_past will be listed here.')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MeetingList extends ConsumerWidget {
  const _MeetingList({super.key, required this.status, required this.onChanged, required this.emptyTitle, required this.emptyMessage});
  final String status;
  final VoidCallback onChanged;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = meetingsProvider(status);
    final value = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      ref.invalidate(pendingMeetingRequestsProvider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return AsyncBody<PagedList<StaffMeeting>>(
      value: value,
      onRetry: () => ref.invalidate(provider),
      isEmpty: (p) => p.items.isEmpty,
      empty: RefreshIndicator(onRefresh: refresh, child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [ConstrainedBox(constraints: const BoxConstraints(minHeight: 360), child: EmptyState(illo: Illo.emptyEvents, title: emptyTitle, message: emptyMessage))])),
      data: (p) => RefreshScroll(
        onRefresh: refresh,
        children: [
          const ReadOnlyBanner(),
          for (final m in p.items) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: _MeetingCard(m, onChanged: onChanged)),
          LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
        ],
      ),
    );
  }
}

class _MeetingCard extends ConsumerWidget {
  const _MeetingCard(this.m, {required this.onChanged});
  final StaffMeeting m;
  final VoidCallback onChanged;

  Future<void> _do(BuildContext context, String action) async {
    final saved = await showMeetingActionSheet(context, m, action);
    if (saved) onChanged();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final readOnly = ref.watch(readOnlyProvider);
    final when = m.scheduledAt;
    final timeLine = when != null
        ? '${relativeDay(when)}, ${fmtTime(when)}  ·  ${m.durationMin} min'
        : m.proposedAt != null
        ? 'Parent would like ${relativeDay(m.proposedAt!)}, ${fmtTime(m.proposedAt!)}'
        : 'No preferred time given';
    final isLink = m.mode == 'online' && (m.locationOrLink ?? '').isNotEmpty;

    Widget action(String a, String label, IconData icon, {bool primary = false, bool danger = false}) {
      if (!m.can(a)) return const SizedBox.shrink();
      if (primary) return FilledButton.icon(onPressed: readOnly ? null : () => _do(context, a), icon: Icon(icon, size: 18), label: Text(label), style: FilledButton.styleFrom(minimumSize: const Size(0, 48)));
      return OutlinedButton.icon(
        onPressed: readOnly ? null : () => _do(context, a),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48), foregroundColor: danger ? t.danger : null, side: danger ? BorderSide(color: t.danger.withValues(alpha: .5)) : null),
      );
    }

    final actions = [
      action('confirm', 'Confirm', Icons.check_rounded, primary: true),
      action('reschedule', 'Reschedule', Icons.edit_calendar_outlined),
      action('complete', 'Mark done', Icons.task_alt_rounded, primary: m.status == 'confirmed'),
      action('decline', 'Decline', Icons.close_rounded, danger: true),
      action('cancel', 'Cancel', Icons.event_busy_outlined, danger: true),
    ].where((w) => w is! SizedBox).toList();

    return AppCard(
      semanticLabel: 'Meeting about ${m.studentName}, ${m.status}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(m.studentName, style: context.text.titleMedium)),
              const SizedBox(width: Gaps.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MeetingStatusChip(m.status),
                  if (m.onlineMeeting?.isScheduled ?? false) const Padding(padding: EdgeInsets.only(top: 4), child: OnlineChip()),
                ],
              ),
            ],
          ),
          if (m.classLabel.isNotEmpty || m.admissionNo != null) Text([m.classLabel, if (m.admissionNo != null) m.admissionNo!].where((e) => e.isNotEmpty).join('  ·  '), style: context.text.bodySmall),
          const SizedBox(height: Gaps.sm),
          Text(m.topic, style: context.text.bodyMedium),
          const SizedBox(height: Gaps.sm),
          _Fact(Icons.schedule_rounded, timeLine),
          _Fact(Icons.person_outline_rounded, [if (m.guardianName != null) 'With ${m.guardianName}', 'Teacher ${m.teacherName}'].join('  ·  ')),
          _Fact(switch (m.mode) { 'online' => Icons.videocam_outlined, 'phone' => Icons.call_outlined, _ => Icons.meeting_room_outlined }, [m.modeLabel, if (!isLink && (m.locationOrLink ?? '').isNotEmpty) m.locationOrLink!].join('  ·  ')),
          if (m.onlineMeeting != null) ...[const SizedBox(height: Gaps.sm), OnlineMeetingCard(meeting: m.onlineMeeting!)],
          // The generated link above replaces a hand-typed one; if the school's link failed, the typed one stays.
          if (isLink && !(m.onlineMeeting?.isScheduled ?? false)) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => openLink(context, m.locationOrLink), icon: const Icon(Icons.open_in_new_rounded, size: 18), label: const Text('Open meeting link'))),
          if ((m.outcomeNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: Gaps.sm),
            AppCard(tone: CardTone.subtle, padding: const EdgeInsets.all(Gaps.md), child: Text(m.outcomeNotes!, style: context.text.bodyMedium)),
          ],
          if (actions.isNotEmpty) ...[const SizedBox(height: Gaps.md), Wrap(spacing: Gaps.sm, runSpacing: Gaps.sm, children: actions)],
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: context.tokens.textTertiary)), const SizedBox(width: Gaps.sm), Expanded(child: Text(text, style: context.text.bodyMedium?.copyWith(color: context.tokens.textSecondary)))]),
    );
  }
}

class _MeetingStatusChip extends StatelessWidget {
  const _MeetingStatusChip(this.status);
  final String status;

  @override
  Widget build(BuildContext context) => switch (status) {
    'requested' => const StatusChip('Needs your answer', tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded),
    'confirmed' => const StatusChip('Confirmed', tone: StatusTone.success, icon: Icons.check_rounded),
    'completed' => const StatusChip('Done', tone: StatusTone.info, icon: Icons.task_alt_rounded),
    'declined' => const StatusChip('Declined', tone: StatusTone.danger, icon: Icons.close_rounded),
    'cancelled' => const StatusChip('Cancelled', tone: StatusTone.neutral, icon: Icons.block_rounded),
    _ => StatusChip(status),
  };
}
