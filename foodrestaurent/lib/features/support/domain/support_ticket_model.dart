class SupportTicketModel {
  SupportTicketModel({
    required this.id,
    required this.category,
    required this.issueType,
    required this.subject,
    required this.description,
    required this.orderRef,
    required this.priority,
    required this.status,
    required this.adminResponse,
    required this.createdAt,
  });

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    return SupportTicketModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      issueType: (json['issueType'] ?? '').toString(),
      subject: (json['subject'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      orderRef: (json['orderRef'] ?? '').toString(),
      priority: (json['priority'] ?? 'medium').toString(),
      status: (json['status'] ?? 'open').toString(),
      adminResponse: (json['adminResponse'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String category;
  final String issueType;
  final String subject;
  final String description;
  final String orderRef;
  final String priority;
  final String status; // open | in-progress | resolved
  final String adminResponse;
  final DateTime createdAt;
}
