import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/finance/domain/finance_model.dart';
import 'package:food_user_application/features/finance/domain/subscription_invoice_model.dart';
import 'package:food_user_application/features/finance/domain/withdrawal_model.dart';

class FinanceRepository {
  FinanceRepository(this._dio);

  final Dio _dio;

  Future<FinanceModel> getFinance() async {
    final response = await _dio.get('/food/restaurant/finance');
    return FinanceModel.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<List<WithdrawalModel>> listWithdrawals() async {
    final response = await _dio.get('/food/restaurant/withdrawals');
    final list = (response.data as List? ?? []);
    return list
        .map(
          (e) => WithdrawalModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<void> requestWithdrawal({
    required double amount,
    required Map<String, String> bankDetails,
  }) async {
    await _dio.post(
      '/food/restaurant/withdraw',
      data: {'amount': amount, 'bankDetails': bankDetails},
    );
  }

  Future<List<SubscriptionInvoiceModel>> listSubscriptionInvoices() async {
    final response = await _dio.get('/food/restaurant/subscription/invoices');
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['invoices'] as List? ?? []);
    return list
        .map(
          (e) => SubscriptionInvoiceModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(dioProvider));
});
