import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../core/constants/app_constants.dart';

/// Events the user app cares about. `new_order`, `order_claimed` and friends
/// are restaurant/rider/admin events and are deliberately ignored.
enum OrderSocketEvent { statusUpdate, orderReady, riderMoved, dropOtp }

class OrderSocketMessage {
  final OrderSocketEvent event;
  final Map<String, dynamic> data;

  const OrderSocketMessage(this.event, this.data);

  static double? _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  // The location-update payload sends numbers (int or double), plus legacy
  // `boy_lat`/`boy_lng` aliases — parse all of them robustly.
  double? get lat => _num(data['lat'] ?? data['latitude'] ?? data['boy_lat']);
  double? get lng => _num(data['lng'] ?? data['longitude'] ?? data['boy_lng']);
  double get heading => _num(data['heading']) ?? 0.0;
  String? get otp => (data['otp'] ?? data['code'] ?? data['handoverOtp'])?.toString();
  String? get orderId => (data['orderId'] ?? data['orderMongoId'])?.toString();
}

/// One `chat:message` or `chat:typing` payload.
class ChatSocketMessage {
  final Map<String, dynamic> data;
  const ChatSocketMessage(this.data);
}

/// The app's single Socket.IO connection — shared by order tracking and chat.
///
/// Sockets are an optimisation, not the contract — both tracking and chat
/// must still work by polling. This class never throws upward: if the socket
/// can't connect, callers simply keep polling/pulling.
///
/// One connection is opened for the app's lifetime (see
/// `di/socket_providers.dart`); `joinTracking`/`leaveTracking` layer per-order
/// rooms on top without opening a second connection.
class SocketService {
  io.Socket? _socket;
  final _orderController = StreamController<OrderSocketMessage>.broadcast();
  final _chatMessageController = StreamController<ChatSocketMessage>.broadcast();
  final _chatTypingController = StreamController<ChatSocketMessage>.broadcast();
  final Set<String> _trackedOrderIds = {};

  Stream<OrderSocketMessage> get orderEvents => _orderController.stream;
  Stream<ChatSocketMessage> get chatMessages => _chatMessageController.stream;
  Stream<ChatSocketMessage> get chatTyping => _chatTypingController.stream;
  bool get isConnected => _socket?.connected ?? false;

  /// Supplies a fresh access token when the server rejects the handshake.
  Future<String?> Function()? _tokenProvider;
  int _authRetries = 0;
  static const _maxAuthRetries = 5;

  /// Connects (or reconnects, if the token changed) once for the app.
  ///
  /// [tokenProvider] lets the socket pick up a refreshed access token: the
  /// handshake token is otherwise fixed at first connect, so once it expired
  /// every reconnect was rejected (AUTH_INVALID) for the rest of the session.
  void connect(String accessToken, {Future<String?> Function()? tokenProvider}) {
    if (tokenProvider != null) _tokenProvider = tokenProvider;
    if (_socket != null) return;

    try {
      final socket = io.io(
        AppConstants.socketUrl,
        io.OptionBuilder()
            // Keep 'polling' first — some networks block the initial
            // websocket upgrade handshake.
            .setTransports(['polling', 'websocket'])
            .setAuth({'token': accessToken})
            .disableAutoConnect()
            // socket_io_client caches one Manager per URL and hands back its
            // existing namespace socket — after logout/login that was the old,
            // disposed socket still carrying the previous user's token.
            .enableForceNew()
            .enableReconnection()
            .setReconnectionAttempts(1 << 30)
            .setReconnectionDelay(2000)
            .setReconnectionDelayMax(10000)
            .build(),
      );

      // Re-joins every tracked room on every (re)connect, so a dropped socket
      // resumes tracking automatically without any caller doing anything.
      socket.onConnect((_) {
        _log('connected');
        _authRetries = 0;
        for (final id in _trackedOrderIds) {
          socket.emit('join-tracking', id);
        }
      });
      socket.onReconnect((_) {
        _log('reconnected');
        for (final id in _trackedOrderIds) {
          socket.emit('join-tracking', id);
        }
      });

      socket.on('order_status_update', (d) => _emitOrder(OrderSocketEvent.statusUpdate, d));
      socket.on('order_ready', (d) => _emitOrder(OrderSocketEvent.orderReady, d));
      socket.on('location-update', (d) => _emitOrder(OrderSocketEvent.riderMoved, d));
      socket.on('delivery_drop_otp', (d) => _emitOrder(OrderSocketEvent.dropOtp, d));
      socket.on('chat:message', (d) => _emitChat(_chatMessageController, d));
      socket.on('chat:typing', (d) => _emitChat(_chatTypingController, d));

      socket.onConnectError((e) {
        _log('connect error: $e');
        unawaited(_refreshAuth(socket, e));
      });
      socket.onError((e) => _log('error: $e'));

      socket.connect();
      _socket = socket;
    } catch (e) {
      // Polling covers us; never surface a socket failure to the UI.
      _log('socket unavailable: $e');
    }
  }

