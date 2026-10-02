/// Reads latitude/longitude out of a `location`-shaped map. The backend's
/// `normalizeRestaurantLocation` always sets explicit `latitude`/`longitude`
/// keys, but this falls back to the GeoJSON `coordinates: [lng, lat]` pair
/// just in case a given endpoint ever omits them.
double? _latLngFrom(Map<String, dynamic> loc, {required bool isLat}) {
  final direct = isLat ? loc['latitude'] : loc['longitude'];
  if (direct != null) return double.tryParse(direct.toString());
  final coordinates = loc['coordinates'];
  if (coordinates is List && coordinates.length > 1) {
    final value = isLat ? coordinates[1] : coordinates[0];
    return double.tryParse(value.toString());
  }
  return null;
}

/// The restaurant partner document, as returned by `GET /food/restaurant/current`
/// and (in a lighter shape) inside the OTP verify response's `user` field.
///
/// This is the single shared data source for the Explore-section screens
/// (outlet info, restaurant status, delivery settings, bank details, zone
/// setup) — every one of them reads a slice of this same model.
class RestaurantModel {
  RestaurantModel({
    required this.id,
    required this.restaurantName,
    required this.ownerName,
    required this.ownerEmail,
    required this.ownerPhone,
    required this.primaryContactNumber,
    required this.pureVegRestaurant,
    required this.status,
    required this.rejectionReason,
    required this.isAcceptingOrders,
    required this.profileImage,
    required this.addressLine1,
    required this.addressLine2,
    required this.area,
    required this.city,
    required this.state,
    required this.pincode,
    required this.landmark,
    required this.formattedAddress,
    required this.cuisines,
    required this.openDays,
    required this.openingTime,
    required this.closingTime,
    required this.estimatedDeliveryTime,
    required this.panNumber,
    required this.nameOnPan,
    required this.panImage,
    required this.gstRegistered,
    required this.gstNumber,
    required this.gstLegalName,
    required this.gstAddress,
    required this.gstImage,
    required this.fssaiNumber,
    required this.fssaiExpiry,
    required this.fssaiImage,
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.accountType,
    required this.upiId,
    required this.upiQrImage,
    required this.latitude,
    required this.longitude,
    required this.pendingLatitude,
    required this.pendingLongitude,
    required this.locationUpdateStatus,
    required this.locationRejectionReason,
    required this.zoneId,
    required this.rating,
    required this.totalRatings,
    required this.restaurantId,
  });

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    List<String> asStringList(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : <String>[];
    // The backend nests all address/geo fields under a single `location`
    // object (see `toRestaurantProfile`/`normalizeRestaurantLocation` in
    // restaurant.service.js) — it never flattens them to the top level.
    String fromLocation(Map<String, dynamic> loc, String key) =>
        (loc[key] ?? '').toString();
    // Document images (profileImage/panImage/gstImage/fssaiImage/upiQrImage)
    // come back as `{ url }` objects, not plain strings — but stay lenient
    // in case a given endpoint ever returns a bare string instead.
    String extractImageUrl(dynamic value) {
      if (value == null) return '';
      if (value is Map) return (value['url'] ?? '').toString();
      return value.toString();
    }

    final location = json['location'] is Map
        ? Map<String, dynamic>.from(json['location'] as Map)
        : <String, dynamic>{};
    final pendingLocation = json['pendingLocation'] is Map
        ? Map<String, dynamic>.from(json['pendingLocation'] as Map)
        : <String, dynamic>{};

    return RestaurantModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      restaurantId: (json['restaurantId'] ?? '').toString(),
      restaurantName: (json['restaurantName'] ?? '').toString(),
      ownerName: (json['ownerName'] ?? '').toString(),
      ownerEmail: (json['ownerEmail'] ?? '').toString(),
      ownerPhone: (json['ownerPhone'] ?? '').toString(),
      primaryContactNumber: (json['primaryContactNumber'] ?? '').toString(),
      pureVegRestaurant: json['pureVegRestaurant'] == true,
      status: (json['status'] ?? 'pending').toString(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
      isAcceptingOrders: json['isAcceptingOrders'] == true,
      profileImage: extractImageUrl(json['profileImage']),
      addressLine1: fromLocation(location, 'addressLine1'),
      addressLine2: fromLocation(location, 'addressLine2'),
      area: fromLocation(location, 'area'),
      city: fromLocation(location, 'city'),
      state: fromLocation(location, 'state'),
      pincode: fromLocation(location, 'pincode'),
      landmark: fromLocation(location, 'landmark'),
      formattedAddress:
          location['formattedAddress']?.toString() ??
          location['address']?.toString() ??
          '',
      cuisines: asStringList(json['cuisines']),
      openDays: asStringList(json['openDays']),
      openingTime: (json['openingTime'] ?? '09:00').toString(),
      closingTime: (json['closingTime'] ?? '22:00').toString(),
      estimatedDeliveryTime: (json['estimatedDeliveryTime'] ?? '30').toString(),
      panNumber: (json['panNumber'] ?? '').toString(),
      nameOnPan: (json['nameOnPan'] ?? '').toString(),
      panImage: extractImageUrl(json['panImage']),
      gstRegistered: json['gstRegistered'] == true,
      gstNumber: (json['gstNumber'] ?? '').toString(),
      gstLegalName: (json['gstLegalName'] ?? '').toString(),
      gstAddress: (json['gstAddress'] ?? '').toString(),
      gstImage: extractImageUrl(json['gstImage']),
      fssaiNumber: (json['fssaiNumber'] ?? '').toString(),
      fssaiExpiry: (json['fssaiExpiry'] ?? '').toString(),
      fssaiImage: extractImageUrl(json['fssaiImage']),
      accountHolderName: (json['accountHolderName'] ?? '').toString(),
      accountNumber: (json['accountNumber'] ?? '').toString(),
      ifscCode: (json['ifscCode'] ?? '').toString(),
      accountType: (json['accountType'] ?? '').toString(),
      upiId: (json['upiId'] ?? '').toString(),
      upiQrImage: extractImageUrl(json['upiQrImage']),
      latitude: _latLngFrom(location, isLat: true),
      longitude: _latLngFrom(location, isLat: false),
      pendingLatitude: _latLngFrom(pendingLocation, isLat: true),
      pendingLongitude: _latLngFrom(pendingLocation, isLat: false),
      locationUpdateStatus: (json['locationUpdateStatus'] ?? '').toString(),
      locationRejectionReason: (json['locationRejectionReason'] ?? '')
          .toString(),
      zoneId: (json['zoneId'] ?? '').toString(),
      rating: asDouble(json['rating']) ?? 0,
      totalRatings: (json['totalRatings'] is num)
          ? (json['totalRatings'] as num).toInt()
          : 0,
    );
  }

