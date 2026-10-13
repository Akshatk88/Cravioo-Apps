import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/reports/domain/tax_report_model.dart';

class TaxReportRepository {
  TaxReportRepository(this._dio);

  final Dio _dio;

  /// GET /food/restaurant/orders/tax-report?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD
  /// Both params optional (omitted = all time).
  Future<TaxReportModel> getMyTaxesReport({
    String? startDate,
    String? endDate,
  }) async {
    final params = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) {
      params['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) params['endDate'] = endDate;
    final response = await _dio.get(
      '/food/restaurant/orders/tax-report',
      queryParameters: params,
    );
    final data = response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
    return TaxReportModel.fromJson(data);
  }

  /// GET /food/restaurant/orders/tax-report/shared
  Future<List<SharedTaxReport>> listSharedReports() async {
    final response = await _dio.get('/food/restaurant/orders/tax-report/shared');
    final raw = response.data is List ? response.data as List : const [];
    return raw
        .whereType<Map>()
        .map((e) => SharedTaxReport.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

final taxReportRepositoryProvider = Provider<TaxReportRepository>((ref) {
  return TaxReportRepository(ref.watch(dioProvider));
});
