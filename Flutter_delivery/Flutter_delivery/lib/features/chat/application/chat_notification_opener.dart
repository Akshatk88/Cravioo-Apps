import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/fcm_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../orders/application/active_trip_visibility_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../../orders/application/orders_state.dart';
import '../../orders/data/models/delivery_order.dart';
import '../../orders/data/orders_repository.dart';
import '../../orders/presentation/screens/active_trip_screen.dart';
import '../../support/presentation/screens/chat_admin_screen.dart';
import '../presentation/screens/chat_screen.dart';

/// Opens the right chat screen when the rider taps a chat push, in every app
/// state: foreground (local banner tap), background (onMessageOpenedApp) and
/// terminated (getInitialMessage / local-notification launch details).
///
/// All three funnel through [FcmService.onChatNotificationTap]; the cold-start
/// tap is also parked in [FcmService.takePendingChatTap] because it is emitted
/// before this listener exists.
class ChatNotificationOpener {
  ChatNotificationOpener(this._ref);

  final Ref _ref;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _started = false;
  bool _opening = false;

  void start() {
    if (_started) return;
    _started = true;
    final fcm = _ref.read(fcmServiceProvider);
    _sub = fcm.onChatNotificationTap.listen((_) => _consumePending());
    _consumePending();
  }

  /// Called on every resume as well, in case a tap arrived while no frame
  /// could be pushed yet.
  void consumePending() => _consumePending();

  void dispose() {
    _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _consumePending() {
    if (_opening) return;
    final data = _ref.read(fcmServiceProvider).takePendingChatTap();
    if (data == null) return;
    _opening = true;
    unawaited(_open(data).whenComplete(() => _opening = false));
  }

  Future<void> _open(Map<String, dynamic> data) async {
    final orderId = data['orderId']?.toString() ?? '';
    final conversationId = data['conversationId']?.toString();

    if (!await _waitUntilReady()) return;

    final Route<void> route;
    if (orderId.isEmpty) {
      // A thread without an order is the admin/support chat.
      route = MaterialPageRoute<void>(builder: (_) => const ChatAdminScreen());
    } else {
      if (activeChatOrderId == orderId) return; // Already on screen.
      final order = await _resolveOrder(orderId);
      if (order == null) return;
      route = MaterialPageRoute<void>(
        builder: (_) => ChatScreen(order: order, conversationId: conversationId),
      );
    }

    // The active-trip map is an overlay above the router with its own
    // Navigator; push there when it is showing, otherwise the chat would open
    // hidden underneath it.
    final tripNavigator = activeTripNavigatorKey.currentState;
    final tripVisible = _ref.read(activeTripVisibilityControllerProvider);
    if (tripVisible && tripNavigator != null && tripNavigator.mounted) {
      unawaited(tripNavigator.push(route));
      return;
    }
    final rootNavigator = _ref.read(goRouterProvider).routerDelegate.navigatorKey.currentState;
    if (rootNavigator != null) unawaited(rootNavigator.push(route));
  }

  Future<DeliveryOrder?> _resolveOrder(String orderId) async {
    final ordersState = _ref.read(ordersControllerProvider);
    if (ordersState is OrdersLoaded) {
      final current = ordersState.currentOrder;
      if (current != null && current.id == orderId) return current;
    }
    final result = await _ref.read(ordersRepositoryProvider).getOrderDetails(orderId);
    return result.when(
      success: (order) => order,
      // Still open the thread: ChatScreen only needs the ids to load history
      // and reply; names/photos fall back to defaults.
      failure: (_) => DeliveryOrder.fromRealtimePayload({'orderId': orderId}),
    );
  }

  /// Waits (bounded) until the rider is signed in and the router has left the
  /// splash/onboarding routes — pushing earlier would be wiped by the splash's
  /// own redirect to /main on a cold start.
  Future<bool> _waitUntilReady() async {
    const step = Duration(milliseconds: 300);
    for (var i = 0; i < 100; i++) {
      final auth = _ref.read(authControllerProvider);
      if (auth is AuthUnauthenticated || auth is AuthFailure) return false;
      if (auth is AuthAuthenticated) {
        final router = _ref.read(goRouterProvider);
        final location = router.routerDelegate.currentConfiguration.uri.path;
        final navigator = router.routerDelegate.navigatorKey.currentState;
        if (navigator != null && location != '/' && location != '/onboarding') {
          // Let the destination screen (and the trip overlay) build first.
          await Future<void>.delayed(step);
          return true;
        }
      }
      await Future<void>.delayed(step);
    }
    return false;
  }
}

final chatNotificationOpenerProvider = Provider<ChatNotificationOpener>((ref) {
  final opener = ChatNotificationOpener(ref);
  ref.onDispose(opener.dispose);
  return opener;
});
