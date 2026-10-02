class OrderItemModel {
  OrderItemModel({
    required this.name,
    required this.variantName,
    required this.quantity,
    required this.price,
    required this.isVeg,
    required this.notes,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return OrderItemModel(
      name: (json['name'] ?? '').toString(),
      variantName: (json['variantName'] ?? '').toString(),
      quantity: (asNum(json['quantity']) ?? 1).toInt(),
      price: asNum(json['price'])?.toDouble() ?? 0,
      isVeg: json['isVeg'] == true,
      notes: (json['notes'] ?? '').toString(),
    );
  }

  final String name;
  final String variantName;
  final int quantity;
  final double price;
  final bool isVeg;
  final String notes;
}

/// Drop-off address snapshot — captured on the order at checkout time, so it
/// stays correct even if the customer later edits/deletes the saved address.
class DeliveryAddressModel {
  DeliveryAddressModel({
    required this.label,
    required this.recipientName,
    required this.street,
    required this.additionalDetails,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.phone,
  });

  factory DeliveryAddressModel.fromJson(Map<String, dynamic> json) {
    return DeliveryAddressModel(
      label: (json['label'] ?? '').toString(),
      recipientName: (json['fullName'] ?? json['name'] ?? '').toString(),
      street: (json['street'] ?? '').toString(),
      additionalDetails: (json['additionalDetails'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zipCode: (json['zipCode'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
    );
  }

  final String label;
  final String recipientName;
  final String street;
  final String additionalDetails;
  final String city;
  final String state;
  final String zipCode;
  final String phone;

  bool get isEmpty => street.isEmpty && city.isEmpty;

  String get fullAddress => [
    street,
    additionalDetails,
    city,
    state,
    zipCode,
  ].where((s) => s.isNotEmpty).join(', ');
}

/// Full fare breakdown — mirrors `pricingSchema` on the backend order model.
class OrderPricingModel {
  OrderPricingModel({
    required this.subtotal,
    required this.tax,
    required this.packagingFee,
    required this.deliveryFee,
    required this.platformFee,
    required this.discount,
    required this.couponCode,
    required this.total,
  });

  factory OrderPricingModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return OrderPricingModel(
      subtotal: asNum(json['subtotal'])?.toDouble() ?? 0,
      tax: asNum(json['tax'])?.toDouble() ?? 0,
      packagingFee: asNum(json['packagingFee'])?.toDouble() ?? 0,
      deliveryFee: asNum(json['deliveryFee'])?.toDouble() ?? 0,
      platformFee: asNum(json['platformFee'])?.toDouble() ?? 0,
      discount: asNum(json['discount'])?.toDouble() ?? 0,
      couponCode: (json['couponCode'] ?? '').toString(),
      total: asNum(json['total'])?.toDouble() ?? 0,
    );
  }

  final double subtotal;
  final double tax;
  final double packagingFee;
  final double deliveryFee;
  final double platformFee;
  final double discount;
  final String couponCode;
  final double total;
}

class OrderModel {
  OrderModel({
    required this.id,
    required this.displayId,
    required this.customerName,
    required this.customerPhone,
    required this.items,
    required this.deliveryAddress,
    required this.pricing,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.dispatchStatus,
    required this.riderName,
    required this.riderPhone,
    required this.riderRating,
    required this.cancelledBy,
    required this.cancellationReason,
    required this.sendCutlery,
    required this.note,
    required this.deliveryInstructions,
    required this.acceptanceDeadlineAt,
    required this.createdAt,
    this.statusTimes = const {},
  });

  factory OrderModel.fromJson(Map<String, dynamic> rawJson) {
    final json = (rawJson['order'] is Map)
        ? Map<String, dynamic>.from(rawJson['order'] as Map)
        : rawJson;
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    final user = json['userId'];
    final userMap = user is Map ? user : null;
    final pricing = Map<String, dynamic>.from((json['pricing'] ?? {}) as Map);
    final payment = Map<String, dynamic>.from((json['payment'] ?? {}) as Map);
    final dispatch = Map<String, dynamic>.from((json['dispatch'] ?? {}) as Map);
    final deliveryAddress = Map<String, dynamic>.from(
      (json['deliveryAddress'] ?? {}) as Map,
    );
    final rider = dispatch['deliveryPartnerId'];
    final riderMap = rider is Map ? rider : null;
    final items = (json['items'] as List? ?? [])
        .map(
          (e) => OrderItemModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return OrderModel(
      id: (json['_id'] ?? json['orderMongoId'] ?? '').toString(),
      displayId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      customerName: (json['customerName'] ?? userMap?['name'] ?? 'Customer')
          .toString(),
      customerPhone: (json['customerPhone'] ?? userMap?['phone'] ?? '')
          .toString(),
      items: items,
      deliveryAddress: DeliveryAddressModel.fromJson(deliveryAddress),
      pricing: OrderPricingModel.fromJson(pricing),
      total: asNum(pricing['total'])?.toDouble() ?? 0,
      paymentMethod: (payment['method'] ?? '').toString(),
      paymentStatus: (payment['status'] ?? '').toString(),
      orderStatus: (json['orderStatus'] ?? json['status'] ?? '').toString(),
      dispatchStatus: (dispatch['status'] ?? 'unassigned').toString(),
      riderName: (riderMap?['name'] ?? riderMap?['fullName'] ?? '').toString(),
      riderPhone: (riderMap?['phone'] ?? riderMap?['phoneNumber'] ?? '')
          .toString(),
      riderRating: riderMap != null
          ? asNum(riderMap['rating'])?.toDouble()
          : null,
      cancelledBy: (json['cancelledBy'] ?? '').toString(),
      cancellationReason: (json['cancellationReason'] ?? '').toString(),
      sendCutlery: json['sendCutlery'] == true,
      note: (json['note'] ?? '').toString(),
      deliveryInstructions: (json['deliveryInstructions'] ?? '').toString(),
      acceptanceDeadlineAt: DateTime.tryParse(
        (json['acceptanceDeadlineAt'] ?? '').toString(),
      ),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      statusTimes: _parseStatusTimes(json['statusHistory']),
    );
  }

  final String id;
  final String displayId;
  final String customerName;
  final String customerPhone;
  final List<OrderItemModel> items;
  final DeliveryAddressModel deliveryAddress;
  final OrderPricingModel pricing;
  final double total;
  final String paymentMethod;
  final String paymentStatus;
  final String orderStatus;
  final String dispatchStatus;
  final String riderName;
  final String riderPhone;
  final double? riderRating;
  final String cancelledBy;
  final String cancellationReason;
  final bool sendCutlery;
  final String note;
  final String deliveryInstructions;
  final DateTime? acceptanceDeadlineAt;
  final DateTime createdAt;

  bool get isAllVeg => items.isNotEmpty && items.every((item) => item.isVeg);
  bool get isCancelled => orderStatus.startsWith('cancelled');
  bool get hasRider => riderName.isNotEmpty;

  /// When each status was reached, from the server's own status history.
  final Map<String, DateTime> statusTimes;

  /// How far along the delivery is, as a step index into the order timeline:
  /// 0 accepted, 1 preparing, 2 ready, 3 picked up, 4 delivered.
  ///
  /// Derived from [orderStatus] ONLY. [dispatchStatus] must never be used for this:
  /// its schema enum is unassigned/assigned/accepted/rejected/cancelled, so it tracks
  /// who the order was handed to, not where the food is. It never holds 'picked_up'
  /// or 'reached_drop' at any point in an order's life, which is why the last two
  /// steps of the timeline sat at Pending forever, and why the whole timeline
  /// collapsed back to step 0 for the entire span between pickup and delivery.
  ///
  /// Read as ordered thresholds rather than a switch, so an unrecognised or newly
  /// added status can never silently drop the timeline back to zero.
  int get deliveryStepIndex {
    if (_isAtOrPast('delivered')) return 4;
    if (_isAtOrPast('picked_up')) return 3;
    if (_isAtOrPast('ready_for_pickup')) return 2;
    if (_isAtOrPast('preparing')) return 1;
    return 0;
  }

  bool get isPickedUp => deliveryStepIndex >= 3;
  bool get isDelivered => deliveryStepIndex >= 4;

  DateTime? get pickedUpAt => statusTimes['picked_up'];
  DateTime? get deliveredAt => statusTimes['delivered'];

  /// Whether the order has reached [milestone] or anything after it.
  ///
  /// Uses the recorded history as well as the current status: a status the order
  /// has already passed through no longer appears in [orderStatus], and the steps
  /// behind the current one still need to render as done.
  bool _isAtOrPast(String milestone) {
    if (statusTimes.containsKey(milestone)) return true;
    final current = _lifecycleRank(orderStatus);
    final target = _lifecycleRank(milestone);
    return current >= 0 && target >= 0 && current >= target;
  }

  /// Position in the forward-only delivery lifecycle. -1 for anything outside it
  /// (cancelled, expired, unknown), which keeps those out of the comparison
  /// entirely rather than having them read as "past" every milestone.
  static int _lifecycleRank(String status) {
    const order = [
      'created',
      'confirmed',
      'preparing',
      'ready_for_pickup',
      // The rider is at the restaurant but has not taken the food yet, so this
      // still belongs to the "Ready" step, not "Picked Up".
      'reached_pickup',
      'picked_up',
      'reached_drop',
      'delivered',
      'completed',
    ];
    return order.indexOf(status);
  }

  static Map<String, DateTime> _parseStatusTimes(dynamic raw) {
    final result = <String, DateTime>{};
    if (raw is! List) return result;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final to = entry['to']?.toString();
      final at = DateTime.tryParse(entry['at']?.toString() ?? '');
      if (to == null || to.isEmpty || at == null) continue;
      // First occurrence wins: a status re-entered after a correction should still
      // show when it was originally reached.
      result.putIfAbsent(to, () => at);
    }
    return result;
  }

  /// Restaurant-facing lifecycle bucket — matches the 7 tabs on the Orders screen.
  String get restaurantBucket {
    if (isCancelled) return 'cancelled';
    switch (orderStatus) {
      case 'created':
      case 'confirmed':
        return 'new';
      case 'preparing':
        return 'preparing';
      case 'ready_for_pickup':
        return 'ready';
      case 'reached_pickup':
      case 'picked_up':
      case 'reached_drop':
        return 'out_for_delivery';
      case 'delivered':
        return 'completed';
      default:
        return 'other';
    }
  }
}
