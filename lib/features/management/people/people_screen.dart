import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../data/models/staff/people.dart';
import '../../../router/routes_management.dart';
import '../approvals/admission_sheet.dart';
import '../approvals/approval_kinds.dart';
import '../approvals/approvals_providers.dart';
import '../home/management_home_providers.dart';
import '../../workspace/workspace.dart';
import 'people_providers.dart';

enum _Seg { students, staff, admissions }

/// People tab: student search (read-only profiles), the staff directory, and admission applications.
class ManagementPeopleScreen extends ConsumerStatefulWidget {
  const ManagementPeopleScreen({super.key});

  @override
  ConsumerState<ManagementPeopleScreen> createState() => _ManagementPeopleScreenState();
}

class _ManagementPeopleScreenState extends ConsumerState<ManagementPeopleScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  _Seg _seg = _Seg.students;
  String _q = '';
  String? _gradeId;
  int _admissionFilter = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    setState(() {}); // shows / hides the clear button at once; the search itself waits 300 ms
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _q = text.trim());
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _q = '';
      _gradeId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final segs = [if (ref.can('students:view')) _Seg.students, if (ref.can('staff:view')) _Seg.staff, if (ref.can('admissions:view')) _Seg.admissions];
    final seg = segs.contains(_seg) ? _seg : (segs.isEmpty ? _Seg.students : segs.first);
    return FeatureGate(
      label: 'People',
      anyPermission: const ['students:view', 'guardians:view', 'staff:view', 'admissions:view'],
      child: StaffFrame(
        embedded: true,
        title: 'People',
        subtitle: 'Students and staff.',
        headerExtra: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.page, 0, Gaps.page, Gaps.sm),
          child: Column(
            children: [
              if (segs.length > 1)
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_Seg>(
                    showSelectedIcon: false,
                    segments: [for (final s in segs) ButtonSegment(value: s, label: Text(switch (s) { _Seg.students => 'Students', _Seg.staff => 'Staff', _Seg.admissions => 'Admissions' }))],
                    selected: {seg},
                    onSelectionChanged: (v) => setState(() => _seg = v.first),
                  ),
                ),
              if (seg != _Seg.admissions) ...[
                const SizedBox(height: Gaps.sm),
                TextField(
                  controller: _controller,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: seg == _Seg.students ? 'Search by name or admission number' : 'Search staff by name',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isEmpty ? null : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded), onPressed: _clear),
                  ),
                ),
              ],
            ],
          ),
        ),
        body: switch (seg) {
          _Seg.students => _Students(q: _q, gradeId: _gradeId, onGrade: (g) => setState(() => _gradeId = g), onClear: _clear),
          _Seg.staff => _Staff(q: _q),
          _Seg.admissions => _Admissions(filter: _admissionFilter, onFilter: (i) => setState(() => _admissionFilter = i)),
        },
      ),
    );
  }
}

