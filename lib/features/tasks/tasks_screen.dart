import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/models/tasks.dart';
import '../../data/repositories/tasks_repository.dart';
import '../../router/routes_shared.dart';
import '../auth/session.dart';
import '../dashboard/dashboard_providers.dart';
import '../learner/screen_frame.dart';
import 'task_form_sheet.dart';
import 'tasks_providers.dart';

enum _Kind { all, tasks, homework }

/// "My tasks": your own to-dos and pending homework in one list, soonest first.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.embedded = true});
  final bool embedded;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  _Kind _kind = _Kind.all;

  Future<void> _refresh() async {
    ref.invalidate(taskFeedProvider);
    try {
      await ref.read(taskFeedProvider.future);
    } catch (_) {}
  }

  Future<void> _toggle(TaskFeedItem x) async {
    try {
      await ref.read(tasksRepositoryProvider).setStatus(x.id, x.done ? TaskStatus.todo : TaskStatus.done);
      ref.invalidate(taskFeedProvider);
      ref.invalidate(studentDashboardProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    }
  }

  Future<void> _delete(TaskFeedItem x) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(tasksRepositoryProvider).delete(x.id);
      ref.invalidate(taskFeedProvider);
      ref.invalidate(studentDashboardProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Task deleted')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    }
  }

  Future<void> _edit(TaskFeedItem x) async {
    final changed = await showTaskForm(context, existing: x);
    if (changed == true) {
      ref.invalidate(taskFeedProvider);
      ref.invalidate(studentDashboardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(taskFeedProvider);
    final showDone = ref.watch(showDoneProvider);
    final readOnly = ref.watch(sessionProvider.select((s) => s.siteInfo?.readOnly ?? false));
    return ScreenFrame(
      title: 'My Tasks',
      subtitle: 'Homework and your own to-dos, in one list.',
      embedded: widget.embedded,
      showChild: false,
      fab: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final created = await showTaskForm(context);
                if (created == true) {
                  ref.invalidate(taskFeedProvider);
                  ref.invalidate(studentDashboardProvider);
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add task'),
            ),
      body: Column(
        children: [
          Row(
            children: [
              Expanded(child: FilterChips<_Kind>(options: _Kind.values, selected: _kind, onSelected: (k) => setState(() => _kind = k), labelOf: (k) => switch (k) { _Kind.all => 'All', _Kind.tasks => 'My tasks', _Kind.homework => 'Homework' })),
              Padding(padding: const EdgeInsets.only(right: Gaps.sm), child: Row(children: [Text('Done', style: context.text.labelMedium), Switch(value: showDone, onChanged: (x) => ref.read(showDoneProvider.notifier).set(x))])),
            ],
          ),
          const SizedBox(height: Gaps.sm),
          Expanded(
            child: AsyncBody<List<TaskFeedItem>>(
              value: v,
              onRetry: _refresh,
              isEmpty: (l) => l.where(_matches).isEmpty,
              empty: EmptyState(
                illo: Illo.emptyHomework,
                title: _kind == _Kind.homework ? 'No homework to do' : 'You are all caught up',
                message: _kind == _Kind.homework ? 'Pending homework shows up here.' : 'Nothing is waiting. Add a task to remind yourself of something.',
              ),
              data: (list) {
                final items = list.where(_matches).toList();
                return RefreshScroll(
                  onRefresh: _refresh,
                  padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 96),
                  children: [
                    RowGroup(
                      children: [
                        for (final x in items)
                          x.isHomework
                              ? ListRow(
                                  title: x.title,
                                  subtitle: [if (x.subtitle != null) x.subtitle!, if (x.dueAt != null) dueLabel(x.dueAt!)].join('  ·  '),
                                  leading: Icons.assignment_outlined,
                                  trailing: x.overdue ? const StatusChip('Overdue', tone: StatusTone.danger) : const StatusChip('Homework'),
                                  onTap: () => context.push(SharedRoutes.homeworkDetail(x.id)),
                                )
                              : _TaskRow(item: x, onToggle: () => _toggle(x), onTap: () => _edit(x), onDelete: () => _delete(x)),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matches(TaskFeedItem x) => switch (_kind) { _Kind.all => true, _Kind.tasks => !x.isHomework, _Kind.homework => x.isHomework };
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.item, required this.onToggle, required this.onTap, required this.onDelete});
  final TaskFeedItem item;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final done = item.done;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.xs, Gaps.xs, Gaps.xs, Gaps.xs),
          child: Row(
            children: [
              Semantics(
                label: done ? 'Mark as not done' : 'Mark as done',
                child: IconButton(onPressed: onToggle, icon: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: done ? t.success : t.textTertiary)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500, decoration: done ? TextDecoration.lineThrough : null, color: done ? t.textTertiary : null)),
                    if (item.subtitle != null || item.dueAt != null) Text([if (item.subtitle != null) item.subtitle!, if (item.dueAt != null) dueLabel(item.dueAt!)].join('  ·  '), style: context.text.bodySmall?.copyWith(color: item.overdue && !done ? t.danger : null)),
                  ],
                ),
              ),
              if (item.priority == TaskPriority.high && !done) const Padding(padding: EdgeInsets.only(right: 4), child: StatusChip('High', tone: StatusTone.warning)),
              IconButton(tooltip: 'Delete', onPressed: onDelete, icon: Icon(Icons.delete_outline_rounded, color: t.textTertiary, size: 20)),
            ],
          ),
        ),
      ),
    );
  }
}
