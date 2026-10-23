import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/me.dart';
import '../auth/session.dart';
import '../home/child_selector.dart';

/// Whose data a learner-facing screen shows.
///
/// A **student** sees themselves (the API infers the student, so no `studentId` is sent). A **parent** sees
/// the selected child and every request carries `studentId=<child>`. All student/parent features read these
/// two providers, so switching the child refreshes every screen.
final isParentProvider = Provider<bool>((ref) => ref.watch(sessionProvider.select((s) => s.me?.experience == Experience.parent)));

/// The student whose data is shown (own id for students, selected child for parents), or null.
final learnerStudentIdProvider = Provider<String?>((ref) {
  final parent = ref.watch(isParentProvider);
  if (parent) return ref.watch(selectedChildIdProvider);
  return ref.watch(sessionProvider.select((s) => s.me?.profile.studentId));
});

/// The `studentId` query parameter to send: the child for parents, nothing for students.
final learnerQueryIdProvider = Provider<String?>((ref) => ref.watch(isParentProvider) ? ref.watch(selectedChildIdProvider) : null);

final learnerNameProvider = Provider<String?>((ref) {
  final parent = ref.watch(isParentProvider);
  if (parent) return ref.watch(selectedChildProvider)?.name;
  return ref.watch(sessionProvider.select((s) => s.me?.displayName));
});
