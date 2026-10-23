import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/paged.dart';
import '../../data/models/homework.dart';
import '../dashboard/dashboard_widgets.dart';
import '../learner/learner_context.dart';
import '../learner/screen_frame.dart';
import 'homework_providers.dart';

const _filters = <(String?, String)>[(null, 'All'), ('pending', 'To do'), ('submitted', 'Submitted'), ('returned', 'Returned'), ('reviewed', 'Reviewed'), ('overdue', 'Overdue')];

/// Homework for the student (or the selected child), filterable by the learner's own state.
class HomeworkListScreen extends ConsumerStatefulWidget {
  const HomeworkListScreen({super.key, this.embedded = false, this.bare = false});
  final bool embedded;
  final bool bare;

  @override
  ConsumerState<HomeworkListScreen> createState() => _HomeworkListScreenState();
}

class _HomeworkListScreenState extends ConsumerState<HomeworkListScreen> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final q = (studentId: ref.watch(learnerQueryIdProvider), status: _status);
    final provider = homeworkListProvider(q);
    final v = ref.watch(provider);
    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return ScreenFrame(
      title: 'Homework',
      embedded: widget.embedded,
      bare: widget.bare,
      body: Column(
        children: [
          FilterChips<String?>(options: [for (final f in _filters) f.$1], selected: _status, onSelected: (s) => setState(() => _status = s), labelOf: (s) => _filters.firstWhere((f) => f.$1 == s).$2),
          const SizedBox(height: Gaps.sm),
          Expanded(
            child: AsyncBody<PagedList<Homework>>(
              value: v,
              onRetry: () => ref.invalidate(provider),
              isEmpty: (p) => p.items.isEmpty,
              empty: _Empty(filtered: _status != null, onClear: () => setState(() => _status = null)),
              data: (p) => RefreshScroll(
                onRefresh: refresh,
                children: [
                  RowGroup(children: [for (final h in p.items) HomeworkRow(h)]),
                  LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered, required this.onClear});
  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => filtered
      ? EmptyState(illo: Illo.noResults, title: 'No homework matches this filter', actionLabel: 'Show all', onAction: onClear)
      : const EmptyState(illo: Illo.emptyHomework, title: 'No homework yet', message: 'When a teacher sets homework it will show up here.');
}
