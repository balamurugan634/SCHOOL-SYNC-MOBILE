import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/attendance.dart';
import '../../models/staff/roll_call.dart';

/// Roll call, attendance corrections and school-wide attendance (staff side).
/// A student's own summary/records live in `AttendanceRepository` (learner side) and are reused for the student profile.
class RollCallRepository {
  RollCallRepository(this._api);
  final ApiClient _api;

  /// Sections (or period slots) I take attendance for today, marked or not (`GET /attendance/today`).
  Future<AttendanceToday> today() async => AttendanceToday.fromJson(jsonMap(await _api.get('/attendance/today')));

  Future<Roster> roster(String sectionId, {DateTime? date, String? periodId}) async => Roster.fromJson(
    jsonMap(await _api.get('/attendance/sections/$sectionId', query: {if (date != null) 'date': isoDay(date), 'periodId': ?periodId})),
  );

  /// Idempotent upsert of the whole roll call. Every student must be listed (or [defaultStatus] set).
  Future<SubmitResult> submit(String sectionId, {required List<RollEntry> entries, DateTime? date, String? periodId}) async => SubmitResult.fromJson(
    jsonMap(await _api.put('/attendance/sections/$sectionId', data: {if (date != null) 'date': isoDay(date), 'periodId': ?periodId, 'records': [for (final e in entries) e.toJson()]})),
  );

  /// After the edit window: ask for one record to be changed.
  Future<void> requestCorrection(String recordId, {required AttendanceStatus to, required String reason}) async {
    await _api.post('/attendance/records/$recordId/corrections', data: {'toStatus': to.apiValue, 'reason': reason.trim()});
  }

  /// [status] pending (default) | approved | rejected. [mine] narrows to requests I raised.
  Future<Paged<CorrectionItem>> corrections({String? status, String? sectionId, bool mine = false, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/attendance/corrections', query: {'page': page, 'pageSize': pageSize, 'status': ?status, 'sectionId': ?sectionId, if (mine) 'mine': true}),
    CorrectionItem.fromJson,
  );

  Future<void> decideCorrection(String id, {required bool approve, String? note}) async {
    await _api.post('/attendance/corrections/$id/${approve ? 'approve' : 'reject'}', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }

  Future<SectionAttendanceSummary> sectionSummary(String sectionId, {DateTime? from, DateTime? to}) async => SectionAttendanceSummary.fromJson(
    jsonMap(await _api.get('/attendance/sections/$sectionId/summary', query: {if (from != null) 'from': isoDay(from), if (to != null) 'to': isoDay(to)})),
  );

  /// School-wide day summary (management): per-section table, absentees, trend.
  Future<SchoolAttendance> schoolSummary({DateTime? date, int trendDays = 7, int absenteeLimit = 100}) async => SchoolAttendance.fromJson(
    jsonMap(await _api.get('/attendance/summary', query: {if (date != null) 'date': isoDay(date), 'trendDays': trendDays, 'absenteeLimit': absenteeLimit})),
  );
}

final rollCallRepositoryProvider = Provider<RollCallRepository>((ref) => RollCallRepository(ref.watch(apiClientProvider)));
