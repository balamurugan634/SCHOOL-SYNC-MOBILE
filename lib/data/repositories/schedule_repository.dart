import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/schedule.dart';

/// Timetable and calendar. For a parent pass the child's `studentId`; students pass null.
class ScheduleRepository {
  ScheduleRepository(this._api);
  final ApiClient _api;

  Future<TimetableDay> timetable({DateTime? date, String? studentId}) async => TimetableDay.fromJson(
    jsonMap(await _api.get('/timetable/me', query: {if (date != null) 'date': isoDay(date), 'studentId': ?studentId})),
  );

  Future<List<CalendarItem>> calendar({required DateTime from, required DateTime to, String? studentId}) async {
    final body = jsonMap(await _api.get('/calendar', query: {'from': isoDay(from), 'to': isoDay(to), 'studentId': ?studentId}));
    final items = jsonList(body['data']).map(CalendarItem.fromJson).toList();
    items.sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : (a.startTime ?? '').compareTo(b.startTime ?? '');
    });
    return items;
  }
}

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) => ScheduleRepository(ref.watch(apiClientProvider)));
