import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/offers/data/offer_repository.dart';
import 'package:food_user_application/features/offers/domain/offer_model.dart';

class OfferController extends AsyncNotifier<List<OfferModel>> {
  @override
  Future<List<OfferModel>> build() {
    return ref.read(offerRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(offerRepositoryProvider).list(),
    );
  }

  Future<void> create({
    required String couponCode,
    required String discountType,
    required double discountValue,
    double? minOrderValue,
    double? maxDiscount,
    int? usageLimit,
    int? perUserLimit,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await ref
        .read(offerRepositoryProvider)
        .create(
          couponCode: couponCode,
          discountType: discountType,
          discountValue: discountValue,
          minOrderValue: minOrderValue,
          maxDiscount: maxDiscount,
          usageLimit: usageLimit,
          perUserLimit: perUserLimit,
          startDate: startDate,
          endDate: endDate,
        );
    await refresh();
  }

  Future<void> toggleStatus(String id, bool makeActive) async {
    await ref
        .read(offerRepositoryProvider)
        .updateStatus(id, makeActive ? 'active' : 'inactive');
    await refresh();
  }

  Future<void> delete(String id) async {
    await ref.read(offerRepositoryProvider).delete(id);
    await refresh();
  }
}

final offerControllerProvider =
    AsyncNotifierProvider<OfferController, List<OfferModel>>(
      OfferController.new,
    );
