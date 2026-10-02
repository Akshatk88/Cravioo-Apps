import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/zones/domain/zone_model.dart';

/// Zones are admin-managed; restaurants can only view active zone boundaries
/// to make sure their pin lands inside one — see `/food/zones/public`.
class ZoneRepository {
  ZoneRepository(this._dio);

  final Dio _dio;

  Future<List<ZoneModel>> listActiveZones() async {
    final response = await _dio.get('/food/zones/public');
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['zones'] as List? ?? []);
    return list
        .map((e) => ZoneModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final zoneRepositoryProvider = Provider<ZoneRepository>((ref) {
  return ZoneRepository(ref.watch(dioProvider));
});

final activeZonesProvider = FutureProvider<List<ZoneModel>>((ref) {
  return ref.read(zoneRepositoryProvider).listActiveZones();
});
