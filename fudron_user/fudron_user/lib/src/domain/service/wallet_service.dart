import '../repository/wallet_repository.dart';
import '../../data/models/wallet_model.dart';

class WalletService {
  final WalletRepository _repository;

  const WalletService(this._repository);

  /// A wallet with no top-ups/cashback yet legitimately has zero balance and
  /// no transactions — that's real data, not a loading/error state, so it's
  /// returned as-is rather than papered over with sample rows.
  Future<WalletModel> fetchWalletData() => _repository.getWallet();

  Future<CashbackHistory> fetchCashbackHistory() => _repository.getCashbackHistory();

  Future<RefundHistory> fetchRefundHistory() => _repository.getRefundHistory();

  Future<CashbackSettings> fetchCashbackSettings() => _repository.getCashbackSettings();

  /// Business validation for top up amount.
  bool isValidTopupAmount(double amount) {
    return amount >= 10 && amount <= 10000;
  }

  Future<PayLaterAccount> fetchPayLaterAccount() => _repository.getPayLaterAccount();

  Future<PayLaterAccount> repayPayLaterFromWallet() => _repository.repayPayLaterFromWallet();

  Future<Map<String, dynamic>> startPayLaterRazorpayRepayment() =>
      _repository.startPayLaterRazorpayRepayment();

  Future<PayLaterAccount> verifyPayLaterRazorpayRepayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) =>
      _repository.verifyPayLaterRazorpayRepayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );
}
