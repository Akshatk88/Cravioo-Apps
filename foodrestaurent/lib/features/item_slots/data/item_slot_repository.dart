import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/item_slots/domain/item_slot_model.dart';

class ItemSlotRepository {
  ItemSlotRepository(this._dio);

  final Dio _dio;

  Future<List<ItemSlotModel>> list() async {
    final response = await _dio.get('/food/restaurant/item-slot-timings');
    final raw = response.data;
    final data = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final slots = data['slots'];
    if (slots is! List) return [];
    final result = slots
        .whereType<Map>()
        .map((e) => ItemSlotModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    result.sort((a, b) => a.startTime.compareTo(b.startTime));
    return result;
  }

  Future<void> create({
    required String name,
    required String startTime,
    required String endTime,
  }) async {
    await _dio.post(
      '/food/restaurant/item-slot-timings',
      data: {'name': name, 'startTime': startTime, 'endTime': endTime},
    );
  }

  Future<void> update(
    String id, {
    required String name,
    required String startTime,
    required String endTime,
  }) async {
    await _dio.patch(
      '/food/restaurant/item-slot-timings/$id',
      data: {'name': name, 'startTime': startTime, 'endTime': endTime},
    );
  }

  /// Returns the number of menu items that were unlinked from the slot.
  Future<int> delete(String id) async {
    final response = await _dio.delete('/food/restaurant/item-slot-timings/$id');
    final raw = response.data;
    if (raw is Map) {
      return int.tryParse((raw['unlinkedItemCount'] ?? 0).toString()) ?? 0;
    }
    return 0;
  }
}

final itemSlotRepositoryProvider = Provider<ItemSlotRepository>((ref) {
  return ItemSlotRepository(ref.watch(dioProvider));
});
