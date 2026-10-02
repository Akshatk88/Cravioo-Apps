import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/dining/domain/dining_booking_model.dart';
import 'package:food_user_application/features/dining/domain/dining_dashboard_model.dart';
import 'package:food_user_application/features/dining/domain/dining_profile_model.dart';
import 'package:food_user_application/features/dining/domain/dining_slot_model.dart';
import 'package:food_user_application/features/dining/domain/dining_table_model.dart';

class DiningProfileResponse {
  final DiningProfileModel? profile;
  final List<DiningCategoryOption> availableCategories;

  const DiningProfileResponse({
    this.profile,
    required this.availableCategories,
  });
}

class DiningRepository {
  DiningRepository(this._dio);
  final Dio _dio;

  Future<DiningProfileResponse> getMyProfile() async {
    DiningProfileModel? profile;
    List<DiningCategoryOption> catList = [];

    // 1. Fetch restaurant dining profile
    try {
      final response = await _dio.get('/food/restaurant/dining/profile');
      final data = Map<String, dynamic>.from(response.data as Map);
      final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;

      if (payload['profile'] != null) {
        profile = DiningProfileModel.fromJson(Map<String, dynamic>.from(payload['profile'] as Map));
      }

      final profileCats = (payload['availableCategories'] as List? ?? []);
      if (profileCats.isNotEmpty) {
        catList = profileCats
            .map((c) => DiningCategoryOption.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();
      }
    } catch (_) {}

    // 2. If categories are empty or not returned by restaurant endpoint, fetch directly from public categories endpoint
    if (catList.isEmpty) {
      try {
        final catRes = await _dio.get('/food/dining/categories');
        final catData = Map<String, dynamic>.from(catRes.data as Map);
        final items = (catData['items'] as List? ?? []);
        catList = items
            .map((c) => DiningCategoryOption.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList();
      } catch (_) {}
    }

    return DiningProfileResponse(
      profile: profile,
      availableCategories: catList,
    );
  }

  Future<DiningProfileModel> submitProfile(FormData formData) async {
    final response = await _dio.post(
      '/food/restaurant/dining/profile',
      data: formData,
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    return DiningProfileModel.fromJson(payload);
  }

  Future<DiningProfileModel> updateSettings(Map<String, dynamic> settings) async {
    final response = await _dio.patch('/food/restaurant/dining/settings', data: settings);
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    return DiningProfileModel.fromJson(payload);
  }

  Future<DiningDashboardModel> getDashboard() async {
    final response = await _dio.get('/food/restaurant/dining/dashboard');
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    return DiningDashboardModel.fromJson(payload);
  }

  // ----- Tables Management -----
  Future<Map<String, dynamic>> listTables() async {
    final response = await _dio.get('/food/restaurant/dining/tables');
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    final itemsRaw = payload['items'] as List? ?? [];
    final items = itemsRaw
        .whereType<Map>()
        .map((e) => DiningTableModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final summary = payload['summary'] != null
        ? DiningTableSummary.fromJson(Map<String, dynamic>.from(payload['summary'] as Map))
        : DiningTableSummary(tables: items.length, seats: items.fold(0, (sum, t) => sum + t.seats));
    return {'items': items, 'summary': summary};
  }

  Future<DiningTableModel> createTable(Map<String, dynamic> body) async {
    final response = await _dio.post('/food/restaurant/dining/tables', data: body);
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    return DiningTableModel.fromJson(payload);
  }

  Future<DiningTableModel> updateTable(String id, Map<String, dynamic> body) async {
    final response = await _dio.patch('/food/restaurant/dining/tables/$id', data: body);
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    return DiningTableModel.fromJson(payload);
  }

  Future<void> deleteTable(String id) async {
    await _dio.delete('/food/restaurant/dining/tables/$id');
  }

  // ----- Slots & Availability -----
  Future<Map<String, dynamic>> getSlots() async {
    final response = await _dio.get('/food/restaurant/dining/slots');
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    final daysRaw = payload['days'] as List? ?? [];
    final days = daysRaw
        .whereType<Map>()
        .map((e) => DiningDaySlotsModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final blockedRaw = payload['blockedDates'] as List? ?? [];
    final blockedDates = blockedRaw
        .whereType<Map>()
        .map((e) => DiningBlockedDateModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return {'days': days, 'blockedDates': blockedDates};
  }

  Future<List<DiningDaySlotsModel>> saveSlots(List<Map<String, dynamic>> days) async {
    final response = await _dio.put('/food/restaurant/dining/slots', data: {'days': days});
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    final daysRaw = payload['days'] as List? ?? [];
    return daysRaw
        .whereType<Map>()
        .map((e) => DiningDaySlotsModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<DiningBlockedDateModel> addBlockedDate(String date, String reason) async {
    final response = await _dio.post('/food/restaurant/dining/blocked-dates', data: {
      'date': date,
      'reason': reason,
    });
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    return DiningBlockedDateModel.fromJson(payload);
  }

  Future<void> removeBlockedDate(String id) async {
    await _dio.delete('/food/restaurant/dining/blocked-dates/$id');
  }

  // ----- Bookings -----
  Future<List<DiningBookingModel>> listBookings({
    String status = 'all',
    String? date,
    String? search,
  }) async {
    try {
      final response = await _dio.get(
        '/food/restaurant/dining/bookings',
        queryParameters: {
          if (status.isNotEmpty && status != 'all') 'status': status,
          if (date != null && date.isNotEmpty) 'date': date,
          if (search != null && search.isNotEmpty) 'search': search,
          'limit': 100,
        },
      );
      final raw = response.data;
      List rawList = [];
      if (raw is List) {
        rawList = raw;
      } else if (raw is Map) {
        if (raw['items'] is List) {
          rawList = raw['items'] as List;
        } else if (raw['data'] is Map && raw['data']['items'] is List) {
          rawList = raw['data']['items'] as List;
        } else if (raw['data'] is List) {
          rawList = raw['data'] as List;
        }
      }
      return rawList
          .whereType<Map>()
          .map((e) {
            try {
              return DiningBookingModel.fromJson(Map<String, dynamic>.from(e));
            } catch (_) {
              return null;
            }
          })
          .whereType<DiningBookingModel>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<DiningBookingModel> getBookingById(String id) async {
    final response = await _dio.get('/food/restaurant/dining/bookings/$id');
    final data = Map<String, dynamic>.from(response.data as Map);
    final payload = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
    return DiningBookingModel.fromJson(payload);
  }

  Future<void> updateBookingStatus(
    String id,
    String status, {
    String? note,
    List<String>? tableIds,
  }) async {
    await _dio.patch(
      '/food/restaurant/dining/bookings/$id/status',
      data: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
        if (tableIds != null && tableIds.isNotEmpty) 'tableIds': tableIds,
      },
    );
  }
}

final diningRepositoryProvider = Provider<DiningRepository>((ref) {
  return DiningRepository(ref.watch(dioProvider));
});

