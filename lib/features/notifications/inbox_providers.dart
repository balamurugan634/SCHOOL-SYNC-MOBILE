import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/notifications.dart';
import '../../data/repositories/notifications_repository.dart';

class InboxNotifier extends CursorNotifier<AppNotification, bool> {
  InboxNotifier(super.arg);

  @override
  Future<CursorPage<AppNotification>> fetch(String? cursor) => ref.read(notificationsRepositoryProvider).list(cursor: cursor, unreadOnly: arg);
}

/// The inbox. Key: `true` = unread only.
final inboxProvider = AsyncNotifierProvider.family<InboxNotifier, CursorList<AppNotification>, bool>(InboxNotifier.new);

final notificationPrefsProvider = FutureProvider<List<NotificationPref>>((ref) => ref.watch(notificationsRepositoryProvider).preferences());
