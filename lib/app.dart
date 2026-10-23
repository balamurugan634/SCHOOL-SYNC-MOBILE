import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/design.dart';
import 'core/providers.dart';
import 'features/auth/session.dart';
import 'features/security/lifecycle_gate.dart';
import 'router/app_router.dart';

class SchoolSyncApp extends ConsumerWidget {
  const SchoolSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final seed = ref.watch(sessionProvider.select((s) => parseHexColor(s.siteInfo?.primaryColor)));
    final mode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'SchoolSync',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: mode,
      theme: buildTheme(seed, Brightness.light),
      darkTheme: buildTheme(seed, Brightness.dark),
      themeAnimationDuration: const Duration(milliseconds: 160),
      builder: (context, child) {
        // System bar icons follow the app theme (the splash/intro/headers are tinted, so keep it simple).
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
            statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: dark ? Brightness.dark : Brightness.light,
          ),
          child: AppSkeletonTheme(child: LifecycleGate(child: child ?? const SizedBox.shrink())),
        );
      },
    );
  }
}
