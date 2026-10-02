class ZoneModel {
  ZoneModel({required this.id, required this.name, required this.points});

  factory ZoneModel.fromJson(Map<String, dynamic> json) {
    final rawCoordinates = (json['coordinates'] as List? ?? []);
    final points = rawCoordinates
        .whereType<List>()
        .where((pair) => pair.length >= 2)
        .map(
          (pair) => (
            lat: (pair[0] as num).toDouble(),
            lng: (pair[1] as num).toDouble(),
          ),
        )
        .toList();

    return ZoneModel(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? json['zoneName'] ?? 'Zone').toString(),
      points: points,
    );
  }

  final String id;
  final String name;
  final List<({double lat, double lng})> points;
}
