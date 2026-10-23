import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/staff/people.dart';
import '../../../data/repositories/staff/academics_repository.dart';
import '../../workspace/staff_context.dart';

/// A section I teach or lead, with the subjects I teach in it.
class MyClass {
  const MyClass({required this.section, required this.subjects, required this.leads});
  final SectionItem section;
  final List<String> subjects;

  /// I am the class teacher.
  final bool leads;
}

/// `GET /academics/sections?mine=true` joined with my teaching assignments.
final myClassesProvider = FutureProvider.autoDispose<List<MyClass>>((ref) async {
  final repo = ref.watch(academicsRepositoryProvider);
  final staffId = ref.watch(staffIdProvider);
  final leading = ref.watch(classTeacherSectionIdsProvider).toSet();
  final sections = await repo.sections();
  List<MyAssignment> mine = const [];
  if (staffId != null) {
    try {
      mine = await repo.myAssignments(staffId);
    } catch (_) {
      // The class list is still useful without the subject names.
    }
  }
  final classes = [
    for (final s in sections)
      MyClass(
        section: s,
        subjects: [for (final a in mine) if (a.sectionId == s.id) a.subjectName],
        leads: leading.contains(s.id) || (staffId != null && s.classTeacherId == staffId),
      ),
  ]..sort((a, b) {
    final g = a.section.gradeOrdinal.compareTo(b.section.gradeOrdinal);
    return g != 0 ? g : a.section.name.compareTo(b.section.name);
  });
  return classes;
});
