import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/widgets.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/design/keyboard_inset.dart';
import 'core/network/device_meta.dart';
import 'core/providers.dart';
import 'core/push/background_handler.dart';
import 'core/push/firebase_bootstrap.dart';
import 'core/storage/prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  KeyboardInset.track();

  // Never let a stray error print tokens or personal data in release builds.
  if (!kDebugMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  FlutterError.onError = (details) {
    if (kDebugMode) FlutterError.dumpErrorToConsole(details);
  };

  // Draw behind the system bars (edge-to-edge); the app sets icon colours per theme.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent, systemNavigationBarContrastEnforced: false, systemStatusBarContrastEnforced: false));
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  final results = await Future.wait<Object?>([
    SharedPreferences.getInstance(),
    DeviceMeta.load(),
    FirebaseBootstrap.init(),
  ]);
  if (FirebaseBootstrap.ready) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  runApp(
    ProviderScope(
      // Riverpod 3 retries failed providers automatically; our repositories handle retry explicitly.
      retry: (retryCount, error) => null,
      overrides: [
        prefsProvider.overrideWithValue(AppPrefs(results[0]! as SharedPreferences)),
        deviceMetaProvider.overrideWithValue(results[1]! as DeviceMeta),
      ],
      child: const SchoolSyncApp(),
    ),
  );
}
