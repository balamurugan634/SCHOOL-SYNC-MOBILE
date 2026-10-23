import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notifications_repository.dart';
import '../auth/session.dart';

/// Unread notifications (for the bell badge). Invalidate after reading/deleting.
final notificationsUnreadProvider = FutureProvider<int>((ref) async {
  if (!ref.watch(sessionProvider.select((s) => s.signedIn))) return 0;
  try {
    return await ref.watch(notificationsRepositoryProvider).unreadCount();
  } catch (_) {
    return 0;
  }
});

/// Maps a server `data.route` (web paths) to an in-app path, or null when this app has no such screen.
String? mapServerRoute(String? route) {
  if (route == null || route.isEmpty || !route.startsWith('/')) return null;
  final path = Uri.tryParse(route)?.path ?? route;
  const prefixes = ['/homework', '/announcements', '/events', '/results', '/fees', '/attendance', '/leave', '/meetings', '/calendar', '/timetable', '/materials', '/tasks', '/notifications'];
  for (final p in prefixes) {
    if (path == p || path.startsWith('$p/')) return path == '/tasks' ? '/tab/1' : path;
  }
  return null;
}
