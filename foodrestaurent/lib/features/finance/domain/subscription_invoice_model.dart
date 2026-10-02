class SubscriptionInvoiceModel {
  SubscriptionInvoiceModel({
    required this.id,
    required this.billingMonthLabel,
    required this.planName,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.status,
  });

  factory SubscriptionInvoiceModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return SubscriptionInvoiceModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      billingMonthLabel:
          (json['billingMonthLabel'] ?? json['billingMonth'] ?? '').toString(),
      planName: (json['planName'] ?? '').toString(),
      totalAmount: asNum(json['totalAmount'])?.toDouble() ?? 0,
      paidAmount: asNum(json['paidAmount'])?.toDouble() ?? 0,
      outstandingAmount: asNum(json['outstandingAmount'])?.toDouble() ?? 0,
      status: (json['status'] ?? 'pending').toString(),
    );
  }

  final String id;
  final String billingMonthLabel;
  final String planName;
  final double totalAmount;
  final double paidAmount;
  final double outstandingAmount;
  final String status;
}
