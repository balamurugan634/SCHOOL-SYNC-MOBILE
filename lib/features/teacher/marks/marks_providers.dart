import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/staff/marks.dart';
import '../../../data/repositories/staff/marks_repository.dart';

/// Mark sheets I am the subject teacher of (all states). One page of up to 100 is plenty for a teacher.
final mySheetsProvider = FutureProvider.autoDispose<List<MarkSheet>>((ref) async => (await ref.watch(marksRepositoryProvider).sheets(mine: true, pageSize: 100)).items);

final markSheetProvider = FutureProvider.autoDispose.family<MarkSheetDetail, String>((ref, id) => ref.watch(marksRepositoryProvider).sheet(id));

void refreshMarks(WidgetRef ref, {String? sheetId}) {
  ref.invalidate(mySheetsProvider);
  if (sheetId != null) ref.invalidate(markSheetProvider(sheetId));
}
