import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/push/push_service.dart';
import '../features/auth/change_password_screen.dart';
import '../features/auth/forgot_password_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/session.dart';
import '../features/auth/sessions_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/connect_school_screen.dart';
import '../features/onboarding/intro_screen.dart';
import '../features/onboarding/primer_screens.dart';
import '../features/onboarding/update_required_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/security/lock_screen.dart';
import '../features/shell/fade_through_branches.dart';
import '../features/shell/shell_scaffold.dart';
import '../features/shell/tab_body.dart';
import '../features/splash/splash_screen.dart';
import 'guard.dart';
import 'role_modules.dart';
import 'routes_shared_list.dart';
import 'routes.dart';
import 'transitions.dart';

/// Re-evaluates the redirect whenever the session changes.
class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Ref ref) {
    _sub = ref.listen<AppSession>(sessionProvider, (prev, next) {
      if (prev == null || targetRouteFor(prev) != targetRouteFor(next) || prev.me?.id != next.me?.id) notifyListeners();
    });
  }
  late final ProviderSubscription<AppSession> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

GoRoute _tab(String path, int index) => GoRoute(
  path: path,
  pageBuilder: (c, s) => NoTransitionPage<void>(key: s.pageKey, child: TabBody(index: index)),
);

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _SessionRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(ref.read(sessionProvider), state.uri.toString()),
    routes: [
      GoRoute(path: Routes.splash, pageBuilder: (c, s) => fadeThroughPage(key: s.pageKey, child: const SplashScreen())),
      GoRoute(path: Routes.intro, pageBuilder: (c, s) => fadeThroughPage(key: s.pageKey, child: const IntroScreen())),
      GoRoute(path: Routes.connect, pageBuilder: (c, s) => sharedAxisPage(key: s.pageKey, child: const ConnectSchoolScreen())),
      GoRoute(path: Routes.update, pageBuilder: (c, s) => fadeThroughPage(key: s.pageKey, child: const UpdateRequiredScreen())),
      GoRoute(path: Routes.login, pageBuilder: (c, s) => sharedAxisPage(key: s.pageKey, child: const LoginScreen())),
      GoRoute(path: Routes.forgot, pageBuilder: (c, s) => sharedAxisPage(key: s.pageKey, child: const ForgotPasswordScreen())),
      GoRoute(path: Routes.forcePassword, pageBuilder: (c, s) => sharedAxisPage(key: s.pageKey, child: const ChangePasswordScreen(forced: true))),
      GoRoute(path: Routes.primerNotifications, pageBuilder: (c, s) => sharedAxisPage(key: s.pageKey, child: const NotificationsPrimerScreen())),
      GoRoute(path: Routes.primerBiometric, pageBuilder: (c, s) => sharedAxisPage(key: s.pageKey, child: const BiometricPrimerScreen())),
      GoRoute(path: Routes.locked, pageBuilder: (c, s) => fadeThroughPage(key: s.pageKey, child: const LockScreen())),

      // ── the app: one shell, five tabs, content chosen by the user's experience ──
      StatefulShellRoute(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        navigatorContainerBuilder: (context, shell, children) => FadeThroughBranches(index: shell.currentIndex, children: children),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, pageBuilder: (c, s) => NoTransitionPage<void>(key: s.pageKey, child: const TabBody(index: 0)))]),
          StatefulShellBranch(routes: [_tab('/tab/1', 1)]),
          StatefulShellBranch(routes: [_tab('/tab/2', 2)]),
          StatefulShellBranch(routes: [_tab('/tab/3', 3)]),
          StatefulShellBranch(routes: [_tab('/tab/4', 4)]),
        ],
      ),
      // Pushed routes of every role experience (see routes_<role>.dart).
      for (final m in roleModules) ...m.routes,
      // Pushed screens shared by student and parent.
      ...sharedRoutes,

      GoRoute(path: Routes.settings, builder: (c, s) => const SettingsScreen()),
      GoRoute(path: Routes.sessions, builder: (c, s) => const SessionsScreen()),
      GoRoute(path: Routes.changePassword, builder: (c, s) => const ChangePasswordScreen()),
      GoRoute(path: Routes.notifications, builder: (c, s) => const NotificationsScreen()),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('That page does not exist.')),
    ),
  );

  // Notification taps: once the person is in the app, jump to the requested route.
  ref.listen<String?>(pendingRouteProvider, (_, route) => _consume(ref, router, route));
  ref.listen<AppSession>(sessionProvider, (_, _) => _consume(ref, router, ref.read(pendingRouteProvider)));

  ref.onDispose(router.dispose);
  return router;
});

void _consume(Ref ref, GoRouter router, String? route) {
  if (route == null) return;
  if (targetRouteFor(ref.read(sessionProvider)) != Routes.home) return; // not ready yet; keep it pending
  ref.read(pendingRouteProvider.notifier).set(null);
  router.push(route);
}
