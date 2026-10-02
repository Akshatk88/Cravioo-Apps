import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/support/domain/support_ticket_model.dart';

class SupportRepository {
  SupportRepository(this._dio);

  final Dio _dio;

  Future<List<SupportTicketModel>> list() async {
    final response = await _dio.get('/food/restaurant/support/tickets');
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['tickets'] as List? ?? []);
    return list
        .map(
          (e) =>
              SupportTicketModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<SupportTicketModel> create({
    required String category,
    required String issueType,
    String subject = '',
    String description = '',
    String orderRef = '',
    String priority = 'medium',
  }) async {
    final response = await _dio.post(
      '/food/restaurant/support/tickets',
      data: {
        'category': category,
        'issueType': issueType,
        'subject': subject,
        'description': description,
        'orderRef': orderRef,
        'priority': priority,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return SupportTicketModel.fromJson(
      Map<String, dynamic>.from(data['ticket'] as Map),
    );
  }
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(ref.watch(dioProvider));
});
