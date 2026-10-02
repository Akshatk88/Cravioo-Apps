import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repository/favorites_repository.dart';
import '../datasources/favorites_remote_datasource.dart';
import '../models/food_model.dart';
import '../models/restaurant_model.dart';

/// Favorites store with backend sync and SharedPreferences fallback.
class FavoritesRepositoryImpl implements FavoritesRepository {
  static const _keyRestaurant = 'favorite_restaurant_ids';
  static const _keyFood = 'favorite_food_ids';
  static const _keyRestaurantModels = 'favorite_restaurant_models';
  static const _keyFoodModels = 'favorite_food_models';

  final FavoritesRemoteDataSource? _remote;

  const FavoritesRepositoryImpl([this._remote]);

  @override
  Future<Set<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRestaurant)?.toSet() ?? <String>{};
  }

  @override
  Future<void> saveFavoriteIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyRestaurant, ids.toList());
  }

  @override
  Future<Set<String>> getFavoriteFoodIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFood)?.toSet() ?? <String>{};
  }

  @override
  Future<void> saveFavoriteFoodIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFood, ids.toList());
  }

  @override
  Future<List<RestaurantModel>> getFavoriteRestaurants() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyRestaurantModels);
      if (list == null || list.isEmpty) return const [];
      final result = <RestaurantModel>[];
      for (final raw in list) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          result.add(RestaurantModel.fromJson(map));
        } catch (_) {}
      }
      return result;
    } catch (e) {
      developer.log('[FAVORITE] Failed to load cached restaurant models: $e', name: 'FAVORITE');
      return const [];
    }
  }

  @override
  Future<void> saveFavoriteRestaurants(List<RestaurantModel> restaurants) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = restaurants.map((r) => jsonEncode(r.toJson())).toList();
      await prefs.setStringList(_keyRestaurantModels, list);
    } catch (e) {
      developer.log('[FAVORITE] Failed to save restaurant models: $e', name: 'FAVORITE');
    }
  }

  @override
  Future<List<FoodModel>> getFavoriteFoods() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyFoodModels);
      if (list == null || list.isEmpty) return const [];
      final result = <FoodModel>[];
      for (final raw in list) {
        try {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          result.add(FoodModel.fromJson(map));
        } catch (_) {}
      }
      return result;
    } catch (e) {
      developer.log('[FAVORITE] Failed to load cached food models: $e', name: 'FAVORITE');
      return const [];
    }
  }

  @override
  Future<void> saveFavoriteFoods(List<FoodModel> foods) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = foods.map((f) => jsonEncode(f.toJson())).toList();
      await prefs.setStringList(_keyFoodModels, list);
    } catch (e) {
      developer.log('[FAVORITE] Failed to save food models: $e', name: 'FAVORITE');
    }
  }

  @override
  Future<void> toggleFavoriteRestaurant(String restaurantId, bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_keyRestaurant)?.toSet() ?? <String>{};

    if (isFavorite) {
      ids.add(restaurantId);
    } else {
      ids.remove(restaurantId);
    }

    // Always persist to local SharedPreferences immediately
    await prefs.setStringList(_keyRestaurant, ids.toList());

    // Best-effort sync with backend if available
    if (_remote != null) {
      try {
        await _remote.toggleFavoriteRestaurant(restaurantId, isFavorite);
      } catch (e) {
        developer.log(
          '[FAVORITE] [Backend Sync Notice] Remote toggle failed for ID: $restaurantId (Kept locally) | Error: $e',
          name: 'FAVORITE',
        );
      }
    }
  }

  @override
  Future<void> toggleFavoriteFood(String foodId, bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_keyFood)?.toSet() ?? <String>{};

    if (isFavorite) {
      ids.add(foodId);
    } else {
      ids.remove(foodId);
    }

    // Always persist to local SharedPreferences immediately
    await prefs.setStringList(_keyFood, ids.toList());

    // Best-effort sync with backend if available
    if (_remote != null) {
      try {
        await _remote.toggleFavoriteFood(foodId, isFavorite);
      } catch (e) {
        developer.log(
          '[FAVORITE] [Backend Sync Notice] Remote toggle food failed for ID: $foodId (Kept locally) | Error: $e',
          name: 'FAVORITE',
        );
      }
    }
  }

  @override
  Future<FavoritesResponse?> getRemoteFavorites() async {
    if (_remote == null) return null;
    try {
      final res = await _remote.getFavorites();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyRestaurant, res.restaurantIds.toList());
      await prefs.setStringList(_keyFood, res.foodIds.toList());
      if (res.restaurants.isNotEmpty) {
        await saveFavoriteRestaurants(res.restaurants);
      }
      if (res.foods.isNotEmpty) {
        await saveFavoriteFoods(res.foods);
      }
      return res;
    } catch (e) {
      developer.log('[FAVORITE] Repository getRemoteFavorites Error: $e', name: 'FAVORITE');
      return null;
    }
  }

  @override
  Future<void> syncWithBackend() async {
    await getRemoteFavorites();
  }

  @override
  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRestaurant);
    await prefs.remove(_keyFood);
    await prefs.remove(_keyRestaurantModels);
    await prefs.remove(_keyFoodModels);
  }
}
