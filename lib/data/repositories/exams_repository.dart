import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/exams.dart';

/// Exams (schedule), published results, report cards and the progress trend.
class ExamsRepository {
  ExamsRepository(this._api);
  final ApiClient _api;

  Future<List<Exam>> exams() async => Paged.parse(await _api.get('/exams', query: {'pageSize': 50}), Exam.fromJson).items;

  Future<List<ExamPaper>> papers(String examId) async {
    final body = jsonMap(await _api.get('/exams/$examId/papers'));
    final list = jsonList(body['data']).map(ExamPaper.fromJson).toList();
    list.sort((a, b) => (a.examDate ?? DateTime(2100)).compareTo(b.examDate ?? DateTime(2100)));
    return list;
  }

  Future<List<ExamResult>> results({String? studentId}) async {
    final body = jsonMap(await _api.get('/results', query: {'studentId': ?studentId}));
    return jsonList(body['data']).map(ExamResult.fromJson).toList(growable: false);
  }

  Future<ReportCard> reportCard(String examId, String studentId) async => ReportCard.fromJson(jsonMap(await _api.get('/report-cards/$examId/students/$studentId')));

  Future<List<ProgressPoint>> progress({String? studentId}) async {
    final body = jsonMap(await _api.get('/results/progress', query: {'studentId': ?studentId}));
    return jsonList(body['exams']).map(ProgressPoint.fromJson).toList(growable: false);
  }

  String reportCardPdfPath(String examId, String studentId) => '/report-cards/$examId/students/$studentId/pdf';
}

final examsRepositoryProvider = Provider<ExamsRepository>((ref) => ExamsRepository(ref.watch(apiClientProvider)));
