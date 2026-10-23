import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/leave.dart';

class LeaveRepository {
  LeaveRepository(this._api);
  final ApiClient _api;

  Future<Paged<LeaveRequest>> list({String? studentId, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/leave', query: {'page': page, 'pageSize': pageSize, 'studentId': ?studentId}),
    LeaveRequest.fromJson,
  );

  Future<LeaveRequest> apply({String? studentId, required LeaveType type, required DateTime from, required DateTime to, required String reason, String? attachmentFileId}) async => LeaveRequest.fromJson(
    jsonMap(await _api.post('/leave', data: {'studentId': ?studentId, 'leaveType': type.name, 'fromDate': isoDay(from), 'toDate': isoDay(to), 'reason': reason.trim(), 'attachmentFileId': ?attachmentFileId})),
  );

  Future<LeaveRequest> cancel(String id) async => LeaveRequest.fromJson(jsonMap(await _api.post('/leave/$id/cancel')));
}

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) => LeaveRepository(ref.watch(apiClientProvider)));
