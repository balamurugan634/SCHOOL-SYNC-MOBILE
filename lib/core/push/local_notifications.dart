import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android notification channels. Ids are stable API: the server may target them.
abstract final class Channels {
  static const general = AndroidNotificationChannel(
    'general',
    'General',
    description: 'Announcements, homework, attendance and fee updates.',
    importance: Importance.defaultImportance,
  );
  static const urgent = AndroidNotificationChannel(
    'urgent',
    'Urgent',
    description: 'Time-critical alerts from your school.',
    importance: Importance.max,
  );
}

/// What the server puts in `data` of an FCM message.
class PushData {
  const PushData({this.notificationId, this.type, this.route});
  final String? notificationId;
  final String? type;
  final String? route;

  factory PushData.fromMap(Map<String, dynamic> m) => PushData(
    notificationId: m['notificationId']?.toString(),
    type: m['type']?.toString(),
    route: m['route']?.toString(),
  );

  String toPayload() => jsonEncode({'notificationId': notificationId, 'type': type, 'route': route});

  static PushData? fromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      return PushData.fromMap((jsonDecode(payload) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}

/// Wraps flutter_local_notifications. Safe to call from the background isolate.
abstract final class LocalNotifications {
  static final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init({void Function(PushData data)? onTap}) async {
    if (_ready) return;
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_schoolsync'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final data = PushData.fromPayload(r.payload);
        if (data != null) onTap?.call(data);
      },
    );
    final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(Channels.general);
    await android?.createNotificationChannel(Channels.urgent);
    _ready = true;
  }

  /// The launch payload when a tap started the app from a terminated state.
  static Future<PushData?> launchData() async {
    final d = await plugin.getNotificationAppLaunchDetails();
    if (d?.didNotificationLaunchApp ?? false) return PushData.fromPayload(d?.notificationResponse?.payload);
    return null;
  }

  static bool _isUrgent(RemoteMessage m) {
    final channel = m.notification?.android?.channelId;
    if (channel == Channels.urgent.id) return true;
    final t = m.data['type']?.toString();
    return m.data['priority'] == 'urgent' || t == 'urgent' || t == 'emergency';
  }

  /// Shows an FCM message ourselves (foreground, or data-only in background).
  static Future<void> showRemote(RemoteMessage m) async {
    if (!_ready) await init();
    final title = m.notification?.title ?? m.data['title']?.toString();
    final body = m.notification?.body ?? m.data['body']?.toString();
    if (title == null && body == null) return;
    final data = PushData.fromMap(m.data.cast<String, dynamic>());
    final urgent = _isUrgent(m);
    final channel = urgent ? Channels.urgent : Channels.general;
    final idSource = data.notificationId ?? m.messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
    await plugin.show(
      id: idSource.hashCode & 0x7fffffff,
      title: title,
      body: body,
      payload: data.toPayload(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: urgent ? Priority.max : Priority.defaultPriority,
          icon: 'ic_stat_schoolsync',
          color: const Color(0xFF4F46E5),
          // Contents stay hidden on a secure lock screen (blueprint: no private data on lock screens).
          visibility: NotificationVisibility.private,
          category: AndroidNotificationCategory.message,
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
    );
  }

  static Future<bool> areEnabled() async {
    if (Platform.isAndroid) {
      return await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled() ?? true;
    }
    final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final p = await ios?.checkPermissions();
    return p?.isEnabled ?? false;
  }

  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? true;
    }
    final ios = plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }
}
