import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/addons/data/addon_repository.dart';
import 'package:food_user_application/features/addons/domain/addon_model.dart';

class AddonController extends AsyncNotifier<List<AddonModel>> {
  @override
  Future<List<AddonModel>> build() {
    return ref.read(addonRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(addonRepositoryProvider).list(),
    );
  }

  Future<void> create({
    required String name,
    required String foodType,
    String description = '',
    required double price,
    String image = '',
  }) async {
    await ref
        .read(addonRepositoryProvider)
        .create(
          name: name,
          foodType: foodType,
          description: description,
          price: price,
          image: image,
        );
    await refresh();
  }

  Future<void> updateAddon(
    String id, {
    String? name,
    String? foodType,
    String? description,
    double? price,
    String? image,
    bool? isAvailable,
  }) async {
    await ref
        .read(addonRepositoryProvider)
        .update(
          id,
          name: name,
          foodType: foodType,
          description: description,
          price: price,
          image: image,
          isAvailable: isAvailable,
        );
    await refresh();
  }

  Future<void> toggleAvailability(String id, bool isAvailable) async {
    final current = state.value;
    if (current != null) {
      state = AsyncValue.data([
        for (final addon in current)
          if (addon.id == id)
            AddonModel(
              id: addon.id,
              name: addon.name,
              description: addon.description,
              foodType: addon.foodType,
              price: addon.price,
              image: addon.image,
              isAvailable: isAvailable,
              approvalStatus: addon.approvalStatus,
              rejectionReason: addon.rejectionReason,
            )
          else
            addon,
      ]);
    }
    try {
      await ref
          .read(addonRepositoryProvider)
          .update(id, isAvailable: isAvailable);
    } catch (_) {
      await refresh();
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    await ref.read(addonRepositoryProvider).delete(id);
    await refresh();
  }
}

final addonControllerProvider =
    AsyncNotifierProvider<AddonController, List<AddonModel>>(
      AddonController.new,
    );
