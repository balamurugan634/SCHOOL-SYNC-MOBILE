import 'me.dart';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.sessionId,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  final String sessionId;

  bool expiresWithin(Duration d) => DateTime.now().add(d).isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.millisecondsSinceEpoch,
    'sessionId': sessionId,
  };

  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(j['expiresAt'] as int),
    sessionId: j['sessionId'] as String,
  );
}

class TokenResponse {
  const TokenResponse({required this.tokens, required this.user});
  final AuthTokens tokens;
  final Me user;

  factory TokenResponse.fromJson(Map<String, dynamic> j) {
    final expiresIn = (j['expiresIn'] as num?)?.toInt() ?? 900;
    return TokenResponse(
      tokens: AuthTokens(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
        sessionId: j['sessionId'] as String,
      ),
      user: Me.fromJson((j['user'] as Map).cast<String, dynamic>()),
    );
  }
}

class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.platform,
    required this.createdAt,
    required this.lastUsedAt,
    required this.current,
    this.deviceName,
    this.appVersion,
    this.ip,
  });

  final String id;
  final String platform;
  final String? deviceName;
  final String? appVersion;
  final String? ip;
  final DateTime createdAt;
  final DateTime lastUsedAt;
  final bool current;

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
    id: j['id'] as String,
    platform: (j['platform'] as String?) ?? 'web',
    deviceName: j['deviceName'] as String?,
    appVersion: j['appVersion'] as String?,
    ip: j['ip'] as String?,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    lastUsedAt: DateTime.tryParse(j['lastUsedAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    current: j['current'] as bool? ?? false,
  );
}
