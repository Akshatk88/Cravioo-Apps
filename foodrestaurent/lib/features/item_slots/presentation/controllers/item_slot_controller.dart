import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/item_slots/data/item_slot_repository.dart';
import 'package:food_user_application/features/item_slots/domain/item_slot_model.dart';

class ItemSlotController extends AsyncNotifier<List<ItemSlotModel>> {
  @override
  Future<List<ItemSlotModel>> build() {
    return ref.read(itemSlotRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(itemSlotRepositoryProvider).list(),
    );
  }

  Future<void> save({
    String? id,
    required String name,
    required String startTime,
    required String endTime,
  }) async {
    final repo = ref.read(itemSlotRepositoryProvider);
    if (id == null) {
      await repo.create(name: name, startTime: startTime, endTime: endTime);
    } else {
      await repo.update(id, name: name, startTime: startTime, endTime: endTime);
    }
    await refresh();
  }

  Future<int> delete(String id) async {
    final unlinked = await ref.read(itemSlotRepositoryProvider).delete(id);
    await refresh();
    return unlinked;
  }
}

final itemSlotControllerProvider =
    AsyncNotifierProvider<ItemSlotController, List<ItemSlotModel>>(
      ItemSlotController.new,
    );
