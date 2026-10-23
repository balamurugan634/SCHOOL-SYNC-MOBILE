/// A normalised school address: where the API lives and, when known, which
/// tenant to ask for.
class SiteAddress {
  const SiteAddress({required this.baseUrl, required this.input, this.tenantCode});

  /// Origin only, no trailing slash: `https://greenvalley.schoolsync.app`.
  final String baseUrl;

  /// What the person typed (trimmed). Kept for display and for re-validation.
  final String input;

  /// Sent as `X-Tenant`. Set for code-style input in dev mode, and for every
  /// site once `/site/info` has told us the authoritative code.
  final String? tenantCode;

  SiteAddress withTenant(String code) => SiteAddress(baseUrl: baseUrl, input: input, tenantCode: code);

  String get host => Uri.parse(baseUrl).host;

  Map<String, dynamic> toJson() => {'baseUrl': baseUrl, 'input': input, 'tenantCode': tenantCode};

  factory SiteAddress.fromJson(Map<String, dynamic> j) =>
      SiteAddress(baseUrl: j['baseUrl'] as String, input: (j['input'] as String?) ?? '', tenantCode: j['tenantCode'] as String?);

  @override
  bool operator ==(Object other) =>
      other is SiteAddress && other.baseUrl == baseUrl && other.tenantCode == tenantCode;

  @override
  int get hashCode => Object.hash(baseUrl, tenantCode);

  @override
  String toString() => 'SiteAddress($baseUrl, tenant: $tenantCode)';
}

enum SiteInputProblem { empty, badUrl, insecure, badCode, unsupportedScheme }

class SiteInputException implements Exception {
  const SiteInputException(this.problem);
  final SiteInputProblem problem;

  String get message => switch (problem) {
    SiteInputProblem.empty => 'Enter your school code or website address.',
    SiteInputProblem.badUrl => 'That address does not look right. Try something like https://greenvalley.schoolsync.app',
    SiteInputProblem.insecure => 'For your safety only secure (https) school addresses are allowed.',
    SiteInputProblem.badCode => 'School codes use 3 to 31 letters, numbers or hyphens, and start with a letter.',
    SiteInputProblem.unsupportedScheme => 'Only https:// addresses are supported.',
  };

  @override
  String toString() => 'SiteInputException($problem)';
}

/// Turns whatever the person typed into a [SiteAddress].
///
/// Accepts either a full URL (`https://greenvalley.schoolsync.app`, a bare host
/// such as `greenvalley.schoolsync.app`) or a short school code (`greenvalley`)
/// that is expanded to `https://<code>.<baseDomain>`. With a [devApi] every code
/// goes to that one API and is carried in the `X-Tenant` header instead.
SiteAddress normalizeSiteInput(
  String raw, {
  required String baseDomain,
  String devApi = '',
  bool allowInsecure = false,
}) {
  final input = raw.trim();
  if (input.isEmpty) throw const SiteInputException(SiteInputProblem.empty);
  if (input.contains(RegExp(r'\s'))) throw const SiteInputException(SiteInputProblem.badUrl);

  final looksLikeUrl = input.contains('://') || input.contains('.') || input.contains('/') || input.contains(':');
  if (!looksLikeUrl) {
    final code = input.toLowerCase();
    if (!siteCodePattern.hasMatch(code)) throw const SiteInputException(SiteInputProblem.badCode);
    final dev = devApi.trim();
    if (dev.isNotEmpty) {
      return SiteAddress(baseUrl: _origin(Uri.parse(dev)), input: input, tenantCode: code);
    }
    return SiteAddress(baseUrl: 'https://$code.${baseDomain.trim().toLowerCase()}', input: input);
  }

  var candidate = input;
  if (!candidate.contains('://')) candidate = 'https://$candidate';
  final Uri uri;
  try {
    uri = Uri.parse(candidate);
  } on FormatException {
    throw const SiteInputException(SiteInputProblem.badUrl);
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') throw const SiteInputException(SiteInputProblem.unsupportedScheme);
  if (scheme == 'http' && !allowInsecure) throw const SiteInputException(SiteInputProblem.insecure);
  if (uri.userInfo.isNotEmpty) throw const SiteInputException(SiteInputProblem.badUrl);
  final host = uri.host.toLowerCase();
  if (host.isEmpty || !_hostPattern.hasMatch(host)) throw const SiteInputException(SiteInputProblem.badUrl);
  if (!allowInsecure && (host == 'localhost' || _ipv4.hasMatch(host))) {
    throw const SiteInputException(SiteInputProblem.insecure);
  }
  return SiteAddress(baseUrl: _origin(uri.replace(host: host, scheme: scheme)), input: input);
}

/// Matches the site-code rule used by the API (`SITE_CODE_RE`).
final RegExp siteCodePattern = RegExp(r'^[a-z][a-z0-9-]{2,30}$');
final RegExp _hostPattern = RegExp(r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)*$');
final RegExp _ipv4 = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$');

String _origin(Uri uri) {
  final defaultPort = uri.scheme == 'https' ? 443 : 80;
  final port = uri.hasPort && uri.port != defaultPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port';
}

/// Normalises what is typed into the debug-only "API address" field
/// (`192.168.1.20:4000`, `http://10.0.2.2:4000/`) to an origin like `http://192.168.1.20:4000`.
/// Returns `''` for blank input and `null` when it cannot be an address.
String? normalizeDevApi(String raw) {
  var v = raw.trim();
  if (v.isEmpty) return '';
  if (v.contains(RegExp(r'\s'))) return null;
  if (!v.contains('://')) v = 'http://$v';
  final Uri uri;
  try {
    uri = Uri.parse(v);
  } on FormatException {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if ((scheme != 'http' && scheme != 'https') || uri.userInfo.isNotEmpty) return null;
  final host = uri.host.toLowerCase();
  if (host.isEmpty || !_hostPattern.hasMatch(host)) return null;
  return _origin(uri.replace(host: host, scheme: scheme));
}
