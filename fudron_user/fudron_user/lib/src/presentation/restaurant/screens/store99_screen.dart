import '../../common_widgets/app_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../../domain/model/store99_product.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../cart/widgets/floating_view_cart_bar.dart';
import '../../common_widgets/collapsing_header_delegate.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../common_widgets/smart_image.dart';
import '../../home/viewmodels/veg_filter_provider.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/store99_state.dart';
import '../viewmodels/store99_viewmodel.dart';
import '../widgets/food_detail_sheet.dart';

/// The 99 Store promo landing screen.
///
/// Integrated with the app's core design system ([AppColors], Material 3,
/// theme-aware Light/Dark modes, card elevations, typography, and micro-interactions).
class Store99Screen extends ConsumerStatefulWidget {
  const Store99Screen({super.key});

  @override
  ConsumerState<Store99Screen> createState() => _Store99ScreenState();
}

class _Store99ScreenState extends ConsumerState<Store99Screen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();
  final Map<String, GlobalKey> _dishImageKeys = {};

  // Flips once the sticky header has mostly collapsed, so the status bar
  // icon color can switch from light (over the banner) to dark (over the
  // plain background), mirroring Home's behavior.
  bool _headerCollapsed = false;

  // Sticky header geometry: the back/search icon row + cuisines block travel
  // together as one fixed-height block from their original (floating-over-
  // the-banner) position up to a pinned spot below the status bar — the
  // same mechanic Home uses for its search bar + categories.
  double get _iconRowHeight => 56.h;
  double get _titleHeight => 24.h;
  double get _cuisinesRowHeight => 96.h;
  double get _blockInnerGap => 10.h;
  double get _stickyBlockHeight =>
      _iconRowHeight +
      _blockInnerGap +
      _titleHeight +
      _blockInnerGap +
      _cuisinesRowHeight;
  double get _bannerToBlockOverlap => 20.h;
  double get _collapsedTopPadding => 8.h;
  double get _shadowRoom => 8.h;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(store99ViewModelProvider.notifier).loadMoreProducts();
    }
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = screenWidth * 1000 / 1600;
    final headerRange =
        bannerHeight - _bannerToBlockOverlap - _collapsedTopPadding;
    final collapsed = _scrollController.offset > headerRange * 0.7;
    if (collapsed != _headerCollapsed) {
      setState(() => _headerCollapsed = collapsed);
    }
  }

  Future<void> _handleFirstAddToCart({
    required String imageKeyId,
    required FoodModel food,
  }) async {
    Haptics.light();
    await addFoodToCart(context, ref, food);
  }

  int _getQuantity(CartState cartState, String productId) {
    for (final item in cartState.items) {
      if (item.food.id == productId) return item.quantity;
    }
    return 0;
  }

  String? _getCartItemId(CartState cartState, String productId) {
    for (final item in cartState.items) {
      if (item.food.id == productId) return item.id;
    }
    return null;
  }

  void _onProductTap(Store99Product product) {
    Haptics.light();
    FoodDetailSheet.show(
      context,
      product.toFoodModel(),
      restaurantName: product.restaurantName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final storeState = ref.watch(store99ViewModelProvider);
    final cartState = ref.watch(cartViewModelProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final topInset = MediaQuery.of(context).padding.top;
    // The header image has a fixed 1600x1000 intrinsic aspect ratio (see
    // _buildBannerImage), so its rendered height is deterministic from the
    // screen width alone — no need to measure it after the fact.
    final bannerHeight = screenWidth * 1000 / 1600;
    final expandedBlockTop = bannerHeight - _bannerToBlockOverlap;
    final collapsedBlockTop = topInset + _collapsedTopPadding;
    final expandedHeaderExtent =
        expandedBlockTop + _stickyBlockHeight + _shadowRoom;
    final collapsedHeaderExtent =
        collapsedBlockTop + _stickyBlockHeight + _shadowRoom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (_headerCollapsed && !isDark)
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child:
                        storeState.isLoading && storeState.exploreDishes.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : AppRefreshIndicator(
                            onRefresh: () async {
                              await ref
                                  .read(store99ViewModelProvider.notifier)
                                  .loadInitialData();
                            },
                            child: CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                // Hero banner + sticky back/search row & cuisines
                                // — the banner fades/collapses on scroll-up, and
                                // the icon row + cuisines block sticks to the
                                // top once pinned, exactly like Home.
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
                                    bannerDriftUp: 20.h,
                                    banner: _buildBannerImage(),
                                    stickyBlock: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          height: _iconRowHeight,
                                          child: _buildIconRow(context, isDark),
                                        ),
                                        SizedBox(height: _blockInnerGap),
                                        SizedBox(
                                          height: _titleHeight,
                                          child: _buildSectionTitle(
                                            context,
                                            'Popular Cuisines',
                                            isDark,
                                            onViewAll:
                                                storeState.cuisines.isEmpty
                                                ? null
                                                : () => _showAllCuisines(
                                                    context,
                                                    storeState,
                                                    isDark,
                                                  ),
                                          ),
                                        ),
                                        SizedBox(height: _blockInnerGap),
                                        SizedBox(
                                          height: _cuisinesRowHeight,
                                          child: _buildCuisines(
                                            context,
                                            storeState,
                                            isDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: EdgeInsets.only(bottom: 120.h),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(height: 16.h),

                                        // Quick Delivery — only genuinely
                                        // eligible items (isQuickDelivery set
                                        // by the restaurant), never a
                                        // heuristic guess off prep-time text.
                                        if (storeState.exploreDishes.any(
                                          (d) => d.isQuickDelivery,
                                        )) ...[
                                          _buildSectionTitle(
                                            context,
                                            'Quick Delivery',
                                            isDark,
                                          ),
                                          SizedBox(height: 14.h),
                                          _buildQuickDeliveryDishes(
                                            context,
                                            storeState,
                                            cartState,
                                            isDark,
                                          ),
                                          SizedBox(height: 24.h),
                                        ],

                                        // Trending dishes
                                        if (storeState
                                            .trendingDishes
                                            .isNotEmpty) ...[
                                          _buildSectionTitle(
                                            context,
                                            'Trending dishes near you',
                                            isDark,
                                          ),
                                          SizedBox(height: 14.h),
                                          _buildTrendingDishes(
                                            context,
                                            storeState,
                                            cartState,
                                            isDark,
                                          ),
                                          SizedBox(height: 24.h),
                                        ],

                                        // Top Brands
                                        if (storeState.brands.isNotEmpty) ...[
                                          _buildSectionTitle(
                                            context,
                                            'Big Savings with Top Brands',
                                            isDark,
                                            onViewAll: () => _showAllBrands(
                                              context,
                                              storeState,
                                              isDark,
                                            ),
                                          ),
                                          SizedBox(height: 14.h),
                                          _buildBrands(
                                            context,
                                            storeState,
                                            isDark,
                                          ),
                                          SizedBox(height: 28.h),
                                        ],

                                        // Explore Grid
                                        _buildSectionTitle(
                                          context,
                                          'Explore ₹149 Meals',
                                          isDark,
                                        ),
                                        SizedBox(height: 14.h),
                                        _buildExploreGrid(
                                          context,
                                          storeState,
                                          cartState,
                                          isDark,
                                        ),

                                        // Pagination
                                        if (storeState.isLoadingMore)
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                              vertical: 20.h,
                                              horizontal: 20.w,
                                            ),
                                            child: const SkeletonFoodItemCard(),
                                          ),

                                        SizedBox(height: 20.h),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),

              // Floating View Cart Bar
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
    );
  }

  // ==================== HEADER ====================

  Widget _buildBannerImage() {
    return AspectRatio(
      aspectRatio: 1600 / 1000,
      child: Image.asset(
        'assets/images/new.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primary, AppColors.primaryButton],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconRow(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          _buildCircleIconButton(
            icon: Icons.arrow_back,
            isDark: isDark,
            onTap: () {
              Haptics.light();
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.home);
              }
            },
          ),
          SizedBox(width: 10.w),
          Expanded(child: _buildSearchBar(context, isDark)),
        ],
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          shape: BoxShape.circle,
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.shadow1,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Icon(
          icon,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
          size: 20.sp,
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () {
        Haptics.light();
        context.push(RouteNames.search);
      },
      child: Container(
        height: 40.r,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.shadow1,
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              size: 20.sp,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                "Search for '149' meals...",
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== SECTIONS ====================

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    bool isDark, {
    VoidCallback? onViewAll,
  }) {
    final theme = Theme.of(context);
    final titleStyle =
        theme.textTheme.displaySmall?.copyWith(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ) ??
        TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: titleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onViewAll != null)
            GestureDetector(
              onTap: () {
                Haptics.light();
                onViewAll();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.only(left: 8.w),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18.sp,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Full list for a horizontally-scrolling section.
  ///
  /// A sheet rather than a pushed route: these lists are short and selecting an
  /// entry filters the page underneath, so returning straight to it is the
  /// point. A new route would need its own copy of that filter wiring.
  void _showAllSheet({
    required BuildContext context,
    required String title,
    required bool isDark,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 16.h,
                    crossAxisSpacing: 12.w,
                    childAspectRatio: 0.78,
                  ),
                  itemCount: itemCount,
                  itemBuilder: itemBuilder,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllCuisines(
    BuildContext context,
    Store99State storeState,
    bool isDark,
  ) {
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    _showAllSheet(
      context: context,
      title: 'All Cuisines',
      isDark: isDark,
      itemCount: storeState.cuisines.length,
      itemBuilder: (ctx, index) {
        final cuisine = storeState.cuisines[index];
        final isSelected = cuisine.id == storeState.selectedCuisineId;
        return GestureDetector(
          onTap: () {
            Haptics.light();
            ref
                .read(store99ViewModelProvider.notifier)
                .selectCuisine(cuisine.id);
            Navigator.pop(ctx);
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: _placeholderImage(
                  assetPath: cuisine.imagesPath,
                  fallbackIcon: Icons.restaurant,
                  height: 58.r,
                  width: 58.r,
                  shape: BoxShape.circle,
                  background: Colors.transparent,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 6.h),
              Flexible(
                child: Text(
                  cuisine.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: isSelected ? AppColors.primary : secondaryTextColor,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAllBrands(
    BuildContext context,
    Store99State storeState,
    bool isDark,
  ) {
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    _showAllSheet(
      context: context,
      title: 'All Brands',
      isDark: isDark,
      itemCount: storeState.brands.length,
      itemBuilder: (ctx, index) {
        final brand = storeState.brands[index];
        return GestureDetector(
          onTap: () {
            Haptics.light();
            Navigator.pop(ctx);
            if (brand.restaurant != null) {
              context.push(
                RouteNames.restaurantDetail,
                extra: brand.restaurant,
              );
            } else {
              context.push(
                '${RouteNames.restaurantDetail}/${brand.id}',
                extra: {'restaurantId': brand.id},
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _placeholderImage(
                assetPath: brand.imageUrl,
                fallbackIcon: Icons.storefront,
                height: 58.r,
                width: 58.r,
                shape: BoxShape.circle,
                background: isDark ? AppColors.cardDark : const Color(0xFFF5F5F5),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                ),
              ),
              SizedBox(height: 6.h),
              Flexible(
                child: Text(
                  brand.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.sp, color: secondaryTextColor),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCuisines(
    BuildContext context,
    Store99State storeState,
    bool isDark,
  ) {
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SizedBox(
      height: 96.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: storeState.cuisines.length,
        separatorBuilder: (context, index) => SizedBox(width: 12.w),
        itemBuilder: (context, index) {
          final cuisine = storeState.cuisines[index];
          final isSelected = cuisine.id == storeState.selectedCuisineId;

          return GestureDetector(
            onTap: () {
              Haptics.light();
              ref
                  .read(store99ViewModelProvider.notifier)
                  .selectCuisine(cuisine.id);
            },
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(3.r),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                    border: isSelected
                        ? Border.all(color: AppColors.primary, width: 2)
                        : Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight,
                            width: 1,
                          ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _placeholderImage(
                        assetPath: cuisine.imagesPath,
                        fallbackIcon: Icons.restaurant,
                        height: 64.r,
                        width: 64.r,
                        shape: BoxShape.circle,
                        background: Colors.transparent,
                        fit: BoxFit.contain,
                      ),
                      if (isSelected)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: EdgeInsets.all(2.r),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 10.sp,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 4.h),
                // Flexible so the label can never overflow the fixed row height
                // when font metrics round up (iOS) or text scale is bumped.
                Flexible(
                  child: Text(
                    cuisine.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickDeliveryDishes(
    BuildContext context,
    Store99State storeState,
    CartState cartState,
    bool isDark,
  ) {
    final isVegOnly = ref.watch(vegFilterProvider);
    final eligibleDishes = storeState.exploreDishes
        .where((d) => d.isQuickDelivery)
        .toList();
    final list = isVegOnly
        ? eligibleDishes.where((d) => d.isVeg).toList()
        : eligibleDishes;

    if (list.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 252.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: list.length,
        separatorBuilder: (context, index) => SizedBox(width: 14.w),
        itemBuilder: (context, index) {
          final dish = list[index];
          return _buildDishCard(
            context,
            dish,
            cartState,
            isDark,
            keyPrefix: 'quick',
          );
        },
      ),
    );
  }

  Widget _buildTrendingDishes(
    BuildContext context,
    Store99State storeState,
    CartState cartState,
    bool isDark,
  ) {
    final isVegOnly = ref.watch(vegFilterProvider);
    final eligibleDishes = storeState.trendingDishes
        .where((d) => d.price <= 149.0)
        .toList();
    final list = isVegOnly
        ? eligibleDishes.where((d) => d.isVeg).toList()
        : eligibleDishes;

    if (list.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 252.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: list.length,
        separatorBuilder: (context, index) => SizedBox(width: 14.w),
        itemBuilder: (context, index) {
          final dish = list[index];
          return _buildDishCard(context, dish, cartState, isDark);
        },
      ),
    );
  }

  Widget _buildDishCard(
    BuildContext context,
    Store99Product dish,
    CartState cartState,
    bool isDark, {
    String keyPrefix = 'trend',
  }) {
    final quantity = _getQuantity(cartState, dish.id);
    final cartItemId = _getCartItemId(cartState, dish.id);

    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => _onProductTap(dish),
      child: SizedBox(
        width: 120.w,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _placeholderImage(
                  key: _dishImageKeys.putIfAbsent(
                    '${keyPrefix}_${dish.id}',
                    () => GlobalKey(),
                  ),
                  assetPath: dish.imageUrl,
                  fallbackIcon: Icons.fastfood,
                  height: 115.w,
                  width: 120.w,
                  borderRadius: BorderRadius.circular(16.r),
                  background: isDark
                      ? AppColors.cardDark
                      : const Color(0xFFF0F0F0),
                ),
                Positioned(
                  right: 4.w,
                  bottom: -8.h,
                  child: _buildMorphingQuantityButton(
                    quantity: quantity,
                    isDark: isDark,
                    onAdd: () => _handleFirstAddToCart(
                      imageKeyId: 'trend_${dish.id}',
                      food: dish.toFoodModel(),
                    ),
                    onIncrement: cartItemId == null
                        ? null
                        : () {
                            Haptics.light();
                            ref
                                .read(cartViewModelProvider.notifier)
                                .updateQuantity(cartItemId, quantity + 1);
                          },
                    onDecrement: cartItemId == null
                        ? null
                        : () {
                            Haptics.light();
                            ref
                                .read(cartViewModelProvider.notifier)
                                .updateQuantity(cartItemId, quantity - 1);
                          },
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            SizedBox(
              height: 32.h,
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: EdgeInsets.only(right: 4.w),
                        child: _buildVegIcon(dish.isVeg, size: 10),
                      ),
                    ),
                    TextSpan(text: dish.name),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  height: 1.2,
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (dish.originalPrice != null) ...[
                  Text(
                    '₹${dish.originalPrice!.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: secondaryColor,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  SizedBox(width: 6.w),
                ],
                _buildPriceTag(dish.price.toInt(), fontSize: 11),
              ],
            ),
            SizedBox(height: 8.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.success,
                    size: 11.sp,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    '${dish.rating} (${dish.ratingCount})',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            Divider(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              height: 1,
              thickness: 1,
            ),
            SizedBox(height: 6.h),
            GestureDetector(
              onTap: () {
                Haptics.light();
                if (dish.restaurant != null) {
                  context.push(
                    RouteNames.restaurantDetail,
                    extra: dish.restaurant,
                  );
                } else if (dish.restaurantId.isNotEmpty) {
                  context.push(
                    '${RouteNames.restaurantDetail}/${dish.restaurantId}',
                    extra: {'restaurantId': dish.restaurantId},
                  );
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Text(
                dish.restaurantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.sp, color: secondaryColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrands(
    BuildContext context,
    Store99State storeState,
    bool isDark,
  ) {
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return SizedBox(
      height: 106.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        itemCount: storeState.brands.length,
        separatorBuilder: (context, index) => SizedBox(width: 16.w),
        itemBuilder: (context, index) {
          final brand = storeState.brands[index];
          return GestureDetector(
            onTap: () {
              Haptics.light();
              if (brand.restaurant != null) {
                context.push(
                  RouteNames.restaurantDetail,
                  extra: brand.restaurant,
                );
              } else {
                context.push(
                  '${RouteNames.restaurantDetail}/${brand.id}',
                  extra: {'restaurantId': brand.id},
                );
              }
            },
            child: SizedBox(
              width: 72.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: _placeholderImage(
                      assetPath: brand.imageUrl,
                      fallbackIcon: Icons.storefront,
                      height: 68.r,
                      width: 68.r,
                      shape: BoxShape.circle,
                      background: isDark
                          ? AppColors.cardDark
                          : const Color(0xFFF5F5F5),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFE0E0E0),
                        width: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    brand.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExploreGrid(
    BuildContext context,
    Store99State storeState,
    CartState cartState,
    bool isDark,
  ) {
    final isVegOnly = ref.watch(vegFilterProvider);
    // Repository already filters by price <= ₹149, so no need to re-filter here.
    final exploreList = isVegOnly
        ? storeState.exploreDishes.where((d) => d.isVeg).toList()
        : storeState.exploreDishes;

    if (exploreList.isEmpty && storeState.isLoading) {
      // Show skeleton while loading
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: 6,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 14.w,
            mainAxisSpacing: 18.h,
            childAspectRatio: 0.61,
          ),
          itemBuilder: (context, index) => const SkeletonFoodItemCard(),
        ),
      );
    }

    if (exploreList.isEmpty && !storeState.isLoading) {

      final secondaryColor = isDark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondaryLight;
      final primaryTextColor = isDark
          ? AppColors.textPrimaryDark
          : AppColors.textPrimaryLight;

      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.r,
                height: 64.r,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_offer_outlined,
                  color: AppColors.primary,
                  size: 32.sp,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'No ₹149 deals available right now.',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                'Check back soon for delicious meals at ₹149 or less.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: secondaryColor,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: exploreList.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14.w,
          mainAxisSpacing: 18.h,
          childAspectRatio: 0.61,
        ),
        itemBuilder: (context, index) {
          final dish = exploreList[index];
          return _buildGridDishCard(context, dish, cartState, isDark);
        },
      ),
    );
  }

  Widget _buildGridDishCard(
    BuildContext context,
    Store99Product dish,
    CartState cartState,
    bool isDark,
  ) {
    final quantity = _getQuantity(cartState, dish.id);
    final cartItemId = _getCartItemId(cartState, dish.id);

    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return GestureDetector(
      onTap: () => _onProductTap(dish),
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.shadow1,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
          border: isDark
              ? Border.all(color: AppColors.borderDark, width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: SizedBox(
                height: 120.h,
                width: double.infinity,
                child: _placeholderImage(
                  key: _dishImageKeys.putIfAbsent(
                    'grid_${dish.id}',
                    () => GlobalKey(),
                  ),
                  assetPath: dish.imageUrl,
                  fallbackIcon: Icons.fastfood,
                  height: 120.h,
                  width: double.infinity,
                  background: isDark
                      ? AppColors.surfaceDark
                      : const Color(0xFFF0F0F0),
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: _buildVegIcon(dish.isVeg, size: 11),
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    dish.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: AppColors.success,
                    size: 11.sp,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    '${dish.rating} (${dish.ratingCount})',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (dish.originalPrice != null) ...[
                      Text(
                        '₹${dish.originalPrice!.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: secondaryColor,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    _buildPriceTag(dish.price.toInt(), fontSize: 12),
                  ],
                ),
                const Spacer(),
                _buildGridMorphingButton(
                  quantity: quantity,
                  isDark: isDark,
                  onAdd: () => _handleFirstAddToCart(
                    imageKeyId: 'grid_${dish.id}',
                    food: dish.toFoodModel(),
                  ),
                  onIncrement: cartItemId == null
                      ? null
                      : () {
                          Haptics.light();
                          ref
                              .read(cartViewModelProvider.notifier)
                              .updateQuantity(cartItemId, quantity + 1);
                        },
                  onDecrement: cartItemId == null
                      ? null
                      : () {
                          Haptics.light();
                          ref
                              .read(cartViewModelProvider.notifier)
                              .updateQuantity(cartItemId, quantity - 1);
                        },
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Haptics.light();
                      if (dish.restaurant != null) {
                        context.push(
                          RouteNames.restaurantDetail,
                          extra: dish.restaurant,
                        );
                      } else if (dish.restaurantId.isNotEmpty) {
                        context.push(
                          '${RouteNames.restaurantDetail}/${dish.restaurantId}',
                          extra: {'restaurantId': dish.restaurantId},
                        );
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      dish.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        color: secondaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Text(
                  dish.deliveryTime,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    color: secondaryColor,
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

  // ==================== SHARED WIDGET HELPERS ====================

  Widget _buildMorphingQuantityButton({
    required int quantity,
    required bool isDark,
    required VoidCallback onAdd,
    required VoidCallback? onIncrement,
    required VoidCallback? onDecrement,
  }) {
    final bool hasQty = quantity > 0;
    final double width = hasQty ? 68.w : 28.r;
    final double height = 28.r;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(
          color: hasQty
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: hasQty ? 1.2 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutBack,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: !hasQty
              ? InkWell(
                  key: const ValueKey('circle_plus'),
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(14.r),
                  child: Center(
                    child: Icon(
                      Icons.add,
                      color: AppColors.primary,
                      size: 18.sp,
                    ),
                  ),
                )
              : Row(
                  key: const ValueKey('pill_stepper'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: onDecrement,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14.r),
                        bottomLeft: Radius.circular(14.r),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Icon(
                          Icons.remove,
                          color: AppColors.primary,
                          size: 14.sp,
                        ),
                      ),
                    ),
                    Text(
                      '$quantity',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 12.5.sp,
                      ),
                    ),
                    InkWell(
                      onTap: onIncrement,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(14.r),
                        bottomRight: Radius.circular(14.r),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Icon(
                          Icons.add,
                          color: AppColors.primary,
                          size: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildGridMorphingButton({
    required int quantity,
    required bool isDark,
    required VoidCallback onAdd,
    required VoidCallback? onIncrement,
    required VoidCallback? onDecrement,
  }) {
    final bool hasQty = quantity > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      height: 30.h,
      padding: EdgeInsets.symmetric(horizontal: hasQty ? 6.w : 14.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border.all(
          color: hasQty
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: hasQty ? 1.2 : 1.0,
        ),
        borderRadius: BorderRadius.circular(8.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: !hasQty
              ? InkWell(
                  key: const ValueKey('grid_add_btn'),
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(8.r),
                  child: Center(
                    child: Text(
                      'ADD',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              : Row(
                  key: const ValueKey('grid_pill_stepper'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: onDecrement,
                      borderRadius: BorderRadius.circular(6.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 2.h,
                        ),
                        child: Icon(
                          Icons.remove,
                          color: AppColors.primary,
                          size: 14.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      '$quantity',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    InkWell(
                      onTap: onIncrement,
                      borderRadius: BorderRadius.circular(6.r),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 3.w,
                          vertical: 2.h,
                        ),
                        child: Icon(
                          Icons.add,
                          color: AppColors.primary,
                          size: 14.sp,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVegIcon(bool isVeg, {double size = 10}) {
    final color = isVeg ? const Color(0xFF2E8B57) : const Color(0xFFB33A3A);
    return Container(
      width: size.sp,
      height: size.sp,
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      alignment: Alignment.center,
      child: Container(
        width: (size * 0.4).sp,
        height: (size * 0.4).sp,
        decoration: BoxDecoration(
          color: color,
          shape: isVeg ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }

  Widget _buildPriceTag(int price, {double fontSize = 11}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        '₹$price',
        style: TextStyle(
          fontSize: fontSize.sp,
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _placeholderImage({
    Key? key,
    required String assetPath,
    required IconData fallbackIcon,
    required double height,
    double? width,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
    Color background = const Color(0xFFF5F5F5),
    BoxBorder? border,
    BoxFit fit = BoxFit.cover,
  }) {
    return Container(
      key: key,
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: background,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
        border: border,
      ),
      clipBehavior: Clip.antiAlias,
      child: SmartImage(
        url: assetPath,
        category: ImageCategory.food,
        fit: fit,
        width: width,
        height: height,
      ),
    );
  }
}
