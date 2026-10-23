import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:schoolsync/core/network/api_client.dart';
import 'package:schoolsync/core/network/device_meta.dart';
import 'package:schoolsync/core/network/token_manager.dart';
import 'package:schoolsync/core/providers.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/core/util/site_address.dart';

/// A real API response recorded from the demo school (test/fixtures/api/NAME.json).
dynamic fixture(String name) => jsonDecode(File('test/fixtures/api/$name.json').readAsStringSync());

class Recorded {
  Recorded(this.method, this.path, this.query, this.body, this.headers);
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? body;
  final Map<String, dynamic> headers;
  @override
  String toString() => '$method $path $query';
}

typedef Responder = (int, Object?) Function(Recorded r);

/// An in-memory API. Routes are keyed `'GET /path'` (no `/api/v1` prefix) and map to a fixed response or a function.
/// Every request is recorded so tests can assert on the exact wire format.
class FakeApi implements HttpClientAdapter {
  final Map<String, Responder> routes = {};

  /// Answers anything without an exact route (lets a test serve a whole API from fixtures).
  Responder? fallback;
  final List<Recorded> requests = [];

  /// While true every request fails like a dead network (airplane mode).
  bool offline = false;

  void on(String route, Object? body, {int status = 200}) => routes[route] = (_) => (status, body);
  void onFn(String route, Responder fn) => routes[route] = fn;

  Recorded? find(String method, String path) {
    for (final r in requests.reversed) {
      if (r.method == method && r.path == path) return r;
    }
    return null;
  }

  int count(String method, String path) => requests.where((r) => r.method == method && r.path == path).length;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    if (offline) throw DioException(requestOptions: o, type: DioExceptionType.connectionError, error: const SocketException('Network is unreachable'));
    final path = o.path.replaceFirst('/api/v1', '');
    final rec = Recorded(o.method, path, Map<String, dynamic>.of(o.queryParameters), o.data, Map<String, dynamic>.of(o.headers));
    requests.add(rec);
    final hit = routes['${o.method} $path'] ?? fallback;
    final (status, data) = hit == null ? (404, {'title': 'No such route', 'code': 'NOT_FOUND', 'status': 404}) : hit(rec);
    return ResponseBody.fromString(jsonEncode(data), status, headers: {Headers.contentTypeHeader: [status >= 400 ? 'application/problem+json' : 'application/json']});
  }

  @override
  void close({bool force = false}) {}
}

const _site = SiteAddress(baseUrl: 'https://demo.example.test', input: 'demo', tenantCode: 'demo');

/// An [ApiClient] wired to [api]: tenant headers and error mapping like the real client, no token refresh.
ApiClient clientFor(FakeApi api) {
  final ctx = ClientContext()..site = _site;
  final bare = buildBaseDio(adapter: api);
  final tokens = TokenManager(store: SecureStore(MemorySecureKv()), bareDio: bare, siteGetter: () => ctx.site, deviceGetter: () => DeviceMeta.fallback);
  final dio = buildBaseDio(adapter: api)..interceptors.addAll([TenantInterceptor(context: ctx, deviceGetter: () => DeviceMeta.fallback), ErrorMappingInterceptor()]);
  return ApiClient(dio: dio, tokens: tokens);
}

/// A provider container whose API client talks to [api] and whose secure storage is in memory.
ProviderContainer containerFor(FakeApi api, {MemorySecureKv? kv, List<Override> overrides = const []}) {
  final c = ProviderContainer(overrides: [
    apiClientProvider.overrideWithValue(clientFor(api)),
    secureStoreProvider.overrideWithValue(SecureStore(kv ?? MemorySecureKv())),
    ...overrides,
  ]);
  return c;
}
