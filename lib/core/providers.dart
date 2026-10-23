import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/site_repository.dart';
import 'config/env.dart';
import 'network/api_client.dart';
import 'network/cert_pinning.dart';
import 'network/device_meta.dart';
import 'network/token_manager.dart';
import 'storage/prefs.dart';
import 'storage/secure_store.dart';

/// Overridden in `main()` once SharedPreferences has loaded.
final prefsProvider = Provider<AppPrefs>((ref) => throw UnimplementedError('prefsProvider must be overridden'));

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore(FlutterSecureKv()));

/// Overridden in `main()` with real device facts.
final deviceMetaProvider = Provider<DeviceMeta>((ref) => DeviceMeta.fallback);

final clientContextProvider = Provider<ClientContext>((ref) => ClientContext());

final baseDioProvider = Provider<Dio>((ref) {
  final pins = Env.pins;
  final adapter = pins.isEmpty ? null : PinningAdapter(pins: pins, hostSuffixes: [Env.baseDomain.toLowerCase()]);
  final dio = buildBaseDio(adapter: adapter);
  // The refresh/bare client only needs tenant routing + error mapping.
  dio.interceptors.addAll([
    TenantInterceptor(context: ref.watch(clientContextProvider), deviceGetter: () => ref.read(deviceMetaProvider)),
    ErrorMappingInterceptor(),
  ]);
  ref.onDispose(() => dio.close());
  return dio;
});

final tokenManagerProvider = Provider<TokenManager>((ref) {
  final ctx = ref.watch(clientContextProvider);
  return TokenManager(
    store: ref.watch(secureStoreProvider),
    bareDio: ref.watch(baseDioProvider),
    siteGetter: () => ctx.site,
    deviceGetter: () => ref.read(deviceMetaProvider),
  );
});

final dioProvider = Provider<Dio>((ref) {
  final pins = Env.pins;
  final adapter = pins.isEmpty ? null : PinningAdapter(pins: pins, hostSuffixes: [Env.baseDomain.toLowerCase()]);
  final dio = buildBaseDio(adapter: adapter);
  dio.interceptors.addAll([
    TenantInterceptor(context: ref.watch(clientContextProvider), deviceGetter: () => ref.read(deviceMetaProvider)),
    AuthInterceptor(tokens: ref.watch(tokenManagerProvider), dio: dio),
    RetryInterceptor(dio: dio),
    ErrorMappingInterceptor(),
    if (kDebugMode) SafeLogInterceptor(),
  ]);
  ref.onDispose(() => dio.close());
  return dio;
});

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(dio: ref.watch(dioProvider), tokens: ref.watch(tokenManagerProvider)),
);

final siteRepositoryProvider = Provider<SiteRepository>((ref) => SiteRepository(ref.watch(apiClientProvider)));
final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(ref.watch(apiClientProvider)));

/// Light/dark/system, persisted.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(prefsProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(prefsProvider).setThemeMode(mode);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
