import 'dart:async';

import 'package:dio/dio.dart';

import '../../data/models/auth_models.dart';
import '../../data/models/me.dart';
import '../storage/secure_store.dart';
import '../util/site_address.dart';
import 'app_exception.dart';
import 'device_meta.dart';

enum SessionEndReason { expired, disabled, userInitiated, changedSchool }

/// Owns the access/refresh token pair.
///
/// * Tokens live in memory and in [SecureStore] only.
/// * [refreshIfStale] is **single-flight**: any number of concurrent 401s share
///   one `POST /auth/refresh`, because the refresh token rotates and a second
///   use of the same token would look like theft.
/// * `409 REFRESH_RACE` is handled by re-reading the latest stored token.
class TokenManager {
  TokenManager({required this._store, required Dio bareDio, required this.siteGetter, required this.deviceGetter})
    : _dio = bareDio;

  final SecureStore _store;
  final Dio _dio;
  final SiteAddress? Function() siteGetter;
  final DeviceMeta Function() deviceGetter;

  /// Fresh `/auth/me` payload that came back with a refresh.
  void Function(Me me)? onMe;

  /// The session is gone for good (revoked, expired, disabled).
  void Function(SessionEndReason reason)? onSessionEnded;

  /// Current FCM token, if any, so refresh keeps the device record current.
  String? Function()? pushTokenGetter;

  AuthTokens? _tokens;
  Future<AuthTokens>? _inflight;

  AuthTokens? get current => _tokens;
  bool get hasSession => _tokens != null;

  Future<void> load() async => _tokens = await _store.readTokens();

  Future<void> save(AuthTokens t) async {
    _tokens = t;
    await _store.writeTokens(t);
  }

  Future<void> clear() async {
    _tokens = null;
    _inflight = null;
    await _store.clearTokens();
  }

  /// Returns the latest tokens. If [usedAccessToken] is no longer the current
  /// one, another request already refreshed and we simply hand back the new pair.
  Future<AuthTokens> refreshIfStale(String usedAccessToken) {
    final cur = _tokens;
    if (cur == null) {
      return Future.error(const AppException(kind: ErrorKind.unauthorized, code: 'SESSION_EXPIRED', message: 'Please sign in again.'));
    }
    if (cur.accessToken != usedAccessToken) return Future.value(cur);
    return _inflight ??= _refresh().whenComplete(() => _inflight = null);
  }

  Future<AuthTokens> _refresh() async {
    var raceAttempts = 0;
    while (true) {
      // Re-read: another isolate (push handler) may have rotated the token.
      final latest = await _store.readTokens() ?? _tokens;
      if (latest == null) {
        _end(SessionEndReason.expired);
        throw const AppException(kind: ErrorKind.unauthorized, code: 'SESSION_EXPIRED', message: 'Please sign in again.');
      }
      _tokens = latest;
      try {
        final site = siteGetter();
        final res = await _dio.post<Object?>(
          '/api/v1/auth/refresh',
          data: {
            'refreshToken': latest.refreshToken,
            'device': deviceGetter().toDeviceJson(pushToken: pushTokenGetter?.call()),
          },
          options: Options(extra: {'site': site}),
        );
        final parsed = TokenResponse.fromJson((res.data as Map).cast<String, dynamic>());
        await save(parsed.tokens);
        onMe?.call(parsed.user);
        return parsed.tokens;
      } on DioException catch (e) {
        final ex = AppException.from(e);
        if (ex.code == 'REFRESH_RACE') {
          raceAttempts++;
          await Future<void>.delayed(Duration(milliseconds: 350 * raceAttempts));
          final reread = await _store.readTokens();
          final changed = reread != null && reread.refreshToken != latest.refreshToken;
          if (changed || raceAttempts < 3) {
            if (changed) _tokens = reread;
            if (raceAttempts >= 3 && !changed) {
              // The rotated token never reached us (response lost): the session is unrecoverable.
              await clear();
              _end(SessionEndReason.expired);
              throw ex;
            }
            continue;
          }
        }
        if (const {'SESSION_EXPIRED', 'INVALID_REFRESH'}.contains(ex.code)) {
          await clear();
          _end(SessionEndReason.expired);
        } else if (ex.code == 'ACCOUNT_DISABLED') {
          await clear();
          _end(SessionEndReason.disabled);
        }
        // Network / server errors: keep the session, let the caller surface the error.
        throw ex;
      }
    }
  }

  void _end(SessionEndReason r) => onSessionEnded?.call(r);

  /// Used when a normal request already told us the session is dead.
  Future<void> terminate(SessionEndReason reason) async {
    await clear();
    _end(reason);
  }
}
