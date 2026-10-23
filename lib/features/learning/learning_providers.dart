import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/paged.dart';
import '../../data/json.dart';
import '../../data/models/learner_extras.dart';
import '../../data/models/materials.dart';
import '../../data/repositories/learner_extras_repository.dart';
import '../../data/repositories/materials_repository.dart';
import '../learner/learner_context.dart';

class MaterialsNotifier extends PagedNotifier<StudyMaterial, ({String? studentId, String q})> {
  MaterialsNotifier(super.arg);
  @override
  Future<Paged<StudyMaterial>> fetch(int page) => ref.read(materialsRepositoryProvider).materials(studentId: arg.studentId, q: arg.q, page: page);
}

final materialsProvider = AsyncNotifierProvider.family<MaterialsNotifier, PagedList<StudyMaterial>, ({String? studentId, String q})>(MaterialsNotifier.new);

final syllabusProvider = FutureProvider<List<SyllabusTopic>>((ref) {
  final id = ref.watch(learnerQueryIdProvider);
  return ref.watch(materialsRepositoryProvider).syllabus(studentId: id);
});

final libraryLoansProvider = FutureProvider<List<LibraryLoan>>((ref) {
  final id = ref.watch(learnerQueryIdProvider);
  return ref.watch(learnerExtrasRepositoryProvider).libraryLoans(studentId: id);
});

final myBusProvider = FutureProvider<List<BusAllocation>>((ref) => ref.watch(learnerExtrasRepositoryProvider).myBus());
