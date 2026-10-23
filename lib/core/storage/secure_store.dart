import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/models/auth_models.dart';
import '../../data/models/me.dart';
import '../../data/models/site_info.dart';
import '../util/site_address.dart';

/// Minimal key/value surface so the real Keystore/Keychain store can be swapped
/// for an in-memory one in tests.
abstract class SecureKv {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKv implements SecureKv {
  FlutterSecureKv([FlutterSecureStorage? storage])
    : _s =
          storage ??
          const FlutterSecureStorage(
            // Android: AES-GCM data keys wrapped by an Android Keystore RSA key.
            aOptions: AndroidOptions(),
            // iOS: Keychain, never synced to iCloud, not restored onto another device.
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
          );

  final FlutterSecureStorage _s;

  @override
  Future<String?> read(String key) async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      // A corrupted/rotated Keystore key must never brick the app: behave as "empty".
      return null;
    }
  }

  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class MemorySecureKv implements SecureKv {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

/// Everything sensitive the app persists: the saved school, its cached public
/// info and the session tokens. Tokens never go anywhere else.
class SecureStore {
  SecureStore(this._kv);
  final SecureKv _kv;

  static const _kSite = 'site.v1';
  static const _kSiteInfo = 'site_info.v1';
  static const _kTokens = 'tokens.v1';
  static const _kMe = 'me.v1';

  Future<SiteAddress?> readSite() async {
    final raw = await _kv.read(_kSite);
    if (raw == null) return null;
    try {
      return SiteAddress.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSite(SiteAddress site) => _kv.write(_kSite, jsonEncode(site.toJson()));

  Future<SiteInfo?> readSiteInfo() async {
    final raw = await _kv.read(_kSiteInfo);
    if (raw == null) return null;
    try {
      return SiteInfo.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSiteInfo(SiteInfo info) => _kv.write(_kSiteInfo, jsonEncode(info.toJson()));

  Future<AuthTokens?> readTokens() async {
    final raw = await _kv.read(_kTokens);
    if (raw == null) return null;
    try {
      return AuthTokens.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> writeTokens(AuthTokens t) => _kv.write(_kTokens, jsonEncode(t.toJson()));

  Future<void> clearTokens() => _kv.delete(_kTokens);

  /// Last known profile, so the app can open offline. Encrypted at rest like tokens.
  Future<Me?> readMe() async {
    final raw = await _kv.read(_kMe);
    if (raw == null) return null;
    try {
      return Me.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> writeMeJson(Map<String, dynamic> json) => _kv.write(_kMe, jsonEncode(json));

  Future<void> clearMe() => _kv.delete(_kMe);

  /// Generic encrypted blob (offline caches). Keys are namespaced by the caller and wiped by [clearAll].
  Future<String?> readRaw(String key) => _kv.read(key);

  Future<void> writeRaw(String key, String value) async {
    final keys = <String>{...?(await _kv.read(_kRawIndex))?.split('\n').where((k) => k.isNotEmpty), key};
    await _kv.write(key, value);
    await _kv.write(_kRawIndex, keys.join('\n'));
  }

  static const _kRawIndex = 'raw.index.v1';

  /// "Change school": forget the site, its branding and any session.
  Future<void> clearAll() async {
    final index = await _kv.read(_kRawIndex);
    if (index != null) {
      for (final k in index.split('\n')) {
        if (k.isNotEmpty) await _kv.delete(k);
      }
      await _kv.delete(_kRawIndex);
    }
    await _kv.delete(_kTokens);
    await _kv.delete(_kMe);
    await _kv.delete(_kSite);
    await _kv.delete(_kSiteInfo);
  }
}
