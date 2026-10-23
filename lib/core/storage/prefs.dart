import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env.dart';

/// Non-sensitive local preferences (never tokens or personal data).
class AppPrefs {
  AppPrefs(this._p);
  final SharedPreferences _p;

  static const _kIntro = 'intro_seen';
  static const _kTheme = 'theme_mode';
  static const _kLockEnabled = 'lock_enabled';
  static const _kLockMinutes = 'lock_minutes';
  static const _kPrimersPrefix = 'primers_done.';
  static const _kTourPrefix = 'tour_seen.';
  static const _kPushEnabled = 'push_enabled';
  static const _kSelectedChild = 'selected_child';
  static const _kRootDismissed = 'root_warning_dismissed';
  static const _kDevApi = 'dev_api';

  bool get introSeen => _p.getBool(_kIntro) ?? false;
  Future<void> setIntroSeen(bool v) => _p.setBool(_kIntro, v);

  ThemeMode get themeMode => switch (_p.getString(_kTheme)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
  Future<void> setThemeMode(ThemeMode m) => _p.setString(_kTheme, m.name);

  bool get lockEnabled => _p.getBool(_kLockEnabled) ?? false;
  Future<void> setLockEnabled(bool v) => _p.setBool(_kLockEnabled, v);

  int get lockMinutes => _p.getInt(_kLockMinutes) ?? Env.defaultLockMinutes;
  Future<void> setLockMinutes(int v) => _p.setInt(_kLockMinutes, v);

  bool primersDone(String userId) => _p.getBool('$_kPrimersPrefix$userId') ?? false;
  Future<void> setPrimersDone(String userId, bool v) => _p.setBool('$_kPrimersPrefix$userId', v);

  bool tourSeen(String userId) => _p.getBool('$_kTourPrefix$userId') ?? false;
  Future<void> setTourSeen(String userId, bool v) => _p.setBool('$_kTourPrefix$userId', v);

  /// The person's wish for push; the OS permission is a separate switch.
  bool get pushEnabled => _p.getBool(_kPushEnabled) ?? false;
  Future<void> setPushEnabled(bool v) => _p.setBool(_kPushEnabled, v);

  String? get selectedChild => _p.getString(_kSelectedChild);
  Future<void> setSelectedChild(String? id) =>
      id == null ? _p.remove(_kSelectedChild) : _p.setString(_kSelectedChild, id);

  bool get rootWarningDismissed => _p.getBool(_kRootDismissed) ?? false;
  Future<void> setRootWarningDismissed(bool v) => _p.setBool(_kRootDismissed, v);

  /// Debug builds only: the API address typed into Developer options (null = use the DEV_API define).
  String? get devApi => _p.getString(_kDevApi);
  Future<void> setDevApi(String? v) => v == null ? _p.remove(_kDevApi) : _p.setString(_kDevApi, v);

  /// Called on "Change school" / sign-out of the last user: keeps theme + intro.
  Future<void> resetForNewSchool() async {
    await _p.remove(_kLockEnabled);
    await _p.remove(_kPushEnabled);
    await _p.remove(_kSelectedChild);
    for (final k in _p.getKeys().toList()) {
      if (k.startsWith(_kPrimersPrefix) || k.startsWith(_kTourPrefix)) await _p.remove(k);
    }
  }
}
