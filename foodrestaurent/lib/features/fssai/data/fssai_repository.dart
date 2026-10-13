import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';

/// Outcome of an FSSAI update. For already-approved outlets the backend
/// stages the change for admin review (`pendingReviewSubmitted`) and keeps
/// the previously approved details live.
class FssaiUpdateResult {
  const FssaiUpdateResult({
    required this.pendingReviewSubmitted,
    required this.requireLogout,
    required this.message,
  });

  final bool pendingReviewSubmitted;
  final bool requireLogout;
  final String message;
}

class FssaiRepository {
  FssaiRepository(this._dio);

  final Dio _dio;

  /// PATCH /food/restaurant/profile with the FSSAI fields.
  /// [expiry] must be `YYYY-MM-DD`.
  Future<FssaiUpdateResult> update({
    required String number,
    required String expiry,
    required String imageUrl,
  }) async {
    final response = await _dio.patch(
      '/food/restaurant/profile',
      data: {
        'fssaiNumber': number,
        'fssaiExpiry': expiry,
        'fssaiImage': imageUrl,
      },
    );
    final raw = response.data;
    final data = raw is Map
        ? Map<String, dynamic>.from(raw)
        : <String, dynamic>{};
    final restaurant = data['restaurant'] is Map
        ? Map<String, dynamic>.from(data['restaurant'] as Map)
        : data;
    return FssaiUpdateResult(
      pendingReviewSubmitted: restaurant['pendingReviewSubmitted'] == true,
      requireLogout: restaurant['requireLogout'] == true,
      message: (restaurant['message'] ?? '').toString(),
    );
  }
}

final fssaiRepositoryProvider = Provider<FssaiRepository>((ref) {
  return FssaiRepository(ref.watch(dioProvider));
});
