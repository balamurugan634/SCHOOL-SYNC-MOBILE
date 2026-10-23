import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/meetings.dart';

/// Parent-teacher meetings (parents request; staff answer in the web/teacher app).
class MeetingsRepository {
  MeetingsRepository(this._api);
  final ApiClient _api;

  Future<Paged<Meeting>> list({String? studentId, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/meetings', query: {'page': page, 'pageSize': pageSize, 'studentId': ?studentId}),
    Meeting.fromJson,
  );

  Future<List<MeetingTeacher>> teachers(String studentId) async {
    final body = jsonMap(await _api.get('/meetings/teachers', query: {'studentId': studentId}));
    return jsonList(body['data']).map(MeetingTeacher.fromJson).toList(growable: false);
  }

  Future<Meeting> request({required String studentId, required String staffId, required String topic, DateTime? proposedAt}) async => Meeting.fromJson(
    jsonMap(await _api.post('/meetings', data: {'studentId': studentId, 'staffId': staffId, 'topic': topic.trim(), if (proposedAt != null) 'proposedAt': proposedAt.toUtc().toIso8601String()})),
  );

  Future<Meeting> cancel(String id, {String? reason}) async => Meeting.fromJson(jsonMap(await _api.post('/meetings/$id/cancel', data: {if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim()})));
}

final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) => MeetingsRepository(ref.watch(apiClientProvider)));
