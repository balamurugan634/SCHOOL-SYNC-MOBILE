import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/attendance.dart';

class AttendanceRepository {
  AttendanceRepository(this._api);
  final ApiClient _api;

  Future<AttendanceSummary> summary(String studentId, {DateTime? from, DateTime? to}) async => AttendanceSummary.fromJson(
    jsonMap(await _api.get('/attendance/students/$studentId/summary', query: {if (from != null) 'from': isoDay(from), if (to != null) 'to': isoDay(to)})),
  );

  Future<CursorPage<AttendanceRecord>> records(String studentId, {String? cursor, int limit = 30, AttendanceStatus? status, DateTime? from, DateTime? to}) async => CursorPage.parse(
    await _api.get('/attendance/students/$studentId/records', query: {
      'limit': limit,
      'cursor': ?cursor,
      if (status != null) 'status': status.apiValue,
      if (from != null) 'from': isoDay(from),
      if (to != null) 'to': isoDay(to),
    }),
    AttendanceRecord.fromJson,
  );
}

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) => AttendanceRepository(ref.watch(apiClientProvider)));
