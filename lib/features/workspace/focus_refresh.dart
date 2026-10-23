import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// Calls [onRefresh] when the person comes back to this screen after being away for [minAway]:
/// switching back to this bottom-bar tab, returning from a pushed screen, or reopening the app.
/// Tabs are kept alive by the shell (hidden with `TickerMode`), so without this a dashboard would show stale numbers
/// after, say, a roll call was submitted on another screen.
class RefreshOnFocus extends StatefulWidget {
  const RefreshOnFocus({super.key, required this.onRefresh, required this.child, this.minAway = const Duration(seconds: 15)});

  final VoidCallback onRefresh;
  final Widget child;
  final Duration minAway;

  @override
  State<RefreshOnFocus> createState() => _RefreshOnFocusState();
}

class _RefreshOnFocusState extends State<RefreshOnFocus> with WidgetsBindingObserver {
  ValueListenable<TickerModeData>? _visible;
  DateTime? _awaySince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = TickerMode.getValuesNotifier(context);
    if (!identical(next, _visible)) {
      _visible?.removeListener(_onVisibility);
      _visible = next..addListener(_onVisibility);
    }
  }

  void _onVisibility() {
    if (_visible?.value.enabled ?? true) {
      _back();
    } else {
      _awaySince ??= DateTime.now();
    }
  }

  void _back() {
    final since = _awaySince;
    _awaySince = null;
    if (since != null && DateTime.now().difference(since) >= widget.minAway) widget.onRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _awaySince ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed && (_visible?.value.enabled ?? true)) {
      _back();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _visible?.removeListener(_onVisibility);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
