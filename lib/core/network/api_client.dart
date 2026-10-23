import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../util/site_address.dart';
import 'app_exception.dart';
import 'device_meta.dart';
import 'token_manager.dart';

const apiPrefix = '/api/v1';

/// Problem codes meaning "the access token is the problem, refresh and retry".
const _refreshableCodes = {'TOKEN_EXPIRED', 'TOKEN_STALE', 'INVALID_TOKEN', 'UNAUTHORIZED'};

/// Problem codes meaning "this session is finished".
const _terminalCodes = {'SESSION_EXPIRED', 'ACCOUNT_DISABLED', 'INVALID_REFRESH'};

/// Holds what interceptors need to know about the current school.
class ClientContext {
  SiteAddress? site;
}

/// Builds a Dio with no auth/refresh logic (used for refresh itself and for
/// public calls). Shared defaults: timeouts, JSON, HTTPS enforcement via the
/// platform network security config.
Dio buildBaseDio({HttpClientAdapter? adapter}) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.json,
      headers: {'Accept': 'application/json'},
      // We turn non-2xx into AppException ourselves.
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  );
  if (adapter != null) dio.httpClientAdapter = adapter;
  return dio;
}

/// Adds tenant routing and identity headers. The per-request `extra['site']`
/// wins (used while validating a school that is not saved yet).
class TenantInterceptor extends Interceptor {
  TenantInterceptor({required this.context, required this.deviceGetter});
  final ClientContext context;
  final DeviceMeta Function() deviceGetter;
  static final _rand = Random.secure();

  static String requestId() {
    final b = List<int>.generate(12, (_) => _rand.nextInt(256));
    return b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final site = (options.extra['site'] as SiteAddress?) ?? context.site;
    if (site != null) {
      options.baseUrl = site.baseUrl;
      if (site.tenantCode != null) options.headers['X-Tenant'] = site.tenantCode;
    }
    final d = deviceGetter();
    options.headers['X-Request-Id'] = requestId();
    options.headers['X-Client'] = 'schoolsync-mobile/${d.appVersion}+${d.buildNumber} (${d.platform})';
    handler.next(options);
  }
}

/// Attaches the bearer token, refreshes it just before it expires and once more
/// after a 401 that blames the access token, then retries the request exactly once.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({required this.tokens, required this.dio});
  final TokenManager tokens;
  final Dio dio;

  static bool wantsAuth(RequestOptions o) => o.extra['auth'] != false;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (!wantsAuth(options)) return handler.next(options);
    var t = tokens.current;
    if (t == null) return handler.next(options);
    if (t.expiresWithin(const Duration(seconds: 20))) {
      try {
        t = await tokens.refreshIfStale(t.accessToken);
      } on AppException catch (e) {
        return handler.reject(DioException(requestOptions: options, error: e, type: DioExceptionType.unknown));
      }
    }
    options.headers['Authorization'] = 'Bearer ${t.accessToken}';
    options.extra['usedToken'] = t.accessToken;
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final res = err.response;
    final o = err.requestOptions;
    if (res == null || res.statusCode != 401 || !wantsAuth(o)) return handler.next(err);

    final ex = AppException.fromProblem(401, res.data);
    if (_terminalCodes.contains(ex.code)) {
      await tokens.terminate(ex.code == 'ACCOUNT_DISABLED' ? SessionEndReason.disabled : SessionEndReason.expired);
      return handler.next(err);
    }
    if (o.extra['retried'] == true || !_refreshableCodes.contains(ex.code)) return handler.next(err);

    final used = o.extra['usedToken'] as String?;
    try {
      final fresh = await tokens.refreshIfStale(used ?? '');
      o.extra['retried'] = true;
      o.headers['Authorization'] = 'Bearer ${fresh.accessToken}';
      o.extra['usedToken'] = fresh.accessToken;
      final retried = await dio.fetch<Object?>(o);
      return handler.resolve(retried);
    } on AppException catch (e) {
      return handler.reject(DioException(requestOptions: o, error: e, response: res, type: DioExceptionType.badResponse));
    } on DioException catch (e) {
      return handler.next(e);
    }
  }
}

