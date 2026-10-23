import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/paged.dart';
import '../../../data/json.dart';
import '../../../data/models/staff/people.dart';
import '../../../data/repositories/staff/academics_repository.dart';
import '../../../data/repositories/staff/people_repository.dart';

/// Minimum characters before a student search is sent (the empty state shows a prompt instead).
const kMinSearchChars = 2;

typedef StudentQuery = ({String q, String? gradeId});

/// Whether a student query should hit the API: a name / admission number of 2+ characters, or a grade filter.
bool studentQueryActive(StudentQuery q) => q.q.trim().length >= kMinSearchChars || q.gradeId != null;

class StudentSearch extends PagedNotifier<StudentRow, StudentQuery> {
  StudentSearch(super.arg);

  @override
  Future<Paged<StudentRow>> fetch(int page) {
    if (!studentQueryActive(arg)) return Future.value(const Paged<StudentRow>([], PageMeta()));
    return ref.read(peopleRepositoryProvider).students(q: arg.q, gradeId: arg.gradeId, page: page, pageSize: 25);
  }
}

final studentSearchProvider = AsyncNotifierProvider.family<StudentSearch, PagedList<StudentRow>, StudentQuery>(StudentSearch.new);

class StaffDirectory extends PagedNotifier<StaffMember, String> {
  StaffDirectory(super.arg);

  @override
  Future<Paged<StaffMember>> fetch(int page) => ref.read(peopleRepositoryProvider).staff(q: arg.trim().length >= kMinSearchChars ? arg : null, page: page, pageSize: 30);
}

final staffDirectoryProvider = AsyncNotifierProvider.family<StaffDirectory, PagedList<StaffMember>, String>(StaffDirectory.new);

final managementGradesProvider = FutureProvider.autoDispose<List<Grade>>((ref) => ref.watch(academicsRepositoryProvider).grades());

final staffDetailProvider = FutureProvider.autoDispose.family<StaffDetail, String>((ref, id) => ref.watch(peopleRepositoryProvider).staffDetail(id));

/// Workload is a nicety: a failure (or missing permission) must not break the profile, so it resolves to null.
final staffWorkloadProvider = FutureProvider.autoDispose.family<StaffWorkload?, String>((ref, id) async {
  try {
    return await ref.watch(peopleRepositoryProvider).staffWorkload(id);
  } catch (_) {
    return null;
  }
});
