import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/app_exception.dart';
import '../../../core/providers.dart';
import '../../json.dart';
import '../../models/staff/dashboards.dart';

/// A dashboard plus whether it came from the on-device cache (offline) and when it was fetched.
class Loaded<T> {
  const Loaded(this.value, {this.fromCache = false, this.at});
  final T value;
  final bool fromCache;
  final DateTime? at;
}

/// `GET /dashboard/teacher` and `/dashboard/management`. The last good payload is kept in the encrypted store
/// (wiped on sign-out / change school) so Home still opens when the network is down.
class StaffDashboardRepository {
  StaffDashboardRepository(this._api, this._ref);
  final ApiClient _api;
  final Ref _ref;

  Future<Loaded<TeacherDashboard>> teacher(String userId) => _load('teacher', userId, '/dashboard/teacher', TeacherDashboard.fromJson);
  Future<Loaded<ManagementDashboard>> management(String userId) => _load('management', userId, '/dashboard/management', ManagementDashboard.fromJson);

  Future<Loaded<T>> _load<T>(String kind, String userId, String path, T Function(Json) parse) async {
    final key = 'dash.$kind.$userId';
    try {
      final raw = jsonMap(await _api.get(path));
      await _remember(key, raw);
      return Loaded(parse(raw), at: DateTime.now());
    } on AppException catch (e) {
      if (!(e.isNetwork || e.kind == ErrorKind.server)) rethrow;
      final cached = await _recall(key);
      if (cached == null) rethrow;
      return Loaded(parse(cached.$2), fromCache: true, at: cached.$1);
    }
  }

  Future<void> _remember(String key, Json raw) async {
    try {
      await _ref.read(secureStoreProvider).writeRaw(key, jsonEncode({'at': DateTime.now().toIso8601String(), 'json': raw}));
    } catch (_) {}
  }

  Future<(DateTime, Json)?> _recall(String key) async {
    try {
      final s = await _ref.read(secureStoreProvider).readRaw(key);
      if (s == null) return null;
      final m = jsonMap(jsonDecode(s));
      return (DateTime.tryParse(jStrOr(m['at'])) ?? DateTime.now(), jsonMap(m['json']));
    } catch (_) {
      return null;
    }
  }
}

final staffDashboardRepositoryProvider = Provider<StaffDashboardRepository>((ref) => StaffDashboardRepository(ref.watch(apiClientProvider), ref));
