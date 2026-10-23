import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/staff/people.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../data/repositories/staff/academics_repository.dart';

/// Every section of the current year (management sees them all).
final managementSectionsProvider = FutureProvider.autoDispose<List<SectionItem>>((ref) => ref.watch(academicsRepositoryProvider).sections(mine: false));

/// Syllabus coverage of every section and subject.
final managementCoverageProvider = FutureProvider.autoDispose<List<CoverageRow>>((ref) => ref.watch(academicsRepositoryProvider).coverage());

/// Coverage of one subject in one grade, averaged over its sections (weighted by topics).
class GradeSubjectCoverage {
  const GradeSubjectCoverage({required this.gradeName, required this.subjectName, required this.percent, required this.completed, required this.total, required this.sections});
  final String gradeName;
  final String subjectName;
  final double percent;
  final int completed;
  final int total;
  final int sections;
}

/// Groups coverage rows by grade and subject, lowest coverage first (the ones that need attention).
List<GradeSubjectCoverage> aggregateCoverage(List<CoverageRow> rows) {
  final groups = <String, List<CoverageRow>>{};
  for (final r in rows) {
    groups.putIfAbsent('${r.gradeName}|${r.subjectName}', () => []).add(r);
  }
  final out = <GradeSubjectCoverage>[];
  for (final g in groups.values) {
    final total = g.fold<int>(0, (a, r) => a + r.totalTopics);
    final done = g.fold<int>(0, (a, r) => a + r.completed);
    out.add(GradeSubjectCoverage(
      gradeName: g.first.gradeName,
      subjectName: g.first.subjectName,
      percent: total == 0 ? 0 : double.parse((done * 100 / total).toStringAsFixed(1)),
      completed: done,
      total: total,
      sections: g.length,
    ));
  }
  out.sort((a, b) {
    final c = a.percent.compareTo(b.percent);
    return c != 0 ? c : '${a.gradeName} ${a.subjectName}'.compareTo('${b.gradeName} ${b.subjectName}');
  });
  return out;
}

/// Sections grouped by grade, grades in school order.
List<(String, List<SectionItem>)> groupSectionsByGrade(List<SectionItem> sections) {
  final byGrade = <String, List<SectionItem>>{};
  for (final s in sections) {
    byGrade.putIfAbsent(s.gradeName, () => []).add(s);
  }
  final grades = byGrade.keys.toList()..sort((a, b) => byGrade[a]!.first.gradeOrdinal.compareTo(byGrade[b]!.first.gradeOrdinal));
  return [for (final g in grades) (g, [...byGrade[g]!]..sort((a, b) => a.name.compareTo(b.name)))];
}
