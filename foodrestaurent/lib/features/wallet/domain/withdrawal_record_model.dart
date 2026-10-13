import 'package:food_user_application/features/wallet/presentation/widgets/money_ui.dart';

/// A withdrawal request row from GET /food/restaurant/withdrawals
/// (includes processedAt and the cancelled/processing statuses).
class WithdrawalRecord {
  WithdrawalRecord({
    required this.id,
    required this.amount,
    required this.status,
    required this.rejectionReason,
    required this.requestedAt,
    required this.processedAt,
  });

  factory WithdrawalRecord.fromJson(Map<String, dynamic> json) {
    return WithdrawalRecord(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      amount: asNum(json['amount'])?.toDouble() ?? 0,
      status: (json['status'] ?? 'pending').toString().toLowerCase(),
      rejectionReason: (json['rejectionReason'] ?? '').toString(),
      requestedAt: asDate(json['createdAt']),
      processedAt: asDate(json['processedAt']),
    );
  }

  final String id;
  final double amount;
  final String status;
  final String rejectionReason;
  final DateTime? requestedAt;
  final DateTime? processedAt;

  bool get isPending => status == 'pending' || status == 'processing';
  bool get isCancellable => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejectedOrCancelled =>
      status == 'rejected' || status == 'cancelled';

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Pending';
    }
  }
}
