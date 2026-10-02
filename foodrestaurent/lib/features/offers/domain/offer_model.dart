class OfferModel {
  OfferModel({
    required this.id,
    required this.couponCode,
    required this.discountType,
    required this.discountValue,
    required this.minOrderValue,
    required this.maxDiscount,
    required this.usageLimit,
    required this.perUserLimit,
    required this.isFirstOrderOnly,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory OfferModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) =>
        v == null ? null : DateTime.tryParse(v.toString());
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());

    return OfferModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      couponCode: (json['couponCode'] ?? '').toString(),
      discountType: (json['discountType'] ?? 'percentage').toString(),
      discountValue: asNum(json['discountValue'])?.toDouble() ?? 0,
      minOrderValue: asNum(json['minOrderValue'])?.toDouble() ?? 0,
      maxDiscount: asNum(json['maxDiscount'])?.toDouble(),
      usageLimit: asNum(json['usageLimit'])?.toInt(),
      perUserLimit: asNum(json['perUserLimit'])?.toInt(),
      isFirstOrderOnly: json['isFirstOrderOnly'] == true,
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      status: (json['status'] ?? 'active').toString(),
    );
  }

  final String id;
  final String couponCode;
  final String discountType; // percentage | flat-price
  final double discountValue;
  final double minOrderValue;
  final double? maxDiscount;
  final int? usageLimit;
  final int? perUserLimit;
  final bool isFirstOrderOnly;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;

  bool get isPercentage => discountType == 'percentage';
  bool get isActive => status == 'active';
}
