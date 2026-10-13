import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/new_order_action_channel.dart';
import '../../../core/services/order_resolution_tracker.dart';
import '../../../core/services/socket_service.dart';
import '../data/models/delivery_order.dart';
import '../data/orders_repository.dart';
import 'orders_state.dart';
import 'pending_customer_rating_controller.dart';

class OrdersController extends Notifier<OrdersState> {
  late final OrdersRepository _repository;
  Timer? _pollTimer;
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderClaimedSub;
  StreamSubscription? _orderDeassignedSub;
  StreamSubscription? _orderStatusSub;
  StreamSubscription? _orderReadySub;
  StreamSubscription? _connectionSub;

  // Socket events (new_order/order_claimed/order_deassigned) and the 15s
  // poll can all ask for the same refresh within milliseconds of each other
  // — coalesce concurrent callers onto one in-flight request instead of
  // firing duplicate GETs and replacing state multiple times in a row.
  Future<void>? _refreshAllInFlight;
  Future<void>? _refreshAvailableInFlight;
  Future<void>? _refreshCurrentInFlight;

  @override
  OrdersState build() {
    _repository = ref.read(ordersRepositoryProvider);

    final socket = ref.read(socketServiceProvider);
    _newOrderSub = socket.onNewOrderAvailable.listen((_) => refreshAvailable());
    _orderClaimedSub = socket.onOrderClaimed.listen((_) => refreshAvailable());
    _orderDeassignedSub = socket.onOrderDeassigned.listen((data) {
      _leaveTrackingIfCurrent(data);
      refreshAvailable();
    });
    _orderStatusSub = socket.onOrderStatusUpdate.listen((data) {
      refreshCurrent();
      final status = (data['status'] ?? data['orderStatus'])?.toString();
      if (status == 'ready_for_pickup' || status == 'ready') {
        final orderId = (data['orderId'] ?? data['orderMongoId'])?.toString();
        ref.read(fcmServiceProvider).showLocalNotification(
          title: 'Order ready for pickup 🛍️',
          body: (orderId != null && orderId.isNotEmpty)
              ? 'Order #$orderId is ready at the restaurant.'
              : 'Order is ready at the restaurant.',
          payload: data,
        );
      }
    });
    _orderReadySub = socket.onOrderReady.listen((data) {
      refreshCurrent();
      final orderId = (data['orderId'] ?? data['orderMongoId'])?.toString();
      ref.read(fcmServiceProvider).showLocalNotification(
        title: 'Order ready for pickup 🛍️',
        body: (orderId != null && orderId.isNotEmpty)
            ? 'Order #$orderId is ready at the restaurant.'
            : 'Order is ready at the restaurant.',
        payload: data,
      );
    });
    // Resume live-location sharing for the active order after a reconnect.
    _connectionSub = socket.onConnectionChange.listen((connected) {
      if (!connected) return;
      final current = state;
      if (current is OrdersLoaded && current.currentOrder != null) {
        socket.joinTracking(current.currentOrder!.id);
      }
    });

    ref.onDispose(() {
      stopPolling();
      _newOrderSub?.cancel();
      _orderClaimedSub?.cancel();
      _orderDeassignedSub?.cancel();
      _orderStatusSub?.cancel();
      _orderReadySub?.cancel();
      _connectionSub?.cancel();
    });

    startPolling();
    return const OrdersInitial();
  }

  /// `GET /orders/current` and `GET /orders/available` don't project
  /// `deliveryVerification`, so a routine refresh always reports OTP as
  /// not-required. Never let that silently clear an OTP requirement we
  /// already learned about from reachedDrop/verifyDropOtp responses —
  /// otherwise a background refresh mid-delivery would let the driver
  /// complete the order without ever verifying it.
  DeliveryOrder _preserveOtpState(DeliveryOrder? previousCurrent, DeliveryOrder fresh) {
    if (previousCurrent == null || previousCurrent.id != fresh.id) return fresh;
    if (previousCurrent.dropOtpRequired && !fresh.dropOtpRequired) {
      return fresh.copyWith(
        dropOtpRequired: true,
        dropOtpVerified: previousCurrent.dropOtpVerified,
      );
    }
    return fresh;
  }

