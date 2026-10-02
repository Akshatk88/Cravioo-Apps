import 'dart:convert';

String? _extractUserId(dynamic value) {
  if (value is Map) return (value['_id'] ?? value['id'])?.toString();
  if (value is String && value.isNotEmpty) return value;
  return null;
}

class OrderItem {
  const OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
    this.variantName,
    this.isVeg = true,
    this.notes,
  });

  final String name;
  final double price;
  final int quantity;
  final String? variantName;
  final bool isVeg;
  final String? notes;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      variantName: json['variantName'] as String?,
      isVeg: json['isVeg'] as bool? ?? true,
      notes: json['notes'] as String?,
    );
  }
}

class GeoPoint {
  const GeoPoint({required this.lat, required this.lng});
  final double lat;
  final double lng;

  static GeoPoint? fromCoordinates(dynamic coordinates) {
    if (coordinates is! List || coordinates.length < 2) return null;
    final lng = (coordinates[0] as num?)?.toDouble();
    final lat = (coordinates[1] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return GeoPoint(lat: lat, lng: lng);
  }
}

class RestaurantInfo {
  const RestaurantInfo({
    required this.name,
    this.phone,
    this.addressLine1,
    this.area,
    this.city,
    this.profileImage,
    this.coverImage,
    this.coverImages = const [],
    this.galleryImages = const [],
    this.menuImages = const [],
    this.location,
  });

  final String name;
  final String? phone;
  final String? addressLine1;
  final String? area;
  final String? city;
  final String? profileImage;

  /// Single hero image for the restaurant page.
  final String? coverImage;
  final List<String> coverImages;

  /// Photos of the PREMISES, uploaded specifically so the rider can recognise
  /// the storefront at pickup — the admin panel labels this
  /// "Premises Gallery — shown to the delivery partner at pickup".
  ///
  /// The backend has always sent it; this model simply never read it, so the
  /// one field meant for this screen was the one the rider never saw.
  final List<String> galleryImages;
  final List<String> menuImages;
  final GeoPoint? location;

  String get address =>
      [addressLine1, area, city].where((e) => e != null && e.isNotEmpty).join(', ');

  /// All restaurant-uploaded photos (cover + menu media first, profile logo
  /// last as a fallback), deduped and with empty/null entries removed, for
  /// use in a gallery viewer.
  List<String> get allImages {
    final seen = <String>{};
    final result = <String>[];
    for (final url in [
      // Premises photos first: they are the ones taken for this exact purpose.
      ...galleryImages,
      ?coverImage,
      ...coverImages,
      ...menuImages,
      ?profileImage,
    ]) {
      if (url.isNotEmpty && seen.add(url)) result.add(url);
    }
    return result;
  }

  /// The photo shown on the map marker and pickup card — prefers the
  /// restaurant's uploaded "Media" (cover/gallery) photos over the plain
  /// profile logo, since that's what the delivery partner should recognize
  /// the storefront by.
  String? get displayImage {
    // Same order as allImages: a premises photo beats a marketing cover, which
    // beats a photo of a paper menu, which beats the logo.
    if (galleryImages.isNotEmpty) return galleryImages.first;
    if (coverImage != null && coverImage!.isNotEmpty) return coverImage;
    if (coverImages.isNotEmpty) return coverImages.first;
    if (menuImages.isNotEmpty) return menuImages.first;
    return profileImage;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().where((e) => e.isNotEmpty).toList();
  }

  factory RestaurantInfo.fromJson(Map<String, dynamic> json) {
    return RestaurantInfo(
      name: json['restaurantName'] as String? ?? json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? json['ownerPhone'] as String?,
      addressLine1: json['addressLine1'] as String? ?? json['address'] as String?,
      area: json['area'] as String?,
      city: json['city'] as String?,
      profileImage: json['profileImage'] as String?,
      coverImage: json['coverImage'] as String?,
      coverImages: _stringList(json['coverImages']),
      galleryImages: _stringList(json['galleryImages']),
      menuImages: _stringList(json['menuImages']),
      location: GeoPoint.fromCoordinates(
        (json['location'] as Map<String, dynamic>?)?['coordinates'],
      ),
    );
  }
}

class DeliveryAddress {
  const DeliveryAddress({
    required this.street,
    this.additionalDetails,
    this.city,
    this.state,
    this.phone,
    this.location,
  });

