import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/food_model.dart';
import '../../data/models/restaurant_model.dart';
import '../branding/app_colors.dart';
import '../common_widgets/empty_state_widget.dart';
import '../common_widgets/skeleton_loading.dart';
import '../common_widgets/smart_image.dart';
import '../home/viewmodels/home_viewmodel.dart';
import '../home/widgets/restaurant_card.dart';
import '../restaurant/widgets/food_detail_sheet.dart';
import 'viewmodels/favorites_viewmodel.dart';

/// Favorites Screen with tabs for Restaurants & Dishes.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final nearbyRestaurants =
        ref.watch(homeViewModelProvider).nearbyRestaurants.asData?.value ??
            const <RestaurantModel>[];
    final favoritesAsync = ref.watch(favoritesViewModelProvider);

    if (favoritesAsync.isLoading && !favoritesAsync.hasValue) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SkeletonRestaurantList(count: 3),
          ),
        ),
      );
    }

    final favState = favoritesAsync.value ?? const FavoritesState();

    // 1. Combine restaurants from nearby + backend favorites
    final Map<String, RestaurantModel> restaurantMap = {};
    for (final r in nearbyRestaurants) {
      restaurantMap[r.id] = r;
    }
    for (final r in favState.restaurants) {
      restaurantMap[r.id] = r;
    }

    final favRestaurants = restaurantMap.values
        .where((r) => favState.restaurantIds.contains(r.id))
        .toList();

    // 2. Favorite Foods
    final favFoods = favState.foods;

    final totalCount = favRestaurants.length + favFoods.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  _buildHeader(context, totalCount, textColor, secondaryColor),
                  const SizedBox(height: 16),
                  Container(
                    height: 42.h,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: secondaryColor,
                      labelStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: 'Restaurants (${favRestaurants.length})'),
                        Tab(text: 'Dishes (${favFoods.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Restaurants Tab
                  favRestaurants.isEmpty
                      ? const EmptyStateWidget(
                          title: 'No favorite restaurants',
                          subtitle:
                              'Tap the bookmark on any restaurant to save it here for quick access later.',
                          icon: Icons.bookmark_border_rounded,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 12, bottom: 24),
                          itemCount: favRestaurants.length,
                          itemBuilder: (context, index) {
                            return RestaurantCard(
                              restaurant: favRestaurants[index],
                              index: index,
                            );
                          },
                        ),

                  // Dishes Tab
                  favFoods.isEmpty
                      ? const EmptyStateWidget(
                          title: 'No favorite dishes',
                          subtitle:
                              'Tap the heart on any food item to save it here for fast ordering.',
                          icon: Icons.fastfood_rounded,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: favFoods.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final food = favFoods[index];
                            return _FavoriteFoodCard(
                              food: food,
                              isDark: isDark,
                              onTap: () {
                                Haptics.light();
                                FoodDetailSheet.show(context, food);
                              },
                              onToggleFavorite: () {
                                Haptics.medium();
                                ref
                                    .read(favoritesViewModelProvider.notifier)
                                    .toggleFood(food.id, food);
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, int count, Color textColor, Color secondaryColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Favorites',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Your saved favorites',
                    style: TextStyle(fontSize: 13.sp, color: secondaryColor),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                    size: 14,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoriteFoodCard extends StatelessWidget {
  final FoodModel food;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _FavoriteFoodCard({
    required this.food,
    required this.isDark,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: SmartImage(
                  url: food.imageUrl,
                  category: ImageCategory.food,
                  width: 80.w,
                  height: 80.h,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: food.isVeg ? Colors.green : Colors.red,
                          size: 12,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            food.name,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '₹${food.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (food.description.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        food.description,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: secondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: onToggleFavorite,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
