import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

enum BiometricKind { face, fingerprint, deviceLock, none }

/// Fingerprint / Face unlock with the device PIN/pattern as fallback.
class BiometricService {
  BiometricService([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();
  final LocalAuthentication _auth;

  static bool _inProgress = false;
  static DateTime _graceUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// True while the system prompt is up (and briefly after), so the app-lock does not
  /// mistake the prompt's pause/resume for the person leaving the app.
  static bool get promptActive => _inProgress || DateTime.now().isBefore(_graceUntil);

  /// Can this device authenticate at all (biometrics or screen lock)?
  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<BiometricKind> kind() async {
    try {
      if (!await _auth.isDeviceSupported()) return BiometricKind.none;
      final types = await _auth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.contains(BiometricType.fingerprint)) return BiometricKind.fingerprint;
      if (types.isNotEmpty) return BiometricKind.fingerprint;
      return BiometricKind.deviceLock;
    } on PlatformException {
      return BiometricKind.none;
    }
  }

  Future<bool> authenticate(String reason) async {
    _inProgress = true;
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: false);
    } on PlatformException {
      return false;
    } finally {
      _inProgress = false;
      _graceUntil = DateTime.now().add(const Duration(milliseconds: 1500));
    }
  }
}
