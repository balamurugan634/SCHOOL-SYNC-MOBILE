class SiteFeatures {
  const SiteFeatures({
    this.fees = true,
    this.transport = true,
    this.library = true,
    this.onlinePayments = false,
    this.studentLogin = true,
  });

  final bool fees;
  final bool transport;
  final bool library;
  final bool onlinePayments;
  final bool studentLogin;

  factory SiteFeatures.fromJson(Map<String, dynamic> j) => SiteFeatures(
    fees: j['fees'] as bool? ?? true,
    transport: j['transport'] as bool? ?? true,
    library: j['library'] as bool? ?? true,
    onlinePayments: j['onlinePayments'] as bool? ?? false,
    studentLogin: j['studentLogin'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'fees': fees,
    'transport': transport,
    'library': library,
    'onlinePayments': onlinePayments,
    'studentLogin': studentLogin,
  };
}

/// Public school information from `GET /api/v1/site/info`.
class SiteInfo {
  const SiteInfo({
    required this.code,
    required this.name,
    required this.primaryColor,
    this.shortName,
    this.logoUrl,
    this.accentColor,
    this.timezone = 'UTC',
    this.locale = 'en',
    this.currency = 'INR',
    this.features = const SiteFeatures(),
    this.readOnly = false,
    this.apiVersion = '',
    this.minAppVersion = '0.0.0',
  });

  final String code;
  final String name;
  final String? shortName;
  final String? logoUrl;
  final String primaryColor;
  final String? accentColor;
  final String timezone;
  final String locale;
  final String currency;
  final SiteFeatures features;

  /// Subscription lapsed: reads work, writes are refused.
  final bool readOnly;
  final String apiVersion;
  final String minAppVersion;

  String get displayName => (shortName != null && shortName!.trim().isNotEmpty) ? shortName!.trim() : name;

  factory SiteInfo.fromJson(Map<String, dynamic> j) {
    final api = (j['api'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SiteInfo(
      code: j['code'] as String,
      name: j['name'] as String,
      shortName: j['shortName'] as String?,
      logoUrl: j['logoUrl'] as String?,
      primaryColor: (j['primaryColor'] as String?) ?? '#4f46e5',
      accentColor: j['accentColor'] as String?,
      timezone: (j['timezone'] as String?) ?? 'UTC',
      locale: (j['locale'] as String?) ?? 'en',
      currency: (j['currency'] as String?) ?? 'INR',
      features: SiteFeatures.fromJson((j['features'] as Map?)?.cast<String, dynamic>() ?? const {}),
      readOnly: j['readOnly'] as bool? ?? false,
      apiVersion: (api['version'] as String?) ?? '',
      minAppVersion: (api['minAppVersion'] as String?) ?? '0.0.0',
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'shortName': shortName,
    'logoUrl': logoUrl,
    'primaryColor': primaryColor,
    'accentColor': accentColor,
    'timezone': timezone,
    'locale': locale,
    'currency': currency,
    'features': features.toJson(),
    'readOnly': readOnly,
    'api': {'version': apiVersion, 'minAppVersion': minAppVersion},
  };
}
