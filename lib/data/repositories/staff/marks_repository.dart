import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/staff/marks.dart';

/// Mark sheets: entry for subject teachers, review for approvers.
class MarksRepository {
  MarksRepository(this._api);
  final ApiClient _api;

  /// [mine] = only sheets I am the subject teacher of. [status] draft | submitted | approved | published | returned.
  Future<Paged<MarkSheet>> sheets({bool mine = false, String? status, String? examId, int page = 1, int pageSize = 50}) async => Paged.parse(
    await _api.get('/marks/sheets', query: {'page': page, 'pageSize': pageSize, if (mine) 'mine': true, 'status': ?status, 'examId': ?examId}),
    MarkSheet.fromJson,
  );

  Future<MarkSheetDetail> sheet(String id) async => MarkSheetDetail.fromJson(jsonMap(await _api.get('/marks/sheets/$id')));

  /// Saves a draft (bulk upsert). The sheet must be draft or returned.
  Future<void> saveEntries(String id, List<MarkInput> entries) async {
    await _api.put('/marks/sheets/$id/entries', data: {'entries': [for (final e in entries) e.toJson()]});
  }

  /// Submit for review: every student needs marks or an absent flag.
  Future<void> submit(String id) async {
    await _api.post('/marks/sheets/$id/submit');
  }

  Future<void> approve(String id, {String? note}) async {
    await _api.post('/marks/sheets/$id/approve', data: {if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }

  /// Back to the teacher with a note (3+ characters).
  Future<void> returnSheet(String id, {required String note}) async {
    await _api.post('/marks/sheets/$id/return', data: {'note': note.trim()});
  }
}

final marksRepositoryProvider = Provider<MarksRepository>((ref) => MarksRepository(ref.watch(apiClientProvider)));