  final String street;
  final String? additionalDetails;
  final String? city;
  final String? state;
  final String? phone;
  final GeoPoint? location;

  String get fullAddress => [
    street,
    additionalDetails,
    city,
  ].where((e) => e != null && e.isNotEmpty).join(', ');

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      street: json['street'] as String? ?? json['address'] as String? ?? '',
      additionalDetails: json['additionalDetails'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      phone: json['phone'] as String?,
      location: GeoPoint.fromCoordinates(
        (json['location'] as Map<String, dynamic>?)?['coordinates'],
      ),
    );
  }
}

class DeliveryOrder {
  const DeliveryOrder({
    required this.id,
    required this.orderCode,
    required this.orderStatus,
    required this.currentPhase,
    required this.restaurant,
    required this.deliveryAddress,
    required this.items,
    required this.customerName,
    required this.customerPhone,
    this.customerId,
    this.customerPhoto,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.total,
    required this.riderEarning,
    required this.dropOtpRequired,
    required this.dropOtpVerified,
    this.deliveryInstructions,
    this.cookingNote,
    this.pickupDistanceKm,
    this.tripDistanceKm,
    this.tripDurationMins,
    this.acceptanceDeadlineAt,
  });

  final String id;
  final String orderCode;
  final String orderStatus;
  final String currentPhase;
  final RestaurantInfo restaurant;
  final DeliveryAddress deliveryAddress;
  final List<OrderItem> items;
  final String customerName;
  final String customerPhone;
  final String? customerId;
  final String? customerPhoto;
  final String paymentMethod;
  final String paymentStatus;
  final double total;
  final double riderEarning;
  final bool dropOtpRequired;
  final bool dropOtpVerified;
  final String? deliveryInstructions;
  final String? cookingNote;
  final double? pickupDistanceKm;
  final double? tripDistanceKm;
  final double? tripDurationMins;
  final DateTime? acceptanceDeadlineAt;

  bool get isCashOnDelivery => paymentMethod == 'cash';
  bool get isPaid => paymentStatus == 'paid';

  DeliveryOrder copyWith({bool? dropOtpRequired, bool? dropOtpVerified}) {
    return DeliveryOrder(
      id: id,
      orderCode: orderCode,
      orderStatus: orderStatus,
      currentPhase: currentPhase,
      restaurant: restaurant,
      deliveryAddress: deliveryAddress,
      items: items,
      customerName: customerName,
      customerPhone: customerPhone,
      customerId: customerId,
      customerPhoto: customerPhoto,
      paymentMethod: paymentMethod,
      paymentStatus: paymentStatus,
      total: total,
      riderEarning: riderEarning,
      dropOtpRequired: dropOtpRequired ?? this.dropOtpRequired,
      dropOtpVerified: dropOtpVerified ?? this.dropOtpVerified,
      deliveryInstructions: deliveryInstructions,
      cookingNote: cookingNote,
      pickupDistanceKm: pickupDistanceKm,
      tripDistanceKm: tripDistanceKm,
      tripDurationMins: tripDurationMins,
      acceptanceDeadlineAt: acceptanceDeadlineAt,
    );
  }

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    final pricing = json['pricing'] as Map<String, dynamic>? ?? {};
    final payment = json['payment'] as Map<String, dynamic>? ?? {};
    final deliveryState = json['deliveryState'] as Map<String, dynamic>? ?? {};
    final deliveryVerification =
        json['deliveryVerification'] as Map<String, dynamic>? ?? {};
    final dropOtp =
        deliveryVerification['dropOtp'] as Map<String, dynamic>? ?? {};
    final restaurantJson = json['restaurantId'];
    final addressJson = json['deliveryAddress'] as Map<String, dynamic>?;

