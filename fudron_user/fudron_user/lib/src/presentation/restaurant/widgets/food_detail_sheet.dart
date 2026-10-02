import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/cart_item_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/food_variant.dart';
import '../../../di/catalog_providers.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../common_widgets/smart_image.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';
import '../../home/viewmodels/veg_filter_provider.dart';

import '../../../domain/service/deep_link_service.dart';
import '../../../core/utils/localizations.dart';

/// Selection-indicator style for a customization option row.
enum _SelectionIndicator { radio, checkbox }

/// Premium, fully backend-driven customization bottom sheet.
///
/// Everything shown — variants, add-ons, price, rating, calories — comes
/// straight off [FoodModel] / [FoodAddon]; a section only renders when the
/// backend actually returned data for it. Shown over the current screen
/// (dimmed backdrop supplied by [showModalBottomSheet] itself) so the caller
/// never rebuilds/reloads, and it never navigates to another screen.
class FoodDetailSheet {
  const FoodDetailSheet._();

  static Future<void> show(
    BuildContext context,
    FoodModel food, {
    VoidCallback? onAdded,
    String? restaurantName,
    CartItemModel? existingCartItem,
    bool autoScrollToOptions = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FoodDetailSheetBody(
        food: food,
        onAdded: onAdded,
        restaurantName: restaurantName,
        existingCartItem: existingCartItem,
        autoScrollToOptions: autoScrollToOptions,
      ),
    );
  }
}

class _FoodDetailSheetBody extends ConsumerStatefulWidget {
  final FoodModel food;
  final VoidCallback? onAdded;
  final String? restaurantName;

  /// Set when this sheet was opened to re-customize a line already in the
  /// cart — the variant/add-on selection seeds from it, and saving updates
  /// that line in place instead of adding a new one.
  final CartItemModel? existingCartItem;
  final bool autoScrollToOptions;

  const _FoodDetailSheetBody({
    required this.food,
    this.onAdded,
    this.restaurantName,
    this.existingCartItem,
    this.autoScrollToOptions = false,
  });

  @override
  ConsumerState<_FoodDetailSheetBody> createState() =>
      _FoodDetailSheetBodyState();
}

