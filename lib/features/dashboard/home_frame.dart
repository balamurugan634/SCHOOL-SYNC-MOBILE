import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../auth/session.dart';
import '../home/home_header.dart';

/// The shared frame of the student and parent homes: header, pull-to-refresh, stale/offline note,
/// and the staggered reveal (first load only).
class HomeFrame extends ConsumerWidget {
  const HomeFrame({super.key, required this.children, required this.onRefresh, this.staleSince, this.error});

  final List<Widget> children;
  final Future<void> Function() onRefresh;

  /// Set when the content is a saved copy (offline).
  final DateTime? staleSince;
  final Object? error;

  static bool _revealed = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();
    final first = !_revealed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealed = true);

    final notes = <Widget>[
      if (session.siteInfo?.readOnly ?? false)
        const InfoBanner(tone: BannerTone.warning, icon: Icons.event_busy_rounded, title: 'View-only mode', message: 'Your school\'s subscription has ended. You can read information, but changes are disabled until it is renewed.'),
      if (staleSince != null)
        InfoBanner(tone: BannerTone.warning, icon: Icons.cloud_off_rounded, message: 'You are offline. Showing what was saved at ${_clock(staleSince!)}.'),
      if (staleSince == null && error != null)
        InfoBanner(tone: BannerTone.warning, icon: AppException.from(error!).isNetwork ? Icons.cloud_off_rounded : Icons.sync_problem_rounded, message: 'Could not refresh. Pull down to try again.'),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(child: HomeHeader(me: me, info: session.siteInfo)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, Gaps.huge),
            sliver: SliverList.separated(
              itemCount: notes.length + children.length,
              separatorBuilder: (_, _) => const SizedBox(height: Gaps.md),
              itemBuilder: (_, i) {
                final w = i < notes.length ? notes[i] : children[i - notes.length];
                return first && i < 6 ? w.reveal(index: i) : w;
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(DateTime d) => '${d.hour % 12 == 0 ? 12 : d.hour % 12}:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'am' : 'pm'}';
}
