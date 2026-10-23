import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/design.dart';
import '../../core/providers.dart';
import '../../data/models/auth_models.dart';
import '../security/secure_scope.dart';

final sessionsProvider = FutureProvider.autoDispose<List<SessionInfo>>((ref) => ref.watch(authRepositoryProvider).sessions());

/// Devices signed in to this account, with remote sign-out.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  static String relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Active now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays < 7) return '${d.inDays} d ago';
    return DateFormat('d MMM y').format(t);
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, SessionInfo s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out this device?'),
        content: Text('${s.deviceName ?? 'This device'} will need the password to sign in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(authRepositoryProvider).revokeSession(s.id);
      ref.invalidate(sessionsProvider);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not sign out that device. Try again.')));
    }
  }

  Future<void> _revokeOthers(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).revokeOthers();
      ref.invalidate(sessionsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out of all other devices.')));
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not complete that. Try again.')));
    }
  }

  IconData _icon(String platform) => switch (platform) {
    'android' => Icons.android_rounded,
    'ios' => Icons.phone_iphone_rounded,
    _ => Icons.laptop_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    return SecureScope(
      child: Scaffold(
        appBar: AppBar(title: const Text('Signed-in devices')),
        body: RefreshIndicator(
          onRefresh: () async => ref.refresh(sessionsProvider.future),
          child: sessions.when(
            loading: () => const SingleChildScrollView(physics: AlwaysScrollableScrollPhysics(), child: Padding(padding: EdgeInsets.only(top: 8), child: SkeletonList(count: 3))),
            error: (e, _) => ListView(children: [SizedBox(height: 420, child: ErrorState(error: e, onRetry: () => ref.invalidate(sessionsProvider)))]),
            data: (list) => ListView(
              padding: const EdgeInsets.fromLTRB(Gaps.page, 8, Gaps.page, Gaps.huge),
              children: [
                Text('These are the devices where your account is signed in. Sign out any you do not recognise.', style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: Gaps.lg),
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Gaps.sm),
                    child: AppCard(
                      child: Row(
                        children: [
                          Icon(_icon(s.platform), color: context.tokens.textSecondary),
                          const SizedBox(width: Gaps.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(child: Text(s.deviceName ?? (s.platform == 'web' ? 'Web browser' : 'Unknown device'), style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  if (s.current) ...[const SizedBox(width: 8), const StatusChip('This device', tone: StatusTone.success)],
                                ]),
                                const SizedBox(height: 2),
                                Text('${relative(s.lastUsedAt)}${s.appVersion != null ? ' · v${s.appVersion}' : ''}', style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          if (!s.current) IconButton(tooltip: 'Sign out this device', icon: const Icon(Icons.logout_rounded), onPressed: () => _revoke(context, ref, s)),
                        ],
                      ),
                    ),
                  ),
                if (list.length > 1) ...[
                  const SizedBox(height: Gaps.sm),
                  SecondaryButton(label: 'Sign out all other devices', icon: Icons.devices_other_rounded, onPressed: () => _revokeOthers(context, ref)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
