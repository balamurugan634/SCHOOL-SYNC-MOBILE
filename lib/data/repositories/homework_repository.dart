import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/app_exception.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/homework.dart';

class HomeworkRepository {
  HomeworkRepository(this._api);
  final ApiClient _api;

  Future<Paged<Homework>> list({String? studentId, String? learnerStatus, int page = 1, int pageSize = 20, String sort = 'dueAsc'}) async => Paged.parse(
    await _api.get('/homework', query: {'page': page, 'pageSize': pageSize, 'sort': sort, 'status': 'published', 'studentId': ?studentId, 'learnerStatus': ?learnerStatus}),
    Homework.fromJson,
  );

  Future<Homework> get(String id, {String? studentId}) async => Homework.fromJson(jsonMap(await _api.get('/homework/$id', query: {'studentId': ?studentId})));

  /// The learner's submission, or null when nothing was submitted yet (404 `NOT_SUBMITTED`).
  Future<Submission?> submission(String homeworkId, {String? studentId}) async {
    try {
      return Submission.fromJson(jsonMap(await _api.get('/homework/$homeworkId/submission', query: {'studentId': ?studentId})));
    } on AppException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<Submission> submit(String homeworkId, {String? text, List<Attachment> attachments = const []}) async => Submission.fromJson(
    jsonMap(await _api.post('/homework/$homeworkId/submit', data: {'text': (text == null || text.trim().isEmpty) ? null : text.trim(), 'attachments': [for (final a in attachments) a.toJson()]})),
  );
}

final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) => HomeworkRepository(ref.watch(apiClientProvider)));