  /// On a fresh app start (or provider rebuild) there's no `previousCurrent`
  /// to fall back on, so `_preserveOtpState` can't protect against
  /// `/orders/current`'s stripped `deliveryVerification`. If the order is
  /// already at the drop step in that situation, hydrate the real OTP state
  /// from `GET /orders/:orderId`, which returns the full document.
  Future<DeliveryOrder> _hydrateOtpState(
    DeliveryOrder? previousCurrent,
    DeliveryOrder fresh,
  ) async {
    if (previousCurrent != null && previousCurrent.id == fresh.id) {
      return _preserveOtpState(previousCurrent, fresh);
    }
    if (fresh.currentPhase == 'at_drop') {
      final detailsResult = await _repository.getOrderDetails(fresh.id);
      return detailsResult.when(
        success: (full) => full,
        failure: (_) => fresh,
      );
    }
    return fresh;
  }

  /// `_doRefreshAll`/`_doRefreshCurrent` run on every 15s poll tick AND every
  /// order-status/order-ready socket event. Without this check, each one
  /// replaces `state` with a brand-new `OrdersLoaded`/`DeliveryOrder` even
  /// when nothing actually changed — `OrdersLoaded` has no `==`, so Riverpod
  /// treats it as new state and rebuilds every watcher, including the
  /// always-mounted `ActiveTripScreen` and its `GoogleMap`. That churn is
  /// what was causing the active-trip flow to jank/feel unresponsive.
  bool _currentOrderChanged(DeliveryOrder? previous, DeliveryOrder? next) {
    if (identical(previous, next)) return false;
    if (previous == null || next == null) return true;
    return previous.id != next.id ||
        previous.currentPhase != next.currentPhase ||
        previous.orderStatus != next.orderStatus ||
        previous.paymentStatus != next.paymentStatus ||
        previous.dropOtpRequired != next.dropOtpRequired ||
        previous.dropOtpVerified != next.dropOtpVerified;
  }

