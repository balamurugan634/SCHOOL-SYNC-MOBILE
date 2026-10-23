import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/paged.dart';
import '../../data/models/announcements.dart';
import '../dashboard/dashboard_widgets.dart';
import '../learner/screen_frame.dart';
import 'announcements_providers.dart';

/// Notices from the school: newest first, filter to unread.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  bool _unread = false;

  @override
  Widget build(BuildContext context) {
    final provider = announcementsProvider(_unread);
    final v = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Announcements',
      showChild: false,
      body: Column(
        children: [
          FilterChips<bool>(options: const [false, true], selected: _unread, onSelected: (x) => setState(() => _unread = x), labelOf: (x) => x ? 'Unread' : 'All'),
          const SizedBox(height: Gaps.sm),
          Expanded(
            child: AsyncBody<PagedList<Announcement>>(
              value: v,
              onRetry: refresh,
              isEmpty: (p) => p.items.isEmpty,
              empty: EmptyState(illo: _unread ? Illo.noResults : Illo.emptyNotifications, title: _unread ? 'Nothing unread' : 'No announcements', message: _unread ? 'You have read everything.' : 'Notices from your school will appear here.'),
              data: (p) => RefreshScroll(
                onRefresh: refresh,
                children: [
                  RowGroup(children: [for (final a in p.items) AnnouncementRow(a)]),
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
