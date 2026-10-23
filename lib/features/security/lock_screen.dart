import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/design.dart';
import '../../core/security/biometric_service.dart';
import '../auth/session.dart';
import 'app_lock.dart';

/// Shown on resume when the app lock is on. Unlock with Face/Fingerprint or the device PIN.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final ok = await ref.read(biometricServiceProvider).authenticate('Unlock SchoolSync');
    if (!mounted) return;
    if (ok) {
      ref.read(sessionProvider.notifier).unlock();
    } else {
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(sessionProvider.select((s) => s.siteInfo));
    final kind = ref.watch(appLockProvider.select((s) => s.kind));
    final t = context.tokens;
    final icon = kind == BiometricKind.face ? Icons.face_unlock_outlined : Icons.fingerprint_rounded;
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gaps.xxl),
          child: Column(
            children: [
              const Spacer(flex: 2),
              SchoolLogo(info: info, size: 56),
              const SizedBox(height: Gaps.lg),
              Text(info?.name ?? 'SchoolSync', style: context.text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('Locked', style: context.text.bodyMedium?.copyWith(color: t.textSecondary)),
              const Spacer(),
              if (_failed) ...[
                Text('Could not verify. Try again.', style: context.text.bodySmall?.copyWith(color: t.danger)),
                const SizedBox(height: Gaps.sm),
              ],
              PrimaryButton(label: 'Unlock', icon: icon, loading: _busy, onPressed: _unlock),
              const SizedBox(height: Gaps.xs),
              GhostButton(label: 'Sign out instead', onPressed: () => ref.read(sessionProvider.notifier).logout()),
              const SizedBox(height: Gaps.sm),
            ],
          ),
        ),
      ),
    );
  }
}
