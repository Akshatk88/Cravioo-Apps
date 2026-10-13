import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/chat_conversation.dart';
import 'models/chat_message.dart';

class ChatRepository {
  ChatRepository(this._dio);

  final Dio _dio;

  /// Opens (or creates) the order's conversation with the customer.
  /// Backend: GET /food/chat/conversations/open?orderId= → {conversationId}.
  Future<Result<String, AppError>> openConversation(String orderId) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.chatConversationOpen,
        queryParameters: {'orderId': orderId},
      );
      final body = res.data['data'] as Map<String, dynamic>? ?? const {};
      final id = body['conversationId']?.toString() ?? '';
      if (id.isEmpty) return Result.failure(NetworkError('Could not open chat'));
      return Result.success(id);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Backend: POST /food/chat/messages {conversationId, text}; answers the
  /// message itself as `data`.
  Future<Result<ChatMessage, AppError>> sendMessage({
    required String conversationId,
    required String text,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.chatMessages,
        data: {'conversationId': conversationId, 'text': text},
      );
      final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
      final message = (body['message'] is Map<String, dynamic>)
          ? body['message'] as Map<String, dynamic>
          : body;
      return Result.success(ChatMessage.fromJson(message));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<List<ChatConversation>, AppError>> getConversations() async {
    try {
      final res = await _dio.get(ApiEndpoints.chatConversations);
      final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
      final list = body['conversations'] as List<dynamic>? ?? [];
      return Result.success(
        list.whereType<Map<String, dynamic>>().map(ChatConversation.fromJson).toList(),
      );
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<ChatHistoryPage, AppError>> getMessages({
    required String conversationId,
    int page = 1,
    int limit = 30,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.chatMessages,
        queryParameters: {
          'conversationId': conversationId,
          'page': page,
          'limit': limit,
        },
      );
      final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
      final list = body['messages'] as List<dynamic>? ?? [];
      final pagination = body['pagination'] as Map<String, dynamic>? ?? {};
      return Result.success(
        ChatHistoryPage(
          messages: list.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList(),
          page: (pagination['page'] as num?)?.toInt() ?? page,
          totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<int, AppError>> markRead(String conversationId) async {
    try {
      final res = await _dio.patch(ApiEndpoints.chatConversationRead(conversationId));
      final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
      return Result.success((body['updated'] as num?)?.toInt() ?? 0);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  AppError _mapError(DioException e) {
    final responseData = e.response?.data;
    final message = responseData is Map<String, dynamic>
        ? (responseData['message'] as String? ??
              responseData['error'] as String? ??
              e.message ??
              'Something went wrong')
        : (e.message ?? 'Something went wrong');
    return NetworkError(message);
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.read(dioProvider));
});
