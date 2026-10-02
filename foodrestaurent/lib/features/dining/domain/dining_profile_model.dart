class DiningCategoryOption {
  final String id;
  final String name;
  final String image;

  const DiningCategoryOption({
    required this.id,
    required this.name,
    this.image = '',
  });

  factory DiningCategoryOption.fromJson(Map<String, dynamic> json) {
    return DiningCategoryOption(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      image: json['image'] is Map
          ? (json['image']['url'] ?? '').toString()
          : (json['image'] ?? '').toString(),
    );
  }
}

class DiningProfileModel {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String status; // 'pending', 'approved', 'rejected', 'suspended'
  final String about;
  final List<DiningCategoryOption> categories;
  final List<String> cuisines;
  final List<String> amenities;
  final double costForTwo;
  final int seatingCapacity;
  final String contactName;
  final String contactPhone;
  final String coverImage;
  final List<String> gallery;
  final List<String> menuImages;
  final String rejectionReason;
  final bool isOnline;
  final bool autoConfirm;
  final int bookingWindowDays;
  final int slotDurationMins;
  final int maxGuestsPerBooking;
  final int minAdvanceMins;
  final double reservationFee;

  const DiningProfileModel({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.status,
    required this.about,
    required this.categories,
    required this.cuisines,
    required this.amenities,
    required this.costForTwo,
    required this.seatingCapacity,
    required this.contactName,
    required this.contactPhone,
    required this.coverImage,
    required this.gallery,
    required this.menuImages,
    required this.rejectionReason,
    required this.isOnline,
    required this.autoConfirm,
    this.bookingWindowDays = 30,
    this.slotDurationMins = 60,
    this.maxGuestsPerBooking = 12,
    this.minAdvanceMins = 30,
    this.reservationFee = 0.0,
  });

  factory DiningProfileModel.fromJson(Map<String, dynamic> json) {
    final rawCats = json['categories'] as List? ?? [];
    String coverUrl = '';
    if (json['coverImage'] is Map) {
      coverUrl = json['coverImage']['url']?.toString() ?? '';
    } else if (json['coverImage'] != null) {
      coverUrl = json['coverImage'].toString();
    }

    return DiningProfileModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      about: json['about']?.toString() ?? '',
      categories: rawCats
          .map((c) => DiningCategoryOption.fromJson(Map<String, dynamic>.from(c as Map)))
          .toList(),
      cuisines: (json['cuisines'] as List? ?? []).map((e) => e.toString()).toList(),
      amenities: (json['amenities'] as List? ?? []).map((e) => e.toString()).toList(),
      costForTwo: (json['costForTwo'] as num?)?.toDouble() ?? 0.0,
      seatingCapacity: (json['seatingCapacity'] as num?)?.toInt() ?? 0,
      contactName: json['contactName']?.toString() ?? '',
      contactPhone: json['contactPhone']?.toString() ?? '',
      coverImage: coverUrl,
      gallery: (json['gallery'] as List? ?? []).map((e) => e is Map ? e['url']?.toString() ?? '' : e.toString()).where((s) => s.isNotEmpty).toList(),
      menuImages: (json['menuImages'] as List? ?? []).map((e) => e is Map ? e['url']?.toString() ?? '' : e.toString()).where((s) => s.isNotEmpty).toList(),
      rejectionReason: json['rejectionReason']?.toString() ?? '',
      isOnline: json['isOnline'] != false,
      autoConfirm: json['autoConfirm'] == true,
      bookingWindowDays: (json['bookingWindowDays'] as num?)?.toInt() ?? 30,
      slotDurationMins: (json['slotDurationMins'] as num?)?.toInt() ?? 60,
      maxGuestsPerBooking: (json['maxGuestsPerBooking'] as num?)?.toInt() ?? 12,
      minAdvanceMins: (json['minAdvanceMins'] as num?)?.toInt() ?? 30,
      reservationFee: (json['reservationFee'] as num?)?.toDouble() ?? 0.0,
    );
  }

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';
}
