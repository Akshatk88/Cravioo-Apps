import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/finance/domain/finance_model.dart';
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
    // The server answers {withdrawals: [...], total, page}; this used to assume a
    // bare list, so the payouts screen's withdrawal list came back empty/failed.
    final raw = response.data;
    final list = raw is Map
        ? (raw['withdrawals'] as List? ?? const [])
        : (raw as List? ?? const []);
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
}

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(ref.watch(dioProvider));
});
