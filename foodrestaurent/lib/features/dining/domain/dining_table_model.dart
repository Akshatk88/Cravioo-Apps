class DiningTableModel {
  final String id;
  final String name;
  final int seats;
  final String section;
  final String note;
  final bool isActive;
  final DateTime? createdAt;

  const DiningTableModel({
    required this.id,
    required this.name,
    required this.seats,
    this.section = 'indoor',
    this.note = '',
    this.isActive = true,
    this.createdAt,
  });

  factory DiningTableModel.fromJson(Map<String, dynamic> json) {
    return DiningTableModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      seats: (json['seats'] as num?)?.toInt() ?? 2,
      section: json['section']?.toString() ?? 'indoor',
      note: json['note']?.toString() ?? '',
      isActive: json['isActive'] != false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'seats': seats,
    'section': section,
    'note': note,
    'isActive': isActive,
  };

  String get sectionLabel {
    switch (section.toLowerCase()) {
      case 'indoor':
        return 'Indoor';
      case 'outdoor':
        return 'Outdoor';
      case 'rooftop':
        return 'Rooftop';
      case 'balcony':
        return 'Balcony';
      case 'private_dining':
        return 'Private Dining';
      default:
        return section;
    }
  }

  DiningTableModel copyWith({
    String? id,
    String? name,
    int? seats,
    String? section,
    String? note,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return DiningTableModel(
      id: id ?? this.id,
      name: name ?? this.name,
      seats: seats ?? this.seats,
      section: section ?? this.section,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DiningTableSummary {
  final int tables;
  final int seats;

  const DiningTableSummary({
    this.tables = 0,
    this.seats = 0,
  });

  factory DiningTableSummary.fromJson(Map<String, dynamic> json) {
    return DiningTableSummary(
      tables: (json['tables'] as num?)?.toInt() ?? 0,
      seats: (json['seats'] as num?)?.toInt() ?? 0,
    );
  }
}
