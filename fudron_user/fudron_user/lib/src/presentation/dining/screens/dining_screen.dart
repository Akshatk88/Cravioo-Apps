import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/dining_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/dining_bookings_viewmodel.dart';
import '../viewmodels/dining_viewmodel.dart';
import '../widgets/table_booking_sheet.dart';

class DiningScreen extends ConsumerStatefulWidget {
  const DiningScreen({super.key});

  @override
  ConsumerState<DiningScreen> createState() => _DiningScreenState();
}

class _DiningScreenState extends ConsumerState<DiningScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _bannerPageController = PageController();
  int _activeBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diningBookingsViewModelProvider.notifier).loadBookings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final diningState = ref.watch(diningViewModelProvider);
    final upcomingBooking = ref.watch(latestUpcomingDiningBookingProvider);
    final bookingsState = ref.watch(diningBookingsViewModelProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.read(diningViewModelProvider.notifier).loadInitialData(),
              ref.read(diningBookingsViewModelProvider.notifier).loadBookings(),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: AppColors.primaryAlpha(0.12),
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Icon(
                              Icons.restaurant_rounded,
                              color: AppColors.primary,
                              size: 22.sp,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dining Out',
                                  style: TextStyle(
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                Text(
                                  'Book a table & enjoy fine dining near you',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // My Bookings Button
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Haptics.light();
                                context.push(RouteNames.diningBookings);
                              },
                              borderRadius: BorderRadius.circular(12.r),
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryAlpha(0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                  border: Border.all(
                                    color: AppColors.primaryAlpha(0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      size: 16.sp,
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(width: 5.w),
                                    Text(
                                      'My Bookings',
                                      style: TextStyle(
                                        fontSize: 11.5.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    if (bookingsState.upcomingCount > 0) ...[
                                      SizedBox(width: 5.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(10.r),
                                        ),
                                        child: Text(
                                          '${bookingsState.upcomingCount}',
                                          style: TextStyle(
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),

                      // Search bar
                      Container(
                        height: 44.h,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                          ),
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            ref.read(diningViewModelProvider.notifier).setSearchQuery(val);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search restaurants, cuisines, cafes...',
                            hintStyle: TextStyle(
                              fontSize: 12.sp,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                              size: 20.sp,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      ref.read(diningViewModelProvider.notifier).setSearchQuery('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                          ),
                        ),
                      ),

                      // Upcoming reservation card if active
                      if (upcomingBooking != null) ...[
                        SizedBox(height: 10.h),
                        GestureDetector(
                          onTap: () {
                            Haptics.light();
                            context.push(RouteNames.diningBookings);
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF1F2937), const Color(0xFF111827)]
                                    : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
                              ),
                              borderRadius: BorderRadius.circular(14.r),
                              border: Border.all(
                                color: AppColors.primaryAlpha(0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryAlpha(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8.r),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryAlpha(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.table_restaurant_rounded,
                                    color: AppColors.primary,
                                    size: 18.sp,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'Upcoming Reservation',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          SizedBox(width: 6.w),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                                            decoration: BoxDecoration(
                                              color: upcomingBooking.status == 'confirmed'
                                                  ? const Color(0xFF15803D)
                                                  : Colors.amber.shade800,
                                              borderRadius: BorderRadius.circular(6.r),
                                            ),
                                            child: Text(
                                              upcomingBooking.displayStatus.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 8.5.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 2.h),
                                      Text(
                                        '${upcomingBooking.restaurantName} • ${upcomingBooking.date} at ${upcomingBooking.formattedSlotTime}',
                                        style: TextStyle(
                                          fontSize: 12.5.sp,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 13.sp,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Banners Carousel
              if (diningState.banners.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    height: 140.h,
                    margin: EdgeInsets.symmetric(vertical: 8.h),
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            controller: _bannerPageController,
                            onPageChanged: (i) => setState(() => _activeBannerIndex = i),
                            itemCount: diningState.banners.length,
                            itemBuilder: (ctx, index) {
                              final banner = diningState.banners[index];
                              return Container(
                                margin: EdgeInsets.symmetric(horizontal: 16.w),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16.r),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      if (banner.imageUrl.isNotEmpty)
                                        CachedNetworkImage(
                                          imageUrl: banner.imageUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [AppColors.primary, const Color(0xFFD84315)],
                                              ),
                                            ),
                                          ),
                                        )
                                      else
                                        Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [AppColors.primary, const Color(0xFFD84315)],
                                            ),
                                          ),
                                        ),
                                      // Gradient overlay
                                      Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              Colors.black.withValues(alpha: 0.75),
                                              Colors.black.withValues(alpha: 0.1),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              banner.title,
                                              style: TextStyle(
                                                fontSize: 15.sp,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (banner.subtitle.isNotEmpty) ...[
                                              SizedBox(height: 3.h),
                                              Text(
                                                banner.subtitle,
                                                style: TextStyle(
                                                  fontSize: 11.sp,
                                                  color: Colors.white70,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            SizedBox(height: 8.h),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(8.r),
                                              ),
                                              child: Text(
                                                banner.ctaText.isNotEmpty ? banner.ctaText : 'Explore',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (diningState.banners.length > 1) ...[
                          SizedBox(height: 6.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              diningState.banners.length,
                              (i) => Container(
                                width: _activeBannerIndex == i ? 16.w : 5.w,
                                height: 4.h,
                                margin: EdgeInsets.symmetric(horizontal: 2.w),
                                decoration: BoxDecoration(
                                  color: _activeBannerIndex == i
                                      ? AppColors.primary
                                      : (isDark ? Colors.white24 : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Categories Rail
              if (diningState.categories.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 6.h),
                    child: Text(
                      'Browse by Dining Style',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 85.h,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                      scrollDirection: Axis.horizontal,
                      itemCount: diningState.categories.length + 1,
                      separatorBuilder: (_, _) => SizedBox(width: 12.w),
                      itemBuilder: (ctx, index) {
                        if (index == 0) {
                          final isSelected = diningState.selectedCategoryId == 'all';
                          return GestureDetector(
                            onTap: () {
                              Haptics.light();
                              ref.read(diningViewModelProvider.notifier).selectCategory('all');
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 52.r,
                                  height: 52.r,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? AppColors.surfaceDark : const Color(0xFFF3F4F6)),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.restaurant_menu_rounded,
                                    color: isSelected ? Colors.white : AppColors.primary,
                                    size: 24.sp,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'All',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primary
                                        : (isDark ? Colors.white70 : Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        final cat = diningState.categories[index - 1];
                        final isSelected = diningState.selectedCategoryId == cat.id;

                        return GestureDetector(
                          onTap: () {
                            Haptics.light();
                            ref.read(diningViewModelProvider.notifier).selectCategory(cat.id);
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 52.r,
                                height: 52.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppColors.primary : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child: cat.imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: cat.imageUrl,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) => Container(
                                            color: AppColors.primaryAlpha(0.1),
                                            child: Icon(Icons.fastfood, color: AppColors.primary),
                                          ),
                                        )
                                      : Container(
                                          color: AppColors.primaryAlpha(0.1),
                                          child: Icon(Icons.fastfood, color: AppColors.primary),
                                        ),
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                cat.name,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],

              // Filter Chips
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          label: 'Popular',
                          selected: diningState.sortBy == 'popular',
                          onTap: () => ref.read(diningViewModelProvider.notifier).setSortBy('popular'),
                          isDark: isDark,
                        ),
                        SizedBox(width: 8.w),
                        _buildFilterChip(
                          label: 'Top Rated 4.0+',
                          selected: diningState.sortBy == 'rating',
                          onTap: () => ref.read(diningViewModelProvider.notifier).setSortBy('rating'),
                          isDark: isDark,
                        ),
                        SizedBox(width: 8.w),
                        _buildFilterChip(
                          label: 'Nearest',
                          selected: diningState.sortBy == 'nearest',
                          onTap: () => ref.read(diningViewModelProvider.notifier).setSortBy('nearest'),
                          isDark: isDark,
                        ),
                        SizedBox(width: 8.w),
                        _buildFilterChip(
                          label: 'Cost: Low to High',
                          selected: diningState.sortBy == 'cost_low',
                          onTap: () => ref.read(diningViewModelProvider.notifier).setSortBy('cost_low'),
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Section Title
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available Dining Outlets',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '${diningState.restaurants.length} Places',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Loading State
              if (diningState.isLoading)
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) => Padding(
                        padding: EdgeInsets.only(bottom: 14.h),
                        child: const SkeletonFoodItemCard(),
                      ),
                      childCount: 4,
                    ),
                  ),
                )
              // Empty State
              else if (diningState.restaurants.isEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    margin: EdgeInsets.all(24.r),
                    padding: EdgeInsets.all(24.r),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.table_restaurant_outlined,
                          size: 48.sp,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'No Dining Outlets Found',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'Try clearing your search query or picking another dining category.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                        ),
                        SizedBox(height: 14.h),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(diningViewModelProvider.notifier).selectCategory('all');
                          },
                          child: const Text('View All Outlets', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              // Restaurant List Cards
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 80.h),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, index) {
                        final item = diningState.restaurants[index];
                        return _buildRestaurantCard(context, item, isDark);
                      },
                      childCount: diningState.restaurants.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : (isDark ? AppColors.surfaceDark : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: selected ? AppColors.primary : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantCard(BuildContext context, DiningRestaurantModel item, bool isDark) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image + Rating badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: item.coverImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: item.coverImage,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.restaurant, size: 40, color: Colors.grey),
                        ),
                ),
              ),
              // Rating Badge
              Positioned(
                top: 10.h,
                right: 10.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32),
                    borderRadius: BorderRadius.circular(8.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.ratingAvg > 0 ? item.ratingAvg.toStringAsFixed(1) : '4.5',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(Icons.star_rounded, color: Colors.white, size: 14.sp),
                    ],
                  ),
                ),
              ),
              // Distance Badge
              if (item.distanceInKm != null)
                Positioned(
                  bottom: 10.h,
                  left: 10.w,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      '${item.distanceInKm!.toStringAsFixed(1)} km away',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          Padding(
            padding: EdgeInsets.all(14.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${item.costForTwo > 0 ? item.costForTwo : 600} for two',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),

                // Cuisines line
                if (item.cuisines.isNotEmpty) ...[
                  Text(
                    item.cuisines.join(' • '),
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                ],

                // Amenities chips
                if (item.amenities.isNotEmpty)
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 4.h,
                    children: item.amenities.take(3).map((amenity) {
                      return Container(
                        padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222222) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          amenity,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                SizedBox(height: 12.h),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 9.h),
                        ),
                        onPressed: () {
                          Haptics.light();
                          context.push('${RouteNames.restaurantDetail}/${item.restaurantId}');
                        },
                        child: Text(
                          'View Menu',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.table_bar_rounded, size: 16.sp, color: Colors.white),
                        label: Text(
                          'Book Table',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 9.h),
                        ),
                        onPressed: () {
                          Haptics.medium();
                          TableBookingSheet.show(context, item);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
