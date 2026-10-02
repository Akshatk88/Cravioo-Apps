import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/new_order_action_channel.dart';
import '../../../core/services/new_order_overlay_bridge.dart';
import '../../../core/services/order_resolution_tracker.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/sound_service.dart';
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
  StreamSubscription<Map<String, dynamic>>? _orderStatusSub;

  // Backend keeps re-offering an order to this partner across re-offer
  // rounds even after it's been declined/expired here — track what's
  // already been resolved this session so it isn't shown again.
  final Set<String> _dismissedOrderIds = {};

  @override
  DeliveryOrder? build() {
    final socket = ref.read(socketServiceProvider);
    _socketSub = socket.onNewOrderAvailable.listen(_onRealtimePayload);
    final socketReadySub = socket.onOrderReady.listen(_onRealtimePayload);
    ref.onDispose(socketReadySub.cancel);
    _orderClaimedSub = socket.onOrderClaimed.listen(_autoDismissIfMatch);
    _orderDeassignedSub = socket.onOrderDeassigned.listen(_autoDismissIfMatch);

    final fcm = ref.read(fcmServiceProvider);
    _fcmReceivedSub = fcm.onNotificationReceived.listen(_onRealtimePayload);
    _fcmTapSub = fcm.onNotificationTap.listen(_onRealtimePayload);

    // A customer cancelling arrives as a status update, not as a claim — so
    // without this the card kept ringing for an order that no longer existed.
    _orderStatusSub = socket.onOrderStatusUpdate.listen((data) {
      final status = (data['orderStatus'] ?? data['status'])?.toString().toLowerCase();
      if (status == 'cancelled' || status == 'canceled') _withdraw(data);
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
      _orderStatusSub?.cancel();
    });

    return null;
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
    // Checked here rather than in the transport handlers: there are three ways
    // in — socket, FCM, and the overlay handoff — and only some were guarded.
    if (order.id.isEmpty || _dismissedOrderIds.contains(order.id)) return;
    if (OrderResolutionTracker.isResolved(order.id)) return;
    if (state?.id == order.id) return;
    // The in-app card takes over only while the app is in front. Backgrounded,
    // the native overlay is the alert the rider can see AND hear, so ringing here
    // as well would play two tones that Accept on the overlay cannot both stop.
    final inFront = WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (inFront) unawaited(NewOrderOverlayBridge.dismiss());
    state = order;
    OrderResolutionTracker.markAlerted(order.id);
    if (inFront) unawaited(NewOrderActionChannel.startSound(order.id));
  }

  /// Silences every ringtone, whichever layer started it. A null id stops the
  /// native ring regardless of which order it belongs to.
  void _silenceAll() {
    unawaited(SoundService.stopRingtone(source: 'IncomingOrderController.silenceAll'));
    unawaited(NewOrderActionChannel.stopSound());
    unawaited(NewOrderOverlayBridge.dismiss());
  }

  Future<void> accept() async {
    final order = state;
    if (order == null) return;
    _dismissedOrderIds.add(order.id);
    OrderResolutionTracker.markResolved(order.id);
    _silenceAll();
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

  /// Raises the alert for an order the rider tapped on the native overlay.
  ///
  /// Only the id crosses over, so the order is fetched fresh — which is the
  /// right thing anyway: by the time they tap, the offer may already be gone.
  Future<void> showById(String orderId, {bool autoAccept = false}) async {
    // The rider has answered on the overlay; nothing may still be ringing,
    // including when the guard below drops the request.
    if (autoAccept) _silenceAll();
    if (_dismissedOrderIds.contains(orderId) || OrderResolutionTracker.isResolved(orderId)) {
      return;
    }

    // ACCEPT on the overlay is the decision, not a request to be asked again.
    // Showing the card and accepting behind it makes the Accept button reappear
    // for a beat — on a slow network, long enough to tap it twice. The order goes
    // straight to the accept call and the trip screen comes up from
    // ordersController; the card is never built.
    if (autoAccept) {
      // Clearing state removes a copy the socket may already have raised while
      // the app was launching, before this handoff was read.
      state = null;
      final result =
          await ref.read(ordersControllerProvider.notifier).acceptOrder(orderId);
      result.when(
        success: (_) {},
        // Almost always "another partner got there first". Refreshing the list
        // puts the rider back on solid ground instead of a trip that never began.
        failure: (e) {
          debugPrint('[offer] accept from overlay failed for $orderId: ${e.message}');
          ref.read(ordersControllerProvider.notifier).refreshAvailable();
        },
      );
      return;
    }

    final result = await ref.read(ordersRepositoryProvider).getOrderDetails(orderId);
    result.when(
      success: show,
      failure: (e) => debugPrint('[offer] showById($orderId) failed: ${e.message}'),
    );
  }

  /// Reports rejections the rider made on the overlay while the app was not
  /// running. Best effort — the server's dispatch timeout covers any that fail.
  Future<void> flushOverlayRejections() async {
    final pending = await NewOrderOverlayBridge.takePendingRejections();
    for (final orderId in pending) {
      _dismissedOrderIds.add(orderId);
      await ref.read(ordersControllerProvider.notifier).rejectOrder(orderId);
    }
  }

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
