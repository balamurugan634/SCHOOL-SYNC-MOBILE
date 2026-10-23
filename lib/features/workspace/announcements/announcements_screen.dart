import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/design.dart';
import '../../../core/paged.dart';
import '../../../data/models/staff/comms.dart';
import '../workspace.dart';
import 'announcement_logic.dart';
import 'announcement_paths.dart';
import 'announcement_providers.dart';
import 'announcement_widgets.dart';

const _filters = <(String?, String)>[(null, 'All'), ('draft', 'Drafts'), ('scheduled', 'Scheduled'), ('published', 'Published'), ('archived', 'Archived')];

/// Announcements the signed-in person manages (their own, or everyone's with school-scope editing).
/// Shared by teachers and management; paths follow the current experience.
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  String? _state;
  bool _mine = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(staffMeProvider);
    final paths = AnnouncementPaths.of(me?.experience);
    final canCreate = ref.can('announcements:create');
    final schoolScope = ref.canSchool('announcements:edit') || ref.canSchool('announcements:create');
    final readOnly = ref.watch(readOnlyProvider);
    final query = (state: _state, mine: _mine);
    final provider = managedAnnouncementsProvider(query);
    final value = ref.watch(provider);

    Future<void> refresh() async {
      ref.invalidate(provider);
      try {
        await ref.read(provider.future);
      } catch (_) {}
    }

    return FeatureGate(
      label: 'Announcements',
      anyPermission: const ['announcements:create', 'announcements:edit', 'announcements:publish', 'announcements:view'],
      child: StaffFrame(
        title: 'Announcements',
        fab: canCreate
            ? FloatingActionButton.extended(
                onPressed: readOnly ? null : () => context.push(paths.create),
                icon: const Icon(Icons.add_rounded),
                label: const Text('New announcement'),
                tooltip: readOnly ? 'View-only mode' : 'Write a new announcement',
              )
            : null,
        headerExtra: Column(
          children: [
            const SizedBox(height: Gaps.sm),
            FilterChips<String?>(options: [for (final f in _filters) f.$1], selected: _state, onSelected: (s) => setState(() => _state = s), labelOf: (s) => _filters.firstWhere((f) => f.$1 == s).$2),
            if (schoolScope)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.xs, Gaps.page, 0),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Only the ones I wrote'),
                  value: _mine,
                  onChanged: (v) => setState(() => _mine = v),
                ),
              ),
            const SizedBox(height: Gaps.xs),
          ],
        ),
        body: AsyncBody<PagedList<ManagedAnnouncement>>(
          value: value,
          onRetry: () => ref.invalidate(provider),
          isEmpty: (p) => p.items.isEmpty,
          empty: _Empty(filtered: _state != null || _mine, canCreate: canCreate && !readOnly, onCreate: () => context.push(paths.create), onClear: () => setState(() {
            _state = null;
            _mine = false;
          })),
          data: (p) => RefreshScroll(
            onRefresh: refresh,
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.sm, Gaps.page, 96),
            children: [
              const ReadOnlyBanner(),
              RowGroup(
                children: [
                  for (final a in p.items) _AnnouncementRow(a, onTap: () => context.push(paths.detail(a.id))),
                ],
              ),
              LoadMoreFooter(paged: p, onMore: () => ref.read(provider.notifier).loadMore()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered, required this.canCreate, required this.onCreate, required this.onClear});
  final bool filtered;
  final bool canCreate;
  final VoidCallback onCreate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => filtered
      ? EmptyState(illo: Illo.noResults, title: 'No announcements match this filter', actionLabel: 'Show all', onAction: onClear)
      : EmptyState(illo: Illo.emptyGeneric, title: 'No announcements yet', message: 'Announcements you write appear here, with who has read them.', actionLabel: canCreate ? 'New announcement' : null, onAction: canCreate ? onCreate : null);
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow(this.a, {required this.onTap});
  final ManagedAnnouncement a;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final counts = [
      if (a.isPublished && a.readCount != null) 'Read by ${a.readCount}',
      if (a.isPublished && a.requiresAck && a.ackCount != null) 'Acknowledged by ${a.ackCount}',
    ].join('  ·  ');
    return Semantics(
      button: true,
      label: '${a.title}. ${a.state}. ${describeAudience(a.audience)}. $counts',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Wrap(spacing: 6, runSpacing: 4, children: [AnnouncementStateChip(a), PriorityChip(a.priority)]),
                      const SizedBox(height: 4),
                      Text('For ${describeAudience(a.audience)}', maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                      if (counts.isNotEmpty) Text(counts, style: context.text.labelSmall?.copyWith(color: t.textTertiary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: t.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
