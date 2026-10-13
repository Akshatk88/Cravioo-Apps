import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/referral/data/referral_repository.dart';
import 'package:food_user_application/features/referral/domain/referral_model.dart';

class ReferralController extends AsyncNotifier<ReferralData> {
  @override
  Future<ReferralData> build() {
    return ref.read(referralRepositoryProvider).load();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(referralRepositoryProvider).load(),
    );
  }
}

final referralControllerProvider =
    AsyncNotifierProvider<ReferralController, ReferralData>(
      ReferralController.new,
    );
