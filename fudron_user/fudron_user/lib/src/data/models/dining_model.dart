import 'package:flutter/foundation.dart';

@immutable
class DiningCategoryModel {
  final String id;
  final String name;
  final String description;
  final String imageUrl;
  final int restaurantCount;

  const DiningCategoryModel({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    this.restaurantCount = 0,
  });

  factory DiningCategoryModel.fromApi(Map<String, dynamic> json) {
    return DiningCategoryModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['image']?.toString() ?? '',
      restaurantCount: (json['restaurantCount'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class DiningBannerModel {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String ctaText;
  final String link;

  const DiningBannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.ctaText,
    required this.link,
  });

  factory DiningBannerModel.fromApi(Map<String, dynamic> json) {
    return DiningBannerModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      imageUrl: json['image']?.toString() ?? '',
      ctaText: json['ctaText']?.toString() ?? 'Explore',
      link: json['link']?.toString() ?? '',
    );
  }
}

@immutable
class DiningRestaurantModel {
  final String id;
  final String restaurantId;
  final String name;
  final String city;
  final String about;
  final String coverImage;
  final List<String> gallery;
  final List<String> cuisines;
  final List<String> amenities;
  final int costForTwo;
  final int seatingCapacity;
  final double ratingAvg;
  final int ratingCount;
  final double? distanceInKm;
  final bool isOnline;

  const DiningRestaurantModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.city,
    required this.about,
    required this.coverImage,
    this.gallery = const [],
    this.cuisines = const [],
    this.amenities = const [],
    this.costForTwo = 0,
    this.seatingCapacity = 0,
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.distanceInKm,
    this.isOnline = true,
  });

  factory DiningRestaurantModel.fromApi(Map<String, dynamic> json) {
    final rawGallery = json['gallery'] as List?;
    final gallery = rawGallery?.map((e) => e.toString()).toList() ?? const [];

    final rawCuisines = json['cuisines'] as List?;
    final cuisines = rawCuisines?.map((e) => e.toString()).toList() ?? const [];

    final rawAmenities = json['amenities'] as List?;
    final amenities = rawAmenities?.map((e) => e.toString()).toList() ?? const [];

    return DiningRestaurantModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      restaurantId: json['restaurantId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['restaurantName']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      about: json['about']?.toString() ?? '',
      coverImage: json['coverImage']?.toString() ??
          (json['profileImage'] is Map ? json['profileImage']['url']?.toString() ?? '' : ''),
      gallery: gallery,
      cuisines: cuisines,
      amenities: amenities,
      costForTwo: (json['costForTwo'] as num?)?.toInt() ?? 0,
      seatingCapacity: (json['seatingCapacity'] as num?)?.toInt() ?? 0,
      ratingAvg: (json['ratingAvg'] as num?)?.toDouble() ?? (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['ratingCount'] as num?)?.toInt() ?? (json['totalRatings'] as num?)?.toInt() ?? 0,
      distanceInKm: (json['distanceInKm'] as num?)?.toDouble(),
      isOnline: json['isOnline'] != false,
    );
  }
}

/// A single time slot returned by the availability endpoint.
@immutable
class DiningSlotModel {
  final String startTime;
  final String endTime;
  final int capacity;
  final int seatsLeft;
  final bool isAvailable;
  final String unavailableReason;

  const DiningSlotModel({
    required this.startTime,
    required this.endTime,
    this.capacity = 0,
    this.seatsLeft = 0,
    this.isAvailable = true,
    this.unavailableReason = '',
  });

  factory DiningSlotModel.fromApi(Map<String, dynamic> json) {
    return DiningSlotModel(
      startTime: json['startTime']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      seatsLeft: (json['seatsLeft'] as num?)?.toInt() ?? 0,
      isAvailable: json['isAvailable'] == true,
      unavailableReason: json['unavailableReason']?.toString() ?? '',
    );
  }
}

/// Availability for a restaurant on a specific date.
@immutable
class DiningAvailabilityModel {
  final String date;
  final bool isOpen;
  final String reason;
  final bool autoConfirm;
  final int maxGuestsPerBooking;
  final int totalSeats;
  final double reservationFee;
  final List<DiningSlotModel> slots;

  const DiningAvailabilityModel({
    required this.date,
    this.isOpen = false,
    this.reason = '',
    this.autoConfirm = false,
    this.maxGuestsPerBooking = 12,
    this.totalSeats = 0,
    this.reservationFee = 0.0,
    this.slots = const [],
  });

