import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/online_meeting.dart';
import '../util/external_launcher.dart';
import 'app_card.dart';
import 'banners.dart';
import 'buttons.dart';
import 'status_chip.dart';
import 'theme.dart';
import 'tokens.dart';

/// "Online" badge for list rows. Callers show it only when `onlineMeeting?.isScheduled` is true.
class OnlineChip extends StatelessWidget {
  const OnlineChip({super.key});

  @override
  Widget build(BuildContext context) => const StatusChip('Online', tone: StatusTone.info, icon: Icons.videocam_outlined);
}

IconData _providerIcon(OnlineProvider p) => switch (p) {
  OnlineProvider.google => Icons.video_camera_front_outlined,
  OnlineProvider.zoom => Icons.videocam_outlined,
};

/// The video call of an event or a parent-teacher meeting.
///
/// * scheduled: provider, **Join meeting**, Copy link, the passcode (copyable) and, for staff who may edit, **Start meeting**.
/// * failed: a calm notice that the school has to retry.
/// * cancelled: a muted line, no buttons.
///
/// Links are opened outside the app and only when they are `https` (see [httpsUri]). Layout never uses fixed heights,
/// so it grows with the user's text size.
class OnlineMeetingCard extends ConsumerWidget {
  const OnlineMeetingCard({super.key, required this.meeting});
  final OnlineMeeting meeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    switch (meeting.status) {
      case OnlineMeetingStatus.failed:
        return const InfoBanner(message: 'The online meeting could not be created. Ask the school to retry.', icon: Icons.videocam_off_outlined);
      case OnlineMeetingStatus.cancelled:
        return Semantics(
          container: true,
          child: AppCard(
            tone: CardTone.subtle,
            padding: const EdgeInsets.symmetric(horizontal: Gaps.lg, vertical: Gaps.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.videocam_off_outlined, size: 20, color: t.textTertiary),
                const SizedBox(width: Gaps.md),
                Expanded(child: Text('This online meeting was cancelled', style: context.text.bodyMedium?.copyWith(color: t.textSecondary))),
              ],
            ),
          ),
        );
      case OnlineMeetingStatus.scheduled:
        return _Scheduled(meeting: meeting);
    }
  }
}

class _Scheduled extends ConsumerWidget {
  const _Scheduled({required this.meeting});
  final OnlineMeeting meeting;

  Future<void> _open(BuildContext context, WidgetRef ref, String? url) async {
    final messenger = ScaffoldMessenger.of(context);
    final launcher = ref.read(externalLauncherProvider);
    final uri = httpsUri(url);
    final opened = uri != null && await launcher.open(uri);
    if (!opened) messenger.showSnackBar(const SnackBar(content: Text('The meeting link could not be opened. Copy the link and open it in your browser.')));
  }

  Future<void> _copy(BuildContext context, String text, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text(done)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final join = httpsUri(meeting.joinUrl) == null ? null : meeting.joinUrl!.trim();
    final start = httpsUri(meeting.startUrl) == null ? null : meeting.startUrl!.trim();
    final passcode = meeting.passcode;
    final provider = meeting.provider.label;
    return Semantics(
      container: true,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(_providerIcon(meeting.provider), size: 24, color: t.accentInk),
                const SizedBox(width: Gaps.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Online meeting', style: context.text.bodySmall),
                      Text(provider, style: context.text.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            if (join != null) ...[
              const SizedBox(height: Gaps.lg),
              PrimaryButton(label: 'Join meeting', icon: Icons.videocam_rounded, onPressed: () => _open(context, ref, join)),
              const SizedBox(height: Gaps.sm),
              SecondaryButton(label: 'Copy link', icon: Icons.link_rounded, onPressed: () => _copy(context, join, 'Meeting link copied')),
            ] else ...[
              const SizedBox(height: Gaps.md),
              Text('The meeting link is not available yet.', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
            ],
            if (passcode != null) ...[
              const SizedBox(height: Gaps.md),
              AppCard(
                tone: CardTone.subtle,
                padding: const EdgeInsets.only(left: Gaps.lg, top: Gaps.xs, bottom: Gaps.xs, right: Gaps.xs),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Passcode', style: context.text.bodySmall),
                          Text(passcode, style: context.text.titleMedium?.copyWith(letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy passcode',
                      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () => _copy(context, passcode, 'Passcode copied'),
                    ),
                  ],
                ),
              ),
            ],
            if (start != null) ...[
              const SizedBox(height: Gaps.md),
              Semantics(hint: 'Host link, opens the meeting as the host', child: SecondaryButton(label: 'Start meeting', icon: Icons.play_arrow_rounded, onPressed: () => _open(context, ref, start))),
            ],
          ],
        ),
      ),
    );
  }
}
