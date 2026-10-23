import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/staff/teaching.dart';

/// Homework as a teacher manages it: create, edit, publish, close, roster, review submissions.
/// (Learner-side homework lives in `HomeworkRepository`.)
class StaffHomeworkRepository {
  StaffHomeworkRepository(this._api);
  final ApiClient _api;

  /// [status] draft | published | closed. [mine] = only homework I created.
  Future<Paged<HomeworkEntry>> list({String? status, String? sectionId, String? subjectId, bool mine = true, String? q, String sort = 'dueDesc', int page = 1, int pageSize = 25}) async => Paged.parse(
    await _api.get('/homework', query: {'page': page, 'pageSize': pageSize, 'sort': sort, if (mine) 'mine': true, 'status': ?status, 'sectionId': ?sectionId, 'subjectId': ?subjectId, if (q != null && q.trim().isNotEmpty) 'q': q.trim()}),
    HomeworkEntry.fromJson,
  );

  Future<HomeworkEntry> get(String id) async => HomeworkEntry.fromJson(jsonMap(await _api.get('/homework/$id')));

  Future<HomeworkEntry> create(HomeworkDraft d, {required bool publish}) async => HomeworkEntry.fromJson(jsonMap(await _api.post('/homework', data: d.toCreateJson(publish: publish))));

  Future<HomeworkEntry> update(String id, HomeworkDraft d) async => HomeworkEntry.fromJson(jsonMap(await _api.patch('/homework/$id', data: d.toUpdateJson())));

  Future<void> publish(String id) async {
    await _api.post('/homework/$id/publish');
  }

  Future<void> close(String id) async {
    await _api.post('/homework/$id/close');
  }

  /// Only homework without submissions can be deleted (otherwise close it).
  Future<void> delete(String id) async {
    await _api.delete('/homework/$id');
  }

  Future<HomeworkRoster> roster(String id) async => HomeworkRoster.fromJson(jsonMap(await _api.get('/homework/$id/roster')));

  Future<Paged<SubmissionEntry>> submissions({String? homeworkId, String? status, int page = 1, int pageSize = 50}) async => Paged.parse(
    await _api.get('/submissions', query: {'page': page, 'pageSize': pageSize, 'homeworkId': ?homeworkId, 'status': ?status}),
    SubmissionEntry.fromJson,
  );

  Future<SubmissionEntry> submission(String id) async => SubmissionEntry.fromJson(jsonMap(await _api.get('/submissions/$id')));

  /// Marks (<= the homework's maximum) and/or feedback; the submission becomes reviewed.
  Future<void> review(String id, {double? marks, String? feedback}) async {
    await _api.post('/submissions/$id/review', data: {'marks': ?marks, if (feedback != null && feedback.trim().isNotEmpty) 'feedback': feedback.trim()});
  }

  /// Sends it back for rework; feedback is required.
  Future<void> returnForRework(String id, {required String feedback}) async {
    await _api.post('/submissions/$id/return', data: {'feedback': feedback.trim()});
  }
}

final staffHomeworkRepositoryProvider = Provider<StaffHomeworkRepository>((ref) => StaffHomeworkRepository(ref.watch(apiClientProvider)));
