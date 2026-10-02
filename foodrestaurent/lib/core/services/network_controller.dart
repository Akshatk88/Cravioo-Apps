import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/legacy.dart';

final networkControllerProvider = StateNotifierProvider<NetworkController, bool>((ref) {
  return NetworkController();
});

class NetworkController extends StateNotifier<bool> {
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  NetworkController() : super(true) {
    _init();
  }

  void _init() {
    // Check initial status
    Connectivity().checkConnectivity().then((results) {
      _updateStatus(results);
    });

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> results) {
    // If the list contains none, or is empty, we are offline.
    if (results.isEmpty || results.contains(ConnectivityResult.none)) {
      if (state != false) state = false;
    } else {
      if (state != true) state = true;
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