/// Retries idempotent reads a couple of times on flaky connections.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({required this.dio, this.maxRetries = 2});
  final Dio dio;
  final int maxRetries;

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    final transient = switch (err.type) {
      DioExceptionType.connectionTimeout || DioExceptionType.receiveTimeout || DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => const {502, 503, 504}.contains(err.response?.statusCode),
      _ => false,
    };
    final attempt = (o.extra['attempt'] as int?) ?? 0;
    if (o.method != 'GET' || !transient || attempt >= maxRetries || o.extra['noRetry'] == true) {
      return handler.next(err);
    }
    o.extra['attempt'] = attempt + 1;
    await Future<void>.delayed(Duration(milliseconds: 400 * (1 << attempt)));
    try {
      handler.resolve(await dio.fetch<Object?>(o));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Maps every failure to an [AppException] so callers never see Dio types.
class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err.copyWith(error: AppException.fromDio(err)));
  }
}

/// Debug-only, content-free logging: method, path and status. Never headers or bodies.
class SafeLogInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    debugPrint('[api] ${response.requestOptions.method} ${response.requestOptions.path} -> ${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('[api] ${err.requestOptions.method} ${err.requestOptions.path} -> ${err.response?.statusCode ?? err.type.name}');
    handler.next(err);
  }
}

/// Thin facade used by repositories. Always returns decoded JSON and only ever
/// throws [AppException].
class ApiClient {
  ApiClient({required this.dio, required this.tokens});
  final Dio dio;
  final TokenManager tokens;

  Future<Object?> get(String path, {Map<String, dynamic>? query, bool auth = true, SiteAddress? site, CancelToken? cancel}) =>
      _run(() => dio.get<Object?>('$apiPrefix$path', queryParameters: query, cancelToken: cancel, options: _opts(auth, site)));

  Future<Object?> post(String path, {Object? data, bool auth = true, SiteAddress? site, CancelToken? cancel}) =>
      _run(() => dio.post<Object?>('$apiPrefix$path', data: data ?? <String, dynamic>{}, cancelToken: cancel, options: _opts(auth, site)));

  Future<Object?> patch(String path, {Object? data, bool auth = true}) =>
      _run(() => dio.patch<Object?>('$apiPrefix$path', data: data, options: _opts(auth, null)));

  Future<Object?> put(String path, {Object? data, bool auth = true}) =>
      _run(() => dio.put<Object?>('$apiPrefix$path', data: data, options: _opts(auth, null)));

  Future<Object?> delete(String path, {Object? data, bool auth = true}) =>
      _run(() => dio.delete<Object?>('$apiPrefix$path', data: data, options: _opts(auth, null)));

  /// Multipart upload (`file` field plus [fields]); returns the decoded JSON.
  Future<Object?> upload(String path, {required String filePath, String? fileName, Map<String, String> fields = const {}, Map<String, dynamic>? query, void Function(int sent, int total)? onProgress, CancelToken? cancel, String method = 'POST'}) {
    return _run(() async {
      final form = FormData.fromMap({...fields, 'file': await MultipartFile.fromFile(filePath, filename: fileName)});
      return dio.request<Object?>('$apiPrefix$path', data: form, queryParameters: query, cancelToken: cancel, onSendProgress: onProgress, options: Options(method: method, extra: {'auth': true}, sendTimeout: const Duration(minutes: 2)));
    });
  }

  /// Authenticated binary download (PDFs, files).
  Future<Uint8List> download(String path, {Map<String, dynamic>? query, void Function(int received, int total)? onProgress}) async {
    try {
      final r = await dio.get<List<int>>('$apiPrefix$path', queryParameters: query, onReceiveProgress: onProgress, options: Options(responseType: ResponseType.bytes, receiveTimeout: const Duration(minutes: 2), extra: {'auth': true}));
      return Uint8List.fromList(r.data ?? const []);
    } on DioException catch (e) {
      throw AppException.from(e);
    }
  }

  Options _opts(bool auth, SiteAddress? site) => Options(extra: {'auth': auth, 'site': ?site});

  Future<Object?> _run(Future<Response<Object?>> Function() call) async {
    try {
      final r = await call();
      return r.data;
    } on DioException catch (e) {
      throw AppException.from(e);
    }
  }
}
