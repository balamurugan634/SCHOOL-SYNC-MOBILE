import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../data/models/me.dart';
import '../auth/session.dart';
import '../home/child_selector.dart';
import 'role_nav.dart';

/// A tab whose real content is coming online: a clear header and one quiet card.
/// Permission and school-feature gating already work.
class TabScreen extends ConsumerWidget {
  const TabScreen({super.key, required this.spec});
  final TabSpec spec;

  /// The "not turned on" / "no access" view for a tab, or null when the tab can be used.
  static Widget? blockedView(TabSpec spec, AppSession session) {
    final me = session.me;
    if (me == null) return null;
    if (!spec.enabledAt(session.siteInfo)) {
      return EmptyState(icon: Icons.toggle_off_outlined, title: '${spec.label} is not turned on', message: '${session.siteInfo?.displayName ?? 'Your school'} has not enabled this yet.');
    }
    if (!spec.allowedFor(me)) {
      return EmptyState(icon: Icons.lock_outline_rounded, title: 'No access', message: 'Your role does not include ${spec.label.toLowerCase()}. Ask your school office if you think this is a mistake.');
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final me = session.me;
    if (me == null) return const SizedBox.shrink();

    final blocked = blockedView(spec, session);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(child: PageHeader(title: spec.title, subtitle: spec.subtitle)),
        if (me.experience == Experience.parent) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.only(bottom: Gaps.sm), child: ChildSelector())),
        if (blocked != null)
          SliverFillRemaining(hasScrollBody: false, child: blocked)
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, Gaps.huge),
            sliver: SliverToBoxAdapter(
              child: ComingSoonCard(
                title: spec.title,
                message: 'This section is being set up and will appear here once it is ready.',
                points: [for (final f in spec.features) f.title],
              ).reveal(),
            ),
          ),
      ],
    );
  }
}

/// Page title (22 / 28, 600) with a one-line description.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(Gaps.page, MediaQuery.paddingOf(context).top + Gaps.lg, Gaps.page, Gaps.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: context.text.headlineMedium)),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: context.text.bodyMedium?.copyWith(color: context.tokens.textSecondary)),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
