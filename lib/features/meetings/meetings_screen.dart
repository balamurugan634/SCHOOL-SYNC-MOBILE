import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/paged.dart';
import '../../core/util/format.dart';
import '../../data/models/meetings.dart';
import '../../data/repositories/meetings_repository.dart';
import '../../router/routes_shared.dart';
import '../auth/session.dart';
import '../dashboard/dashboard_providers.dart';
import 'meetings_providers.dart';

/// Parent-teacher meetings: requests, confirmed times and history, with cancel.
class MeetingsScreen extends ConsumerWidget {
  const MeetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = meetingsProvider(null);
    final v = ref.watch(provider);
    final readOnly = ref.watch(sessionProvider.select((s) => s.siteInfo?.readOnly ?? false));
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Meetings')),
      floatingActionButton: readOnly ? null : FloatingActionButton.extended(onPressed: () => context.push(SharedRoutes.meetingNew), icon: const Icon(Icons.add_rounded), label: const Text('Request a meeting')),
      body: AsyncBody<PagedList<Meeting>>(
        value: v,
        onRetry: refresh,
        isEmpty: (p) => p.items.isEmpty,
        empty: EmptyState(illo: Illo.emptyEvents, title: 'No meetings yet', message: 'Ask a teacher for a meeting about your child.', actionLabel: readOnly ? null : 'Request a meeting', onAction: () => context.push(SharedRoutes.meetingNew)),
        data: (p) {
          final open = p.items.where((m) => m.open).toList();
          final past = p.items.where((m) => !m.open).toList();
          return RefreshScroll(
            onRefresh: refresh,
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 96),
            children: [
              if (open.isNotEmpty) ...[const GroupLabel('Upcoming and requested'), for (final m in open) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: _MeetingCard(m))],
              if (past.isNotEmpty) ...[const GroupLabel('Earlier'), for (final m in past) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: _MeetingCard(m))],
              LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
            ],
          );
        },
      ),
    );
  }
}

class _MeetingCard extends ConsumerStatefulWidget {
  const _MeetingCard(this.m);
  final Meeting m;

  @override
  ConsumerState<_MeetingCard> createState() => _MeetingCardState();
}

class _MeetingCardState extends ConsumerState<_MeetingCard> {
  bool _busy = false;

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this meeting?'),
        content: Text('The request about "${widget.m.topic}" with ${widget.m.teacherName} will be cancelled and the teacher will be told.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')), FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(minimumSize: const Size(110, 44)), child: const Text('Cancel meeting'))],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(meetingsRepositoryProvider).cancel(widget.m.id);
      ref.invalidate(meetingsProvider);
      ref.invalidate(parentDashboardProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.m;
    final t = context.tokens;
    final tone = switch (m.status) { 'confirmed' => StatusTone.success, 'requested' => StatusTone.warning, 'declined' || 'cancelled' => StatusTone.danger, _ => StatusTone.neutral };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(m.topic, style: context.text.titleMedium)), StatusChip('${m.status[0].toUpperCase()}${m.status.substring(1)}', tone: tone)]),
          const SizedBox(height: Gaps.sm),
          FactRow('Teacher', '${m.teacherName}${m.teacherDesignation == null ? '' : ' (${m.teacherDesignation})'}'),
          FactRow('About', m.studentName),
          if (m.when != null) FactRow(m.scheduledAt != null ? 'When' : 'Proposed', fmtDateTime(m.when!)),
          if (m.scheduledAt != null) FactRow('Duration', '${m.durationMin} minutes'),
          if (m.scheduledAt != null) FactRow('How', m.modeLabel),
          if (m.locationOrLink != null) FactRow('Where', m.locationOrLink!),
          if (m.outcomeNotes != null) ...[const SizedBox(height: Gaps.sm), Text('Notes', style: context.text.labelMedium?.copyWith(color: t.textSecondary)), Text(m.outcomeNotes!, style: context.text.bodyMedium)],
          if (m.canCancel) Padding(padding: const EdgeInsets.only(top: Gaps.md), child: SecondaryButton(label: _busy ? 'Cancelling' : 'Cancel meeting', onPressed: _busy ? null : _cancel)),
        ],
      ),
    );
  }
}
