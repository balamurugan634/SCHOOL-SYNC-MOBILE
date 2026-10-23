import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/schedule.dart';
import '../../data/repositories/schedule_repository.dart';
import '../learner/learner_context.dart';

/// Calendar items for a whole month: the key is the first day of that month.
final calendarMonthProvider = FutureProvider.family<List<CalendarItem>, DateTime>((ref, monthStart) async {
  final studentId = ref.watch(learnerQueryIdProvider);
  final from = DateTime(monthStart.year, monthStart.month, 1);
  final to = DateTime(monthStart.year, monthStart.month + 1, 0);
  return ref.watch(scheduleRepositoryProvider).calendar(from: from, to: to, studentId: studentId);
});

/// The timetable of one day (the key is a date without time).
final timetableDayProvider = FutureProvider.family<TimetableDay, DateTime>((ref, date) async {
  final studentId = ref.watch(learnerQueryIdProvider);
  return ref.watch(scheduleRepositoryProvider).timetable(date: date, studentId: studentId);
});
