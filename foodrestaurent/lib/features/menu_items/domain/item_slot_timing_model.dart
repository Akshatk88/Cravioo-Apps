class ItemSlotTimingModel {
  ItemSlotTimingModel({
    required this.id,
    required this.name,
    this.startTime = '',
    this.endTime = '',
  });

  factory ItemSlotTimingModel.fromJson(Map<String, dynamic> json) {
    return ItemSlotTimingModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      startTime: (json['startTime'] ?? '').toString(),
      endTime: (json['endTime'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'startTime': startTime,
    'endTime': endTime,
  };

  final String id;
  final String name;
  final String startTime;
  final String endTime;

  String get displayLabel {
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      return '$name ($startTime - $endTime)';
    }
    return name;
  }
}
