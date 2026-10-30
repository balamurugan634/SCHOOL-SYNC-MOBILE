import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/models/events.dart';
import '../../data/repositories/events_repository.dart';
import '../auth/session.dart';
import 'events_providers.dart';

/// One event: when, where, and (for events that ask) a registration / consent answer for each child.
class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(eventDetailProvider(id));
    final readOnly = ref.watch(sessionProvider.select((s) => s.siteInfo?.readOnly ?? false));
    return Scaffold(
      appBar: AppBar(title: const Text('Event')),
      body: AsyncBody<SchoolEvent>(
        value: v,
        onRetry: () => ref.invalidate(eventDetailProvider(id)),
        data: (e) {
          final t = context.tokens;
          final multi = e.endDate.isAfter(e.startDate);
          return RefreshScroll(
            onRefresh: () async => ref.invalidate(eventDetailProvider(id)),
            children: [
              Wrap(spacing: 6, children: [StatusChip(e.kindLabel, tone: e.kind == 'holiday' ? StatusTone.success : StatusTone.neutral), if (e.cancelled) const StatusChip('Cancelled', tone: StatusTone.danger)]),
              const SizedBox(height: Gaps.sm),
              Text(e.title, style: context.text.headlineMedium),
              const SizedBox(height: Gaps.lg),
              AppCard(
                child: Column(children: [
                  FactRow('When', multi ? '${fmtDay(e.startDate)} to ${fmtDay(e.endDate)}' : fmtDayLong(e.startDate)),
                  if (!e.allDay && e.startTime != null) FactRow('Time', formatTimeRange(e.startTime, e.endTime)),
                  if (e.location != null) FactRow('Where', e.location!),
                  if (e.registrationDeadline != null) FactRow('Reply by', fmtDateTime(e.registrationDeadline!)),
                ]),
              ),
              if (e.onlineMeeting != null) ...[const SizedBox(height: Gaps.lg), OnlineMeetingCard(meeting: e.onlineMeeting!)],
              if (e.description != null && e.description!.trim().isNotEmpty) ...[const SizedBox(height: Gaps.lg), Text(e.description!, style: context.text.bodyLarge)],
              if ((e.registrationRequired || e.consentRequired) && e.children.isNotEmpty) ...[
                GroupLabel(e.consentRequired ? 'Permission' : 'Registration'),
                if (e.consentRequired && e.consentText != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: AppCard(tone: CardTone.subtle, child: Text(e.consentText!, style: context.text.bodyMedium))),
                for (final c in e.children) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: _ChildResponse(event: e, child: c, enabled: e.responseOpen && !readOnly && !e.cancelled)),
                if (!e.responseOpen) Text('Replies are closed for this event.', style: context.text.bodySmall?.copyWith(color: t.textSecondary)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ChildResponse extends ConsumerStatefulWidget {
  const _ChildResponse({required this.event, required this.child, required this.enabled});
  final SchoolEvent event;
  final EventChildResponse child;
  final bool enabled;

  @override
  ConsumerState<_ChildResponse> createState() => _ChildResponseState();
}

class _ChildResponseState extends ConsumerState<_ChildResponse> {
  bool _busy = false;

  Future<void> _send(String response) async {
    setState(() => _busy = true);
    try {
      await ref.read(eventsRepositoryProvider).respond(widget.event.id, studentId: widget.child.studentId, response: response);
      ref.invalidate(eventDetailProvider(widget.event.id));
      ref.invalidate(eventsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your reply was saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final consent = widget.event.consentRequired;
    final r = widget.child.response;
    final yes = consent ? 'consent_given' : 'going';
    final no = consent ? 'consent_denied' : 'not_going';
    String label(String? v) => switch (v) { 'going' => 'Going', 'not_going' => 'Not going', 'consent_given' => 'Permission given', 'consent_denied' => 'Permission declined', _ => 'Not answered yet' };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(widget.child.studentName, style: context.text.titleSmall)),
            StatusChip(label(r), tone: r == yes ? StatusTone.success : (r == no ? StatusTone.danger : StatusTone.warning)),
          ]),
          if (widget.enabled) ...[
            const SizedBox(height: Gaps.md),
            Row(children: [
              Expanded(child: r == yes ? PrimaryButton(label: consent ? 'Permission given' : 'Going', icon: Icons.check_rounded, onPressed: null) : (_busy ? const Center(child: CircularProgressIndicator(strokeWidth: 2.2)) : PrimaryButton(label: consent ? 'Give permission' : 'Going', onPressed: () => _send(yes)))),
              const SizedBox(width: Gaps.sm),
              Expanded(child: SecondaryButton(label: consent ? 'Decline' : 'Not going', onPressed: _busy || r == no ? null : () => _send(no))),
            ]),
          ] else if (r == null) Padding(padding: const EdgeInsets.only(top: Gaps.sm), child: Text('Replies are closed.', style: context.text.bodySmall?.copyWith(color: t.textTertiary))),
        ],
      ),
    );
  }
}
