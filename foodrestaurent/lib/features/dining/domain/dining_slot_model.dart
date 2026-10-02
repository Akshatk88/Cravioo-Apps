class DiningSlotItemModel {
  final String startTime;
  final String endTime;
  final int capacity;
  final bool isActive;

  const DiningSlotItemModel({
    required this.startTime,
    required this.endTime,
    this.capacity = 0,
    this.isActive = true,
  });

  factory DiningSlotItemModel.fromJson(Map<String, dynamic> json) {
    return DiningSlotItemModel(
      startTime: json['startTime']?.toString() ?? '12:00',
      endTime: json['endTime']?.toString() ?? '13:00',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] != false,
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime,
    'endTime': endTime,
    'capacity': capacity,
    'isActive': isActive,
  };

  DiningSlotItemModel copyWith({
    String? startTime,
    String? endTime,
    int? capacity,
    bool? isActive,
  }) {
    return DiningSlotItemModel(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      capacity: capacity ?? this.capacity,
      isActive: isActive ?? this.isActive,
    );
  }
}

class DiningDaySlotsModel {
  final int dayOfWeek;
  final String day;
  final bool isOpen;
  final List<DiningSlotItemModel> slots;

  const DiningDaySlotsModel({
    required this.dayOfWeek,
    required this.day,
    this.isOpen = true,
    this.slots = const [],
  });

  factory DiningDaySlotsModel.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'] as List? ?? [];
    return DiningDaySlotsModel(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      day: json['day']?.toString() ?? '',
      isOpen: json['isOpen'] != false,
      slots: rawSlots
          .whereType<Map>()
          .map((s) => DiningSlotItemModel.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek,
    'day': day,
    'isOpen': isOpen,
    'slots': slots.map((s) => s.toJson()).toList(),
  };

  DiningDaySlotsModel copyWith({
    int? dayOfWeek,
    String? day,
    bool? isOpen,
    List<DiningSlotItemModel>? slots,
  }) {
    return DiningDaySlotsModel(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      day: day ?? this.day,
      isOpen: isOpen ?? this.isOpen,
      slots: slots ?? this.slots,
    );
  }
}

class DiningBlockedDateModel {
  final String id;
  final String date;
  final String reason;

  const DiningBlockedDateModel({
    required this.id,
    required this.date,
    this.reason = '',
  });

  factory DiningBlockedDateModel.fromJson(Map<String, dynamic> json) {
    return DiningBlockedDateModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'reason': reason,
  };
}
