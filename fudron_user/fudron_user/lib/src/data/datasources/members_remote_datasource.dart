import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/member_model.dart';

class MembersRemoteDataSource {
  final ApiClient _client;
  static const Duration _cacheTtl = Duration(minutes: 2);

  MembersRemoteDataSource(this._client);

  Future<MembersLeaderboardResponse> getMembersLeaderboard({
    String? search,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      };

      // Try authenticated endpoint first (for personal rank), then fallback to public
      Map<String, dynamic>? res;
      try {
        res = await _client.get<Map<String, dynamic>>(
          ApiPaths.userMembersLeaderboard,
          query: query,
          auth: true,
          cacheTtl: _cacheTtl,
        );
      } catch (_) {
        res = await _client.get<Map<String, dynamic>>(
          ApiPaths.membersLeaderboard,
          query: query,
          auth: false,
          cacheTtl: _cacheTtl,
        );
      }

      final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
      return MembersLeaderboardResponse.fromApi(data);
    } catch (e) {
      // Re-throw so ViewModel can handle and display true state without fake data
      rethrow;
    }
  }

  /// Fetches mutual contacts who downloaded Cravioo and ranks them by orders
  Future<MembersLeaderboardResponse> getMutualContactsLeaderboard({String? search}) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        ApiPaths.contactsMutual,
        auth: true,
        cacheTtl: const Duration(seconds: 30),
      );

      final data = res['data'] is Map ? res['data'] as Map<String, dynamic> : res;
      var response = MembersLeaderboardResponse.fromApi(data);

      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        final filtered = response.members
            .where((m) => m.name.toLowerCase().contains(q))
            .toList();
        response = MembersLeaderboardResponse(
          totalMembers: response.totalMembers,
          topPodium: response.topPodium,
          myRank: response.myRank,
          members: filtered,
          isContactsSynced: response.isContactsSynced,
          contactPermissionStatus: response.contactPermissionStatus,
        );
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sends a batch chunk of phone contacts to the server
  Future<bool> importContacts(List<Map<String, String>> contacts, bool isLastChunk) async {
    try {
      await _client.post<Map<String, dynamic>>(
        ApiPaths.contactsImport,
        body: {
          'contacts': contacts,
          'isLastChunk': isLastChunk,
        },
        auth: true,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Updates contact permission status on the server ('DENIED' | 'SKIPPED')
  Future<void> updatePermissionStatus(String status) async {
    try {
      await _client.patch<Map<String, dynamic>>(
        ApiPaths.contactsPermissionStatus,
        body: {'status': status},
        auth: true,
      );
    } catch (_) {}
  }
}
