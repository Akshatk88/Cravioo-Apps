class NotificationModel {
  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.link,
    required this.category,
    required this.source,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      link: (json['link'] ?? '').toString(),
      category: (json['category'] ?? 'broadcast').toString(),
      source: (json['source'] ?? 'ADMIN_BROADCAST').toString(),
      isRead: json['isRead'] == true,
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final String title;
  final String message;
  final String link;
  final String category;
  final String source;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      link: link,
      category: category,
      source: source,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }

  /// Pill label shown on each card — mirrors the backend's [source] enum.
  String get tag {
    switch (source) {
      case 'FSSAI_EXPIRY':
        return 'Alert';
      case 'SUPPORT_RESPONSE':
        return 'Support';
      case 'ADMIN_BROADCAST':
      default:
        return 'Broadcast';
    }
  }
}
