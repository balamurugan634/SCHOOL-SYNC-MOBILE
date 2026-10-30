import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/paged.dart';
import '../../core/util/format.dart';
import '../../data/models/events.dart';
import '../../router/routes_shared.dart';
import '../learner/screen_frame.dart';
import 'events_providers.dart';

/// School events and holidays. Events that need a reply (registration or consent) are flagged.
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  bool _upcoming = true;

  @override
  Widget build(BuildContext context) {
    final provider = eventsProvider(_upcoming);
    final v = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Events',
      showChild: false,
      body: Column(
        children: [
          FilterChips<bool>(options: const [true, false], selected: _upcoming, onSelected: (x) => setState(() => _upcoming = x), labelOf: (x) => x ? 'Upcoming' : 'Past'),
          const SizedBox(height: Gaps.sm),
          Expanded(
            child: AsyncBody<PagedList<SchoolEvent>>(
              value: v,
              onRetry: refresh,
              isEmpty: (p) => p.items.isEmpty,
              empty: EmptyState(illo: Illo.emptyEvents, title: _upcoming ? 'No upcoming events' : 'No past events', message: _upcoming ? 'Events and holidays will appear here when the school adds them.' : null),
              data: (p) => RefreshScroll(
                onRefresh: refresh,
                children: [
                  RowGroup(children: [for (final e in p.items) EventRow(e)]),
                  LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EventRow extends StatelessWidget {
  const EventRow(this.e, {super.key});
  final SchoolEvent e;

  @override
  Widget build(BuildContext context) {
    final multi = e.endDate.isAfter(e.startDate);
    return ListRow(
      title: e.title,
      subtitle: [multi ? '${fmtShort(e.startDate)} to ${fmtShort(e.endDate)}' : fmtDay(e.startDate), if (!e.allDay && e.startTime != null) formatTimeRange(e.startTime, e.endTime), if (e.location != null) e.location!].join('  ·  '),
      onTap: () => context.push(SharedRoutes.eventDetail(e.id)),
      chevron: false,
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (e.cancelled) const StatusChip('Cancelled', tone: StatusTone.danger) else StatusChip(e.kindLabel, tone: e.kind == 'holiday' ? StatusTone.success : StatusTone.neutral),
          if (e.needsResponse) const Padding(padding: EdgeInsets.only(top: 4), child: StatusChip('Reply needed', tone: StatusTone.accent)),
          if (e.onlineMeeting?.isScheduled ?? false) const Padding(padding: EdgeInsets.only(top: 4), child: OnlineChip()),
        ],
      ),
    );
  }
}
