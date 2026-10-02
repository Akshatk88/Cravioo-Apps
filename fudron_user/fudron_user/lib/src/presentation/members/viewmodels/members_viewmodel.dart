import 'dart:async';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/members_remote_datasource.dart';
import '../../../data/models/member_model.dart';
import '../../../di/members_providers.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import 'members_state.dart';

final membersViewModelProvider =
    NotifierProvider<MembersViewModel, MembersState>(() {
  return MembersViewModel();
});

class MembersViewModel extends Notifier<MembersState> {
  late final MembersRemoteDataSource _dataSource;
  Timer? _debounceTimer;

  @override
  MembersState build() {
    _dataSource = ref.watch(membersRemoteDataSourceProvider);
    ref.listen(authViewModelProvider, (previous, next) {
      if (previous?.value?.id != next.value?.id) {
        loadMembers(isRefresh: true);
      }
    });
    Future.microtask(() => loadMembers());
    return const MembersState(isLoading: true);
  }

  Future<void> loadMembers({String? query, bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isRefreshing: true, errorMessage: null);
    } else {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }

    try {
      final effectiveQuery = query ?? state.searchQuery;

      // Fetch mutual contacts leaderboard from backend /contacts/mutual
      MembersLeaderboardResponse? mutualRes;
      try {
        mutualRes = await _dataSource.getMutualContactsLeaderboard(
          search: effectiveQuery,
        );
      } catch (_) {}

      final isSynced = mutualRes?.isContactsSynced ?? false;
      final permStatus = mutualRes?.contactPermissionStatus ?? 'PENDING';
      
      // Top 10 maximum members sorted strictly by orders descending
      final rawList = List<MemberModel>.from(mutualRes?.members ?? const []);
      rawList.sort((a, b) => b.orderCount.compareTo(a.orderCount));
      final top10Members = <MemberModel>[];
      for (var i = 0; i < rawList.length && i < 10; i++) {
        final m = rawList[i];
        top10Members.add(MemberModel(
          id: m.id,
          userId: m.userId,
          name: m.name,
          profileImage: m.profileImage,
          orderCount: m.orderCount,
          rank: i + 1,
          badge: m.badge,
          joinedAt: m.joinedAt,
          isCurrentUser: m.isCurrentUser,
        ));
      }
      final topPodium = top10Members.take(3).toList();

      MemberModel? resolvedMyRank = mutualRes?.myRank;
      final currentInTop = top10Members.where((m) => m.isCurrentUser).firstOrNull;
      if (currentInTop != null) {
        resolvedMyRank = currentInTop;
      }

      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        searchQuery: effectiveQuery,
        totalMembers: top10Members.length,
        topPodium: topPodium,
        myRank: resolvedMyRank,
        members: top10Members,
        isContactsMode: true,
        isContactsSynced: isSynced,
        contactPermissionStatus: permStatus,
        mutualMembers: top10Members,
        mutualPodium: topPodium,
        errorMessage: mutualRes == null
            ? 'Failed to load friends leaderboard. Please try again.'
            : null,
      );

      // If contacts not marked synced yet, check if permission was already granted and auto-sync
      if (!isSynced) {
        unawaited(_checkAndAutoSyncIfGranted());
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: 'Failed to load friends leaderboard. Please try again.',
      );
    }
  }

  Future<void> _checkAndAutoSyncIfGranted() async {
    try {
      final user = ref.read(authViewModelProvider).value;
      if (user == null) return;
      final hasPermission = await FlutterContacts.permissions.has(PermissionType.read);
      if (hasPermission) {
        await syncContacts(silent: true);
      }
    } catch (_) {}
  }

  /// Requests permission, reads phone contacts, uploads to backend in chunks, and refreshes leaderboard
  Future<bool> syncContacts({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isSyncingContacts: true);
    }
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      final isGranted = status == PermissionStatus.granted || status == PermissionStatus.limited;
      if (!isGranted) {
        await _dataSource.updatePermissionStatus('DENIED');
        state = state.copyWith(
          isSyncingContacts: false,
          contactPermissionStatus: 'DENIED',
        );
        return false;
      }

      // Read device contacts with names and phone numbers
      final rawContacts = await FlutterContacts.getAll(
        properties: {ContactProperty.name, ContactProperty.phone},
      );

      final payload = <Map<String, String>>[];
      for (final c in rawContacts) {
        final name = (c.displayName ?? '').trim();
        for (final p in c.phones) {
          final number = p.number.trim();
          if (number.isNotEmpty) {
            payload.add({
              'name': name.isNotEmpty ? name : number,
              'phone': number,
            });
          }
        }
      }

      if (payload.isEmpty) {
        await _dataSource.importContacts([], true);
      } else {
        const chunkSize = 400;
        for (var i = 0; i < payload.length; i += chunkSize) {
          final end = (i + chunkSize < payload.length) ? i + chunkSize : payload.length;
          final chunk = payload.sublist(i, end);
          final isLast = end >= payload.length;
          await _dataSource.importContacts(chunk, isLast);
        }
      }

      state = state.copyWith(
        isContactsSynced: true,
        contactPermissionStatus: 'ALLOWED',
        isSyncingContacts: false,
      );

      // Re-load leaderboard with newly synced contacts
      await loadMembers(isRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(isSyncingContacts: false);
      return false;
    }
  }

  void setMode(bool isContactsMode) {
    state = state.copyWith(isContactsMode: isContactsMode);
  }

  void onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      loadMembers(query: query);
    });
  }

  Future<void> refresh() async {
    await loadMembers(isRefresh: true);
  }
}
