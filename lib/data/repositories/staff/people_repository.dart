import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/staff/people.dart';

/// Students, staff directory and admissions (read-mostly; the API enforces scope).
class PeopleRepository {
  PeopleRepository(this._api);
  final ApiClient _api;

  Future<Paged<StudentRow>> students({String? sectionId, String? gradeId, String? q, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/students', query: {'page': page, 'pageSize': pageSize, 'sectionId': ?sectionId, 'gradeId': ?gradeId, if (q != null && q.trim().isNotEmpty) 'q': q.trim()}),
    StudentRow.fromJson,
  );

  Future<StudentDetail> student(String id) async => StudentDetail.fromJson(jsonMap(await _api.get('/students/$id')));

  Future<Paged<StaffMember>> staff({String? q, int page = 1, int pageSize = 30, String? staffType}) async => Paged.parse(
    await _api.get('/staff', query: {'page': page, 'pageSize': pageSize, 'status': 'active', 'staffType': ?staffType, if (q != null && q.trim().isNotEmpty) 'q': q.trim()}),
    StaffMember.fromJson,
  );

  Future<StaffDetail> staffDetail(String id) async => StaffDetail.fromJson(jsonMap(await _api.get('/staff/$id')));

  Future<StaffWorkload> staffWorkload(String id) async => StaffWorkload.fromJson(jsonMap(await _api.get('/staff/$id/workload')));

  Future<Paged<AdmissionApplication>> admissions({String? status, String? q, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/admissions', query: {'page': page, 'pageSize': pageSize, 'status': ?status, if (q != null && q.trim().isNotEmpty) 'q': q.trim()}),
    AdmissionApplication.fromJson,
  );

  /// under_review | waitlisted | accepted | rejected (a note of 3+ characters is required to reject).
  Future<void> setAdmissionStatus(String id, String status, {String? note}) async {
    await _api.post('/admissions/$id/status', data: {'status': status, if (note != null && note.trim().isNotEmpty) 'note': note.trim()});
  }
}

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) => PeopleRepository(ref.watch(apiClientProvider)));
