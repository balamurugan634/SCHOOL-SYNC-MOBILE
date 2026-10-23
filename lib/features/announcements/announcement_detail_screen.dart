import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../core/util/format.dart';
import '../../data/models/announcements.dart';
import '../../data/repositories/announcements_repository.dart';
import '../../data/repositories/files_repository.dart';
import '../auth/session.dart';
import '../dashboard/dashboard_providers.dart';
import '../notifications/notifications_providers.dart';
import 'announcements_providers.dart';

/// One announcement. Opening it marks it read; if it asks for confirmation there is an "I have read this" button.
class AnnouncementDetailScreen extends ConsumerStatefulWidget {
  const AnnouncementDetailScreen({super.key, required this.id});
  final String id;

  @override
  ConsumerState<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends ConsumerState<AnnouncementDetailScreen> {
  bool _acking = false;
  bool _markedRead = false;

  Future<void> _markRead(Announcement a) async {
    if (_markedRead || a.read) return;
    _markedRead = true;
    try {
      await ref.read(announcementsRepositoryProvider).markRead(a.id);
      for (final unreadOnly in [false, true]) {
        ref.read(announcementsProvider(unreadOnly).notifier).mark(a.id, read: true);
      }
      ref.invalidate(studentDashboardProvider);
      ref.invalidate(parentDashboardProvider);
      ref.invalidate(notificationsUnreadProvider);
    } catch (_) {
      _markedRead = false;
    }
  }

  Future<void> _ack(Announcement a) async {
    setState(() => _acking = true);
    try {
      await ref.read(announcementsRepositoryProvider).acknowledge(a.id);
      ref.invalidate(announcementDetailProvider(a.id));
      for (final unreadOnly in [false, true]) {
        ref.read(announcementsProvider(unreadOnly).notifier).mark(a.id, read: true, acknowledged: true);
      }
      ref.invalidate(studentDashboardProvider);
      ref.invalidate(parentDashboardProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
    } finally {
      if (mounted) setState(() => _acking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(announcementDetailProvider(widget.id));
    final readOnly = ref.watch(sessionProvider.select((s) => s.siteInfo?.readOnly ?? false));
    final t = context.tokens;
    return Scaffold(
      appBar: AppBar(title: const Text('Announcement')),
      body: AsyncBody<Announcement>(
        value: v,
        onRetry: () => ref.invalidate(announcementDetailProvider(widget.id)),
        data: (a) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _markRead(a));
          return RefreshScroll(
            onRefresh: () async => ref.invalidate(announcementDetailProvider(widget.id)),
            children: [
              if (a.urgent || a.important) Padding(padding: const EdgeInsets.only(bottom: Gaps.sm), child: Align(alignment: Alignment.centerLeft, child: StatusChip(a.urgent ? 'Urgent' : 'Important', tone: a.urgent ? StatusTone.danger : StatusTone.warning, icon: Icons.priority_high_rounded))),
              Text(a.title, style: context.text.headlineMedium),
              const SizedBox(height: 4),
              Text([if (a.authorName != null) a.authorName!, if (a.publishAt != null) fmtDateTime(a.publishAt!)].join('  ·  '), style: context.text.bodySmall),
              const SizedBox(height: Gaps.lg),
              Text(a.body, style: context.text.bodyLarge),
              if (a.attachments.isNotEmpty) ...[
                const GroupLabel('Attachments'),
                RowGroup(children: [for (final f in a.attachments) ListRow(title: f.name, subtitle: fileSize(f.sizeBytes), leading: Icons.attach_file_rounded, chevron: false, trailing: const Icon(Icons.open_in_new_rounded, size: 18), onTap: () => ref.read(filesRepositoryProvider).openStored(f))]),
              ],
              if (a.requiresAck) ...[
                const SizedBox(height: Gaps.xl),
                if (a.acknowledged)
                  Row(children: [Icon(Icons.check_circle_rounded, color: t.success, size: 20), const SizedBox(width: 8), Text('You confirmed you have read this', style: context.text.bodyMedium?.copyWith(color: t.success))])
                else if (readOnly)
                  const InfoBanner(tone: BannerTone.warning, message: 'Confirming is disabled while the school subscription is inactive.')
                else ...[
                  const InfoBanner(message: 'The school asks you to confirm that you have read this.'),
                  const SizedBox(height: Gaps.md),
                  PrimaryButton(label: 'I have read this', icon: Icons.check_rounded, loading: _acking, onPressed: () => _ack(a)),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
