import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/paged.dart';
import '../../core/util/format.dart';
import '../../data/models/notifications.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../router/routes_shared.dart';
import 'inbox_providers.dart';
import 'notifications_providers.dart';

/// The notification inbox (every role). Tap to open what it is about; swipe or use the menu to delete.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unread = false;

  Future<void> _open(AppNotification n) async {
    final repo = ref.read(notificationsRepositoryProvider);
    if (!n.read) {
      ref.read(inboxProvider(_unread).notifier).edit((l) => [for (final x in l) x.id == n.id ? x.asRead() : x]);
      try {
        await repo.markRead(n.id);
      } catch (_) {}
      ref.invalidate(notificationsUnreadProvider);
    }
    final target = mapServerRoute(n.route);
    if (target != null && mounted) unawaited(context.push(target));
  }

  Future<void> _markAll() async {
    try {
      await ref.read(notificationsRepositoryProvider).markAllRead();
      ref.invalidate(inboxProvider);
      ref.invalidate(notificationsUnreadProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    }
  }

  Future<void> _delete(AppNotification n) async {
    ref.read(inboxProvider(_unread).notifier).edit((l) => l.where((x) => x.id != n.id).toList());
    try {
      await ref.read(notificationsRepositoryProvider).delete(n.id);
      ref.invalidate(notificationsUnreadProvider);
    } catch (e) {
      ref.invalidate(inboxProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = inboxProvider(_unread);
    final v = ref.watch(provider);
    final t = context.tokens;
    Future<void> refresh() async {
      ref.invalidate(provider);
      ref.invalidate(notificationsUnreadProvider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(tooltip: 'Mark all as read', onPressed: _markAll, icon: const Icon(Icons.done_all_rounded)),
          IconButton(tooltip: 'Notification settings', onPressed: () => context.push(SharedRoutes.notificationSettings), icon: const Icon(Icons.tune_rounded)),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: Gaps.sm),
          FilterChips<bool>(options: const [false, true], selected: _unread, onSelected: (x) => setState(() => _unread = x), labelOf: (x) => x ? 'Unread' : 'All'),
          const SizedBox(height: Gaps.sm),
          Expanded(
            child: AsyncBody<CursorList<AppNotification>>(
              value: v,
              onRetry: refresh,
              isEmpty: (l) => l.items.isEmpty,
              empty: EmptyState(illo: Illo.emptyNotifications, title: _unread ? 'Nothing unread' : 'No notifications yet', message: _unread ? 'You are all caught up.' : 'Attendance, homework, results, fee and school notices will show up here.'),
              data: (l) => RefreshScroll(
                onRefresh: refresh,
                children: [
                  RowGroup(
                    children: [
                      for (final n in l.items)
                        Dismissible(
                          key: ValueKey(n.id),
                          direction: DismissDirection.endToStart,
                          background: Container(color: t.dangerTint, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: Gaps.xl), child: Icon(Icons.delete_outline_rounded, color: t.danger)),
                          onDismissed: (_) => _delete(n),
                          child: ListRow(
                            title: n.title,
                            subtitle: '${n.body}${n.createdAt == null ? '' : '\n${relativeDay(n.createdAt!)}, ${fmtTime(n.createdAt!)}'}',
                            leading: _icon(n.category),
                            onTap: () => _open(n),
                            chevron: false,
                            trailing: n.read ? null : Container(width: 8, height: 8, decoration: BoxDecoration(color: t.brand.solid, shape: BoxShape.circle)),
                          ),
                        ),
                    ],
                  ),
                  CursorFooter(list: l, onMore: () => ref.read(provider.notifier).loadMore()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _icon(String c) => switch (c) {
    'attendance' => Icons.fact_check_outlined,
    'homework' => Icons.assignment_outlined,
    'marks' => Icons.workspace_premium_outlined,
    'fees' => Icons.account_balance_wallet_outlined,
    'announcement' => Icons.campaign_outlined,
    'event' => Icons.event_outlined,
    'meeting' => Icons.handshake_outlined,
    'leave' => Icons.event_busy_outlined,
    'tasks' => Icons.checklist_rounded,
    _ => Icons.notifications_none_rounded,
  };
}
