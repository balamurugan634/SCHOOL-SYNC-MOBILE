import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/leave.dart' show LeaveType;
import '../../models/staff/leave.dart';

/// Leave approvals (student + staff), my own staff leave, and my own check-in / check-out.
class StaffLeaveRepository {
  StaffLeaveRepository(this._api);
  final ApiClient _api;

  // ── student leave (class teachers decide for their sections; office for the school) ──
  Future<Paged<StudentLeaveItem>> studentLeave({String? status, String? sectionId, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/leave', query: {'page': page, 'pageSize': pageSize, 'status': ?status, 'sectionId': ?sectionId}),
    StudentLeaveItem.fromJson,
  );

  Future<void> decideStudentLeave(String id, {required bool approve, String? note}) async {
    await _api.post('/leave/$id/${approve ? 'approve' : 'reject'}', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }

  // ── staff leave ──
  Future<Paged<StaffLeaveItem>> staffLeave({String? status, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/staff-leave', query: {'page': page, 'pageSize': pageSize, 'status': ?status}),
    StaffLeaveItem.fromJson,
  );

  Future<StaffLeaveBalance> balance() async => StaffLeaveBalance.fromJson(jsonMap(await _api.get('/staff-leave/balance')));

  Future<void> applyStaffLeave({required LeaveType type, required DateTime from, required DateTime to, required String reason}) async {
    await _api.post('/staff-leave', data: {'leaveType': type.name, 'fromDate': isoDay(from), 'toDate': isoDay(to), 'reason': reason.trim()});
  }

  Future<void> cancelStaffLeave(String id) async {
    await _api.post('/staff-leave/$id/cancel');
  }

  Future<void> decideStaffLeave(String id, {required bool approve, String? note}) async {
    await _api.post('/staff-leave/$id/${approve ? 'approve' : 'reject'}', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }

  // ── my attendance ──
  Future<MyStaffAttendance> myAttendance() async => MyStaffAttendance.fromJson(jsonMap(await _api.get('/staff-attendance/me')));

  Future<void> checkIn() async {
    await _api.post('/staff-attendance/check-in');
  }

  Future<void> checkOut() async {
    await _api.post('/staff-attendance/check-out');
  }
}

final staffLeaveRepositoryProvider = Provider<StaffLeaveRepository>((ref) => StaffLeaveRepository(ref.watch(apiClientProvider)));
