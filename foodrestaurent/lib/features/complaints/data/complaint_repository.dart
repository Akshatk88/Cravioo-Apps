import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/complaints/domain/complaint_model.dart';

class ComplaintRepository {
  ComplaintRepository(this._dio);

  final Dio _dio;

  Future<List<ComplaintModel>> list() async {
    final response = await _dio.get('/food/restaurant/complaints');
    final data = Map<String, dynamic>.from(response.data as Map);
    final list = (data['complaints'] as List? ?? []);
    return list
        .map(
          (e) => ComplaintModel.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }
}

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  return ComplaintRepository(ref.watch(dioProvider));
});
