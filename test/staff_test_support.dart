import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:schoolsync/core/network/api_client.dart';
import 'package:schoolsync/core/network/device_meta.dart';
import 'package:schoolsync/core/network/token_manager.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/core/util/site_address.dart';
import 'package:schoolsync/data/json.dart';

/// A fixture captured from the dev API (`test/fixtures/staff/<name>.json`).
Json fixture(String name) => jsonMap(jsonDecode(File('test/fixtures/staff/$name.json').readAsStringSync()));

class RecordedRequest {
  RecordedRequest(this.method, this.path, this.query, this.body);
  final String method;
  final String path;
  final Map<String, dynamic> query;
  final Object? body;
}

/// A fake HTTP server: routes by "METHOD /path" (no `/api/v1` prefix) and records every request.
class FakeServer implements HttpClientAdapter {
  final Map<String, (int, Object?)> routes = {};
  final List<RecordedRequest> requests = [];

  void on(String route, Object? body, {int status = 200}) => routes[route] = (status, body);

  RecordedRequest get last => requests.last;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    final path = o.path.replaceFirst('/api/v1', '');
    requests.add(RecordedRequest(o.method, path, Map<String, dynamic>.of(o.queryParameters), o.data));
    final hit = routes['${o.method} $path'];
    final (status, data) = hit ?? (404, {'title': 'Not found', 'code': 'NOT_FOUND', 'status': 404});
    return ResponseBody.fromString(jsonEncode(data), status, headers: {Headers.contentTypeHeader: ['application/problem+json']});
  }

  @override
  void close({bool force = false}) {}
}

const _site = SiteAddress(baseUrl: 'https://demo.example.test', input: 'demo', tenantCode: 'demo');

/// An [ApiClient] wired to [server] (no auth header logic; error mapping like the real client).
ApiClient apiFor(FakeServer server) {
  final ctx = ClientContext()..site = _site;
  final bare = buildBaseDio(adapter: server)..interceptors.add(TenantInterceptor(context: ctx, deviceGetter: () => DeviceMeta.fallback));
  final tokens = TokenManager(store: SecureStore(MemorySecureKv()), bareDio: bare, siteGetter: () => ctx.site, deviceGetter: () => DeviceMeta.fallback);
  final dio = buildBaseDio(adapter: server)
    ..interceptors.addAll([TenantInterceptor(context: ctx, deviceGetter: () => DeviceMeta.fallback), ErrorMappingInterceptor()]);
  return ApiClient(dio: dio, tokens: tokens);
}
