import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:food_user_application/config/constants/app_constants.dart';
import 'package:food_user_application/core/providers/core_providers.dart';

/// Thin wrapper around the Socket.IO connection used for live restaurant
/// events (`new_order`, `order_status_update`, ...). The server auto-joins
/// the `restaurant:<id>` room on connect based on the JWT role/id — see
/// `Backend/src/config/socket.js`.
class SocketService {
  SocketService(this._ref);

  final Ref _ref;
  io.Socket? _socket;
  final Map<String, List<void Function(dynamic)>> _handlers = {};

  Future<void> connect() async {
    final token = await _ref.read(tokenStorageProvider).accessToken;
    if (token == null || token.isEmpty) return;

    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }

    final newSocket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .setExtraHeaders({'Authorization': 'Bearer $token', 'authorization': 'Bearer $token'})
          .setQuery({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .build(),
    );

    newSocket.onConnect((_) async {
      final restaurantId = await _ref.read(tokenStorageProvider).restaurantId;
      if (restaurantId != null && restaurantId.isNotEmpty) {
        newSocket.emit('join-restaurant', restaurantId);
      }
    });

    newSocket.onDisconnect((_) {
      newSocket.connect();
    });

    // Reattach all buffered and registered event handlers
    for (final entry in _handlers.entries) {
      for (final handler in entry.value) {
        newSocket.on(entry.key, handler);
      }
    }

    _socket = newSocket;
  }

  bool get isConnected => _socket?.connected ?? false;

  void on(String event, void Function(dynamic data) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
  }

  void off(String event) {
    _handlers.remove(event);
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref);
  ref.onDispose(service.disconnect);
  return service;
});
