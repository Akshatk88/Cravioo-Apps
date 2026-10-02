import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/notifications/domain/notification_model.dart';

class NotificationInboxPage {
  NotificationInboxPage({
    required this.items,
    required this.total,
    required this.totalPages,
    required this.unreadCount,
  });

  final List<NotificationModel> items;
  final int total;
  final int totalPages;
  final int unreadCount;
}

class NotificationRepository {
  NotificationRepository(this._dio);

  final Dio _dio;

  Future<NotificationInboxPage> getInbox({int page = 1, int limit = 50}) async {
    final response = await _dio.get(
      '/food/notifications/inbox',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final items = (data['items'] as List? ?? [])
        .map(
          (e) =>
              NotificationModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
    final pagination = Map<String, dynamic>.from(
      (data['pagination'] ?? {}) as Map,
    );
    return NotificationInboxPage(
      items: items,
      total: (pagination['total'] is num)
          ? (pagination['total'] as num).toInt()
          : items.length,
      totalPages: (pagination['totalPages'] is num)
          ? (pagination['totalPages'] as num).toInt()
          : 1,
      unreadCount: (data['unreadCount'] is num)
          ? (data['unreadCount'] as num).toInt()
          : 0,
    );
  }

  Future<void> markRead(String id) async {
    await _dio.patch('/food/notifications/$id/read');
  }

  Future<void> dismiss(String id) async {
    await _dio.delete('/food/notifications/$id');
  }

  Future<void> dismissAll() async {
    await _dio.delete('/food/notifications/inbox/all');
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(dioProvider));
});