  factory DiningAvailabilityModel.fromApi(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List? ?? [];
    return DiningAvailabilityModel(
      date: json['date']?.toString() ?? '',
      isOpen: json['isOpen'] == true,
      reason: json['reason']?.toString() ?? '',
      autoConfirm: json['autoConfirm'] == true,
      maxGuestsPerBooking: (json['maxGuestsPerBooking'] as num?)?.toInt() ?? 12,
      totalSeats: (json['totalSeats'] as num?)?.toInt() ?? 0,
      reservationFee: (json['reservationFee'] as num?)?.toDouble() ?? 0.0,
      slots: rawSlots
          .whereType<Map>()
          .map((e) => DiningSlotModel.fromApi(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

@immutable
class BookedTableModel {
  final String id;
  final String name;
  final int seats;

  const BookedTableModel({
    required this.id,
    required this.name,
    this.seats = 0,
  });

  factory BookedTableModel.fromApi(Map<String, dynamic> json) {
    return BookedTableModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      seats: (json['seats'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class DiningUserBookingModel {
  final String id;
  final String bookingCode;
  final String status;
  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final String restaurantAddress;
  final String date;
  final String slotStart;
  final String slotEnd;
  final DateTime? bookingAt;
  final int guests;
  final List<BookedTableModel> tables;
  final String guestName;
  final String guestPhone;
  final String occasion;
  final String specialRequest;
  final String cancelledBy;
  final String cancelReason;
  final bool canCancel;
  final bool canRate;
  final int? rating;
  final String review;
  final String paymentStatus;
  final String paymentMethod;
  final double reservationFee;
  final double paidAmount;
  final DateTime? createdAt;

  const DiningUserBookingModel({
    required this.id,
    required this.bookingCode,
    required this.status,
    required this.restaurantId,
    required this.restaurantName,
    this.restaurantImage = '',
    this.restaurantAddress = '',
    required this.date,
    required this.slotStart,
    this.slotEnd = '',
    this.bookingAt,
    required this.guests,
    this.tables = const [],
    required this.guestName,
    required this.guestPhone,
    this.occasion = '',
    this.specialRequest = '',
    this.cancelledBy = '',
    this.cancelReason = '',
    this.canCancel = false,
    this.canRate = false,
    this.rating,
    this.review = '',
    this.paymentStatus = 'free',
    this.paymentMethod = 'free',
    this.reservationFee = 0.0,
    this.paidAmount = 0.0,
    this.createdAt,
  });

  factory DiningUserBookingModel.fromApi(Map<String, dynamic> json) {
    final rawTables = (json['tables'] as List?) ?? const [];
    DateTime? parsedBookingAt;
    if (json['bookingAt'] != null) {
      parsedBookingAt = DateTime.tryParse(json['bookingAt'].toString())?.toLocal();
    }
    DateTime? parsedCreatedAt;
    if (json['createdAt'] != null) {
      parsedCreatedAt = DateTime.tryParse(json['createdAt'].toString())?.toLocal();
    }

    String restImage = json['restaurantImage']?.toString() ?? '';
    if (restImage.isEmpty && json['restaurant'] is Map) {
      final r = json['restaurant'] as Map;
      restImage = r['coverImage']?.toString() ?? r['profileImage']?.toString() ?? '';
    }

    return DiningUserBookingModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      status: (json['status']?.toString() ?? 'pending').toLowerCase(),
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ??
          (json['restaurant'] is Map ? json['restaurant']['name']?.toString() ?? '' : ''),
      restaurantImage: restImage,
      restaurantAddress: json['restaurantAddress']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      slotStart: json['slotStart']?.toString() ?? '',
      slotEnd: json['slotEnd']?.toString() ?? '',
      bookingAt: parsedBookingAt,
      guests: (json['guests'] as num?)?.toInt() ?? 1,
      tables: rawTables
          .whereType<Map>()
          .map((t) => BookedTableModel.fromApi(t.cast<String, dynamic>()))
          .toList(),
      guestName: json['guestName']?.toString() ?? '',
      guestPhone: json['guestPhone']?.toString() ?? '',
      occasion: json['occasion']?.toString() ?? '',
      specialRequest: json['specialRequest']?.toString() ?? '',
      cancelledBy: json['cancelledBy']?.toString() ?? '',
      cancelReason: json['cancelReason']?.toString() ?? '',
      canCancel: json['canCancel'] == true,
      canRate: json['canRate'] == true,
      rating: (json['rating'] as num?)?.toInt(),
      review: json['review']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? 'free',
      paymentMethod: json['paymentMethod']?.toString() ?? 'free',
      reservationFee: (json['reservationFee'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      createdAt: parsedCreatedAt,
    );
  }

  bool get isUpcoming =>
      status == 'pending' || status == 'confirmed' || status == 'seated';

  bool get isCancelled =>
      status == 'cancelled' || status == 'rejected' || status == 'no_show';

  bool get isCompleted => status == 'completed';

  String get displayStatus {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'pending':
        return 'Pending Approval';
      case 'seated':
        return 'Seated';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'rejected':
        return 'Declined';
      case 'no_show':
        return 'No Show';
      default:
        return status.toUpperCase();
    }
  }

  String get formattedSlotTime {
    if (slotStart.isEmpty) return '';
    return _format12Hour(slotStart);
  }

  String get formattedSlotRange {
    if (slotStart.isEmpty) return '';
    if (slotEnd.isEmpty) return _format12Hour(slotStart);
    return '${_format12Hour(slotStart)} - ${_format12Hour(slotEnd)}';
  }

  static String _format12Hour(String timeStr) {
    final parts = timeStr.trim().split(':');
    if (parts.isEmpty) return timeStr;
    final hour = int.tryParse(parts[0]);
    if (hour == null) return timeStr;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mStr = minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }
}

