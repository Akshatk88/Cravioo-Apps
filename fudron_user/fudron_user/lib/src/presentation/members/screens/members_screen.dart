import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../data/models/member_model.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/members_state.dart';
import '../viewmodels/members_viewmodel.dart';

class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(authViewModelProvider).value != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!isLoggedIn) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAF9),
        body: SafeArea(
          child: _buildLoginPrompt(context, isDark),
        ),
      );
    }

    final state = ref.watch(membersViewModelProvider);
    final activeMembers = state.mutualMembers;
    final activePodium = state.mutualPodium;

    return Scaffold(
      backgroundColor: isDark ? AppColors.surfaceDark : const Color(0xFFF8FAF9),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(membersViewModelProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Top Header
              SliverToBoxAdapter(
                child: _buildHeader(context, state, isDark),
              ),

              // Search Bar
              SliverToBoxAdapter(
                child: _buildSearchBar(context, isDark),
              ),


              // Content based on state
              if (state.isLoading && !state.isRefreshing)
                SliverToBoxAdapter(
                  child: _buildLoadingState(isDark),
                )
              else if (state.errorMessage != null && activeMembers.isEmpty && state.members.isEmpty)
                SliverToBoxAdapter(
                  child: _buildErrorState(state.errorMessage!, isDark),
                )
              else ...[
                // Top 3 Podium (Show only if not searching or if search returns podium members)
                if (state.searchQuery.isEmpty && activePodium.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildTopPodium(context, activePodium, isDark),
                  ),

                // My Rank Banner (if available)
                if (state.myRank != null)
                  SliverToBoxAdapter(
                    child: _buildMyRankBanner(context, state.myRank!, isDark),
                  ),

                // Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 8.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4.w,
                              height: 16.h,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              state.searchQuery.isEmpty
                                  ? 'Top 10 Friends (${activeMembers.length})'
                                  : 'Search Friends (${activeMembers.length})',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ranked by Orders',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                              ),
                            ),
                            SizedBox(width: 6.w),
                            InkWell(
                              onTap: state.isSyncingContacts
                                  ? null
                                  : () => ref.read(membersViewModelProvider.notifier).syncContacts(),
                              borderRadius: BorderRadius.circular(12.r),
                              child: Padding(
                                padding: EdgeInsets.all(4.r),
                                child: state.isSyncingContacts
                                    ? SizedBox(
                                        width: 14.r,
                                        height: 14.r,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.sync_rounded,
                                        size: 16.sp,
                                        color: AppColors.primary,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Members List / Empty States
                if (activeMembers.isEmpty)
                  SliverToBoxAdapter(
                    child: state.searchQuery.isNotEmpty
                        ? _buildEmptySearchState(isDark)
                        : (!state.isContactsSynced
                            ? _buildSyncContactsCard(context, state, isDark)
                            : _buildNoContactsFoundCard(context, state, isDark)),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final member = activeMembers[index];
                          return _buildMemberCard(context, member, index + 1, isDark);
                        },
                        childCount: activeMembers.length,
                      ),
                    ),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(height: 30.h),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, MembersState state, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🏆', style: TextStyle(fontSize: 12.sp)),
                    SizedBox(width: 4.w),
                    Text(
                      'FOODIE LEADERBOARD',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFB45309),
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (context) {
                  final count = state.mutualMembers.length;
                  if (count <= 0) return const SizedBox.shrink();
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFA7F3D0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.contacts_rounded,
                          size: 14.sp,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '$count Friends',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Friends Leaderboard',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Top 10 friends ranked by orders placed on Cravioo!',
            style: TextStyle(
              fontSize: 13.sp,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          ),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            ref.read(membersViewModelProvider.notifier).onSearchChanged(val);
          },
          style: TextStyle(
            fontSize: 14.sp,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            hintText: 'Search member by name...',
            hintStyle: TextStyle(
              fontSize: 13.sp,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 20.sp,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white60 : Colors.black45,
                      size: 18.sp,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(membersViewModelProvider.notifier).onSearchChanged('');
                      setState(() {});
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          ),
        ),
      ),
    );
  }

  Widget _buildTopPodium(BuildContext context, List<MemberModel> podium, bool isDark) {
    if (podium.isEmpty) return const SizedBox.shrink();

    final rank1 = podium.isNotEmpty ? podium[0] : null;
    final rank2 = podium.length > 1 ? podium[1] : null;
    final rank3 = podium.length > 2 ? podium[2] : null;

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 8.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E293B),
                  const Color(0xFF0F172A),
                ]
              : [
                  const Color(0xFFFFFFFF),
                  const Color(0xFFF1F5F9),
                ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, color: const Color(0xFFF59E0B), size: 20.sp),
              SizedBox(width: 6.w),
              Text(
                'Top 3 Hall of Fame',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 2nd Place (Left)
              Expanded(
                child: rank2 != null
                    ? _buildPodiumItem(
                        member: rank2,
                        rank: 2,
                        badgeEmoji: '🥈',
                        badgeColor: const Color(0xFF94A3B8),
                        glowColor: const Color(0xFFCBD5E1),
                        avatarSize: 60.r,
                        elevationHeight: 82.h,
                        isDark: isDark,
                      )
                    : const SizedBox(),
              ),

              // 1st Place (Center - Elevated Higher & Bigger)
              Expanded(
                child: rank1 != null
                    ? Transform.translate(
                        offset: Offset(0, -18.h),
                        child: _buildPodiumItem(
                          member: rank1,
                          rank: 1,
                          badgeEmoji: '👑',
                          badgeColor: const Color(0xFFF59E0B),
                          glowColor: const Color(0xFFFBBF24),
                          avatarSize: 78.r,
                          elevationHeight: 112.h,
                          isCenter1st: true,
                          isDark: isDark,
                        ),
                      )
                    : const SizedBox(),
              ),

              // 3rd Place (Right)
              Expanded(
                child: rank3 != null
                    ? _buildPodiumItem(
                        member: rank3,
                        rank: 3,
                        badgeEmoji: '🥉',
                        badgeColor: const Color(0xFFD97706),
                        glowColor: const Color(0xFFFCD34D),
                        avatarSize: 54.r,
                        elevationHeight: 70.h,
                        isDark: isDark,
                      )
                    : const SizedBox(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPodiumItem({
    required MemberModel member,
    required int rank,
    required String badgeEmoji,
    required Color badgeColor,
    required Color glowColor,
    required double avatarSize,
    required double elevationHeight,
    bool isCenter1st = false,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown/Badge on top of avatar
        Text(
          badgeEmoji,
          style: TextStyle(fontSize: isCenter1st ? 24.sp : 18.sp),
        ),
        SizedBox(height: 2.h),

        // Avatar with glowing border
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isCenter1st
                      ? [const Color(0xFFF59E0B), const Color(0xFFFDE68A)]
                      : [glowColor, glowColor.withValues(alpha: 0.6)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: isCenter1st ? 0.5 : 0.3),
                    blurRadius: isCenter1st ? 12 : 6,
                    spreadRadius: isCenter1st ? 2 : 0,
                  ),
                ],
              ),
              padding: EdgeInsets.all(isCenter1st ? 3.r : 2.r),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(avatarSize),
                child: member.profileImage.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: member.fullImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => _buildInitialsAvatar(member),
                        errorWidget: (context, url, error) => _buildInitialsAvatar(member),
                      )
                    : _buildInitialsAvatar(member),
              ),
            ),
            // Rank number badge
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),

        // Name
        Text(
          member.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isCenter1st ? 13.sp : 12.sp,
            fontWeight: isCenter1st ? FontWeight.w800 : FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),

        // Order count chip
        SizedBox(height: 3.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: isCenter1st
                ? const Color(0xFFFEF3C7)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Text(
            '🔥 ${member.orderCount} Orders',
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: isCenter1st
                  ? const Color(0xFFB45309)
                  : (isDark ? Colors.white70 : const Color(0xFF475569)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyRankBanner(BuildContext context, MemberModel myRank, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            const Color(0xFF15803D),
          ],
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46.r,
            height: 46.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${myRank.rank}',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Your Ranking',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        myRank.badge,
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  myRank.orderCount > 0
                      ? 'You have placed ${myRank.orderCount} orders!'
                      : 'Place your 1st order to rank up on the leaderboard!',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.military_tech_rounded,
            color: Colors.white,
            size: 28.sp,
          ),
        ],
      ),
    );
  }



  Widget _buildMemberCard(BuildContext context, MemberModel member, int displayRank, bool isDark) {
    final rank = member.rank > 0 ? member.rank : displayRank;
    final isTop10 = rank <= 10;
    final isTop3 = rank <= 3;

    Color rankColor;
    if (rank == 1) {
      rankColor = const Color(0xFFF59E0B);
    } else if (rank == 2) {
      rankColor = const Color(0xFF94A3B8);
    } else if (rank == 3) {
      rankColor = const Color(0xFFD97706);
    } else if (rank <= 10) {
      rankColor = AppColors.primary;
    } else {
      rankColor = isDark ? Colors.white60 : const Color(0xFF64748B);
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: member.isCurrentUser
            ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
            : (isDark ? AppColors.cardDark : Colors.white),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: member.isCurrentUser
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : const Color(0xFFF1F5F9)),
          width: member.isCurrentUser ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 32.w,
            alignment: Alignment.center,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: isTop10 ? FontWeight.w900 : FontWeight.w700,
                color: rankColor,
              ),
            ),
          ),
          SizedBox(width: 8.w),

          // Avatar
          Container(
            width: 44.r,
            height: 44.r,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isTop3 ? rankColor : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                width: isTop3 ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44.r),
              child: member.profileImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: member.fullImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildInitialsAvatar(member),
                      errorWidget: (context, url, error) => _buildInitialsAvatar(member),
                    )
                  : _buildInitialsAvatar(member),
            ),
          ),
          SizedBox(width: 12.w),

          // Member Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (member.isCurrentUser) ...[
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  member.badge,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Order Count Chip
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: member.orderCount > 0
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: member.orderCount > 20
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (member.orderCount > 0)
                  Text(
                    '🔥 ',
                    style: TextStyle(fontSize: 11.sp),
                  ),
                Text(
                  '${member.orderCount} Orders',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: member.orderCount > 0
                        ? (isDark ? Colors.white : const Color(0xFF0F172A))
                        : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialsAvatar(MemberModel member) {
    final colors = [
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF06B6D4),
    ];
    final color = colors[member.name.hashCode.abs() % colors.length];

    return Container(
      color: color.withValues(alpha: 0.18),
      alignment: Alignment.center,
      child: Text(
        member.initial,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: List.generate(
          6,
          (index) => Container(
            margin: EdgeInsets.only(bottom: 12.h),
            height: 64.h,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 40.h),
      child: Column(
        children: [
          Icon(Icons.error_outline_rounded, size: 48.sp, color: Colors.redAccent),
          SizedBox(height: 12.h),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: isDark ? AppColors.textSecondaryDark : Colors.black54,
            ),
          ),
          SizedBox(height: 16.h),
          ElevatedButton.icon(
            onPressed: () => ref.read(membersViewModelProvider.notifier).loadMembers(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState(bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 30.h),
      child: Column(
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 48.sp,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
          SizedBox(height: 10.h),
          Text(
            'No members found',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'Try searching with a different name or phone number',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildNoContactsFoundCard(
    BuildContext context,
    MembersState state,
    bool isDark,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56.r,
              height: 56.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.people_outline_rounded,
                color: AppColors.primary,
                size: 30.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'No contacts on Cravioo yet',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'None of your phone contacts have downloaded Cravioo yet. Invite your friends to order together and climb the leaderboard!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isSyncingContacts
                        ? null
                        : () => ref.read(membersViewModelProvider.notifier).syncContacts(),
                    icon: state.isSyncingContacts
                        ? SizedBox(
                            width: 14.r,
                            height: 14.r,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : Icon(Icons.sync_rounded, size: 16.sp),
                    label: Text(
                      state.isSyncingContacts ? 'Syncing...' : 'Re-sync Contacts',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(text: 'Hey! Join me on Cravioo for delicious food discounts and fun leaderboard rankings! Download now: https://cravioo.in'),
                      );
                    },
                    icon: Icon(Icons.share_rounded, size: 16.sp),
                    label: Text(
                      'Invite Friends',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncContactsCard(
    BuildContext context,
    MembersState state,
    bool isDark,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56.r,
              height: 56.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.contacts_rounded,
                color: const Color(0xFF3B82F6),
                size: 30.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Find Friends on Cravioo',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Discover people from your phonebook who use Cravioo, see who placed the most orders, and compete for ranks!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            SizedBox(height: 18.h),
            ElevatedButton.icon(
              onPressed: state.isSyncingContacts
                  ? null
                  : () => ref.read(membersViewModelProvider.notifier).syncContacts(),
              icon: state.isSyncingContacts
                  ? SizedBox(
                      width: 16.r,
                      height: 16.r,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.sync_rounded, size: 16.sp),
              label: Text(
                state.isSyncingContacts
                    ? 'Syncing Contacts...'
                    : 'Find Friends on Cravioo',
                style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginPrompt(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Trophy Icon
            Container(
              width: 88.r,
              height: 88.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFEF3C7),
                    const Color(0xFFFDE68A),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '🏆',
                style: TextStyle(fontSize: 40.sp),
              ),
            ),
            SizedBox(height: 24.h),

            // Title
            Text(
              'Foodie Leaderboard',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 8.h),

            // Description
            Text(
              'Log in to see your friends\' rankings, compare orders, and compete for the top spot!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            SizedBox(height: 28.h),

            // Login Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.push(RouteNames.login);
                },
                icon: Icon(Icons.login_rounded, size: 20.sp),
                label: Text(
                  'Log In to View Leaderboard',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  elevation: 2,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // Subtle hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14.sp,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Login required to access this section',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
