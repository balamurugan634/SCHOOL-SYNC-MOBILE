import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../util/site_address.dart';
import 'env.dart';

/// Whether the "Developer options" UI may appear. Always false in release/profile builds.
///
/// Screens must gate on `kDebugMode && ref.watch(developerOptionsEnabledProvider)` so the
/// compiler removes the whole UI (and its strings) from release builds; the provider exists
/// only so a test can switch the section off in a debug-mode test run.
final developerOptionsEnabledProvider = Provider<bool>((ref) => kDebugMode);

/// The API address that every school code is sent to (as `X-Tenant`), or `''` for none.
///
/// Debug builds: the value saved from Developer options, falling back to `--dart-define=DEV_API`.
/// Other builds: only the compile-time define (and release still refuses plain http).
class DevApi extends Notifier<String> {
  @override
  String build() {
    if (kDebugMode) {
      final saved = ref.read(prefsProvider).devApi;
      if (saved != null) return saved;
    }
    return normalizeDevApi(Env.devApi) ?? '';
  }

  /// Persists an address typed in Developer options. Invalid input is ignored.
  Future<void> set(String raw) async {
    if (!kDebugMode) return;
    final v = normalizeDevApi(raw);
    if (v == null) return;
    state = v;
    await ref.read(prefsProvider).setDevApi(v);
  }

  Future<void> reset() async {
    if (!kDebugMode) return;
    await ref.read(prefsProvider).setDevApi(null);
    state = normalizeDevApi(Env.devApi) ?? '';
  }
}

final devApiProvider = NotifierProvider<DevApi, String>(DevApi.new);