class _Students extends ConsumerWidget {
  const _Students({required this.q, required this.gradeId, required this.onGrade, required this.onClear});
  final String q;
  final String? gradeId;
  final ValueChanged<String?> onGrade;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = (q: q, gradeId: gradeId);
    final provider = studentSearchProvider(query);
    final grades = ref.watch(managementGradesProvider).value ?? const [];
    final active = studentQueryActive(query);
    return Column(
      children: [
        if (grades.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: Gaps.sm),
            child: FilterChips<String?>(options: [null, for (final g in grades) g.id], selected: gradeId, onSelected: onGrade, labelOf: (id) => id == null ? 'All grades' : grades.firstWhere((g) => g.id == id).name),
          ),
        Expanded(
          child: !active
              ? RefreshScroll(
                  onRefresh: () async => ref.invalidate(managementGradesProvider),
                  children: const [EmptyState(icon: Icons.person_search_outlined, title: 'Find a student', message: 'Type at least 2 letters of a name or an admission number, or pick a grade to browse its students.')],
                )
              : AsyncBody<PagedList<StudentRow>>(
                  value: ref.watch(provider),
                  onRetry: () => ref.invalidate(provider),
                  isEmpty: (p) => p.items.isEmpty,
                  empty: EmptyState(illo: Illo.noResults, title: 'No students found', message: q.isEmpty ? 'This grade has no students yet.' : 'Nothing matches "$q". Check the spelling or try the admission number.', actionLabel: 'Clear search', onAction: onClear),
                  data: (p) => RefreshScroll(
                    onRefresh: () async {
                      ref.invalidate(provider);
                      try {
                        await ref.read(provider.future);
                      } catch (_) {}
                    },
                    children: [
                      Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: Text('${p.total} ${p.total == 1 ? 'student' : 'students'}', style: context.text.bodySmall)),
                      RowGroup(children: [for (final s in p.items) PersonTile(name: s.name, subtitle: '${s.classLabel}  ·  ${s.admissionNo}', photoUrl: s.photoUrl, trailing: s.status == 'active' ? null : StatusChip(s.status[0].toUpperCase() + s.status.substring(1), tone: StatusTone.warning, icon: Icons.info_outline_rounded), onTap: () => context.push(ManagementRoutes.student(s.id)))]),
                      LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Staff extends ConsumerWidget {
  const _Staff({required this.q});
  final String q;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = staffDirectoryProvider(q);
    return AsyncBody<PagedList<StaffMember>>(
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      isEmpty: (p) => p.items.isEmpty,
      empty: EmptyState(illo: Illo.noResults, title: 'No staff found', message: q.isEmpty ? 'The staff directory is empty.' : 'Nothing matches "$q".'),
      data: (p) => RefreshScroll(
        onRefresh: () async {
          ref.invalidate(provider);
          try {
            await ref.read(provider.future);
          } catch (_) {}
        },
        children: [
          Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: Text('${p.total} staff', style: context.text.bodySmall)),
          RowGroup(
            children: [
              for (final s in p.items)
                PersonTile(
                  name: s.name,
                  subtitle: [?s.designation, ?s.department].join('  ·  '),
                  photoUrl: s.photoUrl,
                  onTap: () => context.push(ManagementRoutes.staffMember(s.id)),
                  trailing: s.phone == null || s.phone!.isEmpty ? null : IconButton(tooltip: 'Call ${s.name}', onPressed: () => callPhone(context, s.phone), icon: const Icon(Icons.call_outlined)),
                ),
            ],
          ),
          LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
        ],
      ),
    );
  }
}

class _Admissions extends ConsumerWidget {
  const _Admissions({required this.filter, required this.onFilter});
  final int filter;
  final ValueChanged<int> onFilter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spec = approvalSpecFor(ApprovalKind.admissions)!;
    final status = spec.statuses[filter].$1;
    final provider = approvalFeedProvider((kind: ApprovalKind.admissions, status: status));
    void changed() {
      ref.invalidate(approvalFeedProvider);
      ref.invalidate(managementDashboardProvider);
    }

    return Column(
      children: [
        Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: FilterChips<int>(options: List.generate(spec.statuses.length, (i) => i), selected: filter, onSelected: onFilter, labelOf: (i) => spec.statuses[i].$2)),
        Expanded(
          child: AsyncBody<PagedList<Object>>(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            isEmpty: (p) => p.items.isEmpty,
            empty: EmptyState(icon: spec.icon, title: filter == 0 ? spec.emptyTitle : 'Nothing ${spec.statuses[filter].$2.toLowerCase()}', message: filter == 0 ? spec.emptyMessage : 'No applications have this status.'),
            data: (p) => RefreshScroll(
              onRefresh: () async {
                ref.invalidate(provider);
                try {
                  await ref.read(provider.future);
                } catch (_) {}
              },
              children: [
                RowGroup(
                  children: [
                    for (final a in p.items.whereType<AdmissionApplication>())
                      ListRow(
                        title: a.name,
                        subtitle: '${[if (a.gradeAppliedName != null) a.gradeAppliedName!, a.applicationNo].join('  ·  ')}\n${a.guardianName}, ${a.guardianPhone}',
                        trailing: DecisionChip(a.status),
                        onTap: () => openAdmission(context, ref, a, onChanged: changed),
                      ),
                  ],
                ),
                LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
