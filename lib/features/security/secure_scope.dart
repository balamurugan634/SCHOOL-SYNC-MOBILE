import 'package:flutter/widgets.dart';

import '../../core/security/platform_bridge.dart';

/// While [secure] is true (and this widget is mounted) the window is
/// FLAG_SECURE: no screenshots, no screen recording, blank recents thumbnail.
class SecureScope extends StatefulWidget {
  const SecureScope({super.key, required this.child, this.secure = true});
  final Widget child;
  final bool secure;

  @override
  State<SecureScope> createState() => _SecureScopeState();
}

class _SecureScopeState extends State<SecureScope> {
  bool _held = false;

  void _sync() {
    if (widget.secure && !_held) {
      ScreenPrivacy.acquire();
      _held = true;
    } else if (!widget.secure && _held) {
      ScreenPrivacy.release();
      _held = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(SecureScope old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    if (_held) ScreenPrivacy.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
