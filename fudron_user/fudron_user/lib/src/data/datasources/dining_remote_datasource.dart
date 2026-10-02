import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/dining_model.dart';

class DiningBookingResult {
  final bool success;
  final String message;
  final DiningUserBookingModel? booking;
  final String? errorMessage;

  const DiningBookingResult({
    required this.success,
    this.message = '',
    this.booking,
    this.errorMessage,
  });
}

class DiningRemoteDataSource {
  final ApiClient _client;
  static const Duration _cacheTtl = Duration(minutes: 5);

  DiningRemoteDataSource(this._client);

  Future<List<DiningCategoryModel>> getCategories() async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        ApiPaths.diningCategories,
        auth: false,
        cacheTtl: _cacheTtl,
      );
      final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
      final items = (data['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((e) => DiningCategoryModel.fromApi(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<DiningBannerModel>> getBanners() async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        ApiPaths.diningBanners,
        auth: false,
        cacheTtl: _cacheTtl,
      );
      final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
      final items = (data['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((e) => DiningBannerModel.fromApi(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<DiningRestaurantModel>> getRestaurants({
    String? categoryId,
    String? search,
    String? sortBy,
    double? lat,
    double? lng,
  }) async {
    try {
      final query = <String, dynamic>{};
      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        query['categoryId'] = categoryId;
      }
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (sortBy != null && sortBy.isNotEmpty) query['sort'] = sortBy;
      if (lat != null && lng != null) {
        query['lat'] = lat;
        query['lng'] = lng;
      }

      final res = await _client.get<Map<String, dynamic>>(
        ApiPaths.diningRestaurants,
        query: query,
        auth: false,
        cacheTtl: _cacheTtl,
      );
      final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
      final items = (data['items'] as List?) ?? const [];
      return items
          .whereType<Map>()
          .map((e) => DiningRestaurantModel.fromApi(e.cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Fetch real-time availability (slots) for a restaurant on a specific date.
  Future<DiningAvailabilityModel> getAvailability({
    required String restaurantId,
    required String date,
    int guests = 2,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      ApiPaths.diningAvailability(restaurantId),
      query: {'date': date, 'guests': guests},
      auth: false,
    );
    final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
    return DiningAvailabilityModel.fromApi(data);
  }

  /// Book a table — sends the correct fields the backend validator expects.
  Future<DiningBookingResult> bookTable({
    required String restaurantId,
    required String date,
    required String slotStart,
    required int guests,
    required String guestName,
    required String guestPhone,
    String? occasion,
    String? specialRequest,
    String paymentMethod = 'free',
    String? transactionId,
  }) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiPaths.diningBookings,
        body: {
          'restaurantId': restaurantId,
          'date': date,
          'slotStart': slotStart,
          'guests': guests,
          'guestName': guestName,
          'guestPhone': guestPhone,
          'paymentMethod': paymentMethod,
          if (transactionId != null && transactionId.isNotEmpty)
            'transactionId': transactionId,
          if (occasion != null && occasion.isNotEmpty) 'occasion': occasion,
          if (specialRequest != null && specialRequest.isNotEmpty)
            'specialRequest': specialRequest,
        },
        auth: true,
      );
      final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
      final booking = DiningUserBookingModel.fromApi(data);
      final isAutoConfirmed = booking.status == 'confirmed';
      return DiningBookingResult(
        success: true,
        message: isAutoConfirmed
            ? 'Table booked successfully for $guests guests!'
            : 'Table reservation request sent to restaurant!',
        booking: booking,
      );
    } catch (e) {
      final cleanMsg = e
          .toString()
          .replaceAll('Exception: ', '')
          .replaceAll('Failure: ', '')
          .replaceAll('ServerFailure: ', '');
      return DiningBookingResult(
        success: false,
        errorMessage: cleanMsg.isNotEmpty ? cleanMsg : 'Failed to book table. Please try again.',
      );
    }
  }

  /// Get current user's dining reservations / booking history.
  Future<List<DiningUserBookingModel>> getMyBookings({
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null && status.isNotEmpty && status != 'all') {
        query['status'] = status;
      }
      final res = await _client.get<Map<String, dynamic>>(
        ApiPaths.diningBookings,
        query: query,
        auth: true,
      );
      final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
      final items = (data['items'] as List?) ?? const [];
      final list = <DiningUserBookingModel>[];
      for (final item in items) {
        if (item is Map) {
          try {
            list.add(DiningUserBookingModel.fromApi(Map<String, dynamic>.from(item)));
          } catch (_) {}
        }
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Cancel a dining reservation.
  Future<bool> cancelBooking(String bookingId, {required String reason}) async {
    try {
      await _client.patch<Map<String, dynamic>>(
        ApiPaths.diningBookingCancel(bookingId),
        body: {'reason': reason},
        auth: true,
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Rate a completed dining visit.
  Future<bool> rateBooking(String bookingId, {required int rating, String? review}) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiPaths.diningBookingRating(bookingId),
        body: {
          'rating': rating,
          if (review != null && review.isNotEmpty) 'review': review,
        },
        auth: true,
      );
      return true;
    } catch (e) {
      rethrow;
    }
  }
}

