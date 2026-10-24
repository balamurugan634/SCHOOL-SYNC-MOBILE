import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/announcements.dart';
import '../../../data/models/schedule.dart' show CalendarItem, CalendarKind;
import '../../../data/models/staff/comms.dart';
import '../../../data/models/staff/dashboards.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../data/models/staff/teaching.dart';
import '../../../router/routes.dart';
import '../../../router/routes_teacher.dart';
import '../../workspace/workspace.dart';

// ───────────────────────────── attendance to mark ─────────────────────────────

/// Sections still to be marked today, one tap from the roll call.
class AttendanceDueCard extends StatelessWidget {
  const AttendanceDueCard({super.key, required this.attendance});
  final AttendanceToday attendance;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final items = [...attendance.items]..sort((a, b) => a.marked == b.marked ? 0 : (a.marked ? 1 : -1));
    final Widget body;
    if (!attendance.isWorkingDay) {
      body = QuietLine(attendance.holiday == null ? 'No school today. Attendance is not taken.' : 'Holiday: ${attendance.holiday}. Attendance is not taken.', icon: Icons.beach_access_outlined);
    } else if (items.isEmpty) {
      body = const QuietLine('You do not take attendance for any class today.', icon: Icons.fact_check_outlined);
    } else {
      body = Column(children: [for (final (i, it) in items.indexed) ...[if (i > 0) const Divider(), _AttendanceRow(item: it, date: attendance.date)]]);
    }
    final pending = attendance.pendingCount;
    return SectionCard(
      title: 'Attendance',
      action: 'All',
      onAction: () => context.go(Routes.tab(2)),
      trailing: !attendance.isWorkingDay || items.isEmpty
          ? null
          : (pending > 0 ? StatusChip('$pending to mark', tone: StatusTone.warning, icon: Icons.pending_actions_rounded) : const StatusChip('All marked', tone: StatusTone.success, icon: Icons.check_rounded)),
      padding: EdgeInsets.fromLTRB(attendance.isWorkingDay && items.isNotEmpty ? 0 : Gaps.lg, 0, attendance.isWorkingDay && items.isNotEmpty ? 0 : Gaps.lg, Gaps.sm),
      semanticLabel: pending > 0 ? 'Attendance. $pending of your classes are not marked yet.' : null,
      child: DefaultTextStyle.merge(style: TextStyle(color: t.text), child: body),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.item, required this.date});
  final AttendanceTodayItem item;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = item.counts;
    final detail = [
      if (item.periodName != null) item.periodName!,
      if (item.subjectName != null) item.subjectName!,
      if (item.marked && c != null) '${c.present + c.late + c.halfDay} here, ${c.absent} absent' else plural(item.strength, 'student'),
    ].join('  ·  ');
    return Semantics(
      button: true,
      label: '${item.sectionName}. ${item.marked ? 'Marked' : 'Not marked yet. Open the roll call'}. $detail',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push(TeacherRoutes.rollCall(item.sectionId, periodId: item.periodId)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.sectionName, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      Text(detail, style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: Gaps.sm),
                if (item.marked)
                  const StatusChip('Marked', tone: StatusTone.success, icon: Icons.check_rounded)
                else
                  Container(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
                    padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
                    decoration: BoxDecoration(color: t.brand.soft, borderRadius: Radii.field),
                    alignment: Alignment.center,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.fact_check_outlined, size: 18, color: t.brand.ink), const SizedBox(width: 6), Text('Roll call', style: context.text.labelMedium?.copyWith(color: t.brand.ink))]),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── today's timetable ─────────────────────────────

