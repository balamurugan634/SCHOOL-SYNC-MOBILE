import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/notifications.dart';

/// The notification inbox and preferences (shared by every role).
class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<CursorPage<AppNotification>> list({String? cursor, int limit = 30, bool unreadOnly = false, String? category}) async => CursorPage.parse(
    await _api.get('/notifications', query: {'limit': limit, 'cursor': ?cursor, if (unreadOnly) 'unread': true, 'category': ?category}),
    AppNotification.fromJson,
  );

  Future<int> unreadCount() async => jInt(jsonMap(await _api.get('/notifications/unread-count'))['unread']);

  Future<void> markRead(String id) async {
    await _api.post('/notifications/$id/read');
  }

  Future<void> markAllRead({String? category}) async {
    await _api.post('/notifications/read-all', data: {'category': ?category});
  }

  Future<void> delete(String id) async {
    await _api.delete('/notifications/$id');
  }

  Future<List<NotificationPref>> preferences() async => jsonList(jsonMap(await _api.get('/notifications/preferences'))['categories']).map(NotificationPref.fromJson).toList(growable: false);

  Future<void> savePreference(NotificationPref p) async {
    await _api.put('/notifications/preferences', data: {'preferences': [{'category': p.category, 'push': p.push, 'email': p.email}]});
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) => NotificationsRepository(ref.watch(apiClientProvider)));
