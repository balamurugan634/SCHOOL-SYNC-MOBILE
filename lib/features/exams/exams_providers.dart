import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/exams.dart';
import '../../data/repositories/exams_repository.dart';
import '../learner/learner_context.dart';

final examsProvider = FutureProvider<List<Exam>>((ref) => ref.watch(examsRepositoryProvider).exams());

final examPapersProvider = FutureProvider.family<List<ExamPaper>, String>((ref, examId) => ref.watch(examsRepositoryProvider).papers(examId));

/// Published results of the student (or selected child).
final resultsProvider = FutureProvider<List<ExamResult>>((ref) {
  final id = ref.watch(learnerQueryIdProvider);
  return ref.watch(examsRepositoryProvider).results(studentId: id);
});

final progressProvider = FutureProvider<List<ProgressPoint>>((ref) {
  final id = ref.watch(learnerQueryIdProvider);
  return ref.watch(examsRepositoryProvider).progress(studentId: id);
});

/// A report card (exam + the learner's student id).
final reportCardProvider = FutureProvider.family<ReportCard, String>((ref, examId) async {
  final studentId = ref.watch(learnerStudentIdProvider);
  if (studentId == null) throw StateError('no student');
  return ref.watch(examsRepositoryProvider).reportCard(examId, studentId);
});
