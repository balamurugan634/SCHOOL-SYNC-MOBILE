import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/network/api_client.dart';
import 'package:schoolsync/core/network/device_meta.dart';
import 'package:schoolsync/core/network/token_manager.dart';
import 'package:schoolsync/core/storage/secure_store.dart';
import 'package:schoolsync/core/util/site_address.dart';
import 'package:schoolsync/data/models/auth_models.dart';

const _site = SiteAddress(baseUrl: 'https://demo.example.test', input: 'demo', tenantCode: 'demo');

AuthTokens _tokens(String access, String refresh, {Duration ttl = const Duration(minutes: 15)}) =>
    AuthTokens(accessToken: access, refreshToken: refresh, expiresAt: DateTime.now().add(ttl), sessionId: 's1');

Map<String, dynamic> _meJson() => {
  'id': 'u1', 'userType': 'staff', 'displayName': 'Ada', 'username': 'ada', 'email': null, 'phone': null, 'avatarUrl': null,
  'locale': 'en', 'mustChangePassword': false, 'roles': ['principal'], 'experience': 'management', 'permissions': {},
  'profile': {'studentId': null, 'guardianId': null, 'staffId': null, 'children': [], 'sectionId': null, 'gradeName': null, 'sectionName': null, 'classTeacherSectionIds': [], 'assignedSectionIds': []},
};

/// A fake server: validates bearer tokens, rotates refresh tokens, and can inject races.
class FakeApi implements HttpClientAdapter {
  String validAccess = 'access-2';
  String currentRefresh = 'refresh-1';
  int refreshCalls = 0;
  int dataCalls = 0;
  List<String> refreshTokensSeen = [];

  /// Responses to give, in order, for /auth/refresh before normal behaviour.
  final List<(int, Map<String, dynamic>)> scripted = [];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    ResponseBody json(int status, Object data) => ResponseBody.fromString(jsonEncode(data), status, headers: {Headers.contentTypeHeader: ['application/json']});
    if (o.path.endsWith('/auth/refresh')) {
      refreshCalls++;
      final sent = (o.data as Map)['refreshToken'] as String;
      refreshTokensSeen.add(sent);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      if (scripted.isNotEmpty) {
        final (status, data) = scripted.removeAt(0);
        return json(status, data);
      }
      if (sent != currentRefresh) return json(401, {'title': 'Session expired', 'code': 'SESSION_EXPIRED'});
      currentRefresh = 'refresh-${refreshCalls + 1}';
      validAccess = 'access-${refreshCalls + 2}';
      return json(200, {
        'accessToken': validAccess, 'refreshToken': currentRefresh, 'tokenType': 'Bearer', 'expiresIn': 900, 'sessionId': 's1', 'user': _meJson(),
      });
    }
    dataCalls++;
    final auth = o.headers['Authorization'] as String?;
    if (auth != 'Bearer $validAccess') return json(401, {'title': 'Access token expired', 'code': 'TOKEN_EXPIRED'});
    return json(200, {'ok': true, 'tenant': o.headers['X-Tenant']});
  }

  @override
  void close({bool force = false}) {}
}

({ApiClient api, TokenManager tokens, FakeApi server, MemorySecureKv kv, List<SessionEndReason> ended}) _setup(AuthTokens start) {
  final server = FakeApi();
  final kv = MemorySecureKv();
  final store = SecureStore(kv);
  final ctx = ClientContext()..site = _site;
  final bare = buildBaseDio(adapter: server)..interceptors.add(TenantInterceptor(context: ctx, deviceGetter: () => DeviceMeta.fallback));
  final tokens = TokenManager(store: store, bareDio: bare, siteGetter: () => ctx.site, deviceGetter: () => DeviceMeta.fallback);
  final ended = <SessionEndReason>[];
  tokens.onSessionEnded = ended.add;
  final dio = buildBaseDio(adapter: server);
  dio.interceptors.addAll([
    TenantInterceptor(context: ctx, deviceGetter: () => DeviceMeta.fallback),
    AuthInterceptor(tokens: tokens, dio: dio),
    ErrorMappingInterceptor(),
  ]);
  return (api: ApiClient(dio: dio, tokens: tokens), tokens: tokens, server: server, kv: kv, ended: ended);
}

void main() {
  test('sends the bearer token and X-Tenant', () async {
    final s = _setup(_tokens('access-2', 'refresh-1'));
    await s.tokens.save(_tokens('access-2', 'refresh-1'));
    final res = await s.api.get('/anything') as Map;
    expect(res['tenant'], 'demo');
    expect(s.server.refreshCalls, 0);
  });

  test('concurrent 401s share ONE refresh (single flight) and all succeed', () async {
    final s = _setup(_tokens('stale', 'refresh-1'));
    await s.tokens.save(_tokens('stale', 'refresh-1'));
    final results = await Future.wait([for (var i = 0; i < 6; i++) s.api.get('/thing/$i')]);
    expect(results, hasLength(6));
    expect(s.server.refreshCalls, 1, reason: 'a rotating refresh token must only be used once');
    expect(s.server.refreshTokensSeen, ['refresh-1']);
    // New pair persisted.
    expect((await SecureStore(s.kv).readTokens())!.refreshToken, 'refresh-2');
  });

  test('refreshes proactively when the access token is about to expire', () async {
    final s = _setup(_tokens('access-2', 'refresh-1', ttl: const Duration(seconds: 5)));
    await s.tokens.save(_tokens('access-2', 'refresh-1', ttl: const Duration(seconds: 5)));
    await s.api.get('/thing');
    expect(s.server.refreshCalls, 1);
    expect(s.server.dataCalls, 1, reason: 'no wasted 401 round trip');
  });

  test('409 REFRESH_RACE retries with the latest stored token', () async {
    final s = _setup(_tokens('stale', 'refresh-1'));
    await s.tokens.save(_tokens('stale', 'refresh-1'));
    // Another isolate rotated the token meanwhile and stored the new pair.
    s.server.scripted.add((409, {'title': 'Refresh already in progress', 'code': 'REFRESH_RACE'}));
    Future<void>.delayed(const Duration(milliseconds: 100), () async {
      s.server.currentRefresh = 'refresh-9';
      s.server.validAccess = 'access-9';
      await SecureStore(s.kv).writeTokens(_tokens('access-9', 'refresh-9'));
    });
    final res = await s.api.get('/thing') as Map;
    expect(res['ok'], true);
    expect(s.server.refreshTokensSeen, ['refresh-1', 'refresh-9']);
    expect(s.ended, isEmpty);
  });

  test('SESSION_EXPIRED on refresh signs the person out and clears tokens', () async {
    final s = _setup(_tokens('stale', 'wrong-refresh'));
    await s.tokens.save(_tokens('stale', 'wrong-refresh'));
    await expectLater(s.api.get('/thing'), throwsA(isA<Object>()));
    expect(s.ended, [SessionEndReason.expired]);
    expect(s.tokens.hasSession, isFalse);
    expect(await SecureStore(s.kv).readTokens(), isNull);
  });

  test('a network failure during refresh keeps the session', () async {
    final s = _setup(_tokens('stale', 'refresh-1'));
    await s.tokens.save(_tokens('stale', 'refresh-1'));
    s.server.scripted.add((503, {'title': 'Unavailable', 'code': 'UNAVAILABLE'}));
    await expectLater(s.api.get('/thing'), throwsA(isA<Object>()));
    expect(s.ended, isEmpty);
    expect(s.tokens.hasSession, isTrue);
  });
}
