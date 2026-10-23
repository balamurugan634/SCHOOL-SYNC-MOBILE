import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';

/// Initialises Firebase from `--dart-define` values or, failing that, from the
/// native config file (`google-services.json` / `GoogleService-Info.plist`).
/// If neither exists the app simply runs without push.
abstract final class FirebaseBootstrap {
  static bool ready = false;

  static Future<bool> init() async {
    if (ready) return true;
    try {
      if (Firebase.apps.isNotEmpty) {
        ready = true;
        return true;
      }
      if (Env.hasFirebaseDefines) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: Env.firebaseApiKey,
            appId: Env.firebaseAppId,
            messagingSenderId: Env.firebaseSenderId,
            projectId: Env.firebaseProjectId,
            storageBucket: Env.firebaseStorageBucket.isEmpty ? null : Env.firebaseStorageBucket,
          ),
        );
      } else {
        // Works only when the native config file was bundled at build time.
        await Firebase.initializeApp();
      }
      ready = true;
    } catch (e) {
      ready = false;
      if (kDebugMode) debugPrint('[push] Firebase not configured, push disabled.');
    }
    return ready;
  }
}
