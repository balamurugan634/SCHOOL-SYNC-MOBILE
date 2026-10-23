import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True while the device has some network. (It says nothing about whether the
/// API is reachable; request errors cover that.)
class OnlineNotifier extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  bool build() {
    final c = Connectivity();
    _sub = c.onConnectivityChanged.listen((r) => state = _isOnline(r));
    ref.onDispose(() => _sub?.cancel());
    unawaited(c.checkConnectivity().then((r) => state = _isOnline(r)));
    return true;
  }

  static bool _isOnline(List<ConnectivityResult> r) => r.any((e) => e != ConnectivityResult.none);
}

final onlineProvider = NotifierProvider<OnlineNotifier, bool>(OnlineNotifier.new);
