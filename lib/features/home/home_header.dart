import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/util/format.dart';
import '../../data/models/me.dart';
import '../../data/models/site_info.dart';
import '../../router/routes.dart';
import '../notifications/notifications_providers.dart';
import 'child_selector.dart';

String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 5) return 'Good night';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// Plain home header on the page background: school name row, greeting and date.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, required this.me, required this.info});

  final Me me;
  final SiteInfo? info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final now = appNow();
    final unread = ref.watch(notificationsUnreadProvider).value ?? 0;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: t.surface, border: Border(bottom: BorderSide(color: t.border))),
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + Gaps.md, bottom: Gaps.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gaps.page),
            child: Row(
              children: [
                SchoolLogo(info: info, size: 32),
                const SizedBox(width: 10),
                Expanded(child: Text(info?.name ?? 'SchoolSync', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
                IconButton(
                  tooltip: unread > 0 ? 'Notifications, $unread unread' : 'Notifications',
                  onPressed: () => context.push(Routes.notifications),
                  icon: unread > 0 ? Badge.count(count: unread, child: const Icon(Icons.notifications_none_rounded)) : const Icon(Icons.notifications_none_rounded),
                ),
                GestureDetector(
                  onTap: () => context.push(Routes.settings),
                  child: Padding(padding: const EdgeInsets.only(left: 4), child: UserAvatar(name: me.displayName, url: me.avatarUrl, size: 36, ringColor: t.roleTint(me.experience))),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.page, Gaps.lg, Gaps.page, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${greetingFor(now)}, ${me.firstName}', style: context.text.headlineMedium),
                const SizedBox(height: 2),
                Text(DateFormat('EEEE, d MMMM').format(now), style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
              ],
            ),
          ),
          if (me.experience == Experience.parent) ...[const SizedBox(height: Gaps.lg), const ChildSelector()],
        ],
      ),
    );
  }
}
