import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';

class FeedbackRepository {
  FeedbackRepository(this._dio);

  final Dio _dio;

  /// [rating] is 1-5 (mongoose `min:1,max:5`) — callers with a 0-10 NPS-style
  /// UI scale must map it first, e.g. `(npsRating / 2).ceil().clamp(1, 5)`.
  Future<void> submit({required int rating, String comment = ''}) async {
    await _dio.post(
      '/food/restaurant/feedback-experience',
      data: {'rating': rating, 'comment': comment, 'module': 'restaurant'},
    );
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(ref.watch(dioProvider));
});
