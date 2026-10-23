import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/announcements.dart';
import '../../data/repositories/announcements_repository.dart';

class AnnouncementsNotifier extends PagedNotifier<Announcement, bool> {
  AnnouncementsNotifier(super.arg);

  @override
  Future<Paged<Announcement>> fetch(int page) => ref.read(announcementsRepositoryProvider).list(page: page, unreadOnly: arg);

  /// Reflects a read/ack locally so the list updates without a refetch.
  void mark(String id, {bool? read, bool? acknowledged}) {
    final cur = state.value;
    if (cur == null) return;
    state = AsyncData(cur.copyWith(items: [for (final a in cur.items) a.id == id ? a.copyWith(read: read, acknowledged: acknowledged) : a]));
  }
}

/// Key: `true` = unread only.
final announcementsProvider = AsyncNotifierProvider.family<AnnouncementsNotifier, PagedList<Announcement>, bool>(AnnouncementsNotifier.new);

final announcementDetailProvider = FutureProvider.family<Announcement, String>((ref, id) => ref.watch(announcementsRepositoryProvider).get(id));