  final String id;
  final String restaurantId;
  final String restaurantName;
  final String ownerName;
  final String ownerEmail;
  final String ownerPhone;
  final String primaryContactNumber;
  final bool pureVegRestaurant;
  final String status;
  final String rejectionReason;
  final bool isAcceptingOrders;
  final String profileImage;

  final String addressLine1;
  final String addressLine2;
  final String area;
  final String city;
  final String state;
  final String pincode;
  final String landmark;
  final String formattedAddress;

  final List<String> cuisines;
  final List<String> openDays;
  final String openingTime;
  final String closingTime;
  final String estimatedDeliveryTime;

  final String panNumber;
  final String nameOnPan;
  final String panImage;
  final bool gstRegistered;
  final String gstNumber;
  final String gstLegalName;
  final String gstAddress;
  final String gstImage;
  final String fssaiNumber;
  final String fssaiExpiry;
  final String fssaiImage;

  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String accountType;
  final String upiId;
  final String upiQrImage;

  final double? latitude;
  final double? longitude;
  final double? pendingLatitude;
  final double? pendingLongitude;
  final String locationUpdateStatus;
  final String locationRejectionReason;
  final String zoneId;

  final double rating;
  final int totalRatings;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get hasPendingLocationUpdate => locationUpdateStatus == 'pending';

  String get fullAddress {
    final parts = [
      addressLine1,
      area,
      city,
      state,
      pincode,
    ].where((p) => p.trim().isNotEmpty).toList();
    return parts.isEmpty ? formattedAddress : parts.join(', ');
  }
}
