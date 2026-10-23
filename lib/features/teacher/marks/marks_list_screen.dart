import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../data/models/staff/marks.dart';
import '../../../router/routes_teacher.dart';
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import '../homework/homework_widgets.dart' show LabelledMeter;
import 'marks_providers.dart';
import 'marks_widgets.dart';

enum _SheetFilter {
  todo('To do'),
  done('Submitted'),
  all('All');

  const _SheetFilter(this.label);
  final String label;

  bool matches(MarkSheet s) => switch (this) {
    _SheetFilter.todo => s.status == 'draft' || s.status == 'returned',
    _SheetFilter.done => s.status == 'submitted' || s.status == 'approved' || s.status == 'published',
    _SheetFilter.all => true,
  };
}

/// Mark sheets assigned to me, grouped by exam. Tap one to enter or read marks.
class MarksListScreen extends ConsumerStatefulWidget {
  const MarksListScreen({super.key});

  @override
  ConsumerState<MarksListScreen> createState() => _MarksListScreenState();
}

class _MarksListScreenState extends ConsumerState<MarksListScreen> {
  _SheetFilter _filter = _SheetFilter.todo;

  Future<void> _refresh() async {
    ref.invalidate(mySheetsProvider);
    try {
      await ref.read(mySheetsProvider.future);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(mySheetsProvider);
    return SecureScope(child: StaffFrame(
      title: 'Marks',
      headerExtra: Padding(
        padding: const EdgeInsets.only(top: Gaps.sm, bottom: Gaps.sm),
        child: FilterChips<_SheetFilter>(options: _SheetFilter.values, selected: _filter, onSelected: (f) => setState(() => _filter = f), labelOf: (f) => f.label),
      ),
      body: FeatureGate(
        label: 'Marks',
        anyPermission: const ['marks:view', 'marks:create'],
        child: AsyncBody<List<MarkSheet>>(
          value: v,
          onRetry: () => ref.invalidate(mySheetsProvider),
          isEmpty: (all) => all.where(_filter.matches).isEmpty,
          empty: _Empty(noneAtAll: v.value?.isEmpty ?? true, filter: _filter, onShowAll: () => setState(() => _filter = _SheetFilter.all)),
          data: (all) {
            final sheets = all.where(_filter.matches).toList();
            final groups = <String, List<MarkSheet>>{};
            for (final s in sheets) {
              groups.putIfAbsent(s.examName, () => []).add(s);
            }
            return RefreshScroll(
              onRefresh: _refresh,
              children: [
                const ReadOnlyBanner(),
                for (final e in groups.entries) ...[
                  GroupLabel(e.key),
                  RowGroup(children: [for (final s in e.value) _SheetRow(sheet: s, onTap: () => context.push(TeacherRoutes.marksSheet(s.id)))]),
                ],
              ],
            );
          },
        ),
      ),
    ));
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.noneAtAll, required this.filter, required this.onShowAll});
  final bool noneAtAll;
  final _SheetFilter filter;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) => noneAtAll
      ? const EmptyState(icon: Icons.grading_rounded, title: 'No mark sheets yet', message: 'When the school opens marks entry for an exam you teach, your sheets appear here.')
      : EmptyState(icon: Icons.done_all_rounded, title: filter == _SheetFilter.todo ? 'Nothing to enter' : 'Nothing here', message: filter == _SheetFilter.todo ? 'You have no mark sheets waiting for you.' : 'No sheets in this state.', actionLabel: 'Show all', onAction: onShowAll);
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({required this.sheet, required this.onTap});
  final MarkSheet sheet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = sheet;
    final done = s.enteredCount + s.absentCount;
    final entered = '$done of ${s.studentCount} entered';
    return Semantics(
      button: true,
      label: '${s.subjectName}, ${s.sectionTitle}, ${SheetStatusLabel.of(s.status)}, $entered${s.isReturned && s.returnNote != null ? '. Returned: ${s.returnNote}' : ''}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.subjectName, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        Text('${s.sectionTitle}  ·  out of ${_fmt(s.maxMarks)}', style: context.text.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: Gaps.sm),
                  SheetStatusChip(s.status),
                ],
              ),
              if (s.studentCount > 0 && s.status != 'published') ...[const SizedBox(height: Gaps.sm), LabelledMeter(value: done / s.studentCount, label: entered)],
              if (s.isReturned && (s.returnNote ?? '').isNotEmpty) ...[
                const SizedBox(height: Gaps.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.undo_rounded, size: 16, color: t.warning),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Reviewer: ${s.returnNote}', maxLines: 3, overflow: TextOverflow.ellipsis, style: context.text.bodySmall?.copyWith(color: t.warning))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Plain words for a sheet status (used in semantics labels).
abstract final class SheetStatusLabel {
  static String of(String status) => switch (status) {
    'draft' => 'to enter',
    'returned' => 'returned for changes',
    'submitted' => 'in review',
    'approved' => 'approved',
    'published' => 'published',
    _ => status,
  };
}
