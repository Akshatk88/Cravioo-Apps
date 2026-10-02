import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/new_order_action_channel.dart';
import '../../../core/services/order_resolution_tracker.dart';
import '../../../core/services/socket_service.dart';
import '../data/models/delivery_order.dart';
import '../data/orders_repository.dart';
import 'orders_controller.dart';
import 'orders_state.dart';

/// Single source of truth for the full-screen incoming-order alert.
/// `null` means no active alert; non-null means "show it now" — regardless
/// of whether the order arrived via Socket.IO (app open) or FCM (app
/// backgrounded/foregrounded), both transports funnel into this state.
class IncomingOrderController extends Notifier<DeliveryOrder?> {
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _fcmReceivedSub;
  StreamSubscription<Map<String, dynamic>>? _fcmTapSub;
  StreamSubscription<Map<String, dynamic>>? _orderClaimedSub;
  StreamSubscription<Map<String, dynamic>>? _orderDeassignedSub;
  StreamSubscription<NewOrderAction>? _nativeActionSub;
  StreamSubscription<String>? _nativeIncomingSub;

  // Backend keeps re-offering an order to this partner across re-offer
  // rounds even after it's been declined/expired here — track what's
  // already been resolved this session so it isn't shown again.
  final Set<String> _dismissedOrderIds = {};

  @override
  DeliveryOrder? build() {
    NewOrderActionChannel.initialize();
    final socket = ref.read(socketServiceProvider);
    _socketSub = socket.onNewOrderAvailable.listen(_onRealtimePayload);
    final socketReadySub = socket.onOrderReady.listen(_onRealtimePayload);
    ref.onDispose(socketReadySub.cancel);
    _orderClaimedSub = socket.onOrderClaimed.listen(_autoDismissIfMatch);
    _orderDeassignedSub = socket.onOrderDeassigned.listen(_autoDismissIfMatch);

    final fcm = ref.read(fcmServiceProvider);
    _fcmReceivedSub = fcm.onNotificationReceived.listen(_onRealtimePayload);
    _fcmTapSub = fcm.onNotificationTap.listen(_onRealtimePayload);

    _nativeIncomingSub = NewOrderActionChannel.onIncomingOrder.listen(_onIncomingOrderId);

    _nativeActionSub = NewOrderActionChannel.onAction.listen((action) {
      if (action.accepted) {
        if (state?.id == action.orderId) {
          accept();
        } else {
          ref.read(ordersControllerProvider.notifier).acceptOrder(action.orderId);
        }
      } else {
        if (state?.id == action.orderId) {
          decline();
        } else {
          ref.read(ordersControllerProvider.notifier).rejectOrder(action.orderId);
        }
      }
    });

    ref.listen<OrdersState>(ordersControllerProvider, (prev, next) {
      if (next is OrdersLoaded && next.currentOrder == null && next.availableOrders.isNotEmpty) {
        if (state == null) {
          for (final order in next.availableOrders) {
            final st = order.orderStatus.toLowerCase();
            // STRICT: Delivery app must ONLY popup when order is ready_for_pickup or ready
            if (st != 'ready_for_pickup' && st != 'ready') {
              continue;
            }
            if (!_dismissedOrderIds.contains(order.id) && !OrderResolutionTracker.isResolved(order.id)) {
              show(order);
              break;
            }
          }
        }
      }
    });

    ref.onDispose(() {
      _socketSub?.cancel();
      _fcmReceivedSub?.cancel();
      _fcmTapSub?.cancel();
      _orderClaimedSub?.cancel();
      _orderDeassignedSub?.cancel();
      _nativeActionSub?.cancel();
      _nativeIncomingSub?.cancel();
    });

    return null;
  }

  void _onIncomingOrderId(String orderId) async {
    if (orderId.isEmpty || _dismissedOrderIds.contains(orderId) || OrderResolutionTracker.isResolved(orderId)) return;
    if (state != null && state!.id == orderId) return;

    final result = await ref.read(ordersRepositoryProvider).getOrderDetails(orderId);
    result.when(
      success: (order) {
        final st = order.orderStatus.toLowerCase();
        if (st != 'ready_for_pickup' && st != 'ready') {
          return;
        }
        if (!_dismissedOrderIds.contains(order.id) && !OrderResolutionTracker.isResolved(order.id)) {
          show(order);
        }
      },
      failure: (_) {},
    );
  }

