import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_client.dart';
import '../../core/network/app_exception.dart';
import '../../core/providers.dart';
import '../json.dart';
import '../models/learner_dashboard.dart';

/// `GET /dashboard/student` and `/dashboard/parent`. The last good payload is kept (in memory and in
/// the encrypted store) so the home screen still opens offline.
class DashboardRepository {
  DashboardRepository(this._api, this._ref);
  final ApiClient _api;
  final Ref _ref;

  /// Fetches the student home; on a network failure falls back to the last saved copy (marked `fromCache`).
  Future<StudentDashboard> student(String userId) async {
    try {
      final json = jsonMap(await _api.get('/dashboard/student'));
      await _remember(userId, null, json);
      return StudentDashboard.fromJson(json);
    } on AppException catch (e) {
      if (!e.isNetwork) rethrow;
      final cached = await _recall(userId, null);
      if (cached == null) rethrow;
      return StudentDashboard.fromJson(cached.$2, at: cached.$1, fromCache: true);
    }
  }

  Future<ParentDashboard> parent(String userId, {String? studentId}) async {
    try {
      final json = jsonMap(await _api.get('/dashboard/parent', query: {'studentId': ?studentId}));
      await _remember(userId, studentId, json);
      return ParentDashboard.fromJson(json);
    } on AppException catch (e) {
      if (!e.isNetwork) rethrow;
      final cached = await _recall(userId, studentId);
      if (cached == null) rethrow;
      return ParentDashboard.fromJson(cached.$2, at: cached.$1, fromCache: true);
    }
  }

  // --- offline cache (encrypted, per user and child; wiped on sign-out / change school) ---
  String _key(String userId, String? studentId) => 'dash.$userId.${studentId ?? '-'}';

  Future<void> _remember(String userId, String? studentId, Json raw) async {
    try {
      await _ref.read(secureStoreProvider).writeRaw(_key(userId, studentId), jsonEncode({'at': DateTime.now().toIso8601String(), 'json': raw}));
    } catch (_) {}
  }

  Future<(DateTime, Json)?> _recall(String userId, String? studentId) async {
    try {
      final s = await _ref.read(secureStoreProvider).readRaw(_key(userId, studentId));
      if (s == null) return null;
      final m = jsonMap(jsonDecode(s));
      return (DateTime.tryParse(jStrOr(m['at'])) ?? DateTime.now(), jsonMap(m['json']));
    } catch (_) {
      return null;
    }
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository(ref.watch(apiClientProvider), ref));
