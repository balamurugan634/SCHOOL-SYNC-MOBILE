import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';
import 'attendance_providers.dart';

/// Requests: corrections to saved roll calls and student leave, with what is waiting for me.
class RequestsSection extends ConsumerWidget {
  const RequestsSection({super.key});

  String? _count(AsyncValue<dynamic> v, int? n, bool more) => v.hasValue && n != null ? (n == 0 ? null : '$n${more ? '+' : ''} waiting') : null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canApprove = ref.can('attendance:approve');
    final canLeave = ref.can('leave:view');
    final toDecide = canApprove ? ref.watch(correctionsProvider((status: 'pending', mine: false))) : null;
    final mine = ref.watch(correctionsProvider((status: 'pending', mine: true)));
    final leave = canLeave ? ref.watch(studentLeaveListProvider('pending')) : null;

    Future<void> refresh() async {
      ref.invalidate(correctionsProvider);
      ref.invalidate(studentLeaveListProvider);
    }

    String? decideCount = toDecide == null ? null : _count(toDecide, toDecide.value?.items.length, toDecide.value?.hasMore ?? false);
    final myCount = mine.hasValue && (mine.value?.total ?? 0) > 0 ? '${mine.value!.total} pending' : null;
    final leaveCount = leave == null ? null : _count(leave, leave.value?.total, false);

    return RefreshScroll(
      onRefresh: refresh,
      children: [
        Text('Ask for a change to a roll call that has closed, and decide requests for the classes you lead.', style: context.text.bodyMedium?.copyWith(color: context.tokens.textSecondary)),
        const SizedBox(height: Gaps.md),
        RowGroup(
          children: [
            ListRow(
              leading: Icons.rule_rounded,
              title: canApprove ? 'Attendance corrections' : 'My correction requests',
              subtitle: canApprove ? 'Decide requests, and follow the ones you raised.' : 'Requests you raised and their decisions.',
              trailing: decideCount != null || myCount != null ? _CountTrailing(decideCount ?? myCount!) : null,
              onTap: () => context.push(TeacherRoutes.corrections),
            ),
            if (canLeave)
              ListRow(
                leading: Icons.event_busy_outlined,
                title: 'Student leave',
                subtitle: 'Leave requests from parents for your classes.',
                trailing: leaveCount != null ? _CountTrailing(leaveCount) : null,
                onTap: () => context.push(TeacherRoutes.studentLeave),
              ),
          ],
        ),
      ],
    );
  }
}

/// A waiting-count chip plus a chevron that never pushes the row wider than the screen (text can scale to 200%).
class _CountTrailing extends StatelessWidget {
  const _CountTrailing(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 124),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: StatusChip(label, tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded)), const Icon(Icons.chevron_right_rounded)]),
  );
}
