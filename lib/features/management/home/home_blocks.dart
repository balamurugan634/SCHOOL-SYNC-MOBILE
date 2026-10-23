import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/announcements.dart';
import '../../../data/models/staff/dashboards.dart';
import '../../../data/models/staff/finance.dart';
import '../../../data/models/staff/roll_call.dart';
import '../../../router/routes_management.dart';
import '../../workspace/workspace.dart';
import '../approvals/approval_kinds.dart';
import '../charts/attendance_trend_chart.dart';
import '../charts/chart_text.dart';
import '../charts/hbars.dart';
import '../charts/money_figure.dart';
import '../charts/monthly_money_chart.dart';
import '../attendance/attendance_widgets.dart';

/// Students, staff, parents, classes: two by two on a phone.
class KpiGrid extends StatelessWidget {
  const KpiGrid({super.key, required this.kpis});
  final DashboardKpis kpis;

  @override
  Widget build(BuildContext context) {
    Widget row(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: Gaps.md), Expanded(child: b)]);
    return Column(
      children: [
        row(StatTile(label: 'Students', value: '${kpis.students}', caption: plural(kpis.grades, 'grade')), StatTile(label: 'Classes', value: '${kpis.sections}', caption: 'sections this year')),
        const SizedBox(height: Gaps.md),
        row(StatTile(label: 'Staff', value: '${kpis.staff}'), StatTile(label: 'Parents', value: '${kpis.parents}', caption: 'with a login or linked')),
      ],
    );
  }
}

