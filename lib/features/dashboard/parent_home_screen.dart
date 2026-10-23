import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/learner_dashboard.dart';
import '../../data/models/meetings.dart';
import '../../router/routes_shared.dart';
import '../home/child_selector.dart';
import 'dashboard_providers.dart';
import 'dashboard_widgets.dart';
import 'home_frame.dart';

/// Parent Home: every child at a glance, then the selected child's day, fees, meetings and notices.
class ParentHomeScreen extends ConsumerWidget {
  const ParentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(parentDashboardProvider);
    final child = ref.watch(selectedChildProvider);
    Future<void> refresh() async {
      ref.invalidate(parentDashboardProvider);
      try {
        await ref.read(parentDashboardProvider.future);
      } catch (_) {}
    }

    if (child == null) {
      return const HomeFrame(onRefresh: _noop, children: [AppCard(child: EmptyState(illo: Illo.firstUse, title: 'No children linked yet', message: 'The school links each child to your account after verifying you are the parent or guardian. Ask the school office if this looks wrong.', compact: true))]);
    }
    if (!v.hasValue) {
      return v.hasError ? ErrorState(error: v.error!, onRetry: () => ref.invalidate(parentDashboardProvider)) : const HomeFrame(onRefresh: _noop, children: [SkeletonList(count: 4, padding: EdgeInsets.zero)]);
    }
    final d = v.requireValue;
    final day = d.child;
    return HomeFrame(
      onRefresh: refresh,
      staleSince: d.fromCache ? d.fetchedAt : null,
      error: v.hasError ? v.error : null,
      children: [
        if (d.children.length > 1) _ChildrenCard(children: d.children, selected: child.studentId),
        if (day != null) ...[
          TodayCard(day: day.timetable),
          AttendanceCard(summary: day.attendance, today: day.attendanceToday),
          HomeworkDashCard(snapshot: day.homework),
        ],
        if (d.fees != null) _FeesCard(fees: d.fees!),
        if (day != null) ExamsDashCard(exams: day.upcomingExams, published: day.publishedResults),
        _MeetingsCard(meetings: d.meetings),
        _LeaveCard(pending: d.pendingLeaveCount),
        AnnouncementsDashCard(snapshot: d.announcements),
        CalendarDashCard(items: d.calendar),
      ],
    );
  }
}

Future<void> _noop() async {}

class _ChildrenCard extends ConsumerWidget {
  const _ChildrenCard({required this.children, required this.selected});
  final List<ChildOverview> children;
  final String selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return DashCard(
      title: 'Your children',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final c in children)
            ListRow(
              title: c.student.name,
              subtitle: [c.student.classLabel, if (c.attendancePercentage != null) '${c.attendancePercentage!.toStringAsFixed(0)}% attendance', if (c.outstandingMinor > 0) '${formatMinor(c.outstandingMinor)} due'].where((e) => e.isNotEmpty).join('  ·  '),
              leading: c.student.id == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              dense: true,
              chevron: false,
              trailing: c.attendanceToday == null ? null : StatusChip(c.attendanceToday!.label, tone: c.attendanceToday!.name == 'present' ? StatusTone.success : (c.attendanceToday!.name == 'absent' ? StatusTone.danger : StatusTone.neutral)),
              onTap: () => ref.read(selectedChildIdProvider.notifier).select(c.student.id),
            ),
          Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md), child: Text('Tap a child to switch the whole app to them.', style: context.text.bodySmall?.copyWith(color: t.textTertiary))),
        ],
      ),
    );
  }
}

class _FeesCard extends StatelessWidget {
  const _FeesCard({required this.fees});
  final FeesSnapshot fees;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final owing = fees.outstandingMinor > 0;
    return DashCard(
      title: 'Fees',
      action: owing ? 'View' : 'History',
      onAction: () => context.push(SharedRoutes.fees),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(owing ? formatMinor(fees.outstandingMinor, currency: fees.currency) : 'Nothing due', style: figureStyle(context, size: 32)),
          const SizedBox(height: 2),
          Text(owing ? 'outstanding' : 'All invoices are paid', style: context.text.bodySmall),
          if (fees.overdueCount > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [StatusChip('${fees.overdueCount} overdue · ${formatMinor(fees.overdueMinor, currency: fees.currency)}', tone: StatusTone.danger, icon: Icons.warning_amber_rounded)])),
          if (fees.nextDueDate != null && fees.nextDueInvoiceId != null) ...[
            const SizedBox(height: Gaps.md),
            Row(children: [
              Expanded(child: Text('Next due ${fmtShort(fees.nextDueDate!)}${fees.nextDueBalanceMinor == null ? '' : '  ·  ${formatMinor(fees.nextDueBalanceMinor!, currency: fees.currency)}'}', style: context.text.bodyMedium?.copyWith(color: t.textSecondary))),
              TextButton(onPressed: () => context.push(SharedRoutes.invoice(fees.nextDueInvoiceId!)), child: const Text('Open')),
            ]),
          ],
        ],
      ),
    );
  }
}

class _MeetingsCard extends StatelessWidget {
  const _MeetingsCard({required this.meetings});
  final List<Meeting> meetings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final open = meetings.where((m) => m.open).toList();
    return DashCard(
      title: 'Meetings',
      action: 'Request',
      onAction: () => context.push(SharedRoutes.meetingNew),
      padding: EdgeInsets.zero,
      child: open.isEmpty
          ? Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md), child: Text('No upcoming meetings. You can ask a teacher for one.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)))
          : Column(children: [for (final m in open.take(2)) MeetingRow(m)]),
    );
  }
}

class MeetingRow extends StatelessWidget {
  const MeetingRow(this.m, {super.key});
  final Meeting m;

  @override
  Widget build(BuildContext context) {
    final tone = switch (m.status) { 'confirmed' => StatusTone.success, 'requested' => StatusTone.warning, 'declined' || 'cancelled' => StatusTone.danger, _ => StatusTone.neutral };
    return ListRow(
      title: m.topic,
      subtitle: '${m.teacherName}${m.when == null ? '' : '  ·  ${fmtDateTime(m.when!)}'}',
      dense: true,
      chevron: false,
      trailing: StatusChip(m.status == 'requested' ? 'Requested' : '${m.status[0].toUpperCase()}${m.status.substring(1)}', tone: tone),
      onTap: () => context.push(SharedRoutes.meetings),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  const _LeaveCard({required this.pending});
  final int pending;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: ListRow(title: 'Leave requests', subtitle: pending > 0 ? '${plural(pending, 'request')} waiting for the school' : 'Apply for leave for your child', leading: Icons.event_busy_outlined, onTap: () => context.push(SharedRoutes.leave)),
  );
}
