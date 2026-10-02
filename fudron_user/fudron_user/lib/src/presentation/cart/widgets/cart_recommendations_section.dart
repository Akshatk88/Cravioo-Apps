import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../common_widgets/smart_image.dart';
import '../../home/viewmodels/veg_filter_provider.dart';
import '../../../di/restaurant_providers.dart';
import '../../restaurant/viewmodels/restaurant_detail_viewmodel.dart';
import '../../restaurant/widgets/food_detail_sheet.dart';
import '../animations/add_to_cart_animation.dart';
import '../viewmodels/cart_viewmodel.dart';

class CartRecommendationsSection extends ConsumerStatefulWidget {
  final String restaurantId;
  final GlobalKey? targetCartKey;

  const CartRecommendationsSection({
    super.key,
    required this.restaurantId,
    this.targetCartKey,
  });

  @override
  ConsumerState<CartRecommendationsSection> createState() => _CartRecommendationsSectionState();
}

class _CartRecommendationsSectionState extends ConsumerState<CartRecommendationsSection> {
  int _selectedTabIndex = 0;
  int _categoryCount = 0;
  Timer? _autoScrollTimer;
  final _tabScrollController = ScrollController();
  final _tabKeys = <GlobalKey>[];

  static const _autoScrollInterval = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_autoScrollInterval, (_) {
      if (!mounted || _categoryCount < 2) return;
      _selectTab((_selectedTabIndex + 1) % _categoryCount);
    });
  }

  void _selectTab(int index) {
    setState(() => _selectedTabIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _tabKeys.length) return;
      final tabContext = _tabKeys[index].currentContext;
      if (tabContext != null) {
        Scrollable.ensureVisible(
          tabContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          alignment: 0.5,
        );
      }
    });
  }

  void _onUserSelected(int index) {
    Haptics.light();
    _selectTab(index);
    // A manual pick shouldn't get immediately overridden by an auto-advance
    // that was already mid-countdown, so give the user's choice a full
    // interval before auto-scroll resumes.
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _tabScrollController.dispose();
    super.dispose();
  }

  /// Upsell strip, not a menu: a handful of suggestions is the point, and the
  /// cap is what makes building the row eagerly (for IntrinsicHeight) cheap.
  static const int _maxCards = 12;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;

    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurantId));
    final isVegOnly = ref.watch(vegFilterProvider);

    return menuAsync.when(
      data: (items) {
        final rawItems = isVegOnly ? items.where((f) => f.isVeg).toList() : items;
        if (rawItems.isEmpty) return const SizedBox.shrink();

        // Categories come from the menu itself via the same classifier the
        // restaurant screen uses, rather than a hardcoded Popular/Beverages/
        // Sides trio with its own private keyword lists. Those lists had drifted
        // from the real ones, which is why picking a category could show items
        // that plainly did not belong to it.
        final service = ref.read(restaurantServiceProvider);
        final categories = service
            .extractCategories(rawItems)
            .where((c) => c.id != 'all')
            .toList();
        if (categories.isEmpty) return const SizedBox.shrink();
        final tabIndex = _selectedTabIndex % categories.length;
        _categoryCount = categories.length;
        while (_tabKeys.length < categories.length) {
          _tabKeys.add(GlobalKey());
        }

        final displayItems = service.filterMenu(
          items: rawItems,
          query: '',
          categoryId: categories[tabIndex].id,
          isVegOnly: isVegOnly,
          isNonVegOnly: false,
          isMinRating4: false,
        );
        // No silent fallback to the full menu: showing everything under a
        // category the user explicitly picked is exactly what made the filters
        // look broken. extractCategories only emits non-empty categories, so
        // this is a guard rather than an expected state.
        if (displayItems.isEmpty) return const SizedBox.shrink();
        final shown = displayItems.take(_maxCards).toList();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with circular icon and section title
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : const Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Complete your meal with',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Category Tabs Row (Scrollable with proper spacing and padding)
              SingleChildScrollView(
                controller: _tabScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F4F7),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(categories.length, (index) {
                      final isSelected = tabIndex == index;
                      return Padding(
                        key: _tabKeys[index],
                        padding: EdgeInsets.only(right: index == categories.length - 1 ? 0 : 4),
                        child: GestureDetector(
                          onTap: () => _onUserSelected(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF383838) : Colors.white)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isSelected && !isDark
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? (isDark ? Colors.white : const Color(0xFF1D2939))
                                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                ),
                                child: Text(
                                  categories[index].name,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Horizontal Scrollable Products List
              //
              // Sized to the tallest card rather than a fixed 222: the cards
              // come in around 190, and the difference was showing up as a band
              // of empty space under the row.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                clipBehavior: Clip.none,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const SizedBox(width: 12),
                        _RecommendationProductCard(
                          // Keyed by item, not position. A horizontal list
                          // otherwise reuses the element at each index across a
                          // category switch, so card 0 keeps its old image until
                          // the new one decodes — the flicker on every change.
                          key: ValueKey(shown[i].id),
                          food: shown[i],
                          targetCartKey: widget.targetCartKey,
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          isDark: isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SkeletonFoodItemCard(),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _RecommendationProductCard extends ConsumerStatefulWidget {
  final FoodModel food;
  final GlobalKey? targetCartKey;
  final Color textColor;
  final Color secondaryTextColor;
  final bool isDark;

  const _RecommendationProductCard({
    super.key,
    required this.food,
    required this.targetCartKey,
    required this.textColor,
    required this.secondaryTextColor,
    required this.isDark,
  });

  @override
  ConsumerState<_RecommendationProductCard> createState() => _RecommendationProductCardState();
}

class _RecommendationProductCardState extends ConsumerState<_RecommendationProductCard> {
  final GlobalKey _imageKey = GlobalKey();

  void _onAddToCart() {
    Haptics.light();
    final targetKey = widget.targetCartKey;
    if (targetKey == null || targetKey.currentContext == null) {
      ref.read(cartViewModelProvider.notifier).addItem(widget.food);
      Haptics.medium();
      return;
    }

    AddToCartAnimation.run(
      context: context,
      startKey: _imageKey,
      endKey: targetKey,
      imageUrl: widget.food.imageUrl,
      onAnimationComplete: () {
        ref.read(cartViewModelProvider.notifier).addItem(widget.food);
        Haptics.medium();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final vegColor = food.isVeg ? const Color(0xFF2E8B57) : const Color(0xFFB33A3A);

    return GestureDetector(
      onTap: () {
        Haptics.light();
        FoodDetailSheet.show(context, food);
      },
      child: SizedBox(
        width: 125,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food Image with Veg/Non-Veg badge and floating "+" button
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Image container
                ClipRRect(
                  key: _imageKey,
                  borderRadius: BorderRadius.circular(14),
                  child: SmartImage(
                    url: food.imageUrl,
                    category: ImageCategory.food,
                    width: 125,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),

                // Veg / Non-Veg Indicator at Bottom Left
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        border: Border.all(color: vegColor, width: 1.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: vegColor,
                            shape: food.isVeg ? BoxShape.circle : BoxShape.rectangle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating Plus / Add Button at Bottom Right
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      onTap: _onAddToCart,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Product Name
            Text(
              food.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.textColor,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 3),

            // Price
            Text(
              '₹${food.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: widget.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
