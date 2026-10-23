import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'firebase_bootstrap.dart';
import 'local_notifications.dart';

/// A route requested by a notification tap, consumed once the app is ready.
class PendingRoute extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? route) => state = route;
}

final pendingRouteProvider = NotifierProvider<PendingRoute, String?>(PendingRoute.new);

/// Only same-app absolute paths are accepted from a push payload.
bool isSafeRoute(String? route) {
  if (route == null || route.isEmpty) return false;
  if (!route.startsWith('/') || route.startsWith('//')) return false;
  if (route.contains('://') || route.contains('\\')) return false;
  const blocked = {'/splash', '/intro', '/connect', '/login', '/locked', '/update'};
  final path = Uri.tryParse(route)?.path;
  return path != null && !blocked.contains(path);
}

/// Push registration for this device: permission, FCM token, `POST /devices`,
/// foreground display and tap-to-deep-link. Does nothing when Firebase is not
/// configured.
class PushService {
  PushService(this._ref);
  final Ref _ref;

  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _msgSub;
  StreamSubscription<RemoteMessage>? _openSub;
  String? _token;
  bool _started = false;

  bool get available => FirebaseBootstrap.ready;
  String? get token => _token;

  /// Attach listeners once Firebase is up. Idempotent.
  Future<void> start() async {
    if (_started) return;
    _started = true;
    await LocalNotifications.init(onTap: _handleTap);
    final launch = await LocalNotifications.launchData();
    if (launch != null) _handleTap(launch);
    if (!available) return;

    final fm = FirebaseMessaging.instance;
    await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
    _msgSub = FirebaseMessaging.onMessage.listen((m) {
      // iOS shows foreground notifications itself (presentation options above).
      if (defaultTargetPlatform == TargetPlatform.android) unawaited(LocalNotifications.showRemote(m));
    });
    _openSub = FirebaseMessaging.onMessageOpenedApp.listen((m) => _handleTap(PushData.fromMap(m.data.cast<String, dynamic>())));
    final initial = await fm.getInitialMessage();
    if (initial != null) _handleTap(PushData.fromMap(initial.data.cast<String, dynamic>()));
    // Deprecated in firebase_messaging 17 in favour of Installation-ID based registration, but the
    // SchoolSync server sends through firebase-admin to classic FCM registration tokens, so we keep them.
    // ignore: deprecated_member_use
    _tokenSub = fm.onTokenRefresh.listen((t) {
      _token = t;
      unawaited(syncRegistration());
    });
  }

  void _handleTap(PushData data) {
    if (isSafeRoute(data.route)) _ref.read(pendingRouteProvider.notifier).set(data.route);
  }

  Future<bool> isPermissionGranted() => LocalNotifications.areEnabled();

  Future<bool> requestPermission() async {
    if (available && defaultTargetPlatform == TargetPlatform.iOS) {
      final s = await FirebaseMessaging.instance.requestPermission();
      return s.authorizationStatus == AuthorizationStatus.authorized || s.authorizationStatus == AuthorizationStatus.provisional;
    }
    return LocalNotifications.requestPermission();
  }

  /// Registers (or refreshes) this device's FCM token with the API.
  /// Returns whether the server now has a token for this device.
  Future<bool> syncRegistration() async {
    if (!available) return false;
    final prefs = _ref.read(prefsProvider);
    if (!prefs.pushEnabled || !_ref.read(tokenManagerProvider).hasSession) return false;
    try {
      // ignore: deprecated_member_use
      final t = _token ?? await FirebaseMessaging.instance.getToken();
      if (t == null || t.length < 20) return false;
      _token = t;
      await _ref.read(authRepositoryProvider).registerDevice(device: _ref.read(deviceMetaProvider), pushToken: t);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[push] token registration failed');
      return false;
    }
  }

  /// "Turn on notifications": ask the OS, then register. Returns the outcome.
  Future<bool> enable() async {
    final granted = await requestPermission();
    if (!granted) return false;
    await _ref.read(prefsProvider).setPushEnabled(true);
    await syncRegistration();
    return true;
  }

  Future<void> disable() async {
    await _ref.read(prefsProvider).setPushEnabled(false);
    await unregister(deleteToken: false);
  }

  /// Tells the API to stop pushing to this device. Best effort.
  Future<void> unregister({required bool deleteToken}) async {
    final t = _token;
    if (available) {
      try {
        if (t != null) await _ref.read(authRepositoryProvider).unregisterDevice(t);
      } catch (_) {}
      if (deleteToken) {
        try {
          // ignore: deprecated_member_use
          await FirebaseMessaging.instance.deleteToken();
        } catch (_) {}
        _token = null;
      }
    }
  }

  void dispose() {
    unawaited(_tokenSub?.cancel());
    unawaited(_msgSub?.cancel());
    unawaited(_openSub?.cancel());
  }
}

final pushServiceProvider = Provider<PushService>((ref) {
  final s = PushService(ref);
  ref.onDispose(s.dispose);
  return s;
});
