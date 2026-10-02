import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../common_widgets/app_refresh_indicator.dart';
import '../common_widgets/skeleton_loading.dart';
import '../common_widgets/exit_confirmation_dialog.dart';

import '../../core/utils/haptics.dart';
import '../branding/app_colors.dart';
import '../cart/widgets/floating_view_cart_bar.dart';
import '../navigation/route_names.dart';
import '../search/widgets/voice_search_dialog.dart';

import '../../data/models/restaurant_model.dart';
import '../../data/models/promo_banner_model.dart';

import '../orders/viewmodels/active_order_viewmodel.dart';
import '../common_widgets/collapsing_header_delegate.dart';

import 'screens/home_filter_screen.dart';
import 'viewmodels/banners_viewmodel.dart';
import '../../../generated/l10n/app_localizations.dart';
import 'viewmodels/home_viewmodel.dart';
import 'viewmodels/near_you_viewmodel.dart';
import 'viewmodels/veg_filter_provider.dart';
import 'viewmodels/zone_viewmodel.dart';
import '../address/viewmodels/address_viewmodel.dart';
import '../address/widgets/saved_addresses_bottom_sheet.dart';

import 'widgets/category_list.dart';
import 'widgets/home_header_banner.dart';
import 'widgets/popular_brands_list.dart';
import 'widgets/promo_banner_carousel.dart';
import 'widgets/restaurant_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();

  final ScrollController _scrollController = ScrollController();

  String _selectedCategory = 'All';

  bool _headerCollapsed = false;

  double get _headerGap => 8.h;

  double get _sectionGap => 16.h;

  double get _stickyBlockHeight => 50.h + 4.h + 84.h;

  double get _bannerToBlockOverlap => 26.h;

  double get _collapsedTopPadding => 8.h;

  double get _shadowRoom => 8.h;

  double get _headerRange =>
      315.h - _bannerToBlockOverlap - _collapsedTopPadding;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // ========================================================================
  // SCROLL HANDLER
  // ========================================================================

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final collapsed = _scrollController.offset > (_headerRange * 0.7);

    if (collapsed != _headerCollapsed && mounted) {
      setState(() {
        _headerCollapsed = collapsed;
      });
    }
  }

  // ========================================================================
  // BUILD
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeViewModelProvider);
    final zoneAsync = ref.watch(zoneViewModelProvider);

    final theme = Theme.of(context);

    final isDark = theme.brightness == Brightness.dark;

    // Show loading skeleton while initially detecting zone
    if (zoneAsync.isLoading && zoneAsync.value == null) {
      return Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: const SafeArea(
          child: SkeletonRestaurantList(count: 6),
        ),
      );
    }

    // Show out-of-service view if user location is outside any delivery zone
    if (zoneAsync.value != null && !zoneAsync.value!.isInService) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;

          final shouldExit = await showExitConfirmationDialog(context);

          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        },
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          child: Scaffold(
            backgroundColor: isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight,
            body: SafeArea(
              child: _buildOutOfServiceContent(context, isDark),
            ),
          ),
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);

    final topInset = mediaQuery.padding.top;

    final bannerHeight = topInset + 315.h;

    final expandedBlockTop = bannerHeight - _bannerToBlockOverlap;

    final collapsedBlockTop = topInset + _collapsedTopPadding;

    final expandedHeaderExtent =
        expandedBlockTop + _stickyBlockHeight + _shadowRoom;

    final collapsedHeaderExtent =
        collapsedBlockTop + _stickyBlockHeight + _shadowRoom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final shouldExit = await showExitConfirmationDialog(context);

        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (_headerCollapsed && !isDark)
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                // ==========================================================
                // MAIN SCROLL CONTENT
                // ==========================================================

                AppRefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(homeViewModelProvider.notifier)
                        .loadHomeData(isRefresh: true);

                    await ref
                        .read(activeOrderViewModelProvider.notifier)
                        .fetchActiveOrder(isRefresh: true);

                    ref.invalidate(promoBannersProvider);
                  },
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // ====================================================
                      // HERO HEADER + SEARCH + CATEGORIES
                      // ====================================================

                      SliverPersistentHeader(
                        pinned: true,
                        delegate: CollapsingHeaderDelegate(
                          expandedExtent: expandedHeaderExtent,
                          collapsedExtent: collapsedHeaderExtent,
                          expandedBlockTop: expandedBlockTop,
                          collapsedBlockTop: collapsedBlockTop,
                          blockHeight: _stickyBlockHeight,
                          backdropColor: isDark
                              ? AppColors.backgroundDark
                              : AppColors.backgroundLight,
                          bannerDriftUp: 30.h,
                          banner: const HomeHeaderBanner(),
                          stickyBlock: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildSearchBar(context, isDark),

                              SizedBox(height: 4.h),

                              CategoryList(
                                categories:
                                    homeState.categories.asData?.value ??
                                    const [],
                                selectedCategoryName: _selectedCategory,
                                onCategorySelected: (catName) {
                                  if (!mounted) return;

                                  setState(() {
                                    _selectedCategory = catName;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ====================================================
                      // REST OF HOME
                      // ====================================================
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: _sectionGap - _shadowRoom),

                            // =================================================
                            // QUICK FILTERS
                            // =================================================
                            _buildQuickFilterPills(isDark),

                            SizedBox(height: 18.h),

                            // =================================================
                            // EXPLORE MORE
                            // =================================================
                            _buildExploreMore(isDark),

                            SizedBox(height: _sectionGap),

                            // =================================================
                            // PROMOTIONAL BANNERS
                            // =================================================
                            ref
                                .watch(promoBannersProvider)
                                .when(
                                  data: (banners) {
                                    if (banners.isEmpty) {
                                      return const SizedBox.shrink();
                                    }

                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        PromoBannerCarousel(banners: banners),
                                        SizedBox(height: _sectionGap),
                                      ],
                                    );
                                  },
                                  loading: () {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const PromoBannerCarousel(
                                          banners: [
                                            PromoBannerModel(
                                              id: 'banner_collections',
                                              imageUrl: 'assets/collectionspagebanner.png',
                                              title: 'Your Collections',
                                            ),
                                            PromoBannerModel(
                                              id: 'banner_offer',
                                              imageUrl: 'assets/offerpagebanner.png',
                                              title: 'Special Offers',
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: _sectionGap),
                                      ],
                                    );
                                  },
                                  error: (err, stack) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const PromoBannerCarousel(
                                          banners: [
                                            PromoBannerModel(
                                              id: 'banner_collections',
                                              imageUrl: 'assets/collectionspagebanner.png',
                                              title: 'Your Collections',
                                            ),
                                            PromoBannerModel(
                                              id: 'banner_offer',
                                              imageUrl: 'assets/offerpagebanner.png',
                                              title: 'Special Offers',
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: _sectionGap),
                                      ],
                                    );
                                  },
                                ),

                            // =================================================
                            // POPULAR BRANDS
                            // =================================================
                            _buildSectionHeader(
                              title: AppLocalizations.of(
                                context,
                              )!.popularBrands,
                              onViewAll: () {
                                context.push(RouteNames.search);
                              },
                              isDark: isDark,
                            ),

                            SizedBox(height: _headerGap),

                            homeState.nearbyRestaurants.when(
                              data: (restaurants) {
                                return PopularBrandsList(
                                  restaurants: _filterRestaurants(restaurants),
                                );
                              },
                              loading: () {
                                return const SkeletonBanner(height: 80);
                              },
                              error: (err, stack) {
                                return const SizedBox.shrink();
                              },
                            ),

                            SizedBox(height: _sectionGap),

                            // =================================================
                            // RESTAURANTS DELIVERING TO YOU
                            // =================================================
                            homeState.nearbyRestaurants.when(
                              data: (allRestaurants) {
                                final restaurants = _filterRestaurants(
                                  allRestaurants,
                                );

                                if (restaurants.isEmpty) {
                                  return const SizedBox.shrink();
                                }

                                final totalCount = restaurants.length;

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionHeader(
                                      title: AppLocalizations.of(
                                        context,
                                      )!.restaurantsDeliveringToYou(totalCount),
                                      onViewAll: null,
                                      isDark: isDark,
                                    ),

                                    SizedBox(height: _headerGap),

                                    ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: restaurants.length,
                                      itemBuilder: (context, index) {
                                        return RestaurantCard(
                                          restaurant: restaurants[index],
                                          index: index,
                                        );
                                      },
                                    ),
                                  ],
                                );
                              },
                              loading: () {
                                return const SkeletonRestaurantList(count: 3);
                              },
                              error: (err, stack) {
                                return const SizedBox.shrink();
                              },
                            ),

                            // =================================================
                            // BOTTOM SPACING
                            // =================================================
                            SizedBox(height: 110.h),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ==========================================================
                // FLOATING CART BAR
                // ==========================================================
                FloatingViewCartBar(
                  key: _cartBarKey,
                  onTap: () {
                    Haptics.light();
                    context.go(RouteNames.cart);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // SEARCH BAR + VEG TOGGLE
  // ========================================================================

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    final isVegOnly = ref.watch(vegFilterProvider);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          // ================================================================
          // SEARCH BAR
          // ================================================================

          Expanded(
            child: Container(
              height: 50.h,
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFEEEEEE),
                  width: 1,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.shadow1,
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  // ========================================================
                  // SEARCH CLICKABLE AREA
                  // ========================================================

                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Haptics.light();
                        context.push(RouteNames.search);
                      },
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            size: 20.sp,
                          ),

                          SizedBox(width: 8.w),

                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.searchHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ========================================================
                  // VOICE SEARCH
                  // ========================================================
                  InkWell(
                    borderRadius: BorderRadius.circular(20.r),
                    onTap: () async {
                      Haptics.light();

                      final query = await VoiceSearchDialog.show(context);

                      if (query != null &&
                          query.trim().isNotEmpty &&
                          context.mounted) {
                        developer.log(
                          '[VOICE] Navigation started to SearchScreen with query: "$query"',
                          name: 'VOICE',
                        );

                        context.push(RouteNames.search, extra: query.trim());

                        developer.log(
                          '[VOICE] Navigation completed',
                          name: 'VOICE',
                        );
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Icon(
                        Icons.mic_rounded,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(width: 10.w),

          // ================================================================
          // VEG TOGGLE
          // ================================================================
          InkWell(
            onTap: () {
              Haptics.light();

              ref.read(vegFilterProvider.notifier).toggle();
            },
            borderRadius: BorderRadius.circular(20.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50.h,
              width: 64.w,
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isVegOnly
                      ? AppColors.success
                      : (isDark
                            ? AppColors.borderDark
                            : const Color(0xFFEEEEEE)),
                  width: isVegOnly ? 1.5 : 1.0,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: isVegOnly
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.shadow1,
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 4.sp,
                        height: 4.sp,
                        decoration: BoxDecoration(
                          color: isVegOnly
                              ? AppColors.success
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF008A45)),
                          shape: BoxShape.circle,
                        ),
                      ),

                      SizedBox(width: 3.w),

                      Text(
                        'VEG',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w900,
                          color: isVegOnly
                              ? AppColors.success
                              : (isDark
                                    ? AppColors.textSecondaryDark
                                    : const Color(0xFF008A45)),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 3.h),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 34.w,
                    height: 18.h,
                    padding: EdgeInsets.all(2.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10.r),
                      color: isVegOnly
                          ? AppColors.success
                          : (isDark
                                ? const Color(0xFF3B3B3B)
                                : const Color(0xFFE0E0E0)),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 200),
                      alignment: isVegOnly
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 14.h,
                        height: 14.h,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // QUICK FILTER PILLS
  // ========================================================================

  Widget _buildQuickFilterPills(bool isDark) {
    final l10n = AppLocalizations.of(context)!;

    final List<Map<String, dynamic>> pills = [
      {
        'icon': Icons.local_fire_department_rounded,
        'title': l10n.pillTrending,
        'highlight': l10n.pillNow,
        'bg': AppColors.primary.withValues(alpha: 0.12),
        'color': AppColors.primary,
        'onTap': () => _openFilter(
          title: 'Trending Now',
          emptyMessage: 'No trending restaurants right now',
          emptyIcon: Icons.local_fire_department_rounded,
          matches: (r) => r.isFeatured,
        ),
      },
      {
        'icon': Icons.timer_outlined,
        'title': 'Under',
        'highlight': '30 mins',
        'bg': AppColors.primary.withValues(alpha: 0.12),
        'color': AppColors.primary,
        'onTap': () => _openFilter(
          title: 'Under 30 mins',
          emptyMessage: 'No restaurants delivering under 30 minutes right now',
          emptyIcon: Icons.timer_outlined,
          matches: (r) => _isUnder30Minutes(r.deliveryTime),
        ),
      },
      {
        'icon': Icons.location_on_outlined,
        'title': 'Near',
        'highlight': 'You',
        'bg': const Color(0xFFF8F0FF),
        'color': const Color(0xFF7B1FA2),
        'onTap': () => _openFilter(
          title: 'Near You',
          emptyMessage: 'No nearby fast-delivery restaurants right now',
          emptyIcon: Icons.location_on_rounded,
          matches: (r) => r.isNearAndFast,
        ),
      },
    ];

    return SizedBox(
      height: 38.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: pills.length,
        separatorBuilder: (context, index) {
          return SizedBox(width: 8.w);
        },
        itemBuilder: (context, index) {
          final p = pills[index];

          final Color bgColor = isDark
              ? AppColors.surfaceDark
              : (p['bg'] as Color);

          final Color textColor = p['color'] as Color;

          return InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: p['onTap'] as VoidCallback,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p['icon'] as IconData, color: textColor, size: 15.sp),

                  SizedBox(width: 5.w),

                  Text(
                    p['title'] as String,
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),

                  if ((p['highlight'] as String).isNotEmpty) ...[
                    SizedBox(width: 3.w),

                    Text(
                      p['highlight'] as String,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ========================================================================
  // EXPLORE MORE
  // ========================================================================

  Widget _buildExploreMore(bool isDark) {
    final List<Map<String, dynamic>> items = [
      {
        'title': 'Offers',
        'asset': 'assets/explore more icons/explore_offers.png',
        'fallback': Icons.local_offer_rounded,
        'onTap': () => _openFilter(
          title: 'Offers',
          emptyMessage: 'No special offers available right now',
          emptyIcon: Icons.local_offer_rounded,
          matches: (r) => r.offerBadges.isNotEmpty,
        ),
      },
      {
        'title': 'Top 10',
        'asset': 'assets/explore more icons/explore_top10.png',
        'fallback': Icons.location_on_rounded,
        'onTap': () => _openFilter(
          title: 'Top 10',
          emptyMessage: 'No top restaurants available right now',
          emptyIcon: Icons.location_on_rounded,
          matches: (r) => r.isFeatured,
        ),
      },
      {
        'title': 'Collections',
        'asset': 'assets/explore more icons/explore_collections.png',
        'fallback': Icons.collections_bookmark_rounded,
        'onTap': () {
          Haptics.light();
          context.push(RouteNames.favorites);
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ================================================================
        // TITLE
        // ================================================================
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Text(
                'EXPLORE MORE',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white : const Color(0xFF0F3E2E),
                ),
              ),
              SizedBox(width: 6.w),
              CustomPaint(
                size: Size(16.w, 16.h),
                painter: const _ExploreMoreSparklePainter(
                  color: Color(0xFF34D399),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 12.h),

        // ================================================================
        // 3 CARDS ROW
        // ================================================================
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final String title = item['title'] as String;
              final String assetPath = item['asset'] as String;
              final IconData fallback = item['fallback'] as IconData;
              final VoidCallback onTap = item['onTap'] as VoidCallback;

              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < items.length - 1 ? 10.w : 0,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(20.r),
                      child: Container(
                        height: 116.h,
                        padding: EdgeInsets.symmetric(vertical: 4.h),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDark
                                ? [
                                    AppColors.surfaceDark,
                                    const Color(0xFF0F2A21),
                                  ]
                                : const [
                                    Color(0xFFF5FDF9),
                                    Color(0xFFE8F8F0),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: isDark
                                ? AppColors.primary.withValues(alpha: 0.3)
                                : const Color(0xFF86EFAC),
                            width: 1.2,
                          ),
                          boxShadow: isDark
                              ? []
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: _buildExploreIcon(
                                  assetPath: assetPath,
                                  fallback: fallback,
                                  isDark: isDark,
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: 4.h,
                                left: 4.w,
                                right: 4.w,
                              ),
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF064E3B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // EXPLORE ICON (HD 3D Asset render)
  // ========================================================================

  Widget _buildExploreIcon({
    required String assetPath,
    required IconData fallback,
    required bool isDark,
  }) {
    return SizedBox(
      width: 92.w,
      height: 84.h,
      child: Center(
        child: Image.asset(
          assetPath,
          width: 92.w,
          height: 84.h,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            fallback,
            size: 42.sp,
            color: const Color(0xFF047857),
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // UNDER 30 MINUTES
  // ========================================================================

  bool _isUnder30Minutes(String deliveryTime) {
    if (deliveryTime.trim().isEmpty) {
      return false;
    }

    final matches = RegExp(r'\d+').allMatches(deliveryTime);

    if (matches.isEmpty) {
      return false;
    }

    final minutes = matches
        .map((match) => int.tryParse(match.group(0)!))
        .whereType<int>()
        .toList();

    if (minutes.isEmpty) {
      return false;
    }

    final maximumMinutes = minutes.reduce((a, b) => a > b ? a : b);

    return maximumMinutes <= 30;
  }

  // ========================================================================
  // OPEN FILTER
  // ========================================================================

  void _openFilter({
    required String title,
    required String emptyMessage,
    required IconData emptyIcon,
    required bool Function(RestaurantModel) matches,
  }) {
    Haptics.light();

    context.push(
      RouteNames.homeFilter,
      extra: HomeFilterArgs(
        title: title,
        emptyMessage: emptyMessage,
        emptyIcon: emptyIcon,
        matches: matches,
      ),
    );
  }

  // ========================================================================
  // SECTION HEADER
  // ========================================================================

  Widget _buildSectionHeader({
    required String title,
    required VoidCallback? onViewAll,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ================================================================
          // TITLE
          // ================================================================

          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),

          if (onViewAll != null) ...[
            SizedBox(width: 10.w),

            InkWell(
              borderRadius: BorderRadius.circular(8.r),
              onTap: () {
                Haptics.light();
                onViewAll();
              },
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 2.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.viewAll,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 16.sp,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========================================================================
  // RESTAURANT FILTER
  // ========================================================================

  List<RestaurantModel> _filterRestaurants(List<RestaurantModel> restaurants) {
    final isVegOnly = ref.watch(vegFilterProvider);

    var list = restaurants;

    // ================================================================
    // VEG FILTER
    // ================================================================

    if (isVegOnly) {
      list = list.where((restaurant) => restaurant.isPureVeg).toList();
    }

    // ================================================================
    // ALL / MORE
    // ================================================================

    if (_selectedCategory == 'All' || _selectedCategory == 'More') {
      return list;
    }

    // ================================================================
    // CATEGORY FILTER
    // ================================================================

    final query = _selectedCategory.toLowerCase().trim();

    final singular = query.endsWith('s')
        ? query.substring(0, query.length - 1)
        : query;

    return list.where((restaurant) {
      final haystack =
          '${restaurant.name} '
                  '${restaurant.tags.join(' ')} '
                  '${restaurant.restaurantTags.join(' ')}'
              .toLowerCase();

      return haystack.contains(query) || haystack.contains(singular);
    }).toList();
  }

  // ========================================================================
  // OUT OF SERVICE (NO DELIVERY ZONE) VIEW
  // ========================================================================

  Future<void> _navigateToChangeLocation(BuildContext context) async {
    Haptics.light();
    await context.push(RouteNames.addAddress);
    if (!mounted) return;
    await _refreshAll();
  }

  Future<void> _refreshAll() async {
    await ref.read(addressViewModelProvider.notifier).load();
    await ref.read(zoneViewModelProvider.notifier).refresh();
    ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants();
    await ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
  }

  Widget _buildOutOfServiceContent(BuildContext context, bool isDark) {
    final addresses = ref.watch(addressViewModelProvider);
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Column(
      children: [
        _buildOutOfServiceTopBar(context, isDark),
        Expanded(
          child: AppRefreshIndicator(
            onRefresh: _refreshAll,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(height: 48.h),

                    // Tap-able Location Pin Icon with ripple & interactive feedback
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _navigateToChangeLocation(context),
                      child: Container(
                        width: 110.r,
                        height: 110.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.18),
                              blurRadius: 28,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.location_off_rounded,
                            size: 52.sp,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 24.h),

                    // Heading
                    Text(
                      "We don't deliver here",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // Subtitle
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        "We are currently not serving in this location. Please change your location to explore restaurants in your area.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                          color: secondaryColor,
                        ),
                      ),
                    ),

                    SizedBox(height: 32.h),

                    // Change Location Primary Button
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        padding: EdgeInsets.symmetric(
                          horizontal: 32.w,
                          vertical: 14.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      onPressed: () => _navigateToChangeLocation(context),
                      icon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                      label: Text(
                        'Change Location',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Optional Saved Addresses Button
                    if (addresses.isNotEmpty) ...[
                      SizedBox(height: 14.h),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: AppColors.primary.withValues(alpha: 0.7),
                            width: 1.4,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        onPressed: () async {
                          Haptics.light();
                          await showSavedAddressesSheet(context);
                          await _refreshAll();
                        },
                        icon: const Icon(Icons.bookmark_outline_rounded, size: 18),
                        label: Text(
                          'Choose from Saved Addresses',
                          style: TextStyle(
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: 40.h),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOutOfServiceTopBar(BuildContext context, bool isDark) {
    final addresses = ref.watch(addressViewModelProvider);
    final savedAddress = addresses.isEmpty
        ? null
        : (addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => addresses.first,
          ));
    final nearYouState = ref.watch(nearYouViewModelProvider);

    String titleText = 'Select Location';
    String areaText = 'Tap to set delivery location';

    if (savedAddress != null) {
      final isHomeOrOffice = savedAddress.type.toLowerCase() == 'home' ||
          savedAddress.type.toLowerCase() == 'office' ||
          savedAddress.title.toLowerCase() == 'home' ||
          savedAddress.title.toLowerCase() == 'office';

      String buildingPart = savedAddress.building.trim();
      final streetPart = savedAddress.street.trim();
      final cityPart = savedAddress.city.trim();

      final parts = <String>[];
      if (buildingPart.isNotEmpty) parts.add(buildingPart);
      if (streetPart.isNotEmpty &&
          streetPart.toLowerCase() != buildingPart.toLowerCase()) {
        parts.add(streetPart);
      }
      if (cityPart.isNotEmpty &&
          cityPart.toLowerCase() != streetPart.toLowerCase()) {
        parts.add(cityPart);
      }

      // Deduplicate parts cleanly without repeating names
      final cleanTokens = <String>[];
      final candidateParts = parts.isNotEmpty
          ? parts
          : savedAddress.fullAddress.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

      for (final t in candidateParts) {
        if (!cleanTokens.any((c) => c.toLowerCase() == t.toLowerCase())) {
          cleanTokens.add(t);
        }
      }
      final cleanCombined = cleanTokens.join(', ');

      if (isHomeOrOffice) {
        titleText = savedAddress.type.isNotEmpty
            ? savedAddress.type
            : savedAddress.title;
        areaText = cleanCombined.isNotEmpty ? cleanCombined : titleText;
      } else {
        titleText = savedAddress.title.isNotEmpty &&
                savedAddress.title.toLowerCase() != 'other'
            ? savedAddress.title
            : (buildingPart.isNotEmpty
                ? buildingPart
                : (streetPart.isNotEmpty ? streetPart : 'My Address'));
        areaText = cleanCombined;
      }
    } else if (nearYouState.location != null &&
        nearYouState.location!.isSuccess) {
      final loc = nearYouState.location!;
      titleText = loc.area.isNotEmpty
          ? loc.area
          : (loc.street.isNotEmpty
              ? loc.street
              : (loc.building.isNotEmpty ? loc.building : (loc.city.isNotEmpty ? loc.city : 'Current Location')));

      final cleanParts = <String>[];
      for (final seg in [loc.building, loc.street, loc.city]) {
        final trimmed = seg.trim();
        if (trimmed.isNotEmpty &&
            !cleanParts.any((c) => c.toLowerCase() == trimmed.toLowerCase()) &&
            trimmed.toLowerCase() != titleText.toLowerCase()) {
          cleanParts.add(trimmed);
        }
      }
      areaText = cleanParts.isNotEmpty
          ? cleanParts.join(', ')
          : (loc.fullAddress.isNotEmpty
              ? loc.fullAddress
              : 'Live GPS Detected');
    }

    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _navigateToChangeLocation(context),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                titleText,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: textColor,
                              size: 18.sp,
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          areaText,
                          style: TextStyle(
                            color: secondaryColor,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreMoreSparklePainter extends CustomPainter {
  final Color color;
  const _ExploreMoreSparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final ox = size.width * 0.2;
    final oy = size.height * 0.5;

    // Top ray: pointing up-right
    canvas.drawLine(
      Offset(ox + 4, oy - 2),
      Offset(ox + 12, oy - 7),
      paint,
    );
    // Middle ray: pointing right
    canvas.drawLine(
      Offset(ox + 6, oy),
      Offset(ox + 14, oy),
      paint,
    );
    // Bottom ray: pointing down-right
    canvas.drawLine(
      Offset(ox + 4, oy + 2),
      Offset(ox + 12, oy + 7),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ExploreMoreSparklePainter oldDelegate) =>
      oldDelegate.color != color;
}