  /// Swaps in the latest access token after a failed handshake.
  ///
  /// Transport errors (e.g. `timeout`) are retried by the manager itself, so
  /// only the auth is refreshed. A middleware rejection (`AUTH_*`) is final for
  /// that attempt in Socket.IO, so it also re-dials — a bounded number of times
  /// so a permanently invalid session does not loop.
  Future<void> _refreshAuth(io.Socket socket, dynamic error) async {
    final provider = _tokenProvider;
    if (provider == null) return;
    String? token;
    try {
      token = await provider();
    } catch (_) {
      return;
    }
    if (token == null || token.isEmpty || !identical(_socket, socket)) return;
    socket.auth = {'token': token};

    final isAuthError = error.toString().contains('AUTH_');
    if (!isAuthError || socket.connected) return;
    if (_authRetries >= _maxAuthRetries) return;
    _authRetries++;
    await Future<void>.delayed(Duration(seconds: 2 * _authRetries));
    if (identical(_socket, socket) && !socket.connected) socket.connect();
  }

  /// Joins `tracking:<orderId>` — the server verifies the order actually
  /// belongs to this user and silently refuses otherwise.
  void joinTracking(String orderId) {
    _trackedOrderIds.add(orderId);
    _socket?.emit('join-tracking', orderId);
  }

  void leaveTracking(String orderId) {
    _trackedOrderIds.remove(orderId);
    _socket?.emit('leave-tracking', orderId);
  }

  void emitChatTyping({
    required String toRole,
    String? toId,
    required String conversationId,
    required bool typing,
  }) {
    _socket?.emit('chat:typing', {
      'toRole': toRole,
      'toId': ?toId,
      'conversationId': conversationId,
      'typing': typing,
    });
  }

  void _emitOrder(OrderSocketEvent event, dynamic payload) {
    if (_orderController.isClosed) return;
    final map = payload is Map ? payload.cast<String, dynamic>() : <String, dynamic>{};
    _orderController.add(OrderSocketMessage(event, map));
  }

  void _emitChat(StreamController<ChatSocketMessage> controller, dynamic payload) {
    if (controller.isClosed) return;
    final map = payload is Map ? payload.cast<String, dynamic>() : <String, dynamic>{};
    controller.add(ChatSocketMessage(map));
  }

  /// Disconnects entirely — called on logout. A fresh [connect] re-opens.
  void disconnect() {
    final socket = _socket;
    _socket = null;
    _trackedOrderIds.clear();
    if (socket == null) return;
    try {
      socket.dispose();
    } catch (_) {
      // Already gone.
    }
  }

  void dispose() {
    disconnect();
    _orderController.close();
    _chatMessageController.close();
    _chatTypingController.close();
  }

  void _log(String msg) {
    if (kDebugMode) debugPrint('[Socket] $msg');
  }
}