/// Today's lessons. The current period is highlighted with the brand soft tint and a "Now" chip.
class TodayTimetableCard extends StatelessWidget {
  const TodayTimetableCard({super.key, required this.day});
  final TeacherDay day;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Widget body;
    if (!day.isWorkingDay) {
      body = const Padding(padding: EdgeInsets.all(Gaps.sm), child: QuietLine('No school today.', icon: Icons.beach_access_outlined));
    } else if (day.entries.isEmpty) {
      body = const Padding(padding: EdgeInsets.all(Gaps.sm), child: QuietLine('You have no lessons today.', icon: Icons.event_available_outlined));
    } else {
      body = Column(children: [for (final e in day.entries) _PeriodRow(period: e, isNext: day.next != null && e.periodId == day.next!.periodId && !e.isBreak)]);
    }
    return SectionCard(
      title: 'Today',
      action: 'Week',
      onAction: () => context.push(TeacherRoutes.timetable),
      padding: const EdgeInsets.fromLTRB(Gaps.sm, 0, Gaps.sm, Gaps.sm),
      trailing: day.current != null ? Padding(padding: const EdgeInsets.only(right: Gaps.xs), child: StatusChip('Now: ${day.current!.subjectName ?? day.current!.periodName}', tone: StatusTone.brand, icon: Icons.play_arrow_rounded)) : null,
      child: DefaultTextStyle.merge(style: TextStyle(color: t.text), child: body),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period, required this.isNext});
  final TeacherPeriod period;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final p = period;
    final past = p.state == 'past';
    final String title;
    final String? note;
    if (p.isBreak) {
      title = p.periodName;
      note = null;
    } else {
      title = [p.subjectName ?? p.periodName, if (p.sectionName != null) p.sectionName!].join(' · ');
      note = p.isFree
          ? 'Free: ${p.substituteTeacherName ?? 'another teacher'} is covering your class'
          : p.isCovering
          ? 'You are covering this lesson'
          : [if (p.room != null) 'Room ${p.room}', if (p.substituted && p.substituteTeacherName != null) 'Cover: ${p.substituteTeacherName}'].join('  ·  ');
    }
    final tappable = !p.isBreak && !p.isFree && p.sectionId != null;
    final row = Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: Gaps.sm, vertical: 10),
      constraints: const BoxConstraints(minHeight: 52),
      decoration: BoxDecoration(color: p.isCurrent ? t.brand.soft : null, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(
        children: [
          SizedBox(width: 76, child: Text(formatClock(p.startTime), style: context.text.labelMedium?.copyWith(color: t.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.bodyMedium?.copyWith(fontWeight: p.isBreak ? FontWeight.w400 : FontWeight.w500, color: p.isBreak || past || p.isFree ? t.textTertiary : t.text)),
                if (note != null && note.isNotEmpty) Text(note, style: context.text.bodySmall?.copyWith(color: p.isFree || p.isCovering ? t.warning : null)),
              ],
            ),
          ),
          if (p.isCurrent)
            const StatusChip('Now', tone: StatusTone.accent, icon: Icons.play_arrow_rounded)
          else if (isNext)
            const StatusChip('Next', icon: Icons.schedule_rounded)
          else if (p.isFree)
            const StatusChip('Free', tone: StatusTone.info, icon: Icons.free_breakfast_outlined),
        ],
      ),
    );
    if (!tappable) return row;
    return Semantics(button: true, label: '$title, ${formatTimeRange(p.startTime, p.endTime)}. Open class', excludeSemantics: true, child: InkWell(borderRadius: BorderRadius.circular(Radii.md), onTap: () => context.push(TeacherRoutes.section(p.sectionId!)), child: row));
  }
}

// ───────────────────────────── to do ─────────────────────────────

