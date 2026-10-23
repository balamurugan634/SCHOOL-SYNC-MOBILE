import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/comms.dart';
import '../../../data/repositories/files_repository.dart';
import '../../../data/repositories/staff/comms_repository.dart';
import '../workspace.dart';
import 'announcement_logic.dart';
import 'announcement_paths.dart';
import 'announcement_providers.dart';
import 'announcement_widgets.dart';

/// One announcement in full, with delivery statistics and the actions that fit its state.
class AnnouncementManageScreen extends ConsumerWidget {
  const AnnouncementManageScreen({super.key, required this.announcementId});
  final String announcementId;

  String _userType(String raw) => switch (raw) { 'student' => 'Students', 'parent' => 'Parents', 'staff' => 'Staff', _ => raw };

  void _refresh(WidgetRef ref) {
    ref.invalidate(announcementDetailProvider(announcementId));
    ref.invalidate(announcementStatsProvider(announcementId));
    ref.invalidate(managedAnnouncementsProvider);
  }

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function(CommsRepository r) call, {required String success, String? confirmTitle, String? confirmMessage, String? confirmLabel, bool destructive = false, bool leave = false}) async {
    if (confirmTitle != null) {
      final ok = await confirmAction(context, title: confirmTitle, message: confirmMessage ?? '', confirmLabel: confirmLabel ?? 'Confirm', destructive: destructive);
      if (!ok || !context.mounted) return;
    }
    final done = await runWrite(context, ref, () => call(ref.read(commsRepositoryProvider)), success: success);
    if (!context.mounted) return;
    _refresh(ref);
    if (done && leave) unawaited(Navigator.of(context).maybePop());
  }

  Future<void> _schedule(BuildContext context, WidgetRef ref, ManagedAnnouncement a) async {
    final at = await pickDayTime(context, initial: a.publishAt ?? DateTime.now().add(const Duration(hours: 2)), firstDate: DateTime.now(), help: 'Publish on');
    if (at == null || !context.mounted) return;
    final problems = validateSchedule(publishAt: at, expiresAt: a.expiresAt);
    if (problems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problems.values.first)));
      return;
    }
    await _act(context, ref, (r) => r.scheduleAnnouncement(a.id, at),
        success: 'Scheduled for ${fmtDateTime(at)}.', confirmTitle: 'Schedule this announcement?', confirmMessage: '"${a.title}" will be sent to ${describeAudience(a.audience)} on ${fmtDateTime(at)}.', confirmLabel: 'Schedule');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paths = AnnouncementPaths.of(ref.watch(staffMeProvider)?.experience);
    final value = ref.watch(announcementDetailProvider(announcementId));
    final readOnly = ref.watch(readOnlyProvider);

    return StaffFrame(
      title: 'Announcement',
      body: AsyncBody<ManagedAnnouncement>(
        value: value,
        onRetry: () => _refresh(ref),
        data: (a) => RefreshScroll(
          onRefresh: () async {
            _refresh(ref);
            try {
              await ref.read(announcementDetailProvider(announcementId).future);
            } catch (_) {}
          },
          children: [
            const ReadOnlyBanner(),
            _Header(a),
            if (a.canManage) ...[const SizedBox(height: Gaps.md), _Actions(a: a, readOnly: readOnly, paths: paths, onAct: (call, {required success, confirmTitle, confirmMessage, confirmLabel, destructive = false, leave = false}) => _act(context, ref, call, success: success, confirmTitle: confirmTitle, confirmMessage: confirmMessage, confirmLabel: confirmLabel, destructive: destructive, leave: leave), onSchedule: () => _schedule(context, ref, a))],
            const SizedBox(height: Gaps.md),
            SectionCard(title: 'Message', child: SelectableText(a.body, style: context.text.bodyMedium)),
            const SizedBox(height: Gaps.md),
            SectionCard(
              title: 'Audience',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(spacing: Gaps.sm, runSpacing: Gaps.xs, children: [for (final t in a.audience) Chip(label: Text(t.label), visualDensity: VisualDensity.compact)]),
                  // Drafts have no delivery numbers yet, but the API can say how many people the audience reaches.
                  if (a.isDraft || a.isScheduled) _AudienceSize(a.id),
                ],
              ),
            ),
            if (a.attachments.isNotEmpty) ...[
              const SizedBox(height: Gaps.md),
              SectionCard(
                title: 'Attachments',
                padding: EdgeInsets.zero,
                child: Column(children: [for (final f in a.attachments) ListRow(title: f.name, subtitle: f.sizeBytes == null ? null : fileSize(f.sizeBytes), leading: Icons.attach_file_rounded, dense: true, onTap: () => ref.read(filesRepositoryProvider).openStored(f))]),
              ),
            ],
            if (a.isPublished || a.state == 'expired' || a.state == 'archived') ...[const SizedBox(height: Gaps.md), _Stats(id: a.id, requiresAck: a.requiresAck, userType: _userType)],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.a);
  final ManagedAnnouncement a;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final facts = [
      if (a.authorName != null) 'By ${a.authorName}',
      if (a.isScheduled && a.publishAt != null) 'Publishes ${fmtDateTime(a.publishAt!)}' else if (a.publishAt != null && !a.isDraft) 'Published ${fmtDateTime(a.publishAt!)}',
      if (a.expiresAt != null) 'Expires ${fmtDateTime(a.expiresAt!)}',
      if (a.requiresAck) 'Asks for acknowledgement',
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(a.title, style: context.text.headlineSmall)),
          const SizedBox(height: Gaps.sm),
          Wrap(spacing: 6, runSpacing: 4, children: [AnnouncementStateChip(a), PriorityChip(a.priority)]),
          const SizedBox(height: Gaps.sm),
          for (final f in facts) Text(f, style: context.text.bodySmall?.copyWith(color: t.textSecondary)),
        ],
      ),
    );
  }
}

