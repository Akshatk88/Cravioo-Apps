import 'package:food_user_application/features/menu_items/domain/food_variant_model.dart';
import 'package:food_user_application/features/menu_items/domain/item_slot_timing_model.dart';

class FoodItemModel {
  FoodItemModel({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.name,
    required this.description,
    required this.price,
    required this.otherPrice,
    required this.image,
    this.images = const [],
    required this.foodType,
    required this.isAvailable,
    required this.isRecommended,
    required this.approvalStatus,
    required this.rejectionReason,
    required this.preparationTime,
    this.itemSlotTimingId,
    this.itemSlotTiming,
    this.variants = const [],
  });

  factory FoodItemModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());

    final mainImage = (json['image'] ?? '').toString();
    final rawImages = json['images'];
    final List<String> imagesList = rawImages is List
        ? rawImages.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : [];
    if (imagesList.isEmpty && mainImage.isNotEmpty) {
      imagesList.add(mainImage);
    }

    final rawVariants = json['variants'] ?? json['variations'];
    final List<FoodVariantModel> variantsList = rawVariants is List
        ? rawVariants
            .whereType<Map>()
            .map((e) => FoodVariantModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : [];

    ItemSlotTimingModel? slotTiming;
    if (json['itemSlotTiming'] is Map) {
      slotTiming = ItemSlotTimingModel.fromJson(
        Map<String, dynamic>.from(json['itemSlotTiming'] as Map),
      );
    }

    return FoodItemModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      categoryId: json['categoryId']?.toString(),
      categoryName: (json['categoryName'] ?? json['category'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: asNum(json['price'])?.toDouble() ?? 0,
      otherPrice: asNum(json['otherPrice'])?.toDouble() ?? 0,
      image: mainImage.isNotEmpty
          ? mainImage
          : (imagesList.isNotEmpty ? imagesList.first : ''),
      images: imagesList,
      foodType: (json['foodType'] ?? 'Non-Veg').toString(),
      isAvailable: json['isAvailable'] != false,
      isRecommended: json['isRecommended'] == true,
      approvalStatus: (json['approvalStatus'] ?? 'pending').toString(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
      preparationTime: (json['preparationTime'] ?? '').toString(),
      itemSlotTimingId: json['itemSlotTimingId']?.toString(),
      itemSlotTiming: slotTiming,
      variants: variantsList,
    );
  }

  final String id;
  final String? categoryId;
  final String categoryName;
  final String name;
  final String description;
  final double price;
  final double otherPrice;
  final String image;
  final List<String> images;
  final String foodType; // Veg | Non-Veg
  final bool isAvailable;
  final bool isRecommended;
  final String approvalStatus; // pending | approved | rejected
  final String rejectionReason;
  final String preparationTime;
  final String? itemSlotTimingId;
  final ItemSlotTimingModel? itemSlotTiming;
  final List<FoodVariantModel> variants;

  bool get isVeg => foodType == 'Veg';
  bool get isPending => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
  bool get hasVariants => variants.isNotEmpty;

  FoodItemModel copyWith({
    String? id,
    String? categoryId,
    String? categoryName,
    String? name,
    String? description,
    double? price,
    double? otherPrice,
    String? image,
    List<String>? images,
    String? foodType,
    bool? isAvailable,
    bool? isRecommended,
    String? approvalStatus,
    String? rejectionReason,
    String? preparationTime,
    String? itemSlotTimingId,
    ItemSlotTimingModel? itemSlotTiming,
    List<FoodVariantModel>? variants,
  }) {
    return FoodItemModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      otherPrice: otherPrice ?? this.otherPrice,
      image: image ?? this.image,
      images: images ?? this.images,
      foodType: foodType ?? this.foodType,
      isAvailable: isAvailable ?? this.isAvailable,
      isRecommended: isRecommended ?? this.isRecommended,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      preparationTime: preparationTime ?? this.preparationTime,
      itemSlotTimingId: itemSlotTimingId ?? this.itemSlotTimingId,
      itemSlotTiming: itemSlotTiming ?? this.itemSlotTiming,
      variants: variants ?? this.variants,
    );
  }
}
