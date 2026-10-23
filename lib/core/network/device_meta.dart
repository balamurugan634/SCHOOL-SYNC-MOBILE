import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Facts about this install that go into `device` on login/refresh and into the
/// `X-Client` header. Contains nothing that identifies the person.
class DeviceMeta {
  const DeviceMeta({required this.platform, required this.name, required this.appVersion, required this.buildNumber});

  /// `android` | `ios`, as the API expects.
  final String platform;
  final String name;
  final String appVersion;
  final String buildNumber;

  static const fallback = DeviceMeta(platform: 'android', name: 'Mobile device', appVersion: '1.0.0', buildNumber: '1');

  Map<String, dynamic> toDeviceJson({String? pushToken}) => {
    'platform': platform,
    'name': name,
    'appVersion': appVersion,
    if (pushToken != null && pushToken.length >= 20) 'pushToken': pushToken,
  };

  static Future<DeviceMeta> load() async {
    String name = 'Mobile device';
    var version = '1.0.0';
    var build = '1';
    try {
      final pkg = await PackageInfo.fromPlatform();
      version = pkg.version;
      build = pkg.buildNumber;
    } catch (_) {}
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        final maker = a.manufacturer.isEmpty ? '' : '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)} ';
        name = '$maker${a.model}'.trim();
      } else if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        name = i.utsname.machine.isNotEmpty ? '${i.model} (${i.utsname.machine})' : i.model;
      }
    } catch (_) {}
    return DeviceMeta(
      platform: Platform.isIOS ? 'ios' : 'android',
      name: name.length > 120 ? name.substring(0, 120) : name,
      appVersion: version,
      buildNumber: build,
    );
  }
}
