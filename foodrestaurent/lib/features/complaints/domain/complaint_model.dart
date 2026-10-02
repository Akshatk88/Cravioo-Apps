class ComplaintModel {
  ComplaintModel({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.orderDisplayId,
    required this.orderStatus,
    required this.issueType,
    required this.description,
    required this.status,
    required this.adminResponse,
    required this.createdAt,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    final user = json['userId'];
    final order = json['orderId'];
    final userMap = user is Map ? user : null;
    final orderMap = order is Map ? order : null;

    return ComplaintModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      customerName: (userMap?['name'] ?? 'Customer').toString(),
      customerPhone: (userMap?['phone'] ?? '').toString(),
      orderDisplayId: (orderMap?['orderId'] ?? '').toString(),
      orderStatus: (orderMap?['orderStatus'] ?? '').toString(),
      issueType: (json['issueType'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'open').toString(),
      adminResponse: (json['adminResponse'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String customerName;
  final String customerPhone;
  final String orderDisplayId;
  final String orderStatus;
  final String issueType;
  final String description;
  final String status; // open | in-progress | resolved
  final String adminResponse;
  final DateTime createdAt;
}
