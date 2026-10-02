import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../di/restaurant_providers.dart';
import '../../../data/models/food_model.dart';

final restaurantMenuProvider = FutureProvider.family<List<FoodModel>, String>((ref, restaurantId) async {
  final repository = ref.watch(restaurantRepositoryProvider);
  final response = await repository.getRestaurantMenu(restaurantId);
  if (response.isSuccess) {
    return response.data ?? [];
  } else {
    throw Exception(response.message ?? 'Failed to load menu');
  }
});
