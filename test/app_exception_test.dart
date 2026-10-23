import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:schoolsync/core/network/app_exception.dart';
import 'package:schoolsync/features/auth/auth_messages.dart';
import 'package:schoolsync/features/onboarding/connect_errors.dart';

void main() {
  group('problem+json parsing', () {
    test('invalid credentials', () {
      final e = AppException.fromProblem(401, {
        'type': 'https://schoolsync.app/problems/invalid-credentials',
        'title': 'Incorrect username or password',
        'status': 401,
        'code': 'INVALID_CREDENTIALS',
        'requestId': 'abc',
      });
      expect(e.kind, ErrorKind.unauthorized);
      expect(e.code, 'INVALID_CREDENTIALS');
      expect(e.message, 'Incorrect username or password');
      expect(e.requestId, 'abc');
      expect(e.status, 401);
    });

    test('account locked carries retryAfterSeconds', () {
      final e = AppException.fromProblem(423, {'title': 'Too many failed attempts. Try again later.', 'code': 'ACCOUNT_LOCKED', 'retryAfterSeconds': 75});
      expect(e.kind, ErrorKind.locked);
      expect(e.retryAfter, const Duration(seconds: 75));
      final f = describeLoginFailure(e);
      expect(f.lockedFor, const Duration(seconds: 75));
      expect(f.title, 'Account temporarily locked');
    });

    test('validation errors[] are parsed and the first is the display message', () {
      final e = AppException.fromProblem(422, {
        'title': 'Validation failed',
        'detail': 'One or more fields are invalid',
        'code': 'VALIDATION_ERROR',
        'errors': [
          {'path': 'newPassword', 'message': 'Use at least 10 characters'},
          {'path': 'identifier', 'message': 'Required'},
        ],
      });
      expect(e.kind, ErrorKind.validation);
      expect(e.errors, hasLength(2));
      expect(e.errors.first.path, 'newPassword');
      expect(e.displayMessage, 'Use at least 10 characters');
    });

    test('subscription expired (402) and unknown extras', () {
      final e = AppException.fromProblem(402, {'title': 'Subscription expired', 'code': 'SUBSCRIPTION_EXPIRED', 'foo': 1});
      expect(e.kind, ErrorKind.subscriptionExpired);
      expect(e.extra['foo'], 1);
      expect(e.extra.containsKey('code'), isFalse);
    });

    test('Retry-After header is used for 429', () {
      final e = AppException.fromProblem(429, {'title': 'Too many requests', 'code': 'RATE_LIMITED'}, headers: {'retry-after': ['30']});
      expect(e.kind, ErrorKind.rateLimited);
      expect(e.retryAfter, const Duration(seconds: 30));
    });

    test('tolerates non-problem bodies (HTML from a proxy, null)', () {
      final html = AppException.fromProblem(502, '<html>Bad gateway</html>');
      expect(html.kind, ErrorKind.server);
      expect(html.code, 'HTTP_502');
      final empty = AppException.fromProblem(404, null);
      expect(empty.kind, ErrorKind.notFound);
      expect(empty.message, isNotEmpty);
    });

    test('toString never includes the message or detail', () {
      final e = AppException.fromProblem(401, {'title': 'secret-ish title', 'detail': 'secret detail', 'code': 'X'});
      expect(e.toString(), isNot(contains('secret')));
    });
  });

  group('Dio mapping', () {
    final ro = RequestOptions(path: '/x');

    test('connection errors are network, timeouts are timeout', () {
      expect(AppException.fromDio(DioException(requestOptions: ro, type: DioExceptionType.connectionError)).kind, ErrorKind.network);
      expect(AppException.fromDio(DioException(requestOptions: ro, type: DioExceptionType.receiveTimeout)).kind, ErrorKind.timeout);
      expect(AppException.fromDio(DioException(requestOptions: ro, type: DioExceptionType.badCertificate)).kind, ErrorKind.badCertificate);
    });

    test('badResponse is parsed from the body', () {
      final res = Response<Object?>(requestOptions: ro, statusCode: 404, data: {'title': 'School site not found', 'code': 'SITE_NOT_FOUND'});
      final e = AppException.fromDio(DioException(requestOptions: ro, response: res, type: DioExceptionType.badResponse));
      expect(e.code, 'SITE_NOT_FOUND');
    });

    test('an already-mapped AppException passes through', () {
      const inner = AppException(kind: ErrorKind.forbidden, code: 'X', message: 'm');
      expect(AppException.fromDio(DioException(requestOptions: ro, error: inner)), same(inner));
    });
  });

  group('friendly messages', () {
    test('site errors for the connect screen', () {
      expect(describeConnectFailure(const AppException(kind: ErrorKind.notFound, code: 'SITE_NOT_FOUND', message: 'x')).title, 'School not found');
      expect(describeConnectFailure(const AppException(kind: ErrorKind.forbidden, code: 'SITE_SUSPENDED', message: 'x')).title, 'School unavailable');
      expect(describeConnectFailure(const AppException(kind: ErrorKind.network, code: 'NETWORK', message: 'x'), host: 'a.b').title, 'Cannot reach a.b');
      expect(describeConnectFailure(const AppException(kind: ErrorKind.notFound, code: 'NOT_SCHOOLSYNC', message: 'x')).title, 'Not a SchoolSync address');
    });

    test('login errors', () {
      expect(describeLoginFailure(const AppException(kind: ErrorKind.unauthorized, code: 'INVALID_CREDENTIALS', message: 'x')).message, contains('Incorrect'));
      expect(describeLoginFailure(const AppException(kind: ErrorKind.forbidden, code: 'ACCOUNT_DISABLED', message: 'x')).title, 'Account disabled');
      expect(describeLoginFailure(const AppException(kind: ErrorKind.network, code: 'NETWORK', message: 'x')).title, contains('offline'));
    });

    test('password policy mirrors the API', () {
      expect(const PasswordPolicy('Demo@12345').valid, isTrue);
      expect(const PasswordPolicy('short1A').valid, isFalse);
      expect(const PasswordPolicy('alllowercase1').valid, isFalse);
      expect(const PasswordPolicy('ALLUPPERCASE1').valid, isFalse);
      expect(const PasswordPolicy('NoDigitsHereAtAll').valid, isFalse);
    });
  });
}
