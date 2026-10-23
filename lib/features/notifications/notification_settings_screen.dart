import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/network/app_exception.dart';
import '../../data/models/notifications.dart';
import '../../data/repositories/notifications_repository.dart';
import 'inbox_providers.dart';

/// Which categories push / email you (saved per switch). Quiet hours are set by the school.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen> {
  final Map<String, NotificationPref> _local = {};

  Future<void> _set(NotificationPref p) async {
    setState(() => _local[p.category] = p);
    try {
      await ref.read(notificationsRepositoryProvider).savePreference(p);
    } catch (e) {
      ref.invalidate(notificationPrefsProvider);
      if (mounted) {
        setState(() => _local.remove(p.category));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppException.from(e).displayMessage)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = ref.watch(notificationPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: AsyncBody<List<NotificationPref>>(
        value: v,
        onRetry: () => ref.invalidate(notificationPrefsProvider),
        data: (prefs) => RefreshScroll(
          onRefresh: () async => ref.invalidate(notificationPrefsProvider),
          children: [
            Text('Choose how each kind of message reaches you. Details are always hidden on the lock screen.', style: context.text.bodyMedium),
            const SizedBox(height: Gaps.lg),
            RowGroup(
              children: [
                for (final base in prefs)
                  Builder(builder: (_) {
                    final p = _local[base.category] ?? base;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.label, style: context.text.titleSmall),
                          Row(children: [
                            Expanded(child: Row(children: [Switch(value: p.push, onChanged: (x) => _set(p.copyWith(push: x))), const SizedBox(width: 6), const Text('Push')])),
                            Expanded(child: Row(children: [Switch(value: p.email, onChanged: (x) => _set(p.copyWith(email: x))), const SizedBox(width: 6), const Text('Email')])),
                          ]),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
