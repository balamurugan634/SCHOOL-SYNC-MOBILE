import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/security/biometric_service.dart';
import '../auth/session.dart';
import 'app_lock.dart';

/// Wraps the whole app to
///  1. hide the UI behind a branded cover whenever the app is not in the foreground, so the
///     app-switcher thumbnail and screen mirroring never show school data, and
///  2. engage the biometric app lock when the person comes back after the configured time.
class LifecycleGate extends ConsumerStatefulWidget {
  const LifecycleGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<LifecycleGate> createState() => _LifecycleGateState();
}

class _LifecycleGateState extends ConsumerState<LifecycleGate> with WidgetsBindingObserver {
  bool _covered = false;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        if (!BiometricService.promptActive && ref.read(sessionProvider).signedIn) setState(() => _covered = true);
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _backgroundedAt ??= DateTime.now();
        if (ref.read(sessionProvider).signedIn) setState(() => _covered = true);
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && !BiometricService.promptActive) {
          final lock = ref.read(appLockProvider);
          if (lock.enabled && DateTime.now().difference(since) >= Duration(minutes: lock.minutes)) {
            ref.read(sessionProvider.notifier).lock();
          }
        }
        setState(() => _covered = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(sessionProvider.select((s) => s.siteInfo));
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_covered)
          Positioned.fill(
            child: ColoredBox(
              color: context.tokens.bg,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SchoolLogo(info: info, size: 56),
                    const SizedBox(height: Gaps.md),
                    DefaultTextStyle(
                      style: TextStyle(fontFamily: kFontFamily, fontSize: 16, fontWeight: FontWeight.w600, color: context.tokens.text, decoration: TextDecoration.none),
                      child: Text(info?.displayName ?? 'SchoolSync'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

