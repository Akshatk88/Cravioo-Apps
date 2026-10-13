import '../data/models/delivery_order.dart';

sealed class OrdersState {
  const OrdersState();
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  const OrdersLoaded({
    required this.availableOrders,
    required this.currentOrder,
    this.otherActiveOrders = const [],
  });

  final List<DeliveryOrder> availableOrders;

  /// The trip the rider is working on right now (map, actions, tracking).
  final DeliveryOrder? currentOrder;

  /// Further accepted orders for a partner the admin allowed to hold more
  /// than one at a time (maxConcurrentOrders > 1). They wait here and the
  /// rider can switch to one, or it is promoted when the current trip ends.
  final List<DeliveryOrder> otherActiveOrders;

  bool get hasActiveOrder => currentOrder != null;

  /// Every active order the rider holds (current first).
  int get activeOrderCount =>
      (currentOrder != null ? 1 : 0) + otherActiveOrders.length;

  OrdersLoaded copyWith({
    List<DeliveryOrder>? availableOrders,
    DeliveryOrder? Function()? currentOrder,
    List<DeliveryOrder>? otherActiveOrders,
  }) {
    return OrdersLoaded(
      availableOrders: availableOrders ?? this.availableOrders,
      currentOrder: currentOrder != null ? currentOrder() : this.currentOrder,
      otherActiveOrders: otherActiveOrders ?? this.otherActiveOrders,
    );
  }
}

class OrdersError extends OrdersState {
  const OrdersError(this.message);
  final String message;
}
