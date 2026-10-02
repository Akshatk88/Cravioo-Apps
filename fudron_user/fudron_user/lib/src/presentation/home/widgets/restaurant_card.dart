import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/food_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../favorites/viewmodels/favorites_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../restaurant/viewmodels/restaurant_detail_viewmodel.dart';

class RestaurantCard extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final int index;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    this.index = 0,
  });

  @override
  ConsumerState<RestaurantCard> createState() => _RestaurantCardState();
}

class _RestaurantCardState extends ConsumerState<RestaurantCard> {
  late final ValueNotifier<int> _activePageNotifier;

  @override
  void initState() {
    super.initState();
    _activePageNotifier = ValueNotifier<int>(0);
  }

  @override
  void dispose() {
    _activePageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final menuAsync = ref.watch(restaurantMenuProvider(restaurant.id));
    final menu = menuAsync.asData?.value ?? const <FoodModel>[];

    final featuredDish = menu.isEmpty
        ? null
        : menu.firstWhere((f) => f.isPopular, orElse: () => menu.first);

    final foodMenuUrls = menu
        .map((f) => f.imageUrl)
        .where((url) => url.isNotEmpty)
        .toList();
    final modelMenuUrls = restaurant.menuImages
        .where((url) => url.isNotEmpty)
        .toList();
    final modelCoverUrls = restaurant.coverImages
        .where((url) => url.isNotEmpty)
        .toList();

    final List<String> imageSlides;
    if (foodMenuUrls.isNotEmpty) {
      imageSlides = foodMenuUrls;
    } else if (modelMenuUrls.isNotEmpty) {
      imageSlides = modelMenuUrls;
    } else if (modelCoverUrls.isNotEmpty) {
      imageSlides = modelCoverUrls;
    } else if (restaurant.imageUrl.isNotEmpty) {
      imageSlides = [restaurant.imageUrl];
    } else {
      imageSlides = const [];
    }

    final startingPrice = restaurant.priceForOne > 0
        ? restaurant.priceForOne
        : (featuredDish != null ? featuredDish.price : 0.0);

    final List<String> slideDishLabels;
    if (foodMenuUrls.isNotEmpty) {
      final menuWithImages = menu.where((f) => f.imageUrl.isNotEmpty).toList();
      slideDishLabels = menuWithImages.map((f) {
        return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
      }).toList();
    } else if (menu.isNotEmpty) {
      slideDishLabels = menu.map((f) {
        return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
      }).toList();
    } else {
      slideDishLabels = const [];
    }

    final top3MenuItems = menu.take(3).map((f) {
      return '${f.name}${f.price > 0 ? ' • ₹${f.price.toStringAsFixed(0)}' : ''}';
    }).toList();

    final List<String> displayTopItems;
    if (top3MenuItems.isNotEmpty) {
      displayTopItems = top3MenuItems;
    } else if (restaurant.featuredDishName != null) {
      displayTopItems = [
        '${restaurant.featuredDishName}${startingPrice > 0 ? ' • ₹${startingPrice.toStringAsFixed(0)}' : ''}',
        if (restaurant.tags.isNotEmpty) restaurant.tags.first,
      ];
    } else if (restaurant.tags.isNotEmpty) {
      displayTopItems = restaurant.tags.take(3).toList();
    } else {
      displayTopItems = const [];
    }

    final bool isOpen = restaurant.isOpen;

    Widget cardWidget = Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MediaCarousel(
            restaurant: restaurant,
            restaurantId: restaurant.id,
            imageSlides: imageSlides,
            isOpen: isOpen,
            featuredPriceBadge: startingPrice > 0 ? '₹${startingPrice.toStringAsFixed(0)}' : '₹190',
            featuredDishName: restaurant.featuredDishName ?? featuredDish?.name,
            topMenuItemNames: slideDishLabels.isNotEmpty ? slideDishLabels : displayTopItems,
            onPageChanged: (page) {
              _activePageNotifier.value = page;
            },
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 12.h),
            child: _RestaurantInfo(
              restaurant: restaurant,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );

    if (!isOpen) {
      cardWidget = IgnorePointer(
        ignoring: true,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0,      0,      0,      1, 0,
          ]),
          child: cardWidget,
        ),
      );
    }

    return _EntranceAnimationWrapper(
      index: widget.index,
      child: GestureDetector(
        onTap: isOpen
            ? () {
                Haptics.light();
                context.push(RouteNames.restaurantDetail, extra: restaurant);
              }
            : null,
        child: cardWidget,
      ),
    );
  }
}

