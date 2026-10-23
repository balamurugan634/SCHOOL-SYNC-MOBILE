import '../../core/network/app_exception.dart';

class LoginFailure {
  const LoginFailure(this.message, {this.lockedFor, this.title});
  final String message;
  final String? title;

  /// Set for ACCOUNT_LOCKED so the UI can count down.
  final Duration? lockedFor;
}

/// Friendly sign-in errors, mapped from the API's stable codes.
LoginFailure describeLoginFailure(Object error) {
  final ex = AppException.from(error);
  switch (ex.code) {
    case 'INVALID_CREDENTIALS':
      return const LoginFailure('Incorrect username or password. Please check and try again.', title: 'Could not sign in');
    case 'ACCOUNT_LOCKED':
      final secs = ex.retryAfter?.inSeconds ?? (ex.extra['retryAfterSeconds'] as num?)?.toInt() ?? 60;
      return LoginFailure('Too many failed attempts, so sign-in is paused to protect your account.', title: 'Account temporarily locked', lockedFor: Duration(seconds: secs));
    case 'ACCOUNT_DISABLED':
      return const LoginFailure('This account has been disabled. Please contact the school office.', title: 'Account disabled');
    case 'STUDENT_LOGIN_DISABLED':
      return const LoginFailure('Student sign-in is not turned on for this school yet. Ask your school office.', title: 'Student sign-in unavailable');
    case 'SUBSCRIPTION_EXPIRED':
      return const LoginFailure('This school\'s subscription has ended, so changes are disabled. Please contact the school office.', title: 'School subscription ended');
    case 'RATE_LIMITED':
      return const LoginFailure('Too many attempts in a short time. Please wait a minute and try again.', title: 'Slow down');
  }
  switch (ex.kind) {
    case ErrorKind.network:
    case ErrorKind.timeout:
      return const LoginFailure('We could not reach your school\'s server. Check your internet connection and try again.', title: 'You seem to be offline');
    case ErrorKind.validation:
      return LoginFailure(ex.displayMessage, title: 'Check your details');
    case ErrorKind.rateLimited:
      return const LoginFailure('Too many attempts in a short time. Please wait a minute and try again.', title: 'Slow down');
    case ErrorKind.server:
      return const LoginFailure('The school\'s server is having trouble. Please try again in a few minutes.', title: 'Server problem');
    case ErrorKind.badCertificate:
      return const LoginFailure('The secure connection to your school could not be verified.', title: 'Connection not secure');
    default:
      return LoginFailure(ex.displayMessage, title: 'Could not sign in');
  }
}

/// Mirrors the API's password policy: at least 10 characters with upper, lower and a digit.
class PasswordPolicy {
  const PasswordPolicy(this.password);
  final String password;

  bool get longEnough => password.length >= 10;
  bool get hasUpper => RegExp(r'[A-Z]').hasMatch(password);
  bool get hasLower => RegExp(r'[a-z]').hasMatch(password);
  bool get hasDigit => RegExp(r'\d').hasMatch(password);
  bool get valid => longEnough && hasUpper && hasLower && hasDigit && password.length <= 128;
}
