import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/menu_items/data/menu_repository.dart';
import 'package:food_user_application/features/menu_items/domain/food_variant_model.dart';
import 'package:food_user_application/features/menu_items/domain/menu_section_model.dart';

class MenuController extends AsyncNotifier<List<MenuSectionModel>> {
  @override
  Future<List<MenuSectionModel>> build() {
    return ref.read(menuRepositoryProvider).getMenu();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(menuRepositoryProvider).getMenu(),
    );
  }

  Future<void> createFood({
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
    await ref
        .read(menuRepositoryProvider)
        .createFood(
          name: name,
          foodType: foodType,
          description: description,
          price: price,
          otherPrice: otherPrice,
          image: image,
          images: images,
          categoryId: categoryId,
          isAvailable: isAvailable,
          isRecommended: isRecommended,
          preparationTime: preparationTime,
          itemSlotTimingId: itemSlotTimingId,
          variants: variants,
        );
    await refresh();
  }

  Future<void> updateFood(
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
    await ref
        .read(menuRepositoryProvider)
        .updateFood(
          id,
          name: name,
          foodType: foodType,
          description: description,
          price: price,
          otherPrice: otherPrice,
          image: image,
          images: images,
          categoryId: categoryId,
          isAvailable: isAvailable,
          isRecommended: isRecommended,
          preparationTime: preparationTime,
          itemSlotTimingId: itemSlotTimingId,
          variants: variants,
        );
    await refresh();
  }

  /// Optimistic toggle so the switch flips instantly instead of waiting on
  /// a full menu refetch; reverts (via [refresh]) if the request fails.
  Future<void> toggleAvailability(String id, bool isAvailable) async {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data([
        for (final section in current)
          MenuSectionModel(
            id: section.id,
            categoryId: section.categoryId,
            name: section.name,
            image: section.image,
            items: [
              for (final item in section.items)
                if (item.id == id)
                  item.copyWith(isAvailable: isAvailable)
                else
                  item,
            ],
          ),
      ]);
    }
    try {
      await ref
          .read(menuRepositoryProvider)
          .updateFood(id, isAvailable: isAvailable);
    } catch (_) {
      await refresh();
      rethrow;
    }
  }

  /// Optimistic toggle for Veg / Non-Veg
  Future<void> toggleFoodType(String id, bool isVeg) async {
    final current = state.value;
    final foodType = isVeg ? 'Veg' : 'Non-Veg';
    if (current != null) {
      state = AsyncValue.data([
        for (final section in current)
          MenuSectionModel(
            id: section.id,
            categoryId: section.categoryId,
            name: section.name,
            image: section.image,
            items: [
              for (final item in section.items)
                if (item.id == id)
                  item.copyWith(foodType: foodType)
                else
                  item,
            ],
          ),
      ]);
    }
    try {
      await ref
          .read(menuRepositoryProvider)
          .updateFood(id, foodType: foodType);
    } catch (_) {
      await refresh();
      rethrow;
    }
  }
}

final menuControllerProvider =
    AsyncNotifierProvider<MenuController, List<MenuSectionModel>>(
      MenuController.new,
    );
