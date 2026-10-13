import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/wallet/data/wallet_repository.dart';
import 'package:food_user_application/features/wallet/domain/withdrawal_record_model.dart';

class WithdrawalHistoryController
    extends AsyncNotifier<List<WithdrawalRecord>> {
  @override
  Future<List<WithdrawalRecord>> build() {
    return ref.read(walletRepositoryProvider).listWithdrawals();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(walletRepositoryProvider).listWithdrawals(),
    );
  }

  /// Throws on failure so the UI can show the message.
  Future<void> cancel(String id) async {
    await ref.read(walletRepositoryProvider).cancelWithdrawal(id);
    state = await AsyncValue.guard(
      () => ref.read(walletRepositoryProvider).listWithdrawals(),
    );
  }
}

final withdrawalHistoryControllerProvider =
    AsyncNotifierProvider<WithdrawalHistoryController, List<WithdrawalRecord>>(
      WithdrawalHistoryController.new,
    );
