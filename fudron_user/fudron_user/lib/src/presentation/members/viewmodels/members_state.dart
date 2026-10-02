import 'package:flutter/foundation.dart';
import '../../../data/models/member_model.dart';

@immutable
class MembersState {
  final bool isLoading;
  final bool isRefreshing;
  final String searchQuery;
  final int totalMembers;
  final List<MemberModel> topPodium;
  final MemberModel? myRank;
  final List<MemberModel> members;
  final bool isContactsMode;
  final bool isContactsSynced;
  final bool isSyncingContacts;
  final String contactPermissionStatus;
  final List<MemberModel> mutualMembers;
  final List<MemberModel> mutualPodium;
  final String? errorMessage;

  const MembersState({
    this.isLoading = false,
    this.isRefreshing = false,
    this.searchQuery = '',
    this.totalMembers = 0,
    this.topPodium = const [],
    this.myRank,
    this.members = const [],
    this.isContactsMode = true,
    this.isContactsSynced = false,
    this.isSyncingContacts = false,
    this.contactPermissionStatus = 'PENDING',
    this.mutualMembers = const [],
    this.mutualPodium = const [],
    this.errorMessage,
  });

  MembersState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? searchQuery,
    int? totalMembers,
    List<MemberModel>? topPodium,
    MemberModel? myRank,
    List<MemberModel>? members,
    bool? isContactsMode,
    bool? isContactsSynced,
    bool? isSyncingContacts,
    String? contactPermissionStatus,
    List<MemberModel>? mutualMembers,
    List<MemberModel>? mutualPodium,
    String? errorMessage,
  }) {
    return MembersState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      searchQuery: searchQuery ?? this.searchQuery,
      totalMembers: totalMembers ?? this.totalMembers,
      topPodium: topPodium ?? this.topPodium,
      myRank: myRank ?? this.myRank,
      members: members ?? this.members,
      isContactsMode: isContactsMode ?? this.isContactsMode,
      isContactsSynced: isContactsSynced ?? this.isContactsSynced,
      isSyncingContacts: isSyncingContacts ?? this.isSyncingContacts,
      contactPermissionStatus: contactPermissionStatus ?? this.contactPermissionStatus,
      mutualMembers: mutualMembers ?? this.mutualMembers,
      mutualPodium: mutualPodium ?? this.mutualPodium,
      errorMessage: errorMessage,
    );
  }
}
