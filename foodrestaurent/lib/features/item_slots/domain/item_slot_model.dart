class ItemSlotModel {
  const ItemSlotModel({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;

  /// 24h "HH:mm".
  final String startTime;
  final String endTime;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ItemSlotModel.fromJson(Map<String, dynamic> json) {
    return ItemSlotModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      startTime: (json['startTime'] ?? '').toString(),
      endTime: (json['endTime'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()),
    );
  }

  /// "13:05" -> "1:05 PM". Returns the input when it cannot be parsed.
  static String display(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return hhmm;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${m.toString().padLeft(2, '0')} $suffix';
  }
}
