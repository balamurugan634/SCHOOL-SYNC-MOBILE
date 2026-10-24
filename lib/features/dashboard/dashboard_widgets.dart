import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/announcements.dart';
import '../../data/models/attendance.dart';
import '../../data/models/homework.dart';
import '../../data/models/learner_dashboard.dart';
import '../../data/models/schedule.dart';
import '../../data/models/tasks.dart';
import '../../router/routes_shared.dart';

/// Title row + content, in one card. Used by every dashboard block.
class DashCard extends StatelessWidget {
  const DashCard({super.key, required this.title, required this.child, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.md), this.trailing});

  final String title;
  final Widget child;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.sm, 0),
          child: Row(
            children: [
              Expanded(child: Text(title, style: context.text.titleMedium)),
              ?trailing,
              if (action != null) TextButton(onPressed: onAction, style: TextButton.styleFrom(visualDensity: VisualDensity.compact, minimumSize: const Size(48, 36)), child: Text(action!)),
            ],
          ),
        ),
        Padding(padding: padding.add(const EdgeInsets.only(top: 0)), child: child),
      ],
    ),
  );
}

String _muted(String s) => s;

class _Plain extends StatelessWidget {
  const _Plain(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: Gaps.xs), child: Text(_muted(text), style: context.text.bodyMedium?.copyWith(color: context.tokens.textSecondary)));
}

/// Today's periods. The current one is highlighted with the brand soft tint; the next is marked.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.day});
  final TimetableDay? day;

  @override
  Widget build(BuildContext context) {
    final d = day;
    final t = context.tokens;
    return DashCard(
      title: 'Today',
      action: 'Timetable',
      onAction: () => context.push(SharedRoutes.timetable),
      padding: const EdgeInsets.fromLTRB(Gaps.sm, Gaps.xs, Gaps.sm, Gaps.sm),
      child: d == null
          ? const Padding(padding: EdgeInsets.all(Gaps.sm), child: _Plain('The timetable is not available.'))
          : !d.isWorkingDay
          ? const Padding(padding: EdgeInsets.all(Gaps.sm), child: _Plain('No school today.'))
          : d.entries.isEmpty
          ? const Padding(padding: EdgeInsets.all(Gaps.sm), child: _Plain('No classes are scheduled today.'))
          : Column(
              children: [
                for (final e in d.entries)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 1),
                    padding: const EdgeInsets.symmetric(horizontal: Gaps.sm, vertical: 10),
                    decoration: BoxDecoration(color: e.state == 'current' ? t.brand.soft : null, borderRadius: BorderRadius.circular(Radii.md)),
                    child: Row(
                      children: [
                        SizedBox(width: 78, child: Text(formatClock(e.startTime), style: context.text.labelMedium?.copyWith(color: t.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        Expanded(
                          child: e.isBreak
                              ? Text(e.periodName, style: context.text.bodyMedium?.copyWith(color: t.textTertiary))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.subjectName ?? e.periodName, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                                    Text([if (e.teacherName != null) e.teacherName!, if (e.room != null) 'Room ${e.room}'].join('  ·  '), style: context.text.bodySmall),
                                    if (e.substituted) Text('Cover: ${e.substituteTeacherName ?? 'substitute teacher'}', style: context.text.labelSmall?.copyWith(color: t.warning)),
                                  ],
                                ),
                        ),
                        if (e.state == 'current') const StatusChip('Now', tone: StatusTone.accent) else if (d.next != null && e.ordinal == d.next!.ordinal && !e.isBreak) const StatusChip('Next'),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Today's attendance mark and the running percentage.
class AttendanceCard extends StatelessWidget {
  const AttendanceCard({super.key, required this.summary, required this.today});
  final AttendanceSummary? summary;
  final AttendanceStatus? today;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = summary;
    final tone = switch (today) {
      AttendanceStatus.present => StatusTone.success,
      AttendanceStatus.late || AttendanceStatus.halfDay => StatusTone.warning,
      AttendanceStatus.absent => StatusTone.danger,
      AttendanceStatus.leave => StatusTone.info,
      null => StatusTone.neutral,
    };
    return DashCard(
      title: 'Attendance',
      action: 'Details',
      onAction: () => context.push(SharedRoutes.attendance),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s == null ? '-' : '${s.totals.percentage.toStringAsFixed(s.totals.percentage % 1 == 0 ? 0 : 1)}%', style: figureStyle(context, size: 32)),
                Text(s == null ? 'No records yet' : 'this year, ${plural(s.totals.present + s.totals.late + s.totals.halfDay, 'day')} present of ${s.totals.total}', style: context.text.bodySmall),
                if (s != null && s.isShort) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Below the ${s.thresholdPercent.toStringAsFixed(0)}% requirement', style: context.text.labelMedium?.copyWith(color: t.danger))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [Text('Today', style: context.text.labelSmall?.copyWith(color: t.textSecondary)), const SizedBox(height: 4), StatusChip(today?.label ?? 'Not marked', tone: tone, icon: _statusIcon(today))],
          ),
        ],
      ),
    );
  }

  static IconData? _statusIcon(AttendanceStatus? s) => switch (s) {
    AttendanceStatus.present => Icons.check_rounded,
    AttendanceStatus.absent => Icons.close_rounded,
    AttendanceStatus.late => Icons.schedule_rounded,
    AttendanceStatus.leave => Icons.event_busy_rounded,
    AttendanceStatus.halfDay => Icons.timelapse_rounded,
    null => null,
  };
}

/// Pending / overdue homework with the next few items.
class HomeworkDashCard extends StatelessWidget {
  const HomeworkDashCard({super.key, required this.snapshot});
  final HomeworkSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = snapshot.items.take(3).toList();
    return DashCard(
      title: 'Homework',
      action: 'View all',
      onAction: () => context.push(SharedRoutes.homework),
      padding: EdgeInsets.zero,
      child: items.isEmpty
          ? Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md), child: Text('Nothing is due. You are all caught up.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.xs),
                  child: Row(children: [
                    StatusChip('${snapshot.pendingCount} to do', tone: StatusTone.brand),
                    const SizedBox(width: 6),
                    if (snapshot.overdueCount > 0) StatusChip('${snapshot.overdueCount} overdue', tone: StatusTone.danger),
                  ]),
                ),
                for (final h in items) HomeworkRow(h, compact: true),
              ],
            ),
    );
  }
}

