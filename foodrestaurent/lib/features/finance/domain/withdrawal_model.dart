class WithdrawalModel {
  WithdrawalModel({
    required this.id,
    required this.amount,
    required this.status,
    required this.rejectionReason,
    required this.createdAt,
  });

  factory WithdrawalModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return WithdrawalModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      amount: asNum(json['amount'])?.toDouble() ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String id;
  final double amount;
  final String status; // pending | approved | rejected
  final String rejectionReason;
  final DateTime createdAt;
}
