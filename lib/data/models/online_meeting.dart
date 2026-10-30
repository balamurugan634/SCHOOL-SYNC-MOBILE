import 'package:flutter/foundation.dart';

import '../json.dart';

/// Who hosts the call. Anything else the server may add later is not understood by this app version.
enum OnlineProvider {
  zoom('Zoom'),
  google('Google Meet');

  const OnlineProvider(this.label);
  final String label;

  static OnlineProvider? parse(Object? v) => switch (v is String ? v.trim().toLowerCase() : null) {
    'zoom' => OnlineProvider.zoom,
    'google' => OnlineProvider.google,
    _ => null,
  };
}

enum OnlineMeetingStatus {
  /// The link exists and can be used.
  scheduled,

  /// The school asked for an online meeting but the provider refused; there is no link.
  failed,

  /// The link was withdrawn.
  cancelled;

  static OnlineMeetingStatus? parse(Object? v) => switch (v is String ? v.trim().toLowerCase() : null) {
    'scheduled' => OnlineMeetingStatus.scheduled,
    'failed' => OnlineMeetingStatus.failed,
    'cancelled' => OnlineMeetingStatus.cancelled,
    _ => null,
  };
}

/// The video call attached to an event or a parent-teacher meeting
/// (`onlineMeeting` on `/events` and `/meetings`, list items and details).
///
/// Absent, `null`, or a value this app does not understand all mean "no online meeting" ([tryParse] returns `null`).
@immutable
class OnlineMeeting {
  const OnlineMeeting({required this.provider, required this.status, this.joinUrl, this.passcode, this.startUrl});

  final OnlineProvider provider;
  final OnlineMeetingStatus status;

  /// The participants' link; `null` when [status] is failed or cancelled.
  final String? joinUrl;
  final String? passcode;

  /// The host's link. The server sends it only to staff who may edit the event or meeting.
  final String? startUrl;

  bool get isScheduled => status == OnlineMeetingStatus.scheduled;

  static OnlineMeeting? tryParse(Object? v) {
    if (v is! Map) return null;
    final j = jsonMap(v);
    final provider = OnlineProvider.parse(j['provider']);
    final status = OnlineMeetingStatus.parse(j['status']);
    if (provider == null || status == null) return null;
    return OnlineMeeting(provider: provider, status: status, joinUrl: _text(j['joinUrl']), passcode: _text(j['passcode']), startUrl: _text(j['startUrl']));
  }

  static String? _text(Object? v) {
    final s = jStr(v)?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  @override
  bool operator ==(Object other) => other is OnlineMeeting && other.provider == provider && other.status == status && other.joinUrl == joinUrl && other.passcode == passcode && other.startUrl == startUrl;

  @override
  int get hashCode => Object.hash(provider, status, joinUrl, passcode, startUrl);

  // Links and passcodes are credentials: keep them out of logs.
  @override
  String toString() => 'OnlineMeeting(${provider.name}, ${status.name})';
}