/// Alerts the API raised (unmarked attendance, licence, insurance). Severity is an icon plus a word, never colour alone.
class AlertsCard extends StatelessWidget {
  const AlertsCard({super.key, required this.alerts});
  final List<DashboardAlert> alerts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SectionCard(
      title: 'Alerts',
      padding: const EdgeInsets.only(bottom: Gaps.xs),
      child: Column(
        children: [
          for (final a in alerts)
            Builder(
              builder: (context) {
                final (icon, word, color) = switch (a.severity) {
                  'critical' => (Icons.error_rounded, 'Critical', t.danger),
                  'warning' => (Icons.warning_amber_rounded, 'Warning', t.warning),
                  _ => (Icons.info_outline_rounded, 'Notice', t.brand.ink),
                };
                final route = appRouteForAlert(a.route);
                return InkWell(
                  onTap: route == null ? null : () => context.push(route),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
                      child: Row(
                        children: [
                          Icon(icon, color: color, size: 22),
                          const SizedBox(width: Gaps.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(word, style: context.text.labelSmall?.copyWith(color: color)),
                                Text(a.message, style: context.text.bodyMedium),
                              ],
                            ),
                          ),
                          if (route != null) Icon(Icons.chevron_right_rounded, color: t.textTertiary),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// "Needs your approval": one row per queue the person can act on, with its count.
class ApprovalsCard extends ConsumerWidget {
  const ApprovalsCard({super.key, required this.counts});
  final ApprovalCounts counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(staffMeProvider);
    final fees = ref.watch(feesEnabledProvider);
    if (me == null) return const SizedBox.shrink();
    final queues = visibleQueues(counts, me, feesEnabled: fees);
    final total = queues.fold<int>(0, (a, q) => a + q.$2);
    return SectionCard(
      title: 'Needs your approval',
      action: 'All',
      onAction: () => context.push(ManagementRoutes.approvals),
      padding: const EdgeInsets.only(bottom: Gaps.xs),
      child: total == 0
          ? const Padding(padding: EdgeInsets.fromLTRB(Gaps.lg, Gaps.xs, Gaps.lg, Gaps.sm), child: QuietLine('Nothing is waiting for a decision.', icon: Icons.check_circle_outline_rounded))
          : Column(
              children: [
                Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.xs), child: Align(alignment: Alignment.centerLeft, child: StatusChip('$total waiting', tone: StatusTone.warning, icon: Icons.hourglass_empty_rounded))),
                for (final (spec, n) in queues)
                  ListRow(
                    title: spec.label,
                    leading: spec.icon,
                    dense: true,
                    onTap: () => context.push(ManagementRoutes.approval(spec.kind)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(label: '$n waiting', excludeSemantics: true, child: Text('$n', style: context.text.titleMedium?.copyWith(color: n > 0 ? context.tokens.text : context.tokens.textTertiary, fontFeatures: const [FontFeature.tabularFigures()]))),
                        Icon(Icons.chevron_right_rounded, color: context.tokens.textTertiary),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Today's attendance: figure, counts, classes marked, and the trend.
class HomeAttendanceCard extends StatelessWidget {
  const HomeAttendanceCard({super.key, required this.attendance, this.onOpen});
  final SchoolAttendance attendance;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = attendance;
    final pct = a.totals.percentPresent;
    final off = !a.isWorkingDay || a.holiday != null;
    return SectionCard(
      title: 'Attendance today',
      action: 'Details',
      onAction: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (off)
            QuietLine(a.holiday != null ? 'Holiday: ${a.holiday}. No roll call is expected today.' : 'Today is not a school day.', icon: Icons.event_outlined)
          else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: Gaps.sm,
              children: [
                Semantics(label: pct == null ? 'No attendance marked yet' : '${pct.toStringAsFixed(1)} percent present', excludeSemantics: true, child: Text(pct == null ? '-' : '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%', style: figureStyle(context, size: 36))),
                Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('present, of ${a.totals.markedStudents} students marked', style: context.text.bodySmall)),
              ],
            ),
            const SizedBox(height: Gaps.sm),
            CountsWrap(counts: a.totals.counts),
            const SizedBox(height: Gaps.md),
            MeterBar(value: a.sectionsTotal == 0 ? 0 : a.sectionsMarked / a.sectionsTotal, label: '${a.sectionsMarked} of ${a.sectionsTotal}', semanticLabel: 'Classes that have marked attendance'),
            const SizedBox(height: 4),
            Text(a.sectionsMarked >= a.sectionsTotal ? 'Every class has marked attendance.' : '${plural(a.sectionsTotal - a.sectionsMarked, 'class', 'classes')} not marked yet.', style: context.text.bodySmall?.copyWith(color: a.sectionsMarked >= a.sectionsTotal ? t.textSecondary : t.warning)),
          ],
          if (a.trend.length > 1) ...[
            const SizedBox(height: Gaps.lg),
            Text('Last ${a.trend.length} school days', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Gaps.sm),
            AttendanceTrendChart(points: a.trend),
          ],
        ],
      ),
    );
  }
}

/// Money at a glance (read-only). Expenses are hidden when the API says the caller may not see them.
class HomeFinanceCard extends StatelessWidget {
  const HomeFinanceCard({super.key, required this.finance, required this.onOpen});
  final FinanceSummary finance;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final f = finance;
    final cur = f.currency;
    Widget fact(String label, int minor, {Color? color}) => Expanded(child: MoneyFact(label: label, minor: minor, currency: cur, color: color, size: 22));
    return SectionCard(
      title: 'Fees',
      action: 'Details',
      onAction: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [fact('Collected', f.netCollectedMinor), const SizedBox(width: Gaps.md), fact('Outstanding', f.outstandingMinor)]),
          const SizedBox(height: Gaps.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fact('Overdue', f.overdueMinor, color: f.overdueMinor > 0 ? t.danger : null),
              const SizedBox(width: Gaps.md),
              if (f.expensesMinor != null) fact('Expenses', f.expensesMinor!) else const Spacer(),
            ],
          ),
          if (f.collectionRatePercent != null) ...[
            const SizedBox(height: Gaps.md),
            Text('Collection rate', style: context.text.labelSmall?.copyWith(color: t.textSecondary)),
            const SizedBox(height: 4),
            MeterBar(value: f.collectionRatePercent! / 100, label: '${f.collectionRatePercent!.toStringAsFixed(1)}%', semanticLabel: 'Collection rate'),
          ],
          if (f.byMonth.isNotEmpty) ...[
            const SizedBox(height: Gaps.lg),
            Text('Collected by month', style: context.text.labelMedium?.copyWith(color: t.textSecondary)),
            const SizedBox(height: Gaps.sm),
            MonthlyMoneyChart(months: f.byMonth, currency: cur, height: 170),
          ],
        ],
      ),
    );
  }
}

