import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/learner_dashboard.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../auth/session.dart';
import '../home/child_selector.dart';

/// Student home data (`GET /dashboard/student`), with an offline fallback to the last saved copy.
final studentDashboardProvider = FutureProvider<StudentDashboard>((ref) async {
  final userId = ref.watch(sessionProvider.select((s) => s.me?.id));
  if (userId == null) throw StateError('not signed in');
  return ref.watch(dashboardRepositoryProvider).student(userId);
});

/// Parent home data for the selected child (`GET /dashboard/parent?studentId=`).
final parentDashboardProvider = FutureProvider<ParentDashboard>((ref) async {
  final userId = ref.watch(sessionProvider.select((s) => s.me?.id));
  if (userId == null) throw StateError('not signed in');
  final child = ref.watch(selectedChildIdProvider);
  return ref.watch(dashboardRepositoryProvider).parent(userId, studentId: child);
});
