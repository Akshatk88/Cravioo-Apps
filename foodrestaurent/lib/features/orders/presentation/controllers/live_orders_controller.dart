import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/new_order_action_channel.dart';
import 'package:food_user_application/core/services/order_resolution_tracker.dart';
import 'package:food_user_application/core/services/socket_service.dart';
import 'package:food_user_application/features/orders/data/order_repository.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';

/// Backs the main Orders tab: one list of current orders, bucketed
/// client-side into the 7 status tabs (see [OrderModel.restaurantBucket]),
/// kept fresh by the `new_order` / `order_status_update` socket events.
///
/// Socket.IO never replays events missed while disconnected (app
/// backgrounded, brief network drop, etc.), so a status change like a
/// cancellation during that window would otherwise sit stale until a manual
/// pull-to-refresh — also refresh on reconnect and on app resume to close
/// that gap.
class LiveOrdersController extends AsyncNotifier<List<OrderModel>> {
  bool _socketWired = false;
  AppLifecycleListener? _lifecycleListener;

  @override
  Future<List<OrderModel>> build() async {
    await _wireSocket();
    _lifecycleListener ??= AppLifecycleListener(onResume: refresh);
    ref.onDispose(() => _lifecycleListener?.dispose());
    return ref.read(orderRepositoryProvider).listCurrent();
  }

  Future<void> _wireSocket() async {
    if (_socketWired) return;
    _socketWired = true;
    final socket = ref.read(socketServiceProvider);
    await socket.connect();

    void onOrderEvent(dynamic _) => refresh();

    socket.on('new_order', onOrderEvent);
    socket.on('new_order_available', onOrderEvent);
    socket.on('order_status_update', onOrderEvent);
    socket.on('order_cancelled', onOrderEvent);
    socket.on('cancel_order', onOrderEvent);
    socket.on('order_accepted', onOrderEvent);
    socket.on('order_rejected', onOrderEvent);
    socket.on('connect', onOrderEvent);
    ref.onDispose(() {
      socket.off('new_order');
      socket.off('new_order_available');
      socket.off('order_status_update');
      socket.off('order_cancelled');
      socket.off('cancel_order');
      socket.off('order_accepted');
      socket.off('order_rejected');
      socket.off('connect');
    });
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(
      () => ref.read(orderRepositoryProvider).listCurrent(),
    );
  }

  Future<void> updateStatus(
    String orderId,
    String orderStatus, {
    String? note,
  }) async {
    OrderResolutionTracker.markResolved(orderId);
    await NewOrderActionChannel.stopSound(orderId);
    await NewOrderActionChannel.dismiss(orderId);
    await cancelFcmTrayCopy(orderId);
    await ref
        .read(orderRepositoryProvider)
        .updateStatus(orderId, orderStatus, note: note);
    if (orderStatus == 'ready_for_pickup') {
      try {
        await ref.read(orderRepositoryProvider).resendNotification(orderId);
      } catch (_) {}
    }
    await refresh();
  }

  Future<void> resendNotification(String orderId) async {
    await ref.read(orderRepositoryProvider).resendNotification(orderId);
  }
}

final liveOrdersControllerProvider =
    AsyncNotifierProvider<LiveOrdersController, List<OrderModel>>(
      LiveOrdersController.new,
    );