  void _leaveTrackingIfCurrent(Map<String, dynamic> data) {
    final current = state;
    if (current is! OrdersLoaded || current.currentOrder == null) return;
    final orderId = (data['orderId'] ?? data['_id'] ?? data['id'])?.toString();
    if (orderId == null || orderId == current.currentOrder!.id) {
      ref.read(socketServiceProvider).leaveTracking(current.currentOrder!.id);
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    refreshAll();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshAll(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refreshAll() {
    return _refreshAllInFlight ??=
        _doRefreshAll().whenComplete(() => _refreshAllInFlight = null);
  }

  Future<void> _doRefreshAll() async {
    final epoch = _acceptEpoch;
    if (state is OrdersInitial) state = const OrdersLoading();
    final activeResult = await _repository.getActiveOrders();
    final active = activeResult.when(success: (r) => r, failure: (_) => null);
    if (active != null && await _applyActiveOrders(active)) return;

    final availableResult = await _repository.getAvailableOrders();
    if (epoch != _acceptEpoch) return; // an order was accepted meanwhile
    availableResult.when(
      success: (orders) {
        final readyOrders = orders.where((o) {
          final s = o.orderStatus.toLowerCase();
          return s == 'ready_for_pickup' || s == 'ready';
        }).toList();
        state = OrdersLoaded(availableOrders: readyOrders, currentOrder: null);
      },
      failure: (error) {
        if (state is! OrdersLoaded) state = OrdersError(error.message);
      },
    );
  }

  Future<void> refreshAvailable() {
    return _refreshAvailableInFlight ??=
        _doRefreshAvailable().whenComplete(() => _refreshAvailableInFlight = null);
  }

  Future<void> _doRefreshAvailable() async {
    final prev = state;
    if (prev is OrdersLoaded && prev.hasActiveOrder) return;
    final epoch = _acceptEpoch;
    final result = await _repository.getAvailableOrders();
    if (epoch != _acceptEpoch) return; // an order was accepted meanwhile
    result.when(
      success: (orders) {
        final readyOrders = orders.where((o) {
          final s = o.orderStatus.toLowerCase();
          return s == 'ready_for_pickup' || s == 'ready';
        }).toList();
        state = OrdersLoaded(availableOrders: readyOrders, currentOrder: null);
      },
      failure: (_) {},
    );
  }

  Future<void> refreshCurrent() {
    return _refreshCurrentInFlight ??=
        _doRefreshCurrent().whenComplete(() => _refreshCurrentInFlight = null);
  }

  Future<void> _doRefreshCurrent() async {
    final epoch = _acceptEpoch;
    final result = await _repository.getActiveOrders();
    await result.when(
      success: (active) async {
        if (await _applyActiveOrders(active)) return;
        // No active order on the server any more.
        if (epoch != _acceptEpoch) return;
        final prev = state;
        final previousCurrent = prev is OrdersLoaded ? prev.currentOrder : null;
        if (previousCurrent == null &&
            (prev is! OrdersLoaded || prev.otherActiveOrders.isEmpty)) {
          return;
        }
        state = OrdersLoaded(
          availableOrders: prev is OrdersLoaded ? prev.availableOrders : const [],
          currentOrder: null,
        );
      },
      failure: (_) async {},
    );
  }

  /// Applies the server's active orders. Keeps the trip the rider is on as the
  /// current one while it is still active (a multi-order partner must not have
  /// the map jump to another order on a poll); otherwise takes the server's
  /// activeOrder. The rest wait in otherActiveOrders. Returns false when the
  /// server reports no active order at all.
  Future<bool> _applyActiveOrders(
    ({DeliveryOrder? current, List<DeliveryOrder> all}) active,
  ) async {
    final prev = state;
    final previousCurrent = prev is OrdersLoaded ? prev.currentOrder : null;

    DeliveryOrder? pick;
    if (previousCurrent != null) {
      for (final o in active.all) {
        if (o.id == previousCurrent.id) {
          pick = o;
          break;
        }
      }
    }
    pick ??= active.current ?? (active.all.isNotEmpty ? active.all.first : null);
    if (pick == null) return false;

    final hydrated = await _hydrateOtpState(previousCurrent, pick);
    final others = active.all.where((o) => o.id != hydrated.id).toList();
    final previousOthers =
        prev is OrdersLoaded ? prev.otherActiveOrders : const <DeliveryOrder>[];
    final othersChanged = previousOthers.length != others.length ||
        Iterable<int>.generate(others.length).any(
          (i) => _currentOrderChanged(previousOthers[i], others[i]),
        );
    if (!_currentOrderChanged(previousCurrent, hydrated) && !othersChanged) {
      return true;
    }
    state = OrdersLoaded(
      availableOrders: prev is OrdersLoaded ? prev.availableOrders : const [],
      currentOrder: hydrated,
      otherActiveOrders: others,
    );
    return true;
  }

  /// Multi-order partner: work on [orderId] now. The previous trip goes back
  /// to the waiting list; nothing changes server-side.
  void switchCurrentOrder(String orderId) {
    final prev = state;
    if (prev is! OrdersLoaded) return;
    final index = prev.otherActiveOrders.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    final next = prev.otherActiveOrders[index];
    final others = [...prev.otherActiveOrders]..removeAt(index);
    if (prev.currentOrder != null) others.insert(0, prev.currentOrder!);
    state = OrdersLoaded(
      availableOrders: prev.availableOrders,
      currentOrder: next,
      otherActiveOrders: others,
    );
    ref.read(socketServiceProvider).joinTracking(next.id);
  }

  Future<Result<DeliveryOrder, AppError>> acceptOrder(String orderId) async {
    OrderResolutionTracker.markResolved(orderId);
    unawaited(NewOrderActionChannel.stopSound(orderId));
    unawaited(NewOrderActionChannel.dismiss(orderId));
    unawaited(dismissIncomingOrderAlert(orderId));
    final result = await _repository.accept(orderId);
    final accepted = result.when(
      success: (order) => order,
      failure: (_) => null,
    );
    if (accepted != null) {
      _adoptAcceptedOrder(accepted);
      return result;
    }

    // The accept can fail because it already went through: the overlay
    // bubble sends its own accept before the app opens. If the server now
    // has this order as our current trip, that is a success, not an error.
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) await Future<void>.delayed(const Duration(seconds: 1));
      final current = await _repository.getCurrentOrder();
      final order = current.when(success: (o) => o, failure: (_) => null);
      if (order != null && order.id == orderId) {
        _adoptAcceptedOrder(order);
        return Result.success(order);
      }
    }
    return result;
  }

  /// Bumped on every accepted order. A refresh that started before the
  /// accept compares it before writing, so its stale "no current order"
  /// answer cannot wipe the trip that was just accepted (which dropped the
  /// rider back on the home map after tapping Accept).
  int _acceptEpoch = 0;

  void _adoptAcceptedOrder(DeliveryOrder order) {
    _acceptEpoch++;
    final prev = state;
    final current = prev is OrdersLoaded ? prev.currentOrder : null;
    if (prev is OrdersLoaded && current != null && current.id != order.id) {
      // Multi-order partner taking another order: the trip in progress stays
      // on screen; the new one waits in the list until the rider switches to
      // it or this trip ends.
      state = OrdersLoaded(
        availableOrders: const [],
        currentOrder: current,
        otherActiveOrders: [
          ...prev.otherActiveOrders.where((o) => o.id != order.id),
          order,
        ],
      );
      ref.read(socketServiceProvider).joinTracking(order.id);
      return;
    }
    state = OrdersLoaded(
      availableOrders: const [],
      currentOrder: order,
      otherActiveOrders:
          prev is OrdersLoaded ? prev.otherActiveOrders : const [],
    );
    // Start live location sharing for this order (requirement: after accept).
    ref.read(socketServiceProvider).joinTracking(order.id);
  }

  Future<Result<DeliveryOrder, AppError>> rejectOrder(String orderId) async {
    OrderResolutionTracker.markResolved(orderId);
    unawaited(NewOrderActionChannel.stopSound(orderId));
    unawaited(NewOrderActionChannel.dismiss(orderId));
    unawaited(dismissIncomingOrderAlert(orderId));
    final result = await _repository.reject(orderId);
    result.when(success: (_) => refreshAvailable(), failure: (_) {});
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> reachedPickup(String orderId) =>
      _mutateCurrent(orderId, () => _repository.reachedPickup(orderId));

  Future<Result<DeliveryOrder, AppError>> confirmPickup(
    String orderId, {
    String? billImageUrl,
  }) => _mutateCurrent(
    orderId,
    () => _repository.confirmPickup(orderId, billImageUrl: billImageUrl),
  );

  Future<Result<DeliveryOrder, AppError>> reachedDrop(String orderId) =>
      _mutateCurrent(orderId, () => _repository.reachedDrop(orderId));

  Future<Result<DeliveryOrder, AppError>> verifyDropOtp(
    String orderId,
    String otp,
  ) => _mutateCurrent(orderId, () => _repository.verifyDropOtp(orderId, otp));

  /// The held order with [orderId], whether it is the one on screen or one of
  /// the others a multi-order partner is carrying.
  DeliveryOrder? _heldOrder(String orderId) {
    final s = state;
    if (s is! OrdersLoaded) return null;
    if (s.currentOrder?.id == orderId) return s.currentOrder;
    for (final o in s.otherActiveOrders) {
      if (o.id == orderId) return o;
    }
    return null;
  }

  Future<Result<DeliveryOrder, AppError>> completeOrder(String orderId) async {
    final previousOrder = _heldOrder(orderId);
    // COD: the rider has just collected cash (CollectPaymentSheet). There is no
    // separate collect/cash endpoint, so state it on /complete.
    final isUnpaidCod = previousOrder != null &&
        previousOrder.id == orderId &&
        previousOrder.isCashOnDelivery &&
        !previousOrder.isPaid;
    final result = await _repository.complete(
      orderId,
      paymentMode: isUnpaidCod ? 'cash' : null,
    );
    result.when(
      success: (_) {
        // Stop live location sharing for this order (requirement: after delivered).
        ref.read(socketServiceProvider).leaveTracking(orderId);
        final prev = state;
        final waiting = prev is OrdersLoaded
            ? prev.otherActiveOrders.where((o) => o.id != orderId).toList()
            : <DeliveryOrder>[];
        final current = prev is OrdersLoaded ? prev.currentOrder : null;
        if (current != null && current.id != orderId) {
          // A side order was delivered: the trip on screen carries on.
          state = OrdersLoaded(
            availableOrders: const [],
            currentOrder: current,
            otherActiveOrders: waiting,
          );
        } else if (waiting.isNotEmpty) {
          // Multi-order partner: the next accepted order becomes the trip.
          state = OrdersLoaded(
            availableOrders: const [],
            currentOrder: waiting.first,
            otherActiveOrders: waiting.sublist(1),
          );
          refreshCurrent();
        } else {
          state = const OrdersLoaded(availableOrders: [], currentOrder: null);
          refreshAvailable();
        }
        if (previousOrder != null && previousOrder.id == orderId) {
          ref
              .read(pendingCustomerRatingControllerProvider.notifier)
              .show(previousOrder);
        }
      },
      failure: (_) {},
    );
    return result;
  }

  /// Runs a step (reached pickup / confirm pickup / reached drop / OTP) for
  /// [orderId] and updates ONLY that order.
  ///
  /// Most of these endpoints answer with a slim ack (id + orderStatus, no
  /// deliveryState, restaurant, items or payment). Using that as the order wiped
  /// its details ("0 items", no name) and its step, and with two orders held it
  /// could land in the wrong slot. So the full order is re-read from
  /// GET /orders/:id and put back in exactly the slot it came from; the other
  /// order is never touched.
  Future<Result<DeliveryOrder, AppError>> _mutateCurrent(
    String orderId,
    Future<Result<DeliveryOrder, AppError>> Function() action,
  ) async {
    final result = await action();
    final ack = result.when(success: (o) => o, failure: (_) => null);
    if (ack == null) return result;

    final details = await _repository.getOrderDetails(orderId);
    final full = details.when(success: (o) => o, failure: (_) => null);
    if (full == null) {
      // Could not re-read it: keep what we had and let the poll catch up.
      unawaited(refreshCurrent());
      return Result.success(_heldOrder(orderId) ?? ack);
    }

    final prev = state;
    if (prev is! OrdersLoaded) {
      state = OrdersLoaded(availableOrders: const [], currentOrder: full);
      return Result.success(full);
    }
    final current = prev.currentOrder;
    if (current == null || current.id == orderId) {
      state = OrdersLoaded(
        availableOrders: prev.availableOrders,
        currentOrder: full,
        otherActiveOrders: prev.otherActiveOrders.where((o) => o.id != orderId).toList(),
      );
    } else {
      final others = [
        for (final o in prev.otherActiveOrders) o.id == orderId ? full : o,
      ];
      if (!others.any((o) => o.id == orderId)) others.add(full);
      state = OrdersLoaded(
        availableOrders: prev.availableOrders,
        currentOrder: current,
        otherActiveOrders: others,
      );
    }
    return Result.success(full);
  }
}

final ordersControllerProvider =
    NotifierProvider<OrdersController, OrdersState>(OrdersController.new);