class HomeworkRow extends StatelessWidget {
  const HomeworkRow(this.h, {super.key, this.compact = false});
  final Homework h;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final overdue = h.dueAt != null && h.dueAt!.isBefore(appNow()) && h.learnerStatus.needsAction;
    final tone = switch (h.learnerStatus) {
      LearnerStatus.reviewed => StatusTone.success,
      LearnerStatus.submitted || LearnerStatus.late => StatusTone.brand,
      LearnerStatus.returned => StatusTone.warning,
      LearnerStatus.overdue => StatusTone.danger,
      _ => overdue ? StatusTone.danger : StatusTone.neutral,
    };
    return ListRow(
      title: h.title,
      subtitle: '${h.subjectName}${h.dueAt == null ? '' : '  ·  ${dueLabel(h.dueAt!)}'}',
      onTap: () => context.push(SharedRoutes.homeworkDetail(h.id)),
      trailing: StatusChip(overdue && h.learnerStatus == LearnerStatus.pending ? 'Overdue' : h.learnerStatus.label, tone: tone),
      dense: compact,
    );
  }
}

class TasksDashCard extends StatelessWidget {
  const TasksDashCard({super.key, required this.tasks, required this.onAll});
  final List<TaskFeedItem> tasks;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = tasks.where((e) => !e.isHomework).take(3).toList();
    return DashCard(
      title: 'My tasks',
      action: 'View all',
      onAction: onAll,
      padding: EdgeInsets.zero,
      child: items.isEmpty
          ? Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md), child: Text('No personal tasks. Add one to keep track of your own work.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)))
          : Column(
              children: [
                for (final x in items)
                  ListRow(
                    title: x.title,
                    subtitle: x.dueAt == null ? 'No due date' : dueLabel(x.dueAt!),
                    leading: Icons.radio_button_unchecked_rounded,
                    chevron: false,
                    trailing: x.overdue ? const StatusChip('Overdue', tone: StatusTone.danger) : (x.priority == TaskPriority.high ? const StatusChip('High', tone: StatusTone.warning) : null),
                    dense: true,
                  ),
              ],
            ),
    );
  }
}

class ExamsDashCard extends StatelessWidget {
  const ExamsDashCard({super.key, required this.exams, required this.published});
  final List<DashboardExam> exams;
  final List<PublishedResultRef> published;

