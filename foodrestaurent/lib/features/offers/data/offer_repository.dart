import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/offers/domain/offer_model.dart';

class OfferRepository {
  OfferRepository(this._dio);

  final Dio _dio;

  Future<List<OfferModel>> list() async {
    final response = await _dio.get('/food/restaurant/my-offers');
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['offers'] as List? ?? []);
    return list
        .map((e) => OfferModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<OfferModel> create({
    required String couponCode,
    required String discountType,
    required double discountValue,
    double? minOrderValue,
    double? maxDiscount,
    int? usageLimit,
    int? perUserLimit,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _dio.post(
      '/food/restaurant/my-offers',
      data: {
        'couponCode': couponCode,
        'discountType': discountType,
        'discountValue': discountValue,
        'minOrderValue': ?minOrderValue,
        'maxDiscount': ?maxDiscount,
        'usageLimit': ?usageLimit,
        'perUserLimit': ?perUserLimit,
        'startDate': startDate.toIso8601String().split('T').first,
        'endDate': endDate.toIso8601String().split('T').first,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return OfferModel.fromJson(Map<String, dynamic>.from(data['doc'] as Map));
  }

  Future<void> updateStatus(String id, String status) async {
    await _dio.patch(
      '/food/restaurant/my-offers/$id/status',
      data: {'status': status},
    );
  }

  Future<void> delete(String id) async {
    await _dio.delete('/food/restaurant/my-offers/$id');
  }
}

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  return OfferRepository(ref.watch(dioProvider));
});
