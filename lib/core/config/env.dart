import 'package:flutter/foundation.dart';

/// Compile-time configuration, injected with `--dart-define=KEY=value`.
///
/// Nothing in here is a secret: Firebase client keys are identifiers, not
/// credentials, but they are still kept out of git so every deployment can use
/// its own project.
abstract final class Env {
  /// Domain that school codes are expanded against: `greenvalley` ->
  /// `https://greenvalley.$baseDomain`.
  static const baseDomain = String.fromEnvironment('BASE_DOMAIN', defaultValue: 'schoolsync.app');

  /// Development override. When set (for example `http://10.0.2.2:4000`) every
  /// site code is sent to this one API as `X-Tenant: <code>`.
  static const devApi = String.fromEnvironment('DEV_API');

  /// Comma separated base64 SHA-256 SPKI pins. Empty disables pinning.
  static const pinSha256 = String.fromEnvironment('PIN_SHA256');

  /// FLAG_SECURE / screen-capture protection. Off in debug builds so that
  /// `adb screencap` works; always on in profile/release unless disabled.
  static const _screenPrivacy = String.fromEnvironment('SCREEN_PRIVACY');
  static bool get screenPrivacy => _screenPrivacy.isEmpty ? !kDebugMode : _screenPrivacy == 'true';

  /// Minutes in the background before the biometric lock engages by default.
  static const defaultLockMinutes = int.fromEnvironment('LOCK_MINUTES', defaultValue: 1);

  /// Where the "update required" screen sends people.
  static const storeUrl = String.fromEnvironment(
    'STORE_URL',
    defaultValue: 'https://play.google.com/store/apps/details?id=com.schoolsync.app',
  );

  // --- Firebase (all optional) ---
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static bool get hasFirebaseDefines =>
      firebaseApiKey.isNotEmpty &&
      firebaseAppId.isNotEmpty &&
      firebaseSenderId.isNotEmpty &&
      firebaseProjectId.isNotEmpty;

  static bool get hasDevApi => devApi.trim().isNotEmpty;

  /// Plain `http://` site addresses are only tolerated outside release builds.
  static bool get allowInsecure => !kReleaseMode;

  static List<String> get pins =>
      pinSha256.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false);
}
