class CategoryModel {
  CategoryModel({
    required this.id,
    required this.name,
    required this.image,
    required this.type,
    required this.foodTypeScope,
    required this.isActive,
    required this.approvalStatus,
    required this.rejectionReason,
    required this.itemCount,
    required this.sortOrder,
    required this.canEdit,
    required this.canDelete,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      image: (json['image'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      foodTypeScope: (json['foodTypeScope'] ?? 'Both').toString(),
      isActive: json['isActive'] != false,
      approvalStatus: (json['approvalStatus'] ??
              (json['isApproved'] == true ? 'approved' : 'pending'))
          .toString(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
      itemCount: (json['itemCount'] is num)
          ? (json['itemCount'] as num).toInt()
          : 0,
      sortOrder: (json['sortOrder'] is num)
          ? (json['sortOrder'] as num).toInt()
          : 0,
      canEdit: json['canEdit'] == true,
      canDelete: json['canDelete'] == true,
    );
  }

  final String id;
  final String name;
  final String image;
  final String type;
  final String foodTypeScope;
  final bool isActive;
  final String approvalStatus;
  final String rejectionReason;
  final int itemCount;
  final int sortOrder;
  final bool canEdit;
  final bool canDelete;

  bool get isPending => approvalStatus == 'pending';
  bool get isApproved => approvalStatus == 'approved';
}
