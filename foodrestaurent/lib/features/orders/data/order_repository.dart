import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';

class OrderListPage {
  OrderListPage({
    required this.orders,
    required this.total,
    required this.totalPages,
  });
  final List<OrderModel> orders;
  final int total;
  final int totalPages;
}

class OrderRepository {
  OrderRepository(this._dio);

  final Dio _dio;

  Future<OrderListPage> list({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final response = await _dio.get(
      '/food/restaurant/orders',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['data'] as List? ?? []);
    final meta = Map<String, dynamic>.from((data['meta'] ?? {}) as Map);
    return OrderListPage(
      orders: list
          .map((e) => OrderModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total: (meta['total'] is num)
          ? (meta['total'] as num).toInt()
          : list.length,
      totalPages: (meta['totalPages'] is num)
          ? (meta['totalPages'] as num).toInt()
          : 1,
    );
  }

  /// Live/current orders view — a generous single page covering everything
  /// the Orders screen buckets into its 7 tabs (client-side, see
  /// [OrderModel.restaurantBucket]).
  Future<List<OrderModel>> listCurrent({int limit = 100}) async {
    final page = await list(page: 1, limit: limit);
    return page.orders;
  }

  Future<OrderModel> getById(String orderId) async {
    final response = await _dio.get('/food/restaurant/orders/$orderId');
    final raw = response.data;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final orderMap = (map['order'] is Map)
          ? Map<String, dynamic>.from(map['order'] as Map)
          : map;
      return OrderModel.fromJson(orderMap);
    }
    throw ApiException('Invalid order response format');
  }

  Future<OrderModel> updateStatus(
    String orderId,
    String orderStatus, {
    String? note,
  }) async {
    final response = await _dio.patch(
      '/food/restaurant/orders/$orderId/status',
      data: {
        'orderStatus': orderStatus,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    final raw = response.data;
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      final orderMap = (map['order'] is Map)
          ? Map<String, dynamic>.from(map['order'] as Map)
          : map;
      return OrderModel.fromJson(orderMap);
    }
    throw ApiException('Invalid update order response format');
  }

  Future<void> resendNotification(String orderId) async {
    await _dio.post('/food/restaurant/orders/$orderId/resend-notification');
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(dioProvider));
});