class _EntranceAnimationWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const _EntranceAnimationWrapper({
    required this.index,
    required this.child,
  });

  @override
  State<_EntranceAnimationWrapper> createState() => _EntranceAnimationWrapperState();
}

class _EntranceAnimationWrapperState extends State<_EntranceAnimationWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);
    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(curvedAnimation);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.25),
      end: Offset.zero,
    ).animate(curvedAnimation);

    final delayMs = (widget.index % 6) * 60;
    if (delayMs > 0) {
      _delayTimer = Timer(Duration(milliseconds: delayMs), () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}



class _RestaurantInfo extends StatelessWidget {
  final RestaurantModel restaurant;
  final bool isDark;

  const _RestaurantInfo({
    required this.restaurant,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final offerText = restaurant.offerBadges.isNotEmpty
        ? restaurant.offerBadges.first
        : 'Flat ₹100 OFF above ₹149';

    final ratingVal = restaurant.rating > 0 ? restaurant.rating : 4.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Restaurant Name & Green Rating Badge (Top Row)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                restaurant.name,
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                  color: titleColor,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 8.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: const Color(0xFF15803D), // solid crisp green badge matching screenshot
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ratingVal.toStringAsFixed(1),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.sp,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Icon(
                    Icons.star_rounded,
                    color: Colors.white,
                    size: 13.sp,
                  ),
                ],
              ),
            ),
          ],
        ),

        SizedBox(height: 5.h),

        // 2. Near & Fast Row (Green Bolt + Green Text + optional distance)
        Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              color: const Color(0xFF00A36C),
              size: 17.sp,
            ),
            SizedBox(width: 3.w),
            Text(
              'Near & Fast',
              style: TextStyle(
                color: const Color(0xFF00A36C),
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (restaurant.distanceKm > 0) ...[
              Text(
                '  •  ${restaurant.distanceKm.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),

        SizedBox(height: 5.h),

        // 3. Offer Row (Blue Rosette / Star Icon + Offer Text)
        Row(
          children: [
            Icon(
              Icons.verified_rounded,
              color: const Color(0xFF2563EB),
              size: 16.sp,
            ),
            SizedBox(width: 5.w),
            Expanded(
              child: Text(
                offerText,
                style: TextStyle(
                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF334155),
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // 4. Pure Veg Pill (Leaf + Pure Veg restaurant)
        if (restaurant.isPureVeg) ...[
          SizedBox(height: 7.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.eco_rounded,
                  size: 13.sp,
                  color: const Color(0xFF10B981),
                ),
                SizedBox(width: 4.w),
                Text(
                  'Pure Veg restaurant',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155),
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],

        // 5. Temporary Closed banner if not open
        if (!restaurant.isOpen) ...[
          SizedBox(height: 6.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3F1D24) : const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: isDark ? const Color(0xFF881337) : const Color(0xFFFECDD3),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 14.sp,
                  color: const Color(0xFFE11D48),
                ),
                SizedBox(width: 6.w),
                Text(
                  'Currently closed for delivery',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE11D48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaCarousel extends ConsumerStatefulWidget {
  final RestaurantModel? restaurant;
  final String restaurantId;
  final List<String> imageSlides;
  final bool isOpen;
  final String? featuredPriceBadge;
  final String? featuredDishName;
  final List<String> topMenuItemNames;
  final ValueChanged<int>? onPageChanged;

  const _MediaCarousel({
    this.restaurant,
    required this.restaurantId,
    required this.imageSlides,
    required this.isOpen,
    this.featuredPriceBadge,
    this.featuredDishName,
    this.topMenuItemNames = const [],
    this.onPageChanged,
  });

  @override
  ConsumerState<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends ConsumerState<_MediaCarousel> with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  Timer? _timer;
  Timer? _inactivityTimer;
  int _currentPage = 0;
  bool _isUserInteracting = false;

  late final AnimationController _heartBumpController;
  late final Animation<double> _heartScaleAnimation;

  int get _slideCount => widget.imageSlides.length;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _heartBumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.9), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(
      CurvedAnimation(parent: _heartBumpController, curve: Curves.easeOutCubic),
    );

    if (_slideCount > 1 && widget.isOpen) {
      _startAutoSlideTimer();
    }
  }

  @override
  void didUpdateWidget(covariant _MediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageSlides.length != widget.imageSlides.length ||
        oldWidget.isOpen != widget.isOpen) {
      if (_currentPage >= widget.imageSlides.length) {
        _currentPage = 0;
      }
      if (_slideCount > 1 && widget.isOpen) {
        _startAutoSlideTimer();
      } else {
        _timer?.cancel();
        _inactivityTimer?.cancel();
      }
    }
  }

  void _startAutoSlideTimer() {
    _timer?.cancel();
    if (_slideCount <= 1 || !mounted || _isUserInteracting || !widget.isOpen) return;

    _timer = Timer.periodic(const Duration(milliseconds: 2800), (timer) {
      if (!mounted || _slideCount <= 1 || _isUserInteracting || !widget.isOpen) {
        timer.cancel();
        return;
      }
      if (_pageController.hasClients) {
        final nextPage = (_currentPage + 1) % _slideCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onUserInteractionStart() {
    _isUserInteracting = true;
    _timer?.cancel();
    _inactivityTimer?.cancel();
  }

  void _onUserInteractionEnd() {
    if (!_isUserInteracting) return;
    _isUserInteracting = false;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isUserInteracting && _slideCount > 1) {
        _startAutoSlideTimer();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _inactivityTimer?.cancel();
    _pageController.dispose();
    _heartBumpController.dispose();
    super.dispose();
  }

  void _handleFavoriteTap() {
    Haptics.medium();
    _heartBumpController.forward(from: 0.0);
    ref.read(favoritesViewModelProvider.notifier).toggle(widget.restaurantId, widget.restaurant);
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(
      favoritesViewModelProvider.select((state) => state.value?.restaurantIds.contains(widget.restaurantId) ?? false),
    );

    final String displayDishLabel;
    if (widget.topMenuItemNames.isNotEmpty) {
      displayDishLabel = widget.topMenuItemNames[_currentPage % widget.topMenuItemNames.length];
    } else if (widget.featuredDishName != null) {
      displayDishLabel = '${widget.featuredDishName}${widget.featuredPriceBadge != null ? " · ${widget.featuredPriceBadge}" : ""}';
    } else {
      final tagName = widget.restaurant?.tags.isNotEmpty == true
          ? widget.restaurant!.tags.first
          : (widget.restaurant?.name ?? 'Special');
      final priceStr = widget.featuredPriceBadge ?? '₹190';
      displayDishLabel = '$tagName · $priceStr';
    }

    final isDishVeg = widget.restaurant?.isPureVeg ?? true;

    return SizedBox(
      height: 180.h,
      child: Stack(
        children: [
          // 1. Cover / Food Image Slides Carousel (Grayscale desaturation when closed)
          Positioned.fill(
            child: _slideCount == 0
                ? Container(color: const Color(0xFFF0F0F0))
                : NotificationListener<ScrollNotification>(
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
                      controller: _pageController,
                      itemCount: _slideCount,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                        widget.onPageChanged?.call(page);
                      },
                      itemBuilder: (context, index) {
                        return SmartImage(
                          url: widget.imageSlides[index],
                          category: ImageCategory.restaurant,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        );
                      },
                    ),
                  ),
          ),

          // 2. Subtle Dark Gradient Overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),

          // 3. Temporarily Closed Badge Overlay
          if (!widget.isOpen)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: Center(
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: const Color(0xDC18181B),
                      borderRadius: BorderRadius.circular(22.r),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 26.sp,
                          color: const Color(0xFFF43F5E),
                        ),
                        SizedBox(width: 10.w),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'UNAVAILABLE DELIVERY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            SizedBox(height: 1.h),
                            Text(
                              'Will reopen soon',
                              style: TextStyle(
                                color: const Color(0xFFD4D4D8),
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 4. Top-Left Tag: FSSAI Veg/Non-Veg Mark + Dish Name & Price (Matching Screenshot)
          Positioned(
            top: 12.h,
            left: 12.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Row(
                  key: ValueKey<String>(displayDishLabel),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildVegMark(isVeg: isDishVeg, size: 11.sp),
                    SizedBox(width: 5.w),
                    Flexible(
                      child: Text(
                        displayDishLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Bookmark Ribbon Button on Top-Right (Matching Screenshot)
          Positioned(
            top: 10.h,
            right: 12.w,
            child: GestureDetector(
              onTap: _handleFavoriteTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: ScaleTransition(
                  scale: _heartScaleAnimation,
                  child: Icon(
                    isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    size: 26.sp,
                    color: isFavorite ? AppColors.primary : Colors.white,
                    shadows: const [
                      Shadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 1)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 6. FREE delivery Badge on Bottom-Left (Only if admin set free delivery)
          if (widget.restaurant?.isFreeDelivery == true)
            Positioned(
              bottom: 0,
              left: 0,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.5.h),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(8.r),
                  ),
                ),
                child: Text(
                  'FREE delivery',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),

          // 7. Carousel Dot Indicators on Bottom-Right (Matching Screenshot)
          Positioned(
            bottom: 8.h,
            right: 12.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _slideCount > 1 ? _slideCount : 4,
                  (i) => _dot(i == (_currentPage % (_slideCount > 1 ? _slideCount : 4))),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVegMark({required bool isVeg, double size = 11}) {
    final color = isVeg ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(1.8),
      decoration: BoxDecoration(
        border: Border.all(color: color, width: 1.2),
        borderRadius: BorderRadius.circular(2.5),
        color: Colors.white,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: EdgeInsets.only(left: 4.w),
      width: active ? 14.w : 5.w,
      height: 5.h,
      decoration: BoxDecoration(
        color: active ? Colors.white : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3.r),
      ),
    );
  }
}

/// Animated ticker cycling through items using vertical page-up transition
/// (old text slides UP and exits top, new text arrives UP from bottom).
class PageUpTextTicker extends StatefulWidget {
  final List<String> items;
  final TextStyle style;
  final Widget? prefix;
  final Duration interval;
  final Duration animationDuration;

  const PageUpTextTicker({
    super.key,
    required this.items,
    required this.style,
    this.prefix,
    this.interval = const Duration(milliseconds: 2800),
    this.animationDuration = const Duration(milliseconds: 400),
  });

  @override
  State<PageUpTextTicker> createState() => _PageUpTextTickerState();
}

class _PageUpTextTickerState extends State<PageUpTextTicker> {
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant PageUpTextTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items.length != widget.items.length) {
      _currentIndex = 0;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (widget.items.length <= 1) return;
    _timer = Timer.periodic(widget.interval, (timer) {
      if (!mounted || widget.items.length <= 1) {
        timer.cancel();
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.items.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final currentText = widget.items[_currentIndex % widget.items.length];

    return AnimatedSwitcher(
      duration: widget.animationDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isIncoming =
            (child.key as ValueKey<int>?)?.value == _currentIndex;

        final inAnimation = Tween<Offset>(
          begin: const Offset(0.0, 1.0),
          end: Offset.zero,
        ).animate(animation);

        final outAnimation = Tween<Offset>(
          begin: const Offset(0.0, -1.0),
          end: Offset.zero,
        ).animate(animation);

        return SlideTransition(
          position: isIncoming ? inAnimation : outAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: Row(
        key: ValueKey<int>(_currentIndex),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.prefix != null) ...[
            widget.prefix!,
            SizedBox(width: 4.w),
          ],
          Flexible(
            child: Text(
              currentText,
              style: widget.style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
