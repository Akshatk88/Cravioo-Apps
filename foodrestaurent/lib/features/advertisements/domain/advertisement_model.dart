class AdvertisementModel {
  const AdvertisementModel({
    required this.id,
    required this.adsId,
    required this.title,
    required this.description,
    required this.adsType,
    required this.status,
    required this.lifecycleStatus,
    required this.adsPlaced,
    required this.durationStart,
    required this.durationEnd,
    required this.validity,
    required this.imageUrl,
    required this.videoUrl,
    required this.fileDescription,
    required this.videoDescription,
    required this.paymentStatus,
    required this.pauseNote,
  });

  final String id;
  final String adsId;
  final String title;
  final String description;
  final String adsType;

  /// Display status: Pending, Approved, Rejected, Paused, Expired.
  final String status;
  final String lifecycleStatus;
  final String adsPlaced;
  final String durationStart;
  final String durationEnd;

  /// Raw validity string: "YYYY-MM-DD to YYYY-MM-DD".
  final String validity;
  final String imageUrl;
  final String videoUrl;
  final String fileDescription;
  final String videoDescription;
  final String paymentStatus;
  final String pauseNote;

  static String _s(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    final s = v.toString();
    return s.isEmpty ? fallback : s;
  }

  factory AdvertisementModel.fromJson(Map<String, dynamic> json) {
    final duration = json['duration'] is Map
        ? Map<String, dynamic>.from(json['duration'] as Map)
        : const <String, dynamic>{};
    final id = _s(json['id'], _s(json['_id']));
    return AdvertisementModel(
      id: id,
      adsId: _s(json['adsId'], id),
      title: _s(json['title']),
      description: _s(json['description']),
      adsType: _s(json['adsType'], _s(json['type'])),
      status: _s(json['status'], 'Pending'),
      lifecycleStatus: _s(json['lifecycleStatus'], _s(json['status'])),
      adsPlaced: _s(json['adsPlaced'], 'N/A'),
      durationStart: _s(duration['start'], 'N/A'),
      durationEnd: _s(duration['end'], 'N/A'),
      validity: _s(json['validity']),
      imageUrl: _s(json['imageUrl']),
      videoUrl: _s(json['videoUrl']),
      fileDescription: _s(json['fileDescription']),
      videoDescription: _s(json['videoDescription']),
      paymentStatus: _s(json['paymentStatus']),
      pauseNote: _s(json['pauseNote'], '-'),
    );
  }

  bool get isPaused => status == 'Paused' || lifecycleStatus == 'Paused';
  bool get isApproved =>
      status == 'Approved' ||
      status == 'Running' ||
      lifecycleStatus == 'Approved';

  /// Parses [validity] into (start, end); either may be null.
  (DateTime?, DateTime?) get validityRange {
    final parts = validity
        .split(RegExp(r'\s+to\s+|\s+-\s+', caseSensitive: false))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return (null, null);
    final start = DateTime.tryParse(parts[0]);
    final end = parts.length > 1 ? DateTime.tryParse(parts[1]) : start;
    return (start, end);
  }
}

const advertisementTypes = <String>[
  'Video Promotion',
  'Restaurant Promotion',
  'Image Promotion',
  'Banner Promotion',
];