  void _onRealtimePayload(Map<String, dynamic> data) async {
    if (data['type'] == 'order_taken' ||
        data['type'] == 'order_deassigned' ||
        data['type'] == 'order_cancelled' ||
        data['type'] == 'cancel_order') {
      _withdraw(data);
      return;
    }

    final orderId = (data['orderMongoId'] ??
            data['_id'] ??
            data['orderId'] ??
            data['id'] ??
            data['order_id'])
        ?.toString();
    if (orderId == null || orderId.isEmpty) return;
    if (_dismissedOrderIds.contains(orderId) || OrderResolutionTracker.isResolved(orderId)) return;
    if (state != null && state!.id == orderId) return;

    final type = data['type']?.toString();
    final title = (data['title'] ?? '').toString().toLowerCase();
    final isOrderReadyType = type == 'order_ready' ||
        type == 'order_ready_for_pickup' ||
        title.contains('ready for pickup') ||
        title.contains('order ready');

    String? orderStatus = (data['orderStatus'] ?? data['status'])?.toString().toLowerCase();

    // If orderStatus is missing/null and not explicitly ready, verify with API
    if ((orderStatus == null || orderStatus.isEmpty) && !isOrderReadyType) {
      final res = await ref.read(ordersRepositoryProvider).getOrderDetails(orderId);
      res.when(
        success: (order) {
          final st = order.orderStatus.toLowerCase();
          if (st == 'ready_for_pickup' || st == 'ready') {
            _evaluateAndShowOrder(order);
          }
        },
        failure: (_) {},
      );
      return;
    }

    final isReady = isOrderReadyType || orderStatus == 'ready_for_pickup' || orderStatus == 'ready';
    if (!isReady) {
      // STRICT FILTER: Order is not ready (e.g. created, placed, confirmed, preparing) -> DO NOT POPUP!
      return;
    }

    final isOrderType = isOrderReadyType ||
        type == 'new_order' ||
        type == 'new_order_available' ||
        type == 'order_assigned' ||
        type == 'delivery_partner_assigned' ||
        (type == null && (data.containsKey('pickupAddress') || data.containsKey('restaurantName')));

    if (!isOrderType) return;
    final order = DeliveryOrder.fromRealtimePayload(data);
    _evaluateAndShowOrder(order);
  }

  void _evaluateAndShowOrder(DeliveryOrder order) {
    if (_dismissedOrderIds.contains(order.id) || OrderResolutionTracker.isResolved(order.id)) return;
    if (state != null && state!.id == order.id) return;

    show(order);

    if (order.restaurant.name.isEmpty) {
      ref.read(ordersRepositoryProvider).getOrderDetails(order.id).then((result) {
        result.when(
          success: (full) {
            if (state?.id == order.id) {
              state = full;
            }
          },
          failure: (_) {},
        );
      });
    }
  }

  void _withdraw(Map<String, dynamic> data) {
    final orderId =
        (data['orderMongoId'] ?? data['orderId'] ?? data['_id'] ?? data['id'] ?? data['order_id'])
            ?.toString();
    if (orderId == null || orderId.isEmpty) return;

    _dismissedOrderIds.add(orderId);
    OrderResolutionTracker.markResolved(orderId);
    unawaited(NewOrderActionChannel.stopSound(orderId));
    unawaited(NewOrderActionChannel.dismiss(orderId));
    if (state?.id == orderId) state = null;
  }

  void _autoDismissIfMatch(Map<String, dynamic> data) => _withdraw(data);

  void show(DeliveryOrder order) {
    if (OrderResolutionTracker.isResolved(order.id)) return;
    if (state?.id == order.id) return;
    state = order;
    OrderResolutionTracker.markAlerted(order.id);
    unawaited(NewOrderActionChannel.startSound(order.id));
  }

  Future<void> accept() async {
    final order = state;
    if (order == null) return;
    _dismissedOrderIds.add(order.id);
    OrderResolutionTracker.markResolved(order.id);
    unawaited(NewOrderActionChannel.stopSound(order.id));
    unawaited(NewOrderActionChannel.dismiss(order.id));
    await ref.read(ordersControllerProvider.notifier).acceptOrder(order.id);
    state = null;
  }

  Future<void> decline() async {
    final order = state;
    if (order == null) return;
    _dismissedOrderIds.add(order.id);
    OrderResolutionTracker.markResolved(order.id);
    unawaited(NewOrderActionChannel.stopSound(order.id));
    unawaited(NewOrderActionChannel.dismiss(order.id));
    state = null;
    await ref.read(ordersControllerProvider.notifier).rejectOrder(order.id);
  }

  /// Countdown ran out client-side — best-effort notify the backend so it
  /// can reassign sooner. The BullMQ `processDispatchTimeout` job remains
  /// the authoritative fallback if this call never arrives.
  Future<void> expire() => decline();

  void dismiss() {
    final order = state;
    if (order != null) {
      unawaited(NewOrderActionChannel.stopSound(order.id));
      unawaited(NewOrderActionChannel.dismiss(order.id));
    }
    state = null;
  }
}

final incomingOrderControllerProvider =
    NotifierProvider<IncomingOrderController, DeliveryOrder?>(
  IncomingOrderController.new,
);
