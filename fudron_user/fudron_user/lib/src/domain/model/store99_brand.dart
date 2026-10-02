import '../../data/models/restaurant_model.dart';

/// Domain entity representing a featured brand in the 99 Store.
class Store99Brand {
  final String id;
  final String label;
  final String imageUrl;
  final RestaurantModel? restaurant;

  const Store99Brand({
    required this.id,
    required this.label,
    required this.imageUrl,
    this.restaurant,
  });
}