class ExamsCard extends StatelessWidget {
  const ExamsCard({super.key, required this.exams, required this.underReview});
  final List<UpcomingExam> exams;
  final int underReview;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Exams',
    padding: const EdgeInsets.only(bottom: Gaps.xs),
    child: Column(
      children: [
        if (exams.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.sm), child: QuietLine('No exams are scheduled.', icon: Icons.event_note_outlined)),
        for (final e in exams)
          ListRow(title: e.name, subtitle: e.startDate == null ? null : 'Starts ${fmtFull(e.startDate!)}', leading: Icons.workspace_premium_outlined, dense: true, chevron: false, trailing: StatusChip(_examLabel(e.status), tone: e.status == 'published' ? StatusTone.success : StatusTone.neutral, icon: e.status == 'published' ? Icons.check_rounded : Icons.event_outlined)),
        if (underReview > 0) Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.sm), child: QuietLine('${plural(underReview, 'exam')} under review.', icon: Icons.rate_review_outlined)),
      ],
    ),
  );
}

String _examLabel(String s) => switch (s) {
  'draft' => 'Draft',
  'scheduled' => 'Scheduled',
  'marks_entry' => 'Marks entry',
  'under_review' => 'Under review',
  'published' => 'Published',
  _ => s,
};

class EnrolmentCard extends StatelessWidget {
  const EnrolmentCard({super.key, required this.byGrade});
  final List<GradeEnrollment> byGrade;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Students by grade',
    child: HorizontalBars(items: [for (final g in byGrade) BarItem(label: g.grade, value: g.students.toDouble(), text: '${g.students}')]),
  );
}

/// Licence trouble, for administrators only (the API sends the block only to people who can see it).
class LicenseBanner extends StatelessWidget {
  const LicenseBanner({super.key, required this.license});
  final LicenseInfo license;

  @override
  Widget build(BuildContext context) {
    final n = licenseNotice(license);
    if (n == null) return const SizedBox.shrink();
    return InfoBanner(tone: n.critical ? BannerTone.danger : BannerTone.warning, icon: Icons.verified_outlined, title: n.title, message: n.message);
  }
}

class HomeAnnouncementsCard extends StatelessWidget {
  const HomeAnnouncementsCard({super.key, required this.block});
  final AnnouncementsBlock block;

  @override
  Widget build(BuildContext context) {
    final items = block.latest.take(3).toList();
    return SectionCard(
      title: 'Announcements',
      action: 'All',
      onAction: () => context.push(ManagementRoutes.announcements),
      padding: const EdgeInsets.only(bottom: Gaps.xs),
      child: Column(
        children: [
          if (block.unreadCount > 0) Padding(padding: const EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.xs), child: Align(alignment: Alignment.centerLeft, child: StatusChip('${block.unreadCount} unread', tone: StatusTone.brand))),
          if (items.isEmpty) const Padding(padding: EdgeInsets.fromLTRB(Gaps.lg, 0, Gaps.lg, Gaps.sm), child: QuietLine('No announcements yet.', icon: Icons.campaign_outlined)),
          for (final a in items) _AnnouncementRow(a),
        ],
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow(this.a);
  final Announcement a;

  @override
  Widget build(BuildContext context) => ListRow(
    title: a.title,
    subtitle: [if (a.publishAt != null) fmtShort(a.publishAt!), if (a.authorName != null) a.authorName!].join('  ·  '),
    leading: a.urgent ? Icons.priority_high_rounded : Icons.campaign_outlined,
    dense: true,
    trailing: a.urgent ? const StatusChip('Urgent', tone: StatusTone.danger, icon: Icons.priority_high_rounded) : null,
    onTap: () => context.push(ManagementRoutes.announcements),
  );
}