typedef _ActFn = Future<void> Function(Future<void> Function(CommsRepository r) call, {required String success, String? confirmTitle, String? confirmMessage, String? confirmLabel, bool destructive, bool leave});

class _Actions extends StatelessWidget {
  const _Actions({required this.a, required this.readOnly, required this.paths, required this.onAct, required this.onSchedule});
  final ManagedAnnouncement a;
  final bool readOnly;
  final AnnouncementPaths paths;
  final _ActFn onAct;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final audience = describeAudience(a.audience);
    final buttons = <Widget>[];

    Widget secondary(String label, IconData icon, VoidCallback? onTap) => SecondaryButton(label: label, icon: icon, onPressed: readOnly ? null : onTap);
    Widget danger(String label, IconData icon, VoidCallback onTap) => OutlinedButton.icon(
      onPressed: readOnly ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(foregroundColor: t.danger, side: BorderSide(color: t.danger.withValues(alpha: .5))),
    );

    if (a.isDraft || a.isScheduled) {
      buttons.add(PrimaryButton(
        label: 'Publish now',
        icon: Icons.send_rounded,
        onPressed: readOnly
            ? null
            : () => onAct((r) => r.publishAnnouncement(a.id), success: 'Published to $audience.', confirmTitle: 'Publish now?', confirmMessage: '"${a.title}" will be sent to $audience right away, and they will be notified. You will not be able to edit the message afterwards.', confirmLabel: 'Publish'),
      ));
      buttons.add(secondary('Edit', Icons.edit_outlined, () => context.push(paths.edit(a.id))));
      if (a.isScheduled) {
        buttons.add(secondary('Unschedule', Icons.event_busy_outlined, () => onAct((r) => r.unscheduleAnnouncement(a.id), success: 'Back to a draft.', confirmTitle: 'Unschedule?', confirmMessage: 'It will not be sent at the scheduled time. It stays as a draft.', confirmLabel: 'Unschedule')));
      }
      buttons.add(secondary(a.isScheduled ? 'Change time' : 'Schedule', Icons.schedule_send_outlined, onSchedule));
      buttons.add(danger('Delete draft', Icons.delete_outline_rounded, () => onAct((r) => r.deleteAnnouncement(a.id), success: 'The draft was deleted.', confirmTitle: 'Delete this draft?', confirmMessage: '"${a.title}" will be deleted. This cannot be undone.', confirmLabel: 'Delete', destructive: true, leave: true)));
    } else if (a.isPublished) {
      buttons.add(secondary('Change expiry', Icons.timer_outlined, () => context.push(paths.edit(a.id))));
      buttons.add(secondary('End now', Icons.timer_off_outlined, () => onAct((r) => r.expireAnnouncement(a.id), success: 'The announcement was ended.', confirmTitle: 'End this announcement now?', confirmMessage: 'It disappears from everyone\'s feed straight away. The history is kept.', confirmLabel: 'End now')));
      buttons.add(danger('Archive', Icons.inventory_2_outlined, () => onAct((r) => r.archiveAnnouncement(a.id), success: 'Archived.', confirmTitle: 'Archive this announcement?', confirmMessage: 'It is removed from feeds. The history and delivery numbers are kept.', confirmLabel: 'Archive', destructive: true)));
    } else if (a.state == 'expired') {
      buttons.add(danger('Archive', Icons.inventory_2_outlined, () => onAct((r) => r.archiveAnnouncement(a.id), success: 'Archived.', confirmTitle: 'Archive this announcement?', confirmMessage: 'The history and delivery numbers are kept.', confirmLabel: 'Archive', destructive: true)));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Actions',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final (i, b) in buttons.indexed) ...[if (i > 0) const SizedBox(height: Gaps.sm), b]]),
    );
  }
}

