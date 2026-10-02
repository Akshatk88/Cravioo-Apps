import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/order_remote_datasource.dart';
import '../data/datasources/order_rtdb_datasource.dart';
import '../data/models/order_model.dart';
import 'network_providers.dart';

final orderRemoteDataSourceProvider = Provider<OrderRemoteDataSource>((ref) {
  return OrderRemoteDataSource(ref.watch(apiClientProvider));
});

/// Past (non-active) orders placed at a specific restaurant, most recent
/// first. `GET /food/orders` has no restaurantId filter, so this pulls a
/// page of the user's history and filters client-side — fine for the
/// "reorder from this restaurant" strip, which only needs a handful.
final restaurantPastOrdersProvider = FutureProvider.family<List<OrderModel>, String>((ref, restaurantId) async {
  final result = await ref.read(orderRemoteDataSourceProvider).getOrderModels(limit: 100);
  final matches = result.orders.where((o) => o.restaurantId == restaurantId && !o.isActive).toList()
    ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return matches.take(5).toList();
});

final orderRtdbDataSourceProvider = Provider<OrderRtdbDataSource>((ref) {
  return OrderRtdbDataSource();
});
