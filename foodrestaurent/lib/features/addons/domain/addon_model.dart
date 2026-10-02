class AddonModel {
  AddonModel({
    required this.id,
    required this.name,
    required this.description,
    required this.foodType,
    required this.price,
    required this.image,
    required this.isAvailable,
    required this.approvalStatus,
    required this.rejectionReason,
  });

  factory AddonModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return AddonModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      foodType: (json['foodType'] ?? 'veg').toString(),
      price: asNum(json['price'])?.toDouble() ?? 0,
      image: (json['image'] ?? '').toString(),
      isAvailable: json['isAvailable'] != false,
      approvalStatus: (json['approvalStatus'] ?? 'pending').toString(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
    );
  }

  final String id;
  final String name;
  final String description;
  final String foodType; // veg | non-veg (lowercase, unlike food items)
  final double price;
  final String image;
  final bool isAvailable;
  final String approvalStatus; // pending | approved | rejected
  final String rejectionReason;

  bool get isVeg => foodType == 'veg';
  bool get isPending => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
}
