import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/env.dart';

/// Thin wrapper over the native `com.schoolsync.app/platform` channel
/// (implemented in MainActivity.kt on Android).
abstract final class PlatformBridge {
  static const _channel = MethodChannel('com.schoolsync.app/platform');

  static Future<void> setSecure(bool secure) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecure', {'secure': secure});
    } catch (_) {}
  }

  /// Heuristic root signal (su binaries, test-keys build). Not tamper-proof.
  static Future<bool> isRooted() async {
    try {
      if (Platform.isAndroid) return await _channel.invokeMethod<bool>('isRooted') ?? false;
      if (Platform.isIOS) return _iosJailbreakHints();
    } catch (_) {}
    return false;
  }

  static bool _iosJailbreakHints() {
    const paths = [
      '/Applications/Cydia.app',
      '/Library/MobileSubstrate/MobileSubstrate.dylib',
      '/bin/bash',
      '/usr/sbin/sshd',
      '/etc/apt',
      '/private/var/lib/apt/',
    ];
    return paths.any((p) => File(p).existsSync());
  }

  static Future<void> openNotificationSettings() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod<void>('openNotificationSettings');
      } else {
        await launchUrl(Uri.parse('app-settings:'));
      }
    } catch (_) {}
  }
}

/// Reference-counted FLAG_SECURE: screens call [acquire]/[release]; the window
/// is secure while at least one sensitive screen is mounted.
abstract final class ScreenPrivacy {
  static int _holders = 0;

  static void acquire() {
    if (!Env.screenPrivacy) return;
    _holders++;
    if (_holders == 1) PlatformBridge.setSecure(true);
  }

  static void release() {
    if (!Env.screenPrivacy) return;
    if (_holders > 0) _holders--;
    if (_holders == 0) PlatformBridge.setSecure(false);
  }

  @visibleForTesting
  static int get holders => _holders;
}
