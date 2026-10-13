import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/wallet/domain/withdrawal_record_model.dart';

class WalletRepository {
  WalletRepository(this._dio);

  final Dio _dio;

  /// GET /food/restaurant/withdrawals -> { withdrawals: [...], total, page, ... }
  Future<List<WithdrawalRecord>> listWithdrawals({
    int page = 1,
    int limit = 100,
  }) async {
    final response = await _dio.get(
      '/food/restaurant/withdrawals',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data;
    final List raw = data is List
        ? data
        : (data is Map && data['withdrawals'] is List
              ? data['withdrawals'] as List
              : const []);
    return raw
        .whereType<Map>()
        .map((e) => WithdrawalRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// POST /food/restaurant/withdrawals/:id/cancel (pending only)
  Future<void> cancelWithdrawal(String id) async {
    await _dio.post('/food/restaurant/withdrawals/$id/cancel', data: {});
  }
}

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(dioProvider));
});
