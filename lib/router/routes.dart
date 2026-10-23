/// Every path in the app. Onboarding paths are mutually exclusive with the app proper.
abstract final class Routes {
  static const splash = '/splash';
  static const intro = '/intro';
  static const connect = '/connect';
  static const update = '/update';
  static const login = '/login';
  static const forgot = '/forgot';
  static const forcePassword = '/password-required';
  static const primerNotifications = '/primer/notifications';
  static const primerBiometric = '/primer/biometric';
  static const locked = '/locked';

  // In-app
  static const home = '/home';
  static String tab(int i) => i == 0 ? home : '/tab/$i';
  static const settings = '/settings';
  static const sessions = '/settings/sessions';
  static const changePassword = '/settings/password';
  static const notifications = '/notifications';
  static const profile = '/profile';

  /// Paths that belong to the onboarding / gate flow (everything else is "in the app").
  static const gate = {
    splash,
    intro,
    connect,
    update,
    login,
    forgot,
    forcePassword,
    primerNotifications,
    primerBiometric,
    locked,
  };
}
