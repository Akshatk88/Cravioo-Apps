import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/finance/data/finance_repository.dart';
import 'package:food_user_application/features/finance/domain/finance_model.dart';
import 'package:food_user_application/features/finance/domain/subscription_invoice_model.dart';
import 'package:food_user_application/features/finance/domain/withdrawal_model.dart';

class FinanceController extends AsyncNotifier<FinanceModel> {
  @override
  Future<FinanceModel> build() {
    return ref.read(financeRepositoryProvider).getFinance();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(financeRepositoryProvider).getFinance(),
    );
  }
}

final financeControllerProvider =
    AsyncNotifierProvider<FinanceController, FinanceModel>(
      FinanceController.new,
    );

class WithdrawalsController extends AsyncNotifier<List<WithdrawalModel>> {
  @override
  Future<List<WithdrawalModel>> build() {
    return ref.read(financeRepositoryProvider).listWithdrawals();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(financeRepositoryProvider).listWithdrawals(),
    );
  }

  Future<void> requestWithdrawal({
    required double amount,
    required Map<String, String> bankDetails,
  }) async {
    await ref
        .read(financeRepositoryProvider)
        .requestWithdrawal(amount: amount, bankDetails: bankDetails);
    await refresh();
    await ref.read(financeControllerProvider.notifier).refresh();
  }
}

final withdrawalsControllerProvider =
    AsyncNotifierProvider<WithdrawalsController, List<WithdrawalModel>>(
      WithdrawalsController.new,
    );

class SubscriptionInvoicesController
    extends AsyncNotifier<List<SubscriptionInvoiceModel>> {
  @override
  Future<List<SubscriptionInvoiceModel>> build() {
    return ref.read(financeRepositoryProvider).listSubscriptionInvoices();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(financeRepositoryProvider).listSubscriptionInvoices(),
    );
  }
}

final subscriptionInvoicesControllerProvider =
    AsyncNotifierProvider<
      SubscriptionInvoicesController,
      List<SubscriptionInvoiceModel>
    >(SubscriptionInvoicesController.new);
