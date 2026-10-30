import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

/// Opens a link outside the app (browser or the Zoom / Meet app). Behind a provider so tests never open anything.
abstract interface class ExternalLauncher {
  /// `true` when the system accepted the link.
  Future<bool> open(Uri uri);
}

class SystemExternalLauncher implements ExternalLauncher {
  const SystemExternalLauncher();

  @override
  Future<bool> open(Uri uri) async {
    try {
      return await ul.launchUrl(uri, mode: ul.LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open a link: ${e.runtimeType}');
      return false;
    }
  }
}

final externalLauncherProvider = Provider<ExternalLauncher>((ref) => const SystemExternalLauncher());

/// The link as a `Uri` if it is safe to hand to the system: `https` with a host and no embedded credentials
/// (`https://zoom.us@evil.example` would look like Zoom but is not). Everything else (`http`, `intent:`,
/// `javascript:`, `file:`, relative paths, garbage) returns `null`.
Uri? httpsUri(String? url) {
  final text = url?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) return null;
  return uri;
}
