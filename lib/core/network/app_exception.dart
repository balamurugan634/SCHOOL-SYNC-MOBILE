import 'package:dio/dio.dart';

enum ErrorKind {
  network,
  timeout,
  badCertificate,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  locked,
  rateLimited,
  subscriptionExpired,
  upgradeRequired,
  server,
  cancelled,
  unknown,
}

class FieldError {
  const FieldError({required this.path, required this.message});
  final String path;
  final String message;
}

/// Every failure that leaves the networking layer. Built from RFC 9457
/// `application/problem+json` bodies; transport problems get a synthetic code.
class AppException implements Exception {
  const AppException({
    required this.kind,
    required this.code,
    required this.message,
    this.status,
    this.detail,
    this.errors = const [],
    this.requestId,
    this.retryAfter,
    this.extra = const {},
  });

  final ErrorKind kind;

  /// Stable machine code from the API (`INVALID_CREDENTIALS`) or a client one
  /// (`NETWORK`, `TIMEOUT`).
  final String code;

  /// The API `title`, safe to show to people.
  final String message;
  final String? detail;
  final int? status;
  final List<FieldError> errors;
  final String? requestId;
  final Duration? retryAfter;
  final Map<String, dynamic> extra;

  bool get isNetwork => kind == ErrorKind.network || kind == ErrorKind.timeout;
  bool get isAuthFailure => kind == ErrorKind.unauthorized;

  /// Best single sentence for the UI.
  String get displayMessage {
    final d = detail;
    if (kind == ErrorKind.validation && errors.isNotEmpty) return errors.first.message;
    if (d != null && d.isNotEmpty && kind != ErrorKind.validation) return d;
    return message;
  }

  static ErrorKind _kindFor(int status, String code) {
    if (code == 'SUBSCRIPTION_EXPIRED' || status == 402) return ErrorKind.subscriptionExpired;
    if (code == 'ACCOUNT_LOCKED' || status == 423) return ErrorKind.locked;
    return switch (status) {
      401 => ErrorKind.unauthorized,
      403 => ErrorKind.forbidden,
      404 => ErrorKind.notFound,
      409 => ErrorKind.conflict,
      422 || 400 => ErrorKind.validation,
      426 => ErrorKind.upgradeRequired,
      429 => ErrorKind.rateLimited,
      >= 500 => ErrorKind.server,
      _ => ErrorKind.unknown,
    };
  }

  /// Parses a problem+json body (already decoded). Tolerates bodies that are
  /// not problem documents (proxies, HTML error pages).
  factory AppException.fromProblem(int status, Object? body, {Map<String, List<String>>? headers}) {
    final map = body is Map ? body.cast<String, dynamic>() : const <String, dynamic>{};
    final code = (map['code'] as String?) ?? 'HTTP_$status';
    final title = (map['title'] as String?)?.trim();
    final errs = <FieldError>[];
    final rawErrors = map['errors'];
    if (rawErrors is List) {
      for (final e in rawErrors) {
        if (e is Map) {
          errs.add(FieldError(path: '${e['path'] ?? ''}', message: '${e['message'] ?? 'Invalid'}'));
        }
      }
    }

    int? retrySeconds;
    final ra = map['retryAfterSeconds'];
    if (ra is num) retrySeconds = ra.toInt();
    final headerRa = headers?['retry-after']?.first;
    retrySeconds ??= headerRa == null ? null : int.tryParse(headerRa);

    final extra = Map<String, dynamic>.of(map)
      ..removeWhere((k, _) => const {'type', 'title', 'status', 'code', 'detail', 'errors', 'requestId'}.contains(k));

    return AppException(
      kind: _kindFor(status, code),
      code: code,
      status: status,
      message: (title != null && title.isNotEmpty) ? title : _defaultTitle(status),
      detail: (map['detail'] as String?)?.trim(),
      errors: errs,
      requestId: map['requestId'] as String?,
      retryAfter: retrySeconds == null ? null : Duration(seconds: retrySeconds),
      extra: extra,
    );
  }

  factory AppException.fromDio(DioException e) {
    final inner = e.error;
    if (inner is AppException) return inner;
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const AppException(
          kind: ErrorKind.timeout,
          code: 'TIMEOUT',
          message: 'The server took too long to respond.',
        );
      case DioExceptionType.badCertificate:
        return const AppException(
          kind: ErrorKind.badCertificate,
          code: 'BAD_CERTIFICATE',
          message: 'The secure connection could not be verified.',
        );
      case DioExceptionType.cancel:
        return const AppException(kind: ErrorKind.cancelled, code: 'CANCELLED', message: 'Request cancelled.');
      case DioExceptionType.connectionError:
        return const AppException(
          kind: ErrorKind.network,
          code: 'NETWORK',
          message: 'Cannot reach the server. Check your internet connection.',
        );
      case DioExceptionType.badResponse:
        final r = e.response!;
        return AppException.fromProblem(r.statusCode ?? 0, r.data, headers: r.headers.map);
      case DioExceptionType.unknown:
        final msg = '${e.error ?? ''}';
        if (msg.contains('HandshakeException') || msg.contains('CERTIFICATE') || msg.contains('TlsException')) {
          return const AppException(
            kind: ErrorKind.badCertificate,
            code: 'BAD_CERTIFICATE',
            message: 'The secure connection could not be verified.',
          );
        }
        if (msg.contains('SocketException') || msg.contains('Connection') || msg.contains('Network')) {
          return const AppException(
            kind: ErrorKind.network,
            code: 'NETWORK',
            message: 'Cannot reach the server. Check your internet connection.',
          );
        }
        return const AppException(kind: ErrorKind.unknown, code: 'UNKNOWN', message: 'Something went wrong.');
    }
  }

  static String _defaultTitle(int status) => switch (status) {
    401 => 'You need to sign in again.',
    403 => 'You do not have permission to do that.',
    404 => 'We could not find that.',
    429 => 'Too many requests. Please slow down.',
    >= 500 => 'The server had a problem. Please try again.',
    _ => 'Something went wrong.',
  };

  /// Converts anything thrown into an [AppException].
  static AppException from(Object error) {
    if (error is AppException) return error;
    if (error is DioException) return AppException.fromDio(error);
    return const AppException(kind: ErrorKind.unknown, code: 'UNKNOWN', message: 'Something went wrong.');
  }

  @override
  String toString() => 'AppException($code, status: $status)';
}
