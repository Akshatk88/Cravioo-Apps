import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/referral/domain/referral_model.dart';

class ReferralRepository {
  ReferralRepository(this._dio);

  final Dio _dio;

  Future<String> _referralCode() async {
    try {
      final response = await _dio.get('/food/restaurant/current');
      final data = response.data;
      if (data is Map && data['restaurant'] is Map) {
        final r = Map<String, dynamic>.from(data['restaurant'] as Map);
        final code = '${r['referralCode'] ?? ''}'.trim();
        if (code.isNotEmpty) return code;
        return '${r['_id'] ?? r['id'] ?? ''}'.trim();
      }
    } catch (_) {
      // Code is optional; stats can still render without it.
    }
    return '';
  }

  Future<ReferralData> load() async {
    final results = await Future.wait([
      _dio.get('/food/restaurant/referral-details'),
      _referralCode(),
    ]);
    final raw = (results[0] as Response).data;
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final statsRaw = data['stats'];
    final listRaw = data['referredRestaurants'];
    return ReferralData(
      referralCode: results[1] as String,
      stats: ReferralStats.fromJson(
        statsRaw is Map ? Map<String, dynamic>.from(statsRaw) : {},
      ),
      referred: listRaw is List
          ? listRaw
                .whereType<Map>()
                .map((e) => ReferredRestaurant.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
    );
  }
}

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(ref.watch(dioProvider));
});
