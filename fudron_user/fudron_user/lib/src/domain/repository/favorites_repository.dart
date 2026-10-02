import '../../data/datasources/favorites_remote_datasource.dart';
import '../../data/models/food_model.dart';
import '../../data/models/restaurant_model.dart';

/// Contract for favorited restaurant and food IDs, synchronized with backend.
abstract class FavoritesRepository {
  Future<Set<String>> getFavoriteIds();
  Future<void> saveFavoriteIds(Set<String> ids);

  Future<Set<String>> getFavoriteFoodIds();
  Future<void> saveFavoriteFoodIds(Set<String> ids);

  Future<List<RestaurantModel>> getFavoriteRestaurants();
  Future<void> saveFavoriteRestaurants(List<RestaurantModel> restaurants);

  Future<List<FoodModel>> getFavoriteFoods();
  Future<void> saveFavoriteFoods(List<FoodModel> foods);

  Future<FavoritesResponse?> getRemoteFavorites();
  Future<void> syncWithBackend();
  Future<void> toggleFavoriteRestaurant(String restaurantId, bool isFavorite);
  Future<void> toggleFavoriteFood(String foodId, bool isFavorite);

  /// Drops the cached ids. The cache is not keyed by user, so without this the
  /// next account to log in on the device inherits the previous one's hearts.
  Future<void> clearLocal();
}