  @override
  Widget build(BuildContext context) {
    if (exams.isEmpty && published.isEmpty) return const SizedBox.shrink();
    return DashCard(
      title: 'Exams',
      action: published.isEmpty ? 'Schedule' : 'Results',
      onAction: () => context.push(published.isEmpty ? SharedRoutes.exams : SharedRoutes.results),
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final e in exams.take(3))
            ListRow(
              title: e.subject,
              subtitle: '${e.examName}${e.room == null ? '' : '  ·  ${e.room}'}',
              chevron: false,
              dense: true,
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [Text(e.date == null ? '' : fmtDay(e.date!), style: context.text.labelMedium), Text(formatClock(e.startTime), style: context.text.bodySmall)],
              ),
            ),
          for (final r in published.take(1))
            ListRow(title: '${r.examName} results are published', subtitle: r.publishedAt == null ? null : 'Published ${fmtShort(r.publishedAt!)}', leading: Icons.workspace_premium_outlined, dense: true, onTap: () => context.push(SharedRoutes.reportCard(r.examId))),
        ],
      ),
    );
  }
}

class AnnouncementsDashCard extends StatelessWidget {
  const AnnouncementsDashCard({super.key, required this.snapshot});
  final AnnouncementsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = snapshot.latest.take(3).toList();
    return DashCard(
      title: 'Announcements',
      action: 'View all',
      onAction: () => context.push(SharedRoutes.announcements),
      padding: EdgeInsets.zero,
      trailing: snapshot.unreadCount > 0 ? StatusChip('${snapshot.unreadCount} unread', tone: StatusTone.brand) : null,
      child: items.isEmpty
          ? Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.md), child: Text('No announcements right now.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)))
          : Column(children: [for (final a in items) AnnouncementRow(a, dense: true)]),
    );
  }
}

class AnnouncementRow extends StatelessWidget {
  const AnnouncementRow(this.a, {super.key, this.dense = false});
  final Announcement a;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ListRow(
      title: a.title,
      subtitle: a.body.replaceAll(RegExp(r'\s+'), ' '),
      dense: dense,
      onTap: () => context.push(SharedRoutes.announcementDetail(a.id)),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (a.urgent) const StatusChip('Urgent', tone: StatusTone.danger) else if (a.important) const StatusChip('Important', tone: StatusTone.warning),
          if (a.needsAck) const Padding(padding: EdgeInsets.only(top: 4), child: StatusChip('Needs reply', tone: StatusTone.accent)),
          if (!a.read && !a.urgent && !a.important && !a.needsAck) Container(width: 8, height: 8, decoration: BoxDecoration(color: t.brand.solid, shape: BoxShape.circle)),
        ],
      ),
    );
  }
}

class CalendarDashCard extends StatelessWidget {
  const CalendarDashCard({super.key, required this.items});
  final List<CalendarItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return DashCard(
      title: 'Coming up',
      action: 'Calendar',
      onAction: () => context.push(SharedRoutes.calendar),
      padding: EdgeInsets.zero,
      child: Column(children: [for (final c in items.take(4)) CalendarRow(c)]),
    );
  }
}

class CalendarRow extends StatelessWidget {
  const CalendarRow(this.c, {super.key});
  final CalendarItem c;

  @override
  Widget build(BuildContext context) {
    final tone = switch (c.kind) {
      CalendarKind.holiday => StatusTone.success,
      CalendarKind.exam => StatusTone.warning,
      CalendarKind.homeworkDue => StatusTone.brand,
      _ => StatusTone.neutral,
    };
    return ListRow(
      title: c.title,
      subtitle: [relativeDay(c.date), if (!c.allDay && c.startTime != null) formatTimeRange(c.startTime, c.endTime), if (c.location != null) c.location!].join('  ·  '),
      dense: true,
      chevron: false,
      trailing: StatusChip(c.cancelled ? 'Cancelled' : c.kind.label, tone: c.cancelled ? StatusTone.danger : tone),
      onTap: c.kind == CalendarKind.homeworkDue && c.entityId != null
          ? () => context.push(SharedRoutes.homeworkDetail(c.entityId!))
          : (c.kind == CalendarKind.event || c.kind == CalendarKind.holiday || c.kind == CalendarKind.ptm || c.kind == CalendarKind.sports) && c.entityId != null
          ? () => context.push(SharedRoutes.eventDetail(c.entityId!))
          : null,
    );
  }
}
