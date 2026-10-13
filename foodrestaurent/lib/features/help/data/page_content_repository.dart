import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/help/domain/page_content_model.dart';

class PageContentRepository {
  PageContentRepository(this._dio);

  final Dio _dio;

  /// Public (no-auth) CMS page for restaurant partners.
  /// [key] is one of `privacy`, `terms`, `support`.
  Future<PageContentModel> fetch(String key, {required String fallbackTitle}) async {
    final response = await _dio.get(
      '/food/pages/$key',
      queryParameters: {'role': 'restaurant'},
    );
    final raw = response.data;
    if (raw is Map && raw.isNotEmpty) {
      return PageContentModel.fromJson(
        Map<String, dynamic>.from(raw),
        fallbackTitle: fallbackTitle,
      );
    }
    return PageContentModel.empty(fallbackTitle);
  }
}

final pageContentRepositoryProvider = Provider<PageContentRepository>((ref) {
  return PageContentRepository(ref.watch(dioProvider));
});
