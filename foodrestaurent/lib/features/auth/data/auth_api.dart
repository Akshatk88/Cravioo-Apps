import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';

/// Thin wrapper around the raw `/food/auth/restaurant/*` + `/food/restaurant/current`
/// endpoints. Returns the already-unwrapped `data` payload (see the Dio
/// `onResponse` interceptor) as a `Map<String, dynamic>`.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final response = await _dio.post(
      '/food/auth/restaurant/request-otp',
      data: {'phone': phone},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? fcmToken,
    String platform = 'mobile',
  }) async {
    final response = await _dio.post(
      '/food/auth/restaurant/verify-otp',
      data: {
        'phone': phone,
        'otp': otp,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
        'platform': platform,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getCurrentRestaurant() async {
    final response = await _dio.get('/food/restaurant/current');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> logout({String? refreshToken, String? fcmToken}) async {
    await _dio.post(
      '/food/auth/logout',
      data: {
        'refreshToken': refreshToken,
        'fcmToken': fcmToken,
        'platform': 'mobile',
      },
    );
  }

  Future<void> deleteAccount() async {
    try {
      await _dio.delete('/food/auth/restaurant/account');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        try {
          await _dio.delete('/food/auth/account');
        } on DioException catch (_) {
          await _dio.delete('/food/restaurant/me');
        }
      } else {
        rethrow;
      }
    }
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});
