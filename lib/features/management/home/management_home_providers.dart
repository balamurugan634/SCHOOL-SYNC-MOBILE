import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/staff/dashboards.dart';
import '../../../data/repositories/staff/staff_dashboard_repository.dart';
import '../../workspace/staff_context.dart';

/// `GET /dashboard/management`, with the last good copy served when offline ([Loaded.fromCache]).
/// Invalidate it after any decision (approvals) so Home, the hub and the More badge stay in step.
final managementDashboardProvider = FutureProvider.autoDispose<Loaded<ManagementDashboard>>((ref) {
  final userId = ref.watch(staffMeProvider.select((m) => m?.id));
  if (userId == null) throw StateError('Not signed in');
  return ref.watch(staffDashboardRepositoryProvider).management(userId);
});
