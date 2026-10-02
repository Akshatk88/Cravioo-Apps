import '../../domain/repository/wallet_repository.dart';
import '../datasources/account_remote_datasource.dart';
import '../models/wallet_model.dart';

class WalletRepositoryImpl implements WalletRepository {
  final AccountRemoteDataSource _remoteDataSource;

  const WalletRepositoryImpl(this._remoteDataSource);

  @override
  Future<WalletModel> getWallet() async {
    return await _remoteDataSource.getWallet();
  }

  @override
  Future<Map<String, dynamic>> createTopupOrder(double amount) async {
    return await _remoteDataSource.createTopupOrder(amount);
  }

  @override
  Future<WalletModel> verifyTopup({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required double amount,
  }) async {
    return await _remoteDataSource.verifyTopup(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
      amount: amount,
    );
  }

  @override
  Future<CashbackHistory> getCashbackHistory() => _remoteDataSource.getCashbackHistory();

  @override
  Future<RefundHistory> getRefundHistory() => _remoteDataSource.getRefundHistory();

  @override
  Future<CashbackSettings> getCashbackSettings() => _remoteDataSource.getCashbackSettings();

  @override
  Future<PayLaterAccount> getPayLaterAccount() => _remoteDataSource.getPayLaterAccount();

  @override
  Future<PayLaterAccount> repayPayLaterFromWallet() => _remoteDataSource.repayPayLaterFromWallet();

  @override
  Future<Map<String, dynamic>> startPayLaterRazorpayRepayment() =>
      _remoteDataSource.startPayLaterRazorpayRepayment();

  @override
  Future<PayLaterAccount> verifyPayLaterRazorpayRepayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) =>
      _remoteDataSource.verifyPayLaterRazorpayRepayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
        razorpaySignature: razorpaySignature,
      );
}
