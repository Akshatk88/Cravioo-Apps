class VariantUnitOption {
  const VariantUnitOption(this.value, this.label);

  final String value;
  final String label;
}

const List<VariantUnitOption> kFoodVariantUnits = [
  VariantUnitOption('piece', 'Piece'),
  VariantUnitOption('pieces', 'Pieces'),
  VariantUnitOption('plate', 'Plate'),
  VariantUnitOption('bowl', 'Bowl'),
  VariantUnitOption('glass', 'Glass'),
  VariantUnitOption('cup', 'Cup'),
  VariantUnitOption('serving', 'Serving'),
  VariantUnitOption('slice', 'Slice'),
  VariantUnitOption('g', 'Gram (g)'),
  VariantUnitOption('kg', 'Kilogram (kg)'),
  VariantUnitOption('ml', 'Millilitre (ml)'),
  VariantUnitOption('litre', 'Litre'),
  VariantUnitOption('pack', 'Pack'),
  VariantUnitOption('box', 'Box'),
  VariantUnitOption('portion', 'Portion'),
];

class FoodVariantModel {
  FoodVariantModel({
    this.id,
    required this.name,
    this.unit = 'piece',
    required this.price,
    this.otherPrice = 0,
  });

  factory FoodVariantModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return FoodVariantModel(
      id: (json['id'] ?? json['_id'])?.toString(),
      name: (json['name'] ?? '').toString(),
      unit: (json['unit'] ?? 'piece').toString(),
      price: asNum(json['price'])?.toDouble() ?? 0,
      otherPrice: asNum(json['otherPrice'])?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null && id!.isNotEmpty) 'id': id,
    'name': name,
    'unit': unit,
    'price': price,
    if (otherPrice > 0) 'otherPrice': otherPrice,
  };

  final String? id;
  final String name;
  final String unit;
  final double price;
  final double otherPrice;

  String get unitLabel {
    final match = kFoodVariantUnits.where((u) => u.value == unit);
    return match.isNotEmpty ? match.first.label : unit;
  }
}
