import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/push/push_service.dart';
import '../../core/security/biometric_service.dart';
import '../auth/session.dart';
import '../security/app_lock.dart';
import 'primer_scaffold.dart';

/// Primer 1: why notifications are useful, then the system permission prompt.
class NotificationsPrimerScreen extends ConsumerStatefulWidget {
  const NotificationsPrimerScreen({super.key});

  @override
  ConsumerState<NotificationsPrimerScreen> createState() => _NotificationsPrimerScreenState();
}

class _NotificationsPrimerScreenState extends ConsumerState<NotificationsPrimerScreen> {
  bool _loading = false;

  Future<void> _enable() async {
    setState(() => _loading = true);
    try {
      await ref.read(pushServiceProvider).enable();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await ref.read(sessionProvider.notifier).advancePrimer();
  }

  @override
  Widget build(BuildContext context) => PrimerScaffold(
    step: 1,
    total: 2,
    icon: Icons.notifications_none_rounded,
    title: 'Turn on notifications',
    body: 'Get a message when something needs your attention. You can change this at any time in Settings.',
    bullets: const [
      (Icons.fact_check_outlined, 'Attendance and absence alerts'),
      (Icons.assignment_outlined, 'Homework and exam reminders'),
      (Icons.campaign_outlined, 'Announcements, fee dues and events'),
    ],
    footnote: 'Details are hidden on your lock screen.',
    primaryLabel: 'Turn on notifications',
    onPrimary: _enable,
    loading: _loading,
    secondaryLabel: 'Not now',
    onSecondary: () => ref.read(sessionProvider.notifier).advancePrimer(),
  );
}

/// Primer 2: optional Face / Fingerprint app lock.
class BiometricPrimerScreen extends ConsumerStatefulWidget {
  const BiometricPrimerScreen({super.key});

  @override
  ConsumerState<BiometricPrimerScreen> createState() => _BiometricPrimerScreenState();
}

class _BiometricPrimerScreenState extends ConsumerState<BiometricPrimerScreen> {
  bool _loading = false;
  BiometricKind? _kind;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    final kind = await ref.read(biometricServiceProvider).kind();
    if (!mounted) return;
    if (kind == BiometricKind.none) {
      // Nothing to enable on this device: skip the step.
      await ref.read(sessionProvider.notifier).advancePrimer();
      return;
    }
    setState(() => _kind = kind);
  }

  Future<void> _enable() async {
    setState(() => _loading = true);
    try {
      await ref.read(appLockProvider.notifier).enable();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await ref.read(sessionProvider.notifier).advancePrimer();
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind ?? BiometricKind.fingerprint;
    final label = switch (kind) {
      BiometricKind.face => 'Face unlock',
      BiometricKind.fingerprint => 'Fingerprint',
      _ => 'device lock',
    };
    return PrimerScaffold(
      step: 2,
      total: 2,
      icon: kind == BiometricKind.face ? Icons.face_unlock_outlined : Icons.fingerprint_rounded,
      title: 'Lock the app with $label',
      body: 'Keep records and school information private if someone else picks up your phone.',
      bullets: [
        if (kind == BiometricKind.deviceLock)
          (Icons.pin_outlined, 'Uses your phone\'s PIN, pattern or password')
        else
          (Icons.bolt_rounded, 'Unlock with a touch, no typing'),
        (Icons.visibility_off_outlined, 'Hides the app when you switch away'),
        (Icons.tune_rounded, 'Turn it off or change the delay in Settings'),
      ],
      primaryLabel: _kind == null ? 'Checking this device' : 'Turn on app lock',
      onPrimary: _kind == null ? null : _enable,
      loading: _loading,
      secondaryLabel: 'Not now',
      onSecondary: () => ref.read(sessionProvider.notifier).advancePrimer(),
    );
  }
}
