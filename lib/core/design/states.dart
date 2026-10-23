import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../network/app_exception.dart';
import 'app_card.dart';
import 'buttons.dart';
import 'illustration.dart';
import 'theme.dart';
import 'tokens.dart';

/// Applies neutral shimmer colours to every [Skeletonizer] below.
class AppSkeletonTheme extends StatelessWidget {
  const AppSkeletonTheme({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SkeletonizerConfig(
      data: SkeletonizerConfigData(
        effectResolver: (_) => ShimmerEffect(baseColor: t.subtle, highlightColor: t.surface, duration: const Duration(milliseconds: 1400)),
        justifyMultiLineText: false,
        containersColor: Colors.transparent,
        ignoreContainers: true,
        textBorderRadius: const TextBoneBorderRadius.fromHeightFactor(.3),
      ),
      child: child,
    );
  }
}

/// Plain state: a grey 20 dp icon, one sentence, at most one action.
class _PlainState extends StatelessWidget {
  const _PlainState({this.illo, required this.icon, required this.title, this.message, this.actionLabel, this.actionIcon, this.onAction, this.compact = false});

  final Illo? illo;
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Gaps.xxl, vertical: compact ? Gaps.xl : Gaps.huge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illo != null) IllustrationView(illo!, width: compact ? 160 : 200, decorative: true) else Icon(icon, size: 24, color: t.textTertiary),
            const SizedBox(height: Gaps.md),
            Text(title, textAlign: TextAlign.center, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(message!, textAlign: TextAlign.center, style: context.text.bodySmall?.copyWith(fontSize: 14, height: 20 / 14)),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: Gaps.lg),
              SizedBox(width: 200, child: SecondaryButton(label: actionLabel!, icon: actionIcon, onPressed: onAction)),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, this.illo, this.icon = Icons.inbox_outlined, required this.title, this.message, this.actionLabel, this.onAction, this.compact = false});

  final Illo? illo;
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) => _PlainState(illo: illo, icon: icon, title: title, message: message, actionLabel: actionLabel, onAction: onAction, compact: compact);
}

/// Friendly error with retry. Understands [AppException] kinds.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ex = AppException.from(error);
    final offline = ex.kind == ErrorKind.network || ex.kind == ErrorKind.timeout;
    final (icon, title, message) = switch (ex.kind) {
      ErrorKind.network || ErrorKind.timeout => (Icons.wifi_off_rounded, 'You are offline', 'Check your connection and try again.'),
      ErrorKind.forbidden => (Icons.lock_outline_rounded, 'No access', 'Your account does not have access to this.'),
      ErrorKind.notFound => (Icons.search_off_rounded, 'Not found', 'We could not find what you were looking for.'),
      ErrorKind.subscriptionExpired => (Icons.event_busy_rounded, 'Changes are disabled', ex.displayMessage),
      ErrorKind.server => (Icons.cloud_off_rounded, 'The server is having trouble', 'Please try again in a moment.'),
      _ => (Icons.error_outline_rounded, 'Something went wrong', ex.displayMessage),
    };
    return _PlainState(illo: offline ? Illo.errorOffline : null, icon: icon, title: title, message: message, actionLabel: onRetry == null ? null : 'Try again', actionIcon: Icons.refresh_rounded, onAction: onRetry, compact: compact);
  }
}

/// Slim banner shown while the device has no connection.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.visible});
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedSize(
      duration: Motion.base,
      alignment: Alignment.topCenter,
      child: visible
          ? Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                color: t.warningTint,
                padding: const EdgeInsets.symmetric(horizontal: Gaps.page, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 16, color: t.warning),
                    const SizedBox(width: 8),
                    Expanded(child: Text('You are offline. Showing what was saved on this device.', style: context.text.labelMedium?.copyWith(color: t.warning))),
                  ],
                ),
              ),
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

/// A generic loading list of card-shaped bones.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.padding = const EdgeInsets.symmetric(horizontal: Gaps.page)});
  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Padding(
        padding: padding,
        child: Column(
          children: List.generate(
            count,
            (i) => const Padding(
              padding: EdgeInsets.only(bottom: Gaps.sm),
              child: AppCard(
                child: Row(
                  children: [
                    Bone.circle(size: 40),
                    SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Bone.text(words: 3), SizedBox(height: 6), Bone.text(words: 5, fontSize: 12)])),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Phase-1 stand-in for a feature that is coming online: one quiet card, no faux layout.
class ComingSoonCard extends StatelessWidget {
  const ComingSoonCard({super.key, required this.title, required this.message, this.points = const [], this.label = 'Coming soon'});

  final String title;
  final String message;
  final List<String> points;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppCard(
      tone: CardTone.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.titleMedium)),
              Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.subtle, borderRadius: Radii.badge),
                child: Text(label, style: context.text.labelSmall?.copyWith(color: t.textSecondary, height: 1)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: context.text.bodySmall?.copyWith(fontSize: 14, height: 20 / 14)),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 8, right: 10), child: Container(width: 4, height: 4, decoration: BoxDecoration(color: t.textTertiary, shape: BoxShape.circle))),
                    Expanded(child: Text(p, style: context.text.bodyMedium)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