class _AudienceSize extends ConsumerWidget {
  const _AudienceSize(this.id);
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.watch(announcementStatsProvider(id)).value?.audienceSize;
    if (n == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: Text('It will reach ${plural(n, 'person', 'people')}.', style: context.text.bodyMedium?.copyWith(color: context.tokens.textSecondary)));
  }
}

class _Stats extends ConsumerWidget {
  const _Stats({required this.id, required this.requiresAck, required this.userType});
  final String id;
  final bool requiresAck;
  final String Function(String) userType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(announcementStatsProvider(id));
    return SectionCard(
      title: 'Who has seen it',
      child: stats.when(
        skipLoadingOnReload: true,
        loading: () => const Skeletonizer(child: Padding(padding: EdgeInsets.symmetric(vertical: Gaps.sm), child: Column(children: [Bone.text(words: 4), SizedBox(height: 8), Bone.text(words: 6)]))),
        error: (e, _) => ErrorState(error: e, compact: true, onRetry: () => ref.invalidate(announcementStatsProvider(id))),
        data: (s) {
          final pct = s.readPercent.round();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                container: true,
                label: 'Read by ${s.readCount} of ${s.audienceSize} people, $pct percent.${requiresAck ? ' Acknowledged by ${s.ackCount}.' : ''}',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('$pct%', style: figureStyle(context, size: 32)), const SizedBox(width: Gaps.sm), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${s.readCount} of ${s.audienceSize} have read it', style: context.text.bodyMedium)))]),
                      const SizedBox(height: Gaps.sm),
                      MeterBar(value: s.audienceSize == 0 ? 0 : s.readCount / s.audienceSize),
                    ],
                  ),
                ),
              ),
              if (requiresAck) ...[
                const SizedBox(height: Gaps.md),
                FactRow('Acknowledged', '${s.ackCount} of ${s.audienceSize}'),
                FactRow('Still to acknowledge', '${s.pendingAckCount}'),
              ],
              if (s.byUserType.isNotEmpty) ...[
                const SizedBox(height: Gaps.md),
                Text('By group', style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary)),
                const SizedBox(height: Gaps.xs),
                for (final r in s.byUserType) _Bar(label: userType(r.label), read: r.read, total: r.audience),
              ],
              if (s.bySection.isNotEmpty) ...[
                const SizedBox(height: Gaps.md),
                Text('By class', style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary)),
                const SizedBox(height: Gaps.xs),
                for (final r in s.bySection) _Bar(label: r.label, read: r.read, total: r.audience),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.read, required this.total});
  final String label;
  final int read;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Expanded(child: Text(label, style: context.text.bodyMedium)), Text('$read / $total', style: context.text.labelMedium?.copyWith(color: context.tokens.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))]),
        const SizedBox(height: 4),
        MeterBar(value: total == 0 ? 0 : read / total, semanticLabel: '$label: $read of $total read'),
      ],
    ),
  );
}