class TodoCard extends StatelessWidget {
  const TodoCard({super.key, required this.d, required this.canMarks, required this.canHomework});
  final TeacherDashboard d;
  final bool canMarks;
  final bool canHomework;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (canHomework && d.toReviewCount > 0) _TodoRow(icon: Icons.rate_review_outlined, title: 'Homework to review', detail: '${plural(d.toReviewCount, 'submission')} waiting', count: d.toReviewCount, onTap: () => context.go(Routes.tab(3))),
      if (canMarks && d.marksPending > 0)
        _TodoRow(
          icon: Icons.grading_rounded,
          title: 'Marks to enter',
          detail: d.marksReturned > 0 ? '${d.marksPending} ${d.marksPending == 1 ? 'sheet' : 'sheets'}, ${d.marksReturned} returned with a note' : plural(d.marksPending, 'sheet'),
          count: d.marksPending,
          onTap: () => context.push(TeacherRoutes.marks),
          warn: d.marksReturned > 0,
        ),
      if (d.pendingLeaveCount > 0) _TodoRow(icon: Icons.event_busy_outlined, title: 'Student leave to decide', detail: 'For the classes you lead', count: d.pendingLeaveCount, onTap: () => context.push(TeacherRoutes.studentLeave)),
      if (canMarks)
        for (final m in d.marks.take(3)) _MarksItemRow(m),
    ];
    return SectionCard(
      title: 'To do',
      padding: EdgeInsets.only(bottom: rows.isEmpty ? Gaps.sm : 0, left: rows.isEmpty ? Gaps.lg : 0, right: rows.isEmpty ? Gaps.lg : 0),
      child: rows.isEmpty ? const QuietLine('Nothing waiting for you. Nice.', icon: Icons.task_alt_rounded) : Column(children: [for (final (i, r) in rows.indexed) ...[if (i > 0) const Divider(indent: Gaps.lg), r]]),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({required this.icon, required this.title, required this.detail, required this.count, required this.onTap, this.warn = false});
  final IconData icon;
  final String title;
  final String detail;
  final int count;
  final VoidCallback onTap;
  final bool warn;

  @override
  Widget build(BuildContext context) => ListRow(title: title, subtitle: detail, leading: icon, onTap: onTap, trailing: StatusChip('$count', tone: warn ? StatusTone.warning : StatusTone.brand));
}

class _MarksItemRow extends StatelessWidget {
  const _MarksItemRow(this.m);
  final MarksTodo m;

  @override
  Widget build(BuildContext context) => ListRow(
    title: '${m.subject} · ${m.sectionName}',
    subtitle: m.examName,
    leading: Icons.edit_note_rounded,
    dense: true,
    onTap: () => context.push(TeacherRoutes.marksSheet(m.sheetId)),
    trailing: m.returned ? const StatusChip('Returned', tone: StatusTone.warning, icon: Icons.undo_rounded) : const StatusChip('Draft', icon: Icons.edit_outlined),
  );
}

// ───────────────────────────── homework due soon ─────────────────────────────

class DueSoonCard extends StatelessWidget {
  const DueSoonCard({super.key, required this.items});
  final List<HomeworkEntry> items;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Homework due soon',
    action: 'All',
    onAction: () => context.go(Routes.tab(3)),
    padding: EdgeInsets.only(bottom: items.isEmpty ? Gaps.sm : 0, left: items.isEmpty ? Gaps.lg : 0, right: items.isEmpty ? Gaps.lg : 0),
    child: items.isEmpty
        ? const QuietLine('Nothing of yours is due in the next three days.', icon: Icons.assignment_turned_in_outlined)
        : Column(
            children: [
              for (final (i, h) in items.take(3).indexed) ...[
                if (i > 0) const Divider(indent: Gaps.lg),
                ListRow(
                  title: h.title,
                  subtitle: '${h.sectionTitle} · ${h.subjectName} · ${dueLabel(h.dueAt)}${h.stats == null ? '' : ' · ${h.stats!.handedIn} of ${h.stats!.totalStudents} handed in'}',
                  leading: Icons.assignment_outlined,
                  onTap: () => context.push(TeacherRoutes.homework(h.id)),
                  trailing: h.stats != null && h.stats!.toReview > 0 ? StatusChip('${h.stats!.toReview} to review', tone: StatusTone.brand) : null,
                ),
              ],
            ],
          ),
  );
}

