import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/staff/dashboards.dart';
import '../../../data/repositories/staff/staff_dashboard_repository.dart';
import '../../workspace/staff_context.dart';

/// `GET /dashboard/teacher`, with the last good copy served when offline ([Loaded.fromCache]).
final teacherDashboardProvider = FutureProvider.autoDispose<Loaded<TeacherDashboard>>((ref) {
  final userId = ref.watch(staffMeProvider.select((m) => m?.id));
  if (userId == null) throw StateError('Not signed in');
  return ref.watch(staffDashboardRepositoryProvider).teacher(userId);
});
