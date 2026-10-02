class AddressModel {
  final String id;
  final String title;
  final String fullAddress;
  final String type; // 'Home', 'Office', 'Other'
  final bool isDefault;
  final String? contactName;
  final String? contactPhone;

  // Backend fields — the order payload needs the raw parts and GeoJSON, while
  // the saved-address DTO takes flat latitude/longitude. The server converts.
  final String building;
  final String street;
  final String city;
  final String state;
  final String zipCode;
  final double? latitude;
  final double? longitude;

  const AddressModel({
    required this.id,
    required this.title,
    required this.fullAddress,
    required this.type,
    this.isDefault = false,
    this.contactName,
    this.contactPhone,
    this.building = '',
    this.street = '',
    this.city = '',
    this.state = '',
    this.zipCode = '',
    this.latitude,
    this.longitude,
  });

  /// Maps `GET/POST /food/user/addresses`. The response carries every
  /// coordinate representation at once (latitude/longitude, lat/lng, location).
  factory AddressModel.fromApi(Map<String, dynamic> json) {
    final customTitle = (json['additionalDetails'] ?? '').toString().trim();
    final rawLabel = (json['label'] ?? 'Home').toString().trim();
    final displayTitle = customTitle.isNotEmpty
        ? customTitle
        : (rawLabel.isNotEmpty ? rawLabel : 'Home');

    final rawAddress = (json['address'] ?? json['formattedAddress'] ?? '').toString().trim();

    final parts = [
      json['building'],
      json['street'],
      json['city'],
      json['state'],
      json['zipCode'],
    ].whereType<String>().where((e) => e.trim().isNotEmpty).toList();

    double? lat = (json['latitude'] as num?)?.toDouble();
    double? lng = (json['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) {
      final loc = json['location'];
      if (loc is Map) {
        if (loc['coordinates'] is List && (loc['coordinates'] as List).length >= 2) {
          final coords = loc['coordinates'] as List;
          lng = (coords[0] as num?)?.toDouble();
          lat = (coords[1] as num?)?.toDouble();
        } else if (loc['lat'] != null && loc['lng'] != null) {
          lat = (loc['lat'] as num?)?.toDouble();
          lng = (loc['lng'] as num?)?.toDouble();
        }
      }
    }

    final rawCombined = rawAddress.isNotEmpty
        ? rawAddress
        : (parts.isNotEmpty ? parts.join(', ') : 'Delivery Address');

    // Clean duplicate segments in fullAddress
    final cleanSegments = <String>[];
    for (final seg in rawCombined.split(',')) {
      final s = seg.trim();
      if (s.isNotEmpty && !cleanSegments.any((c) => c.toLowerCase() == s.toLowerCase())) {
        cleanSegments.add(s);
      }
    }
    final computedFullAddress = cleanSegments.isNotEmpty ? cleanSegments.join(', ') : rawCombined;

    // Smart resolution of building / house no
    final rawBuilding = (json['building'] ?? json['houseNo'] ?? '').toString().trim();
    String resolvedBuilding = rawBuilding;
    if (resolvedBuilding.isEmpty) {
      final addDetails = (json['additionalDetails'] ?? '').toString().trim();
      if (addDetails.isNotEmpty &&
          addDetails.toLowerCase() != 'home' &&
          addDetails.toLowerCase() != 'office' &&
          addDetails.toLowerCase() != 'other') {
        resolvedBuilding = addDetails;
      }
    }
    if (resolvedBuilding.isEmpty && rawAddress.isNotEmpty) {
      final streetVal = (json['street'] ?? '').toString().trim();
      final cityVal = (json['city'] ?? '').toString().trim();
      final addrParts = rawAddress.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (addrParts.isNotEmpty) {
        final first = addrParts.first;
        if (first.toLowerCase() != streetVal.toLowerCase() &&
            first.toLowerCase() != cityVal.toLowerCase() &&
            first.toLowerCase() != (json['label'] ?? '').toString().trim().toLowerCase()) {
          resolvedBuilding = first;
        }
      }
    }

    return AddressModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: displayTitle,
      fullAddress: computedFullAddress,
      type: rawLabel.isNotEmpty ? rawLabel : 'Home',
      isDefault: json['isDefault'] as bool? ?? false,
      contactPhone: json['phone']?.toString(),
      building: resolvedBuilding,
      street: (json['street'] ?? '').toString(),
      city: (json['city'] ?? '').toString(),
      state: (json['state'] ?? '').toString(),
      zipCode: (json['zipCode'] ?? '').toString(),
      latitude: lat,
      longitude: lng,
    );
  }

  /// Body for POST/PATCH /food/user/addresses (flat coordinates).
  Map<String, dynamic> toApiPayload() {
    const validLabels = ['Home', 'Office', 'Other', 'Current Location'];
    final normalizedLabel = validLabels.contains(type) ? type : 'Home';
    final safeStreet = street.trim().isNotEmpty
        ? street.trim()
        : (fullAddress.trim().isNotEmpty ? fullAddress.trim() : 'Address');

    return {
      'label': normalizedLabel,
      'building': building.trim(),
      'houseNo': building.trim(),
      'street': safeStreet,
      'additionalDetails': building.trim().isNotEmpty ? building.trim() : title,
      'address': fullAddress,
      'formattedAddress': fullAddress,
      'city': city.trim(),
      'state': state.trim(),
      'zipCode': zipCode.trim(),
      if (contactPhone != null && contactPhone!.trim().isNotEmpty)
        'phone': contactPhone!.trim(),
      'latitude': latitude ?? 0.0,
      'longitude': longitude ?? 0.0,
    };
  }

  /// Body for the order payload's `address` (GeoJSON `[lng, lat]`).
  Map<String, dynamic> toOrderPayload({String? customerName}) => {
        'label': type,
        'name': ?customerName,
        'building': building,
        'houseNo': building,
        'street': street,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'phone': ?contactPhone,
        if (latitude != null && longitude != null)
          'location': {
            'type': 'Point',
            'coordinates': [longitude, latitude],
          },
      };

  AddressModel copyWith({
    String? id,
    String? title,
    String? fullAddress,
    String? type,
    bool? isDefault,
    String? contactName,
    String? contactPhone,
    String? building,
    String? street,
    String? city,
    String? state,
    String? zipCode,
    double? latitude,
    double? longitude,
  }) {
    return AddressModel(
      id: id ?? this.id,
      title: title ?? this.title,
      fullAddress: fullAddress ?? this.fullAddress,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      building: building ?? this.building,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}