// ───────────────────────────── meetings ─────────────────────────────

class MeetingsCard extends StatelessWidget {
  const MeetingsCard({super.key, required this.meetings});
  final List<StaffMeeting> meetings;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Meetings',
    action: 'All',
    onAction: () => context.push(TeacherRoutes.meetings),
    padding: EdgeInsets.only(bottom: meetings.isEmpty ? Gaps.sm : 0, left: meetings.isEmpty ? Gaps.lg : 0, right: meetings.isEmpty ? Gaps.lg : 0),
    child: meetings.isEmpty
        ? const QuietLine('No meetings coming up.', icon: Icons.handshake_outlined)
        : Column(
            children: [
              for (final (i, m) in meetings.take(3).indexed) ...[
                if (i > 0) const Divider(indent: Gaps.lg),
                ListRow(
                  title: m.studentName,
                  subtitle: [if (m.when != null) fmtDateTime(m.when!), m.modeLabel, m.topic].join('  ·  '),
                  leading: Icons.handshake_outlined,
                  onTap: () => context.push(TeacherRoutes.meetings),
                  trailing: m.status == 'requested' ? const StatusChip('Needs a reply', tone: StatusTone.warning, icon: Icons.reply_rounded) : const StatusChip('Confirmed', tone: StatusTone.success, icon: Icons.check_rounded),
                ),
              ],
            ],
          ),
  );
}

// ───────────────────────────── announcements and calendar ─────────────────────────────

class TeacherAnnouncementsCard extends StatelessWidget {
  const TeacherAnnouncementsCard({super.key, required this.block});
  final AnnouncementsBlock block;

  @override
  Widget build(BuildContext context) {
    final items = block.latest.take(3).toList();
    return SectionCard(
      title: 'Announcements',
      action: 'All',
      onAction: () => context.push(TeacherRoutes.announcements),
      padding: EdgeInsets.only(bottom: items.isEmpty ? Gaps.sm : Gaps.xs, left: items.isEmpty ? Gaps.lg : 0, right: items.isEmpty ? Gaps.lg : 0),
      child: Column(
        children: [
          if (block.unreadCount > 0) Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.xs), child: Align(alignment: Alignment.centerLeft, child: StatusChip('${block.unreadCount} unread', tone: StatusTone.brand))),
          if (items.isEmpty) const QuietLine('No announcements yet.', icon: Icons.campaign_outlined),
          for (final Announcement a in items)
            ListRow(
              title: a.title,
              subtitle: [if (a.publishAt != null) fmtShort(a.publishAt!), ?a.authorName].join('  ·  '),
              leading: a.urgent ? Icons.priority_high_rounded : Icons.campaign_outlined,
              dense: true,
              onTap: () => context.push(TeacherRoutes.announcements),
              trailing: a.urgent ? const StatusChip('Urgent', tone: StatusTone.danger, icon: Icons.priority_high_rounded) : (!a.read ? const StatusChip('New', tone: StatusTone.brand) : null),
            ),
        ],
      ),
    );
  }
}

class ComingUpCard extends StatelessWidget {
  const ComingUpCard({super.key, required this.items});
  final List<CalendarItem> items;

  @override
  Widget build(BuildContext context) {
    // Own homework deadlines are already shown above; keep events, holidays and exams.
    final rows = items.where((c) => c.kind != CalendarKind.homeworkDue).take(4).toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Coming up',
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, c) in rows.indexed) ...[
            if (i > 0) const Divider(indent: Gaps.lg),
            ListRow(title: c.title, subtitle: [relativeDay(c.date), if (c.startTime != null) formatClock(c.startTime), if (c.location != null) c.location!].join('  ·  '), leading: Icons.event_outlined, dense: true, chevron: false, trailing: StatusChip(c.kind.label)),
          ],
        ],
      ),
    );
  }
}
