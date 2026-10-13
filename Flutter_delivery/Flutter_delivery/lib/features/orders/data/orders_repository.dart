import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/delivery_order.dart';

class OrdersRepository {
  OrdersRepository(this._dio);

  final Dio _dio;

  Future<Result<List<DeliveryOrder>, AppError>> getAvailableOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.ordersAvailable,
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = res.data['data'];
      final list = (data is Map<String, dynamic> ? data['data'] : data)
          as List<dynamic>?;
      final orders = (list ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DeliveryOrder.fromJson)
          .toList();
      return Result.success(orders);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder?, AppError>> getCurrentOrder() async {
    final result = await getActiveOrders();
    return result.when(
      success: (r) => Result.success(r.current),
      failure: (e) => Result.failure(e),
    );
  }

  /// GET /orders/current: `activeOrder` (most recently updated trip) plus
  /// `activeOrders`, every order the partner holds — more than one only for a
  /// partner whose admin-set maxConcurrentOrders is above 1.
  Future<Result<({DeliveryOrder? current, List<DeliveryOrder> all}), AppError>>
      getActiveOrders() async {
    try {
      final res = await _dio.get(ApiEndpoints.ordersCurrent);
      final data = res.data['data'] as Map<String, dynamic>?;
      final activeOrder = data?['activeOrder'];
      final current = activeOrder is Map<String, dynamic>
          ? DeliveryOrder.fromJson(activeOrder)
          : null;
      final list = (data?['activeOrders'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(DeliveryOrder.fromJson)
          .toList();
      // Older backends send only activeOrder.
      if (list.isEmpty && current != null) list.add(current);
      return Result.success((current: current, all: list));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> getOrderDetails(
    String orderId,
  ) async {
    try {
      final res = await _dio.get(ApiEndpoints.orderDetails(orderId));
      final data = res.data['data'] as Map<String, dynamic>;
      final order = data['order'] ?? data;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> accept(String orderId) =>
      _patchOrder(ApiEndpoints.orderAccept(orderId));

  Future<Result<DeliveryOrder, AppError>> reject(String orderId) =>
      _patchOrder(ApiEndpoints.orderReject(orderId));

  Future<Result<DeliveryOrder, AppError>> reachedPickup(String orderId) =>
      _patchOrder(ApiEndpoints.orderReachedPickup(orderId));

  Future<Result<DeliveryOrder, AppError>> confirmPickup(
    String orderId, {
    String? billImageUrl,
  }) => _patchOrder(
    ApiEndpoints.orderConfirmPickup(orderId),
    data: billImageUrl != null ? {'billImageUrl': billImageUrl} : null,
  );

  Future<Result<DeliveryOrder, AppError>> reachedDrop(String orderId) =>
      _patchOrder(ApiEndpoints.orderReachedDrop(orderId));

  Future<Result<DeliveryOrder, AppError>> verifyDropOtp(
    String orderId,
    String otp,
  ) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.orderVerifyDropOtp(orderId),
        data: {'otp': otp},
      );
      final data = res.data['data'] as Map<String, dynamic>;
      final order = data['order'] ?? data;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// [paymentMode] `'cash'` tells the backend the rider collected cash for a
  /// COD order (completeDelivery marks it paid and records the method).
  Future<Result<DeliveryOrder, AppError>> complete(
    String orderId, {
    String? paymentMode,
  }) => _patchOrder(
    ApiEndpoints.orderComplete(orderId),
    data: paymentMode != null ? {'paymentMode': paymentMode} : null,
  );

  Future<Result<Map<String, dynamic>, AppError>> collectQr(
    String orderId, {
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.collectQr(orderId),
        data: {
          'name': ?name,
          'email': ?email,
          'phone': ?phone,
        },
      );
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<Map<String, dynamic>, AppError>> paymentStatus(
    String orderId,
  ) async {
    try {
      final res = await _dio.get(ApiEndpoints.paymentStatus(orderId));
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Set once the backend answers 404 for the route endpoint, so the app stops
  /// re-requesting a route that does not exist (it used to retry every 30 s
  /// and on every GPS fix while the polyline was empty).
  static bool _routeEndpointMissing = false;

  /// Road route from the rider to [target]. Never fails: when the backend has
  /// no route (GET /orders/:id/route is not implemented server-side — 404) or
  /// the call errors, it returns an empty polyline and the map screens draw a
  /// straight line to the destination instead.
  Future<Result<Map<String, dynamic>, AppError>> getRoute(
    String orderId, {
    required double lat,
    required double lng,
    required String target,
  }) async {
    const fallback = <String, dynamic>{'polyline': '', 'fallback': true};
    if (_routeEndpointMissing) return const Result.success(fallback);
    try {
      final res = await _dio.get(
        ApiEndpoints.orderRoute(orderId),
        queryParameters: {'lat': lat, 'lng': lng, 'target': target},
      );
      final data = res.data is Map ? res.data['data'] : null;
      return Result.success(data is Map<String, dynamic> ? data : fallback);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) _routeEndpointMissing = true;
      return const Result.success(fallback);
    } catch (_) {
      return const Result.success(fallback);
    }
  }

  /// Records that the rider collected cash for a COD order.
  ///
  /// The backend has no `POST /orders/:id/collect/cash` (only collect/qr), so
  /// this no longer calls it (it always 404'd). Cash collection is confirmed
  /// server-side by `PATCH /orders/:id/complete` with `{paymentMode: 'cash'}`,
  /// which marks a COD order paid — see [complete].
  Future<Result<bool, AppError>> collectCash(String orderId) async {
    return const Result.success(true);
  }

  Future<Result<bool, AppError>> rateCustomer(
    String orderId, {
    required int rating,
    String? comment,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.orderRateCustomer(orderId),
        data: {
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      return Result.success(res.data['success'] as bool? ?? true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 405 ||
          e.response?.statusCode == 501) {
        // Backend doesn't support customer rating from driver - treat gracefully as success
        return const Result.success(true);
      }
      return Result.failure(_mapError(e));
    } catch (_) {
      return const Result.success(true);
    }
  }

  Future<Result<DeliveryOrder, AppError>> _patchOrder(
    String path, {
    Object? data,
  }) async {
    try {
      final res = await _dio.patch(path, data: data);
      final body = res.data['data'] as Map<String, dynamic>;
      final order = body['order'] ?? body;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  AppError _mapError(DioException e) {
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'] as String? ??
          responseData['error'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        return NetworkError(message);
      }
    }
    if (e.response?.statusCode == 404) {
      return NetworkError('Not found');
    }
    return NetworkError('Something went wrong. Please try again.');
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.read(dioProvider));
});
