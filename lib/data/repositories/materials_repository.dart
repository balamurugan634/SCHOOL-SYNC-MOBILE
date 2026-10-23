import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/materials.dart';

class MaterialsRepository {
  MaterialsRepository(this._api);
  final ApiClient _api;

  Future<Paged<StudyMaterial>> materials({String? studentId, String? q, int page = 1, int pageSize = 30}) async => Paged.parse(
    await _api.get('/materials', query: {'page': page, 'pageSize': pageSize, 'studentId': ?studentId, if (q != null && q.trim().isNotEmpty) 'q': q.trim()}),
    StudyMaterial.fromJson,
  );

  Future<List<SyllabusTopic>> syllabus({String? studentId}) async {
    final body = jsonMap(await _api.get('/syllabus/topics', query: {'studentId': ?studentId}));
    return jsonList(body['data']).map(SyllabusTopic.fromJson).toList(growable: false);
  }
}

final materialsRepositoryProvider = Provider<MaterialsRepository>((ref) => MaterialsRepository(ref.watch(apiClientProvider)));
