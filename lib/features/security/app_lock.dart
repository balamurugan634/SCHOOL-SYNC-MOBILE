import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/security/biometric_service.dart';

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

class AppLockState {
  const AppLockState({this.enabled = false, this.minutes = 1, this.supported = false, this.kind = BiometricKind.none});

  final bool enabled;

  /// Minutes in the background before the lock engages (0 = immediately).
  final int minutes;
  final bool supported;
  final BiometricKind kind;

  String get kindLabel => switch (kind) {
    BiometricKind.face => 'Face unlock',
    BiometricKind.fingerprint => 'Fingerprint',
    BiometricKind.deviceLock => 'Device lock',
    BiometricKind.none => 'Biometrics',
  };

  AppLockState copyWith({bool? enabled, int? minutes, bool? supported, BiometricKind? kind}) => AppLockState(
    enabled: enabled ?? this.enabled,
    minutes: minutes ?? this.minutes,
    supported: supported ?? this.supported,
    kind: kind ?? this.kind,
  );
}

/// Biometric (or device PIN/pattern) lock that engages when the app returns from the background.
class AppLockController extends Notifier<AppLockState> {
  @override
  AppLockState build() {
    final prefs = ref.read(prefsProvider);
    Future<void>(() async {
      final kind = await ref.read(biometricServiceProvider).kind();
      state = state.copyWith(supported: kind != BiometricKind.none, kind: kind);
    });
    return AppLockState(enabled: prefs.lockEnabled, minutes: prefs.lockMinutes);
  }

  /// Verifies the person can authenticate, then turns the lock on.
  Future<bool> enable() async {
    final svc = ref.read(biometricServiceProvider);
    if (!await svc.isSupported()) return false;
    final ok = await svc.authenticate('Turn on app lock for SchoolSync');
    if (!ok) return false;
    await ref.read(prefsProvider).setLockEnabled(true);
    state = state.copyWith(enabled: true);
    return true;
  }

  Future<bool> disable() async {
    await ref.read(prefsProvider).setLockEnabled(false);
    state = state.copyWith(enabled: false);
    return true;
  }

  Future<void> setMinutes(int minutes) async {
    await ref.read(prefsProvider).setLockMinutes(minutes);
    state = state.copyWith(minutes: minutes);
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(AppLockController.new);
