import 'package:food_user_application/features/menu_items/domain/food_item_model.dart';

class MenuSectionModel {
  MenuSectionModel({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.image,
    required this.items,
  });

  factory MenuSectionModel.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? [])
        .map((e) => FoodItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return MenuSectionModel(
      id: (json['id'] ?? '').toString(),
      categoryId: json['categoryId']?.toString(),
      name: (json['name'] ?? 'Menu').toString(),
      image: (json['image'] ?? '').toString(),
      items: items,
    );
  }

  final String id;
  final String? categoryId;
  final String name;
  final String image;
  final List<FoodItemModel> items;
}
