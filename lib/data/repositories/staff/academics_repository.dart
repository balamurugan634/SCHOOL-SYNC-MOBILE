import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/staff/people.dart';
import '../../models/staff/teaching.dart';

/// Academic structure and teaching: sections, my teaching assignments, my timetable, syllabus progress.
class AcademicsRepository {
  AcademicsRepository(this._api);
  final ApiClient _api;

  /// Sections visible to me in the current year (teacher: assigned, management: all).
  Future<List<SectionItem>> sections({bool mine = true, String? gradeId}) async {
    final body = await _api.get('/academics/sections', query: {'pageSize': 100, if (mine) 'mine': true, 'gradeId': ?gradeId});
    return jsonList(jsonMap(body)['data']).map(SectionItem.fromJson).toList(growable: false);
  }

  Future<SectionDetail> section(String id) async => SectionDetail.fromJson(jsonMap(await _api.get('/academics/sections/$id')));

  Future<List<Grade>> grades() async => jsonList(jsonMap(await _api.get('/academics/grades'))['data']).map(Grade.fromJson).toList(growable: false);

  /// Which (section, subject) pairs the teacher teaches: the only choices homework may be set for.
  Future<List<MyAssignment>> myAssignments(String staffId) async {
    final body = await _api.get('/academics/teaching-assignments', query: {'staffId': staffId, 'pageSize': 100});
    return jsonList(jsonMap(body)['data']).map(MyAssignment.fromJson).toList(growable: false);
  }

  // ── timetable ──
  /// A teacher's own lessons (including covers) for [date] (default today).
  Future<TeacherDay> myDay({DateTime? date}) async => TeacherDay.fromJson(jsonMap(await _api.get('/timetable/me', query: {if (date != null) 'date': isoDay(date)})));

  // ── syllabus ──
  Future<List<TopicEntry>> topics({required String gradeId, required String sectionId, String? subjectId}) async {
    final body = await _api.get('/syllabus/topics', query: {'gradeId': gradeId, 'sectionId': sectionId, 'subjectId': ?subjectId});
    return jsonList(jsonMap(body)['data']).map(TopicEntry.fromJson).toList(growable: false);
  }

  Future<List<CoverageRow>> coverage({String? sectionId, String? gradeId, String? subjectId}) async {
    final body = await _api.get('/syllabus/coverage', query: {'sectionId': ?sectionId, 'gradeId': ?gradeId, 'subjectId': ?subjectId});
    return jsonList(jsonMap(body)['data']).map(CoverageRow.fromJson).toList(growable: false);
  }

  /// Sets the section's progress on several topics at once (atomic).
  Future<void> setProgress(String sectionId, Map<String, SyllabusStatus> changes) async {
    await _api.put('/syllabus/progress', data: {
      'sectionId': sectionId,
      'items': [for (final e in changes.entries) {'topicId': e.key, 'status': e.value.api}],
    });
  }
}

final academicsRepositoryProvider = Provider<AcademicsRepository>((ref) => AcademicsRepository(ref.watch(apiClientProvider)));
