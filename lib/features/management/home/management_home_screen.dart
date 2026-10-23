import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/util/format.dart';
import '../../../data/models/staff/dashboards.dart';
import '../../../data/repositories/staff/staff_dashboard_repository.dart';
import '../../../router/routes.dart';
import '../../../router/routes_management.dart';
import '../../auth/session.dart';
import '../../home/home_header.dart';
import '../../security/secure_scope.dart';
import '../../workspace/workspace.dart';
import '../approvals/approval_kinds.dart';
import '../charts/chart_text.dart' show licenseNotice;
import 'home_blocks.dart';
import 'management_home_providers.dart';

/// The staggered reveal runs on the first dashboard load only (design.md section 9).
bool _homeRevealed = false;

/// Home for principals, administrators, accounts and the office. Every block is hidden when the API returns null for it.
class ManagementHomeScreen extends ConsumerWidget {
  const ManagementHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final value = ref.watch(managementDashboardProvider);
    final header = HomeHeader(me: me, info: session.siteInfo);

    Future<void> refresh() async {
      ref.invalidate(managementDashboardProvider);
      try {
        await ref.read(managementDashboardProvider.future);
      } catch (_) {}
    }

    final children = <Widget>[header];
    if (value.hasValue) {
      children.add(_Blocks(loaded: value.requireValue, stale: value.hasError ? value.error : null, onRetry: refresh));
    } else if (value.hasError) {
      children.add(SizedBox(height: 420, child: ErrorState(error: value.error!, onRetry: () => ref.invalidate(managementDashboardProvider))));
    } else {
      children.add(const Padding(padding: EdgeInsets.only(top: Gaps.lg), child: _HomeSkeleton()));
    }

    // Fee figures are on this screen for roles that may see finance: no screenshots then (README, Security).
    final showsFinance = ref.watch(feesEnabledProvider) && value.value?.value.finance != null;
    return SecureScope(
      secure: showsFinance,
      child: RefreshOnFocus(
        onRefresh: () => ref.invalidate(managementDashboardProvider),
        child: RefreshIndicator(
          onRefresh: refresh,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: EdgeInsets.zero, children: children),
        ),
      ),
    );
  }
}

class _Blocks extends ConsumerWidget {
  const _Blocks({required this.loaded, required this.onRetry, this.stale});
  final Loaded<ManagementDashboard> loaded;
  final Object? stale;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = loaded.value;
    final info = ref.watch(sessionProvider.select((s) => s.siteInfo));
    final fees = ref.watch(feesEnabledProvider);
    final firstLoad = !_homeRevealed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _homeRevealed = true);
    var n = 0;
    Widget stage(Widget w) {
      final i = n++;
      return Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: firstLoad ? w.reveal(index: i) : w);
    }

    final me = ref.watch(staffMeProvider);
    final queues = me != null && visibleQueues(d.approvals, me, feesEnabled: fees).isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, Gaps.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (info?.readOnly ?? false) const Padding(padding: EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, title: 'View-only mode', message: 'Your school\'s subscription has ended. You can read information, but changes are disabled until it is renewed.')),
          if (loaded.fromCache)
            Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, icon: Icons.cloud_off_rounded, message: 'You are offline. Showing the overview saved ${loaded.at == null ? 'earlier' : 'at ${fmtDateTime(loaded.at!)}'}.', action: 'Try again', onAction: onRetry))
          else if (stale != null)
            Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: InfoBanner(tone: BannerTone.warning, icon: Icons.sync_problem_rounded, message: 'Could not refresh. Showing what was loaded last.', action: 'Try again', onAction: onRetry)),
          if (d.license != null && licenseNotice(d.license) != null) Padding(padding: const EdgeInsets.only(bottom: Gaps.md), child: LicenseBanner(license: d.license!)),
          stage(KpiGrid(kpis: d.kpis)),
          if (d.alerts.isNotEmpty) stage(AlertsCard(alerts: d.alerts)),
          if (queues) stage(ApprovalsCard(counts: d.approvals)),
          if (d.attendance != null) stage(HomeAttendanceCard(attendance: d.attendance!, onOpen: () => context.push(ManagementRoutes.attendance))),
          if (d.finance != null && fees) stage(HomeFinanceCard(finance: d.finance!, onOpen: () => context.go(Routes.tab(3)))),
          if (d.upcomingExams != null) stage(ExamsCard(exams: d.upcomingExams!, underReview: d.examsUnderReview)),
          if (d.enrollmentByGrade.isNotEmpty) stage(EnrolmentCard(byGrade: d.enrollmentByGrade)),
          stage(HomeAnnouncementsCard(block: d.announcements)),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      Padding(
        padding: EdgeInsets.symmetric(horizontal: Gaps.page),
        child: Row(children: [Expanded(child: StatTile(label: 'Students')), SizedBox(width: Gaps.md), Expanded(child: StatTile(label: 'Classes'))]),
      ),
      SizedBox(height: Gaps.md),
      SkeletonList(count: 3),
    ],
  );
}
