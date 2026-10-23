import '../features/auth/session.dart';
import 'routes.dart';

/// Where the person belongs right now, given everything we know.
///
///   splash -> intro (once) -> connect school (until one is saved) -> [update required]
///   -> login -> [app lock] -> [forced password change] -> permission primers -> home
///   (the role welcome tour is a dialog shown over home once per user)
String targetRouteFor(AppSession s) {
  if (!s.ready) return Routes.splash;
  if (!s.introSeen) return Routes.intro;
  if (!s.hasSite) return Routes.connect;
  if (s.forceUpdate) return Routes.update;
  if (!s.signedIn) return Routes.login;
  if (s.locked) return Routes.locked;
  if (s.me!.mustChangePassword) return Routes.forcePassword;
  if (s.primerStage == primerStageNotifications) return Routes.primerNotifications;
  if (s.primerStage == primerStageBiometric) return Routes.primerBiometric;
  return Routes.home;
}

/// go_router `redirect`: returns null when [location] is already right.
String? redirectFor(AppSession s, String location) {
  final path = Uri.parse(location).path;
  final target = targetRouteFor(s);

  if (target == Routes.home) {
    // Anywhere inside the app is fine; leave the gate screens.
    return Routes.gate.contains(path) ? Routes.home : null;
  }
  if (path == target) return null;
  // The login step has a sibling screen.
  if (target == Routes.login && path == Routes.forgot) return null;
  return target;
}
