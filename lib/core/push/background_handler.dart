import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'firebase_bootstrap.dart';
import 'local_notifications.dart';

/// Runs in its own isolate when a message arrives while the app is not in the
/// foreground. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseBootstrap.init();
  // Messages with a `notification` block are drawn by the OS; only data-only
  // messages need us to build the notification.
  if (message.notification == null) {
    await LocalNotifications.init();
    await LocalNotifications.showRemote(message);
  }
}