class _FoodDetailSheetBodyState extends ConsumerState<_FoodDetailSheetBody>
    with SingleTickerProviderStateMixin {
  static const double _minSheetSize = 0.55;
  static const double _initialSheetSize = 0.92;
  static const double _maxSheetSize = 0.95;

  final GlobalKey _variantSectionKey = GlobalKey();
  final GlobalKey _addonSectionKey = GlobalKey();
  late final AnimationController _highlightController;
  late final Animation<double> _highlightAnimation;

  FoodVariant? _selectedVariant;
  final Set<String> _selectedAddonIds = {};
  late final PageController _galleryController;
  int _galleryIndex = 0;
  Timer? _autoSlideTimer;
  Timer? _inactivityTimer;
  bool _isUserInteracting = false;
  final _sheetController = DraggableScrollableController();
  bool _dismissing = false;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _galleryController = PageController();

    _highlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _highlightAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
    ]).animate(
      CurvedAnimation(
        parent: _highlightController,
        curve: Curves.easeInOut,
      ),
    );

    final existing = widget.existingCartItem;
    if (existing != null) {
      _selectedAddonIds.addAll(existing.selectedAddons);
      _quantity = existing.quantity;
    }
    if (widget.food.variants.isNotEmpty) {
      _selectedVariant = existing == null
          ? widget.food.variants.first
          : widget.food.variants.firstWhere(
              (v) => v.name == existing.selectedVariant,
              orElse: () => widget.food.variants.first,
            );
    }
    _sheetController.addListener(_maybeDismissOnDrag);
    if (_galleryImages.length > 1) {
      _startAutoSlideTimer();
    }

    if (widget.autoScrollToOptions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final restaurantAddons =
            ref.read(restaurantAddonsProvider(widget.food.restaurantId)).value ??
                const <FoodAddon>[];
        BuildContext? targetContext;
        if (widget.food.variants.isNotEmpty) {
          targetContext = _variantSectionKey.currentContext;
        } else if (restaurantAddons.isNotEmpty) {
          targetContext = _addonSectionKey.currentContext;
        }

        if (targetContext != null) {
          Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            alignment: 0.1,
          );
          _highlightController.forward(from: 0.0);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _FoodDetailSheetBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.food.id != widget.food.id ||
        oldWidget.food.imageGallery.length != widget.food.imageGallery.length) {
      if (_galleryIndex >= _galleryImages.length) {
        _galleryIndex = 0;
      }
      if (_galleryImages.length > 1) {
        _startAutoSlideTimer();
      } else {
        _cancelTimers();
      }
    }
  }

  void _cancelTimers() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void _startAutoSlideTimer() {
    _cancelTimers();
    final count = _galleryImages.length;
    if (count <= 1 || !mounted || _isUserInteracting) return;

    _autoSlideTimer = Timer.periodic(const Duration(milliseconds: 3200), (timer) {
      if (!mounted || _galleryImages.length <= 1 || _isUserInteracting) {
        timer.cancel();
        return;
      }
      if (_galleryController.hasClients) {
        final nextPage = (_galleryIndex + 1) % _galleryImages.length;
        _galleryController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onUserInteractionStart() {
    _isUserInteracting = true;
    _cancelTimers();
  }

  void _onUserInteractionEnd() {
    if (!_isUserInteracting) return;
    _isUserInteracting = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isUserInteracting && _galleryImages.length > 1) {
        _startAutoSlideTimer();
      }
    });
  }

  /// Lets a strong downward drag past the collapsed size dismiss the sheet,
  /// the way swipe-to-dismiss feels on a native bottom sheet.
  void _maybeDismissOnDrag() {
    if (_dismissing || !_sheetController.isAttached) return;
    if (_sheetController.size <= _minSheetSize + 0.02) {
      _dismissing = true;
      Navigator.of(context).maybePop();
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    _sheetController.removeListener(_maybeDismissOnDrag);
    _sheetController.dispose();
    _cancelTimers();
    _galleryController.dispose();
    super.dispose();
  }

  List<String> get _galleryImages {
    final seen = <String>{};
    final list = <String>[];

    if (widget.food.imageUrl.isNotEmpty) {
      seen.add(widget.food.imageUrl);
      list.add(widget.food.imageUrl);
    }
    for (final url in widget.food.imageGallery) {
      if (url.isNotEmpty && seen.add(url)) {
        list.add(url);
      }
    }
    return list;
  }

  void _toggleAddon(String addonId) {
    setState(() {
      if (_selectedAddonIds.contains(addonId)) {
        _selectedAddonIds.remove(addonId);
      } else {
        _selectedAddonIds.add(addonId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF757575);
    final restaurantAddons =
        ref.watch(restaurantAddonsProvider(food.restaurantId)).value ??
        const <FoodAddon>[];
    final isFavorite = ref.watch(
      favoritesViewModelProvider.select(
        (s) => s.value?.foodIds.contains(food.id) ?? false,
      ),
    );

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _initialSheetSize,
      minChildSize: _minSheetSize,
      maxChildSize: _maxSheetSize,
      snap: true,
      snapSizes: const [_initialSheetSize],
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
          child: Container(
            color: surfaceColor,
            child: Column(
              children: [
                _buildDragHandle(isDark),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    children: [
                      _buildImageHeader(food, isFavorite),
                      SizedBox(height: 20.h),
                      _buildProductInfo(
                        food,
                        textColor,
                        secondaryTextColor,
                        isDark,
                      ),
                      if (food.variants.isNotEmpty) ...[
                        SizedBox(height: 22.h),
                        _buildVariantGroup(
                          food,
                          textColor,
                          secondaryTextColor,
                          isDark,
                        ),
                      ],
                      if (restaurantAddons.isNotEmpty) ...[
                        SizedBox(height: 22.h),
                        _buildAddonGroup(
                          textColor,
                          secondaryTextColor,
                          isDark,
                          restaurantAddons,
                        ),
                      ],
                      SizedBox(height: 16.h),
                    ],
                  ),
                ),
                _buildStickyBottomBar(
                  food,
                  surfaceColor,
                  isDark,
                  restaurantAddons,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle(bool isDark) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10.h),
        width: 40.w,
        height: 4.h,
        decoration: BoxDecoration(
          color: isDark ? Colors.white30 : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2.r),
        ),
      ),
    );
  }

  Widget _buildImageHeader(FoodModel food, bool isFavorite) {
    final images = _galleryImages;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
      child: SizedBox(
        height: 240.h,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24.r),
              child: images.length > 1
                  ? NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification &&
                            notification.dragDetails != null) {
                          _onUserInteractionStart();
                        } else if (notification is ScrollEndNotification) {
                          _onUserInteractionEnd();
                        }
                        return false;
                      },
                      child: PageView.builder(
                        controller: _galleryController,
                        itemCount: images.length,
                        onPageChanged: (index) =>
                            setState(() => _galleryIndex = index),
                        itemBuilder: (context, index) => SmartImage(
                          url: images[index],
                          category: ImageCategory.food,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 240.h,
                        ),
                      ),
                    )
                  : SmartImage(
                      url: images.isNotEmpty ? images.first : food.imageUrl,
                      category: ImageCategory.food,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 240.h,
                    ),
            ),
            Positioned(
              top: 12.h,
              left: 12.w,
              child: _buildCircleIconButton(
                Icons.close_rounded,
                Colors.black87,
                () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              top: 12.h,
              right: 12.w,
              child: Row(
                children: [
                  _buildCircleIconButton(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    isFavorite ? AppColors.primary : Colors.black87,
                    () {
                      Haptics.light();
                      ref
                          .read(favoritesViewModelProvider.notifier)
                          .toggleFood(food.id, food);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFavorite
                                  ? 'Removed from favorites'
                                  : 'Added to favorites ❤️',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(width: 8.w),
                  _buildCircleIconButton(
                    Icons.share_rounded,
                    Colors.black87,
                    () async {
                      Haptics.light();
                      try {
                        final text = DeepLinkService.generateProductShareText(
                          productName: food.name,
                          restaurantName: widget.restaurantName,
                          productId: food.id,
                          restaurantId: food.restaurantId,
                        );
                        await SharePlus.instance.share(ShareParams(text: text));
                      } catch (_) {
                        // share_plus not available in this environment — silently ignore
                      }
                    },
                  ),
                ],
              ),
            ),
            if (images.length > 1)
              Positioned(
                right: 12.w,
                bottom: 12.h,
                child: _buildImageBadge(
                  null,
                  '${_galleryIndex + 1} / ${images.length}',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleIconButton(
    IconData icon,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(8.r),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20.sp),
      ),
    );
  }

  Widget _buildImageBadge(IconData? icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.primary, size: 13.sp),
            SizedBox(width: 4.w),
          ],
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillBadge(String label, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: AppColors.primaryTintStrong,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: AppColors.primary),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// Generates a rich, appetizing fallback description based on dish name
  /// and diet type, so the screen is never an empty void even if the restaurant
  /// didn't enter a custom description in the inventory.
  String _fallbackDescription(FoodModel food) {
    final name = food.name.trim();
    final isVeg = food.isVeg;
    if (isVeg) {
      return 'A delightful $name crafted with the finest fresh ingredients — '
          'bursting with authentic flavors and served with love. '
          'Every bite is a wholesome, plant-based experience that satisfies.';
    } else {
      return 'Tender, succulent $name prepared with carefully selected '
          'premium ingredients and aromatic spices. '
          'A rich, indulgent treat for your taste buds — fresh, bold, and utterly satisfying.';
    }
  }

  Widget _buildProductInfo(
    FoodModel food,
    Color textColor,
    Color secondaryTextColor,
    bool isDark,
  ) {
    final effectiveDescription = food.description.isNotEmpty
        ? food.description
        : _fallbackDescription(food);

    // Effective prep time: use preparationTime, fallback to deliveryTime
    final effectivePrepTime = food.preparationTime.trim().isNotEmpty
        ? food.preparationTime.trim()
        : (food.deliveryTime.trim().isNotEmpty ? food.deliveryTime.trim() : null);

    final effectiveRestaurant = widget.restaurantName?.trim().isNotEmpty == true
        ? widget.restaurantName!
        : (food.restaurantName.trim().isNotEmpty ? food.restaurantName.trim() : null);

    final dietLabel = food.isVeg ? 'Pure Veg 🥗' : 'Non-Veg 🍗';
    final cardBg = isDark ? AppColors.cardDark : const Color(0xFFF8F8F8);
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFEEEEEE);

    final badges = [
      if (food.isPopular)
        _pillBadge('Bestseller', Icons.local_fire_department_rounded),
      if (food.isSpicy) _pillBadge('Spicy 🌶️', Icons.whatshot_rounded),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Restaurant pill badge ──
          if (effectiveRestaurant != null) ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: AppColors.primaryTintStrong,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_rounded,
                      size: 11.sp, color: AppColors.primary),
                  SizedBox(width: 4.w),
                  Text(
                    effectiveRestaurant,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
          ],

          // ── Name + Veg icon + Price ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              food.isVeg ? _buildVegIcon() : _buildNonVegIcon(),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  food.name,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.2,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${food.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (food.originalPrice != null) ...[
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Text(
                          '₹${food.originalPrice!.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTintStrong,
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            '${food.discountPercent}% OFF',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),

          // ── Badges row (Bestseller, Spicy) ──
          if (badges.isNotEmpty) ...[
            SizedBox(height: 10.h),
            Wrap(spacing: 8.w, runSpacing: 8.h, children: badges),
          ],

          // ── Diet + Prep time info pills ──
          SizedBox(height: 12.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              _infoPill(dietLabel,
                  food.isVeg ? const Color(0xFF008A45) : const Color(0xFFE23744)),
              if (effectivePrepTime != null)
                _infoPill('⏱ $effectivePrepTime', secondaryTextColor),
              if (food.categoryName.trim().isNotEmpty)
                _infoPill('📂 ${food.categoryName.trim()}', secondaryTextColor),
              if (food.calories > 0)
                _infoPill('🔥 ${food.calories} Kcal', secondaryTextColor),
              if (food.rating > 0)
                _infoPill(
                  '⭐ ${food.rating.toStringAsFixed(1)}'
                  '${food.reviewCount > 0 ? ' (${food.reviewCount})' : ''}',
                  AppColors.rating,
                ),
            ],
          ),

          // ── About this dish card ──
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded,
                        size: 14.sp, color: AppColors.primary),
                    SizedBox(width: 6.w),
                    Text(
                      'About this dish',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  effectiveDescription,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: secondaryTextColor,
                    height: 1.55,
                  ),
                ),
                // tags if any
                if (food.tags.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: food.tags.map((tag) {
                      return Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTintStrong,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // ── Nutrition / Allergies ──
          if (food.nutrition.isNotEmpty || food.allergies.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (food.nutrition.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.lunch_dining_rounded,
                            size: 14.sp, color: AppColors.primary),
                        SizedBox(width: 6.w),
                        Text(
                          'Nutrition',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    ...food.nutrition.map((n) => Padding(
                          padding: EdgeInsets.only(bottom: 2.h),
                          child: Text(
                            '• $n',
                            style: TextStyle(
                                fontSize: 12.sp, color: secondaryTextColor),
                          ),
                        )),
                  ],
                  if (food.allergies.isNotEmpty) ...[
                    if (food.nutrition.isNotEmpty) SizedBox(height: 10.h),
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 14.sp, color: const Color(0xFFE07B00)),
                        SizedBox(width: 6.w),
                        Text(
                          'Allergens',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      food.allergies.join(', '),
                      style: TextStyle(
                          fontSize: 12.sp, color: secondaryTextColor),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Hygiene assurance card ──
          SizedBox(height: 12.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7F0),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: const Color(0xFF008A45).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.verified_rounded,
                    color: const Color(0xFF008A45), size: 18.sp),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    '100% Hygiene & Quality Checked • Contactless Packaging',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: const Color(0xFF008A45),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Kitchen / Restaurant info card ──
          if (effectiveRestaurant != null) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.restaurant_rounded,
                      color: secondaryTextColor, size: 16.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      'Prepared fresh by $effectiveRestaurant',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: secondaryTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _infoPill(String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _groupHeader({
    required String title,
    required String subtitle,
    required bool required,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11.5.sp, color: secondaryTextColor),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: required
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : const Color(0xFFF0F0F0)),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Text(
            required ? context.l10n.required : context.l10n.optional,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
              color: required ? Colors.white : secondaryTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required String title,
    String? description,
    required String priceLabel,
    required bool selected,
    required _SelectionIndicator indicator,
    bool? isVeg,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : const Color(0xFFEFEFEF)),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            if (isVeg != null) ...[
              isVeg ? _buildVegIcon() : _buildNonVegIcon(),
              SizedBox(width: 10.w),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              priceLabel,
              style: TextStyle(
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
                color: secondaryTextColor,
              ),
            ),
            SizedBox(width: 10.w),
            Icon(
              indicator == _SelectionIndicator.radio
                  ? (selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off)
                  : (selected ? Icons.check_circle : Icons.circle_outlined),
              color: selected
                  ? AppColors.primary
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFFBDBDBD)),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantGroup(
    FoodModel food,
    Color textColor,
    Color secondaryTextColor,
    bool isDark,
  ) {
    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        final anim = _highlightAnimation.value;
        return Container(
          key: _variantSectionKey,
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: anim > 0 ? 6.h : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            color: anim > 0
                ? AppColors.primary.withValues(alpha: 0.08 * anim)
                : Colors.transparent,
            border: Border.all(
              color: anim > 0
                  ? AppColors.primary.withValues(alpha: 0.6 * anim)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _groupHeader(
              title: context.l10n.chooseSize,
              subtitle: context.l10n.selectOneOption,
              required: true,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              isDark: isDark,
            ),
            SizedBox(height: 12.h),
            ...food.variants.map((variant) {
              final isSelected = _selectedVariant?.name == variant.name;
              final delta = variant.price - food.price;
              final priceLabel = delta == 0
                  ? context.l10n.includedLabel
                  : '${delta > 0 ? '+' : '-'}₹${delta.abs().toStringAsFixed(0)}';
              return _buildOptionRow(
                title: variant.name,
                priceLabel: priceLabel,
                selected: isSelected,
                indicator: _SelectionIndicator.radio,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
                onTap: () {
                  Haptics.light();
                  setState(() => _selectedVariant = variant);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonGroup(
    Color textColor,
    Color secondaryTextColor,
    bool isDark,
    List<FoodAddon> addons,
  ) {
    final isVegOnly = ref.watch(vegFilterProvider);
    final displayAddons = isVegOnly ? addons.where((a) => a.isVeg).toList() : addons;

    if (displayAddons.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _highlightAnimation,
      builder: (context, child) {
        final anim = _highlightAnimation.value;
        return Container(
          key: _addonSectionKey,
          margin: EdgeInsets.symmetric(horizontal: 16.w),
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: anim > 0 ? 6.h : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            color: anim > 0
                ? AppColors.primary.withValues(alpha: 0.08 * anim)
                : Colors.transparent,
            border: Border.all(
              color: anim > 0
                  ? AppColors.primary.withValues(alpha: 0.6 * anim)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _groupHeader(
              title: context.l10n.addExtras,
              subtitle: context.l10n.selectAnyYouLike,
              required: false,
              textColor: textColor,
              secondaryTextColor: secondaryTextColor,
              isDark: isDark,
            ),
            SizedBox(height: 12.h),
            ...displayAddons.map(
              (addon) => _buildOptionRow(
                title: addon.name,
                description: addon.description,
                priceLabel: '+₹${addon.price.toStringAsFixed(0)}',
                selected: _selectedAddonIds.contains(addon.id),
                indicator: _SelectionIndicator.checkbox,
                isVeg: addon.isVeg,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                isDark: isDark,
                onTap: () {
                  Haptics.light();
                  _toggleAddon(addon.id);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(bool isDark) {
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE0E0E0);
    final bg = isDark ? AppColors.cardDark : Colors.white;
    return Container(
      height: 48.h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (_quantity <= 1) return;
              Haptics.light();
              setState(() => _quantity--);
            },
            child: Container(
              width: 40.r,
              height: 48.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _quantity > 1
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Icon(
                Icons.remove_rounded,
                size: 18.sp,
                color: _quantity > 1 ? AppColors.primary : Colors.grey,
              ),
            ),
          ),
          SizedBox(
            width: 32.w,
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E1E1E),
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Haptics.light();
              setState(() => _quantity++);
            },
            child: Container(
              width: 40.r,
              height: 48.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Icon(
                Icons.add_rounded,
                size: 18.sp,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyBottomBar(
    FoodModel food,
    Color surfaceColor,
    bool isDark,
    List<FoodAddon> addons,
  ) {
    final selectedAddons = addons
        .where((a) => _selectedAddonIds.contains(a.id))
        .toList();
    final selection = FoodSelection(
      variant: _selectedVariant,
      addons: selectedAddons,
    );
    final addonsTotal = selection.addonTotal;
    final unitPrice = selection.unitPrice(food.price);
    final variantDelta = _selectedVariant == null
        ? 0.0
        : _selectedVariant!.price - food.price;
    final totalPrice = unitPrice * _quantity;

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Quantity selector ──
          _buildQuantitySelector(isDark),
          SizedBox(width: 12.w),
          // ── Add to cart button ──
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final allowed = await ensureCartRestaurant(
                    context,
                    ref,
                    food.restaurantId,
                  );
                  if (!allowed || !mounted) return;

                  Haptics.medium();
                  final cartNotifier = ref.read(cartViewModelProvider.notifier);
                  final existing = widget.existingCartItem;
                  if (existing != null) {
                    cartNotifier.updateItem(
                      existing.id,
                      food: food,
                      selectedVariant: _selectedVariant?.name,
                      selectedVariantPrice: variantDelta,
                      selectedAddons:
                          selectedAddons.map((a) => a.id).toList(),
                      selectedAddonsPrice: addonsTotal,
                      selectedAddonDetails: selectedAddons,
                    );
                  } else {
                    cartNotifier.addItem(
                      food,
                      quantity: _quantity,
                      selectedVariant: _selectedVariant?.name,
                      selectedVariantPrice: variantDelta,
                      selectedAddons:
                          selectedAddons.map((a) => a.id).toList(),
                      selectedAddonsPrice: addonsTotal,
                      selectedAddonDetails: selectedAddons,
                    );
                  }
                  widget.onAdded?.call();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          existing != null
                              ? 'Cart updated! 🛒'
                              : '$_quantity × ${food.name} added to cart 🛒',
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                },
                borderRadius: BorderRadius.circular(28.r),
                child: Ink(
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(28.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        color: Colors.white,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        widget.existingCartItem != null
                            ? context.l10n.updateCartAmount(
                                '₹${totalPrice.toStringAsFixed(0)}')
                            : context.l10n.addToCartAmount(
                                '₹${totalPrice.toStringAsFixed(0)}'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVegIcon() {
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      width: 14.sp,
      height: 14.sp,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF008A45), width: 1),
        borderRadius: BorderRadius.circular(3.r),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 6.sp,
        height: 6.sp,
        decoration: const BoxDecoration(
          color: Color(0xFF008A45),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildNonVegIcon() {
    return Container(
      margin: EdgeInsets.only(top: 4.h),
      width: 14.sp,
      height: 14.sp,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE23744), width: 1),
        borderRadius: BorderRadius.circular(3.r),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 6.sp,
        height: 6.sp,
        decoration: const BoxDecoration(
          color: Color(0xFFE23744),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
