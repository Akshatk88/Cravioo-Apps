import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/menu_items/domain/food_item_model.dart';
import 'package:food_user_application/features/menu_items/domain/food_variant_model.dart';
import 'package:food_user_application/features/menu_items/domain/item_slot_timing_model.dart';
import 'package:food_user_application/features/menu_items/domain/menu_section_model.dart';

class MenuRepository {
  MenuRepository(this._dio);

  final Dio _dio;

  Future<List<MenuSectionModel>> getMenu() async {
    final response = await _dio.get('/food/restaurant/menu');
    final data = Map<String, dynamic>.from(response.data as Map);
    final menu = Map<String, dynamic>.from(data['menu'] as Map);
    final sections = (menu['sections'] as List? ?? []);
    return sections
        .map(
          (e) => MenuSectionModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<List<ItemSlotTimingModel>> getItemSlotTimings() async {
    try {
      final response = await _dio.get('/food/restaurant/item-slot-timings');
      final data = Map<String, dynamic>.from(response.data as Map);
      final list = (data['slots'] as List? ?? (data['data']?['slots'] as List? ?? []));
      return list
          .map(
            (e) => ItemSlotTimingModel.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<FoodItemModel> createFood({
    required String name,
    required String foodType,
    String description = '',
    required double price,
    double otherPrice = 0,
    String image = '',
    List<String> images = const [],
    String? categoryId,
    bool isAvailable = true,
    bool isRecommended = false,
    String preparationTime = '',
    String? itemSlotTimingId,
    List<FoodVariantModel> variants = const [],
  }) async {
    final response = await _dio.post(
      '/food/restaurant/foods',
      data: {
        'name': name,
        'foodType': foodType,
        'description': description,
        'price': price,
        if (otherPrice > 0) 'otherPrice': otherPrice,
        'image': image,
        if (images.isNotEmpty) 'images': images,
        if (categoryId != null && categoryId.isNotEmpty)
          'categoryId': categoryId,
        'isAvailable': isAvailable,
        'isRecommended': isRecommended,
        'preparationTime': preparationTime,
        if (itemSlotTimingId != null && itemSlotTimingId.isNotEmpty)
          'itemSlotTimingId': itemSlotTimingId,
        if (variants.isNotEmpty)
          'variants': variants.map((v) => v.toJson()).toList(),
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final foodData = data['food'] ?? data['data']?['food'] ?? data;
    return FoodItemModel.fromJson(
      Map<String, dynamic>.from(foodData as Map),
    );
  }

  Future<FoodItemModel> updateFood(
    String id, {
    String? name,
    String? foodType,
    String? description,
    double? price,
    double? otherPrice,
    String? image,
    List<String>? images,
    String? categoryId,
    bool? isAvailable,
    bool? isRecommended,
    String? preparationTime,
    String? itemSlotTimingId,
    List<FoodVariantModel>? variants,
  }) async {
    final response = await _dio.patch(
      '/food/restaurant/foods/$id',
      data: {
        'name': ?name,
        'foodType': ?foodType,
        'description': ?description,
        'price': ?price,
        'otherPrice': ?otherPrice,
        'image': ?image,
        'images': ?images,
        'categoryId': ?categoryId,
        'isAvailable': ?isAvailable,
        'isRecommended': ?isRecommended,
        'preparationTime': ?preparationTime,
        'itemSlotTimingId': ?itemSlotTimingId,
        'variants': ?variants?.map((v) => v.toJson()).toList(),
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final foodData = data['food'] ?? data['data']?['food'] ?? data;
    return FoodItemModel.fromJson(
      Map<String, dynamic>.from(foodData as Map),
    );
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(dioProvider));
});

final itemSlotTimingsProvider = FutureProvider<List<ItemSlotTimingModel>>((ref) async {
  return ref.watch(menuRepositoryProvider).getItemSlotTimings();
});
