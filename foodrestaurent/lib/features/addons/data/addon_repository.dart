import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/addons/domain/addon_model.dart';

class AddonRepository {
  AddonRepository(this._dio);

  final Dio _dio;

  Future<List<AddonModel>> list() async {
    final response = await _dio.get(
      '/food/restaurant/addons',
      queryParameters: {'limit': 100},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['addons'] as List? ?? []);
    return list
        .map((e) => AddonModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<AddonModel> create({
    required String name,
    required String foodType,
    String description = '',
    required double price,
    String image = '',
  }) async {
    final response = await _dio.post(
      '/food/restaurant/addons',
      data: {
        'name': name,
        'foodType': foodType,
        'description': description,
        'price': price,
        'image': image,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return AddonModel.fromJson(Map<String, dynamic>.from(data['addon'] as Map));
  }

  /// Edits go through `draft` — the live/published version stays until admin
  /// re-approves. `isAvailable` is the one field that applies immediately.
  Future<AddonModel> update(
    String id, {
    String? name,
    String? foodType,
    String? description,
    double? price,
    String? image,
    bool? isAvailable,
  }) async {
    final draft = <String, dynamic>{
      'name': ?name,
      'foodType': ?foodType,
      'description': ?description,
      'price': ?price,
      'image': ?image,
    };
    final response = await _dio.patch(
      '/food/restaurant/addons/$id',
      data: {
        if (draft.isNotEmpty) 'draft': draft,
        'isAvailable': ?isAvailable,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return AddonModel.fromJson(Map<String, dynamic>.from(data['addon'] as Map));
  }

  Future<void> delete(String id) async {
    await _dio.delete('/food/restaurant/addons/$id');
  }
}

final addonRepositoryProvider = Provider<AddonRepository>((ref) {
  return AddonRepository(ref.watch(dioProvider));
});
