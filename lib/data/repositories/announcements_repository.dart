import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/announcements.dart';

class AnnouncementsRepository {
  AnnouncementsRepository(this._api);
  final ApiClient _api;

  Future<Paged<Announcement>> list({int page = 1, int pageSize = 20, bool unreadOnly = false}) async => Paged.parse(
    await _api.get('/announcements', query: {'page': page, 'pageSize': pageSize, if (unreadOnly) 'unread': true}),
    Announcement.fromJson,
  );

  Future<Announcement> get(String id) async => Announcement.fromJson(jsonMap(await _api.get('/announcements/$id')));

  Future<AnnouncementCounts> counts() async => AnnouncementCounts.fromJson(jsonMap(await _api.get('/announcements/unread-count')));

  Future<void> markRead(String id) async {
    await _api.post('/announcements/$id/read');
  }

  Future<void> acknowledge(String id) async {
    await _api.post('/announcements/$id/ack');
  }
}

final announcementsRepositoryProvider = Provider<AnnouncementsRepository>((ref) => AnnouncementsRepository(ref.watch(apiClientProvider)));
