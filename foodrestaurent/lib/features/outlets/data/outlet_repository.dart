import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';

/// One restaurant record under the signed-in owner account.
class OutletModel {
  const OutletModel({
    required this.id,
    required this.restaurantName,
    required this.status,
    required this.isActive,
    required this.area,
    required this.city,
  });

  factory OutletModel.fromJson(Map<String, dynamic> json) => OutletModel(
        id: (json['id'] ?? json['_id'] ?? '').toString(),
        restaurantName: (json['restaurantName'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        isActive: json['isActive'] != false,
        area: (json['area'] ?? '').toString(),
        city: (json['city'] ?? '').toString(),
      );

  final String id;
  final String restaurantName;
  final String status;
  final bool isActive;
  final String area;
  final String city;

  bool get isApproved => status == 'approved';
  bool get isOnboarding => status == 'onboarding';

  String get statusLabel {
    switch (status) {
      case 'approved':
        return 'Live';
      case 'pending':
        return 'Under review';
      case 'onboarding':
        return 'Onboarding pending';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  String get locationLabel =>
      [area, city].where((s) => s.trim().isNotEmpty).join(', ');
}

class OutletList {
  const OutletList({required this.activeOutletId, required this.outlets});

  const OutletList.empty() : activeOutletId = '', outlets = const [];

  final String activeOutletId;
  final List<OutletModel> outlets;

  bool get hasMultiple => outlets.length > 1;

  String nameOf(String outletId) {
    for (final o in outlets) {
      if (o.id == outletId) return o.restaurantName;
    }
    return '';
  }
}

class AddOutletFailure {
  const AddOutletFailure({required this.name, required this.message});
  final String name;
  final String message;
}

class AddOutletsResult {
  const AddOutletsResult({required this.created, required this.failed});
  final List<OutletModel> created;
  final List<AddOutletFailure> failed;
}

/// Tokens issued for another outlet of the same owner, as returned by
/// `POST /food/restaurant/outlets/switch`.
class OutletSession {
  const OutletSession({required this.accessToken, required this.refreshToken});
  final String accessToken;
  final String refreshToken;
}

/// Thin wrapper over the multi-outlet owner endpoints. The Dio client already
/// unwraps the `{success, data}` envelope, so every response here is the `data`
/// payload.
class OutletRepository {
  OutletRepository(this._dio);

  final Dio _dio;

  Future<OutletList> list() async {
    final response = await _dio.get('/food/restaurant/outlets');
    final data = Map<String, dynamic>.from(response.data as Map);
    final rows = (data['outlets'] as List? ?? [])
        .map((e) => OutletModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return OutletList(
      activeOutletId: (data['activeOutletId'] ?? '').toString(),
      outlets: rows,
    );
  }

  Future<OutletSession> switchTo(String outletId) async {
    final response = await _dio.post(
      '/food/restaurant/outlets/switch',
      data: {'outletId': outletId},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final access = data['accessToken']?.toString();
    final refresh = data['refreshToken']?.toString();
    if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
      throw StateError('Could not switch outlet');
    }
    return OutletSession(accessToken: access, refreshToken: refresh);
  }

  /// Creates one onboarding record per name. Each is reviewed by admin on its own.
  Future<AddOutletsResult> add(List<String> names) async {
    final response = await _dio.post(
      '/food/restaurant/outlets',
      data: {'outlets': names},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return AddOutletsResult(
      created: (data['created'] as List? ?? [])
          .map((e) => OutletModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      failed: (data['failed'] as List? ?? []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return AddOutletFailure(
          name: (m['name'] ?? '').toString(),
          message: (m['message'] ?? 'Could not create this outlet').toString(),
        );
      }).toList(),
    );
  }

  /// Registration token scoped to one outlet that is still being onboarded.
  Future<String> onboardingToken(String outletId) async {
    final response = await _dio.post(
      '/food/restaurant/outlets/$outletId/onboarding-token',
      data: const <String, dynamic>{},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['registrationToken']?.toString();
    if (token == null || token.isEmpty) {
      throw StateError('Could not open onboarding for this outlet');
    }
    return token;
  }
}

final outletRepositoryProvider = Provider<OutletRepository>((ref) {
  return OutletRepository(ref.watch(dioProvider));
});