    double n(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    
    return DeliveryOrder(
      id: (json['_id'] ?? '').toString(),
      orderCode: json['order_id'] as String? ?? json['orderId'] as String? ?? '',
      orderStatus: json['orderStatus'] as String? ?? '',
      currentPhase: deliveryState['currentPhase'] as String? ?? 'en_route_to_pickup',
      restaurant: restaurantJson is Map<String, dynamic>
          ? RestaurantInfo.fromJson(restaurantJson)
          : const RestaurantInfo(name: ''),
      deliveryAddress: addressJson != null
          ? DeliveryAddress.fromJson(addressJson)
          : const DeliveryAddress(street: ''),
      items: (json['items'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(OrderItem.fromJson)
          .toList(),
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String? ?? '',
      customerId: _extractUserId(json['userId']),
      customerPhoto: json['customerPhoto'] as String? ?? json['customerImage'] as String? ?? (json['userId'] is Map ? (json['userId']['profilePhoto'] as String? ?? json['userId']['image'] as String?) : null),
      paymentMethod: json['paymentMethod'] as String? ??
          payment['method'] as String? ??
          'cash',
      paymentStatus: payment['status'] as String? ?? 'cod_pending',
      total: (pricing['total'] as num?)?.toDouble() ?? 0,
      riderEarning: n(json['riderEarning'] ?? json['earnings'] ?? json['earningAmount'] ?? json['deliveryEarning']),
      dropOtpRequired: dropOtp['required'] as bool? ?? false,
      dropOtpVerified: dropOtp['verified'] as bool? ?? false,
      deliveryInstructions:
          json['note'] as String? ?? json['deliveryInstructions'] as String?,
      cookingNote: json['cookingNote'] as String?,
      pickupDistanceKm: n(json['pickupDistanceKm']),
      tripDistanceKm: n(json['tripDistanceKm'] ?? json['distanceKm']),
      tripDurationMins: n(json['tripDurationMins']),
      acceptanceDeadlineAt: json['acceptanceDeadlineAt'] != null
          ? DateTime.tryParse(json['acceptanceDeadlineAt'] as String)
          : null,
    );
  }

  /// Parses the flat field set carried by the socket `new_order`/
  /// `new_order_available` events and the FCM `data` payload — as opposed
  /// to [fromJson]'s nested REST-response shape.
  factory DeliveryOrder.fromRealtimePayload(Map<String, dynamic> data) {
    double n(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
    double? nNullable(dynamic v) => v == null ? null : ((v is num) ? v.toDouble() : double.tryParse('$v'));

    List<OrderItem> parseItems(dynamic itemsData) {
      if (itemsData != null) {
        try {
          final List<dynamic> list = itemsData is String ? jsonDecode(itemsData) : itemsData;
          final parsed = list.whereType<Map<String, dynamic>>().map(OrderItem.fromJson).toList();
          if (parsed.isNotEmpty) return parsed;
        } catch (_) {}
      }
      final count = int.tryParse(data['itemCount']?.toString() ?? data['totalItems']?.toString() ?? '0') ?? 0;
      return List.generate(count, (i) => const OrderItem(name: 'Item', price: 0, quantity: 1));
    }

    final resolvedId = (data['orderMongoId'] ??
            data['_id'] ??
            data['orderId'] ??
            data['id'] ??
            data['order_id'] ??
            '')
        .toString();
    final resolvedCode = (data['orderCode'] ??
            data['order_id'] ??
            data['orderId'] ??
            data['id'] ??
            resolvedId)
        .toString();

    return DeliveryOrder(
      id: resolvedId,
      orderCode: resolvedCode,
      orderStatus: data['orderStatus'] as String? ?? '',
      currentPhase: data['currentPhase'] as String? ?? 'en_route_to_pickup',
      restaurant: RestaurantInfo(
        name: data['restaurantName'] as String? ?? '',
        addressLine1: data['restaurantAddress'] as String?,
      ),
      deliveryAddress: DeliveryAddress(
        street: data['customerAddress'] as String? ?? '',
      ),
      items: parseItems(data['items']),
      customerName: data['customerName'] as String? ?? '',
      customerPhone: data['customerPhone'] as String? ?? '',
      customerId: _extractUserId(data['userId'] ?? data['customerId']),
      customerPhoto: data['customerPhoto'] as String? ?? data['customerImage'] as String?,
      paymentMethod: data['paymentMethod'] as String? ?? 'cash',
      paymentStatus: data['paymentStatus'] as String? ?? 'cod_pending',
      total: n(data['total']),
      riderEarning: n(data['riderEarning'] ?? data['earnings']),
      dropOtpRequired: false,
      dropOtpVerified: false,
      pickupDistanceKm: nNullable(data['pickupDistanceKm']),
      tripDistanceKm: nNullable(data['tripDistanceKm']),
      tripDurationMins: nNullable(data['tripDurationMins']),
      acceptanceDeadlineAt: data['acceptanceDeadlineAt'] != null
          ? DateTime.tryParse(data['acceptanceDeadlineAt'].toString())
          : null,
    );
  }
}
