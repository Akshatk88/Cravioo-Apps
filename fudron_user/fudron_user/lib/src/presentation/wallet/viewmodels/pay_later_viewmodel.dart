import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/wallet_model.dart';
import '../../../di/wallet_providers.dart';
import 'wallet_viewmodel.dart';

enum PayLaterStatus { initial, loading, success, error }

class PayLaterState {
  final PayLaterStatus status;
  final PayLaterAccount account;
  final String? errorMessage;

  const PayLaterState({
    this.status = PayLaterStatus.initial,
    this.account = const PayLaterAccount(),
    this.errorMessage,
  });

  PayLaterState copyWith({
    PayLaterStatus? status,
    PayLaterAccount? account,
    String? errorMessage,
  }) {
    return PayLaterState(
      status: status ?? this.status,
      account: account ?? this.account,
      errorMessage: errorMessage,
    );
  }
}

final payLaterViewModelProvider = NotifierProvider<PayLaterViewModel, PayLaterState>(
  () => PayLaterViewModel(),
);

class PayLaterViewModel extends Notifier<PayLaterState> {
  @override
  PayLaterState build() {
    unawaited(refresh());
    return const PayLaterState(status: PayLaterStatus.loading);
  }

  Future<void> refresh() async {
    state = state.copyWith(status: PayLaterStatus.loading, errorMessage: null);
    try {
      final account = await ref.read(walletServiceProvider).fetchPayLaterAccount();
      state = state.copyWith(status: PayLaterStatus.success, account: account);
    } catch (e) {
      state = state.copyWith(status: PayLaterStatus.error, errorMessage: 'Could not load Pay Later details.');
    }
  }

  Future<String?> repayFromWallet() async {
    try {
      final account = await ref.read(walletServiceProvider).repayPayLaterFromWallet();
      state = state.copyWith(status: PayLaterStatus.success, account: account);
      // The wallet balance the repayment was drawn from just changed too.
      unawaited(ref.read(walletViewModelProvider.notifier).loadWallet(isRefresh: true));
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Opens the order for a repayment; [PaymentGateway.repayPayLater] does the
  /// actual sheet + verification, then this refreshes the account afterward.
  Future<Map<String, dynamic>?> startRazorpayRepayment() async {
    try {
      return await ref.read(walletServiceProvider).startPayLaterRazorpayRepayment();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString().replaceFirst('Exception: ', ''));
      return null;
    }
  }
}
