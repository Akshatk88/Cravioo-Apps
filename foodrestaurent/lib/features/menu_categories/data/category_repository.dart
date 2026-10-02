import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/menu_categories/domain/category_model.dart';

class CategoryRepository {
  CategoryRepository(this._dio);

  final Dio _dio;

  Future<List<CategoryModel>> list() async {
    final response = await _dio.get('/food/restaurant/categories');
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['categories'] as List? ?? []);
    return list
        .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CategoryModel> create({
    required String name,
    required String foodTypeScope,
    String type = '',
    String image = '',
    bool isActive = true,
  }) async {
    final response = await _dio.post(
      '/food/restaurant/categories',
      data: {
        'name': name,
        'foodTypeScope': foodTypeScope,
        'type': type,
        'image': image,
        'isActive': isActive,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return CategoryModel.fromJson(
      Map<String, dynamic>.from(data['category'] as Map),
    );
  }

  Future<CategoryModel> update(
    String id, {
    String? name,
    String? foodTypeScope,
    String? type,
    String? image,
    bool? isActive,
  }) async {
    final response = await _dio.patch(
      '/food/restaurant/categories/$id',
      data: {
        'name': ?name,
        'foodTypeScope': ?foodTypeScope,
        'type': ?type,
        'image': ?image,
        'isActive': ?isActive,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return CategoryModel.fromJson(
      Map<String, dynamic>.from(data['category'] as Map),
    );
  }

  Future<void> delete(String id) async {
    await _dio.delete('/food/restaurant/categories/$id');
  }
}

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(dioProvider));
});
