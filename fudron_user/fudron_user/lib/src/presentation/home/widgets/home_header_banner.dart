import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../branding/app_colors.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/banners_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/near_you_viewmodel.dart';
import '../viewmodels/zone_viewmodel.dart';

class HomeHeaderBanner extends ConsumerStatefulWidget {
  const HomeHeaderBanner({super.key});

  @override
  ConsumerState<HomeHeaderBanner> createState() => _HomeHeaderBannerState();
}

class _HomeHeaderBannerState extends ConsumerState<HomeHeaderBanner> {
  List<String> get _slideImages =>
      ref.watch(heroBannersProvider).value ?? const <String>[];

  final PageController _pageController = PageController();

  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAutoRotation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants();
      ref.read(addressViewModelProvider.notifier).load();
    });
  }

  void _startAutoRotation() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted) return;

      if (_pageController.hasClients && _slideImages.length > 1) {
        final next = (_currentPage + 1) % _slideImages.length;

        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    final rowTop = topInset + 6.h;
    final headerHeight = topInset + 315.h;

    return ClipRRect(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28.r)),
      child: SizedBox(
        width: double.infinity,
        height: headerHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ============================================================
            // BACKGROUND HERO IMAGE CAROUSEL
            // ============================================================
            PageView.builder(
              controller: _pageController,

              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },

              itemCount: _slideImages.isEmpty ? 1 : _slideImages.length,

              itemBuilder: (context, index) {
                final imgUrl =
                    (_slideImages.isNotEmpty && index < _slideImages.length)
                    ? _slideImages[index]
                    : '';

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imgUrl.isNotEmpty)
                      SmartImage(
                        url: imgUrl,
                        category: ImageCategory.food,
                        fit: BoxFit.cover,
                      )
                    else
                      Container(color: AppColors.primary),

                    // Dark Vignette Overlay
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x80000000),
                            Color(0x22000000),
                            Color(0x77000000),
                          ],
                          stops: [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ============================================================
            // TOP HEADER ROW
            // Location + Cart + Profile
            // ============================================================
            Positioned(
              top: rowTop,
              left: 16.w,
              right: 16.w,
              height: 44.h,
              child: _buildTopRow(context),
            ),

            // ============================================================
            // CAROUSEL PAGE INDICATOR
            // ============================================================
            Positioned(
              bottom: 34.h,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _slideImages.isEmpty ? 1 : _slideImages.length,
                  (i) => _dot(
                    i ==
                        (_currentPage %
                            (_slideImages.isEmpty ? 1 : _slideImages.length)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // TOP ROW
  // Location + Cart + Profile
  // ========================================================================

  Widget _buildTopRow(BuildContext context) {
    final user = ref.watch(authViewModelProvider).value;
    final avatarUrl = user?.avatarUrl ?? '';
    final nearYouState = ref.watch(nearYouViewModelProvider);

    // Watch the STATE list (not notifier) so the header rebuilds whenever an
    // address is added/changed. .notifier is stable and never triggers rebuilds.
    final addresses = ref.watch(addressViewModelProvider);
    final savedAddress = addresses.isEmpty
        ? null
        : (addresses.firstWhere((a) => a.isDefault, orElse: () => addresses.first));

    // Resolve header title and subtitle
    String titleText = 'Select Location';
    String areaText = 'Tap to set delivery location';

    if (savedAddress != null) {
      final isHomeOrOffice = savedAddress.type.toLowerCase() == 'home' ||
          savedAddress.type.toLowerCase() == 'office' ||
          savedAddress.title.toLowerCase() == 'home' ||
          savedAddress.title.toLowerCase() == 'office';

      // 1. Resolve building no / house no
      String buildingPart = savedAddress.building.trim();
      if (buildingPart.isEmpty && savedAddress.fullAddress.isNotEmpty) {
        final rawParts = savedAddress.fullAddress
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (rawParts.isNotEmpty) {
          final first = rawParts.first;
          if (first.toLowerCase() != savedAddress.street.trim().toLowerCase() &&
              first.toLowerCase() != savedAddress.city.trim().toLowerCase() &&
              first.toLowerCase() != savedAddress.type.toLowerCase()) {
            buildingPart = first;
          }
        }
      }

      final streetPart = savedAddress.street.trim();
      final cityPart = savedAddress.city.trim();

      // Show First Building No, then Street Name, and then City
      final parts = <String>[];
      if (buildingPart.isNotEmpty) {
        parts.add(buildingPart);
      }
      if (streetPart.isNotEmpty &&
          streetPart.toLowerCase() != buildingPart.toLowerCase()) {
        parts.add(streetPart);
      }
      if (cityPart.isNotEmpty &&
          cityPart.toLowerCase() != streetPart.toLowerCase() &&
          cityPart.toLowerCase() != buildingPart.toLowerCase()) {
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
        titleText = savedAddress.type.isNotEmpty ? savedAddress.type : savedAddress.title;
        areaText = cleanCombined.isNotEmpty ? cleanCombined : titleText;
      } else {
        titleText = savedAddress.title.isNotEmpty && savedAddress.title.toLowerCase() != 'other'
            ? savedAddress.title
            : (buildingPart.isNotEmpty
                ? buildingPart
                : (streetPart.isNotEmpty ? streetPart : 'My Address'));
        areaText = cleanCombined;
      }
    } else if (nearYouState.location != null && nearYouState.location!.isSuccess) {
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
          : (loc.fullAddress.isNotEmpty ? loc.fullAddress : 'Live GPS Detected');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ================================================================
        // LOCATION
        // ================================================================

        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,

            onTap: () async {
              Haptics.light();
              await context.push(RouteNames.addAddress);
              if (!mounted) return;
              await ref.read(addressViewModelProvider.notifier).load();
              await ref.read(zoneViewModelProvider.notifier).refresh();
              ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants();
              ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
            },

            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Location Pin
                Container(
                  padding: EdgeInsets.all(5.r),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_on,
                    color: Colors.white,
                    size: 18.sp,
                  ),
                ),

                SizedBox(width: 8.w),

                // Location Information
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Address line
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              titleText,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          SizedBox(width: 3.w),

                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                        ],
                      ),

                      // Area
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              areaText,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          SizedBox(width: 2.w),

                          Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 14.sp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ================================================================
        // CART BUTTON
        // ================================================================
        _buildCartButton(context),

        SizedBox(width: 10.w),

        // ================================================================
        // PROFILE BUTTON
        // ================================================================
        GestureDetector(
          onTap: () {
            Haptics.light();

            context.go(RouteNames.profile);
          },

          child: Container(
            width: 36.w,
            height: 36.h,

            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
              border: Border.all(color: Colors.white, width: 1.5.w),
            ),

            child: ClipOval(
              child: avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,

                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 20,
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // CART BUTTON
  // ========================================================================

  Widget _buildCartButton(BuildContext context) {
    // Get current cart state
    final cartState = ref.watch(cartViewModelProvider);

    // Total quantity of all cart items
    final cartCount = cartState.totalQuantity;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,

      onTap: () {
        Haptics.light();

        // Open existing Cart Screen
        context.go(RouteNames.cart);
      },

      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ==============================================================
          // CART CIRCLE
          // ==============================================================

          Container(
            width: 36.w,
            height: 36.h,

            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5.w),
            ),

            child: Icon(
              Icons.shopping_cart_outlined,
              color: Colors.white,
              size: 20.sp,
            ),
          ),

          // ==============================================================
          // CART QUANTITY BADGE
          // ==============================================================
          if (cartCount > 0)
            Positioned(
              right: -5.w,
              top: -5.h,

              child: Container(
                constraints: BoxConstraints(minWidth: 17.w, minHeight: 17.h),

                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),

                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,

                  border: Border.all(color: Colors.white, width: 1.5.w),
                ),

                alignment: Alignment.center,

                child: Text(
                  cartCount > 99 ? '99+' : '$cartCount',

                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // CAROUSEL DOT
  // ========================================================================

  Widget _dot(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),

      margin: EdgeInsets.symmetric(horizontal: 3.w),

      width: isActive ? 16.w : 6.w,

      height: 6.h,

      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary
            : Colors.white.withValues(alpha: 0.5),

        borderRadius: BorderRadius.circular(3.r),
      ),
    );
  }
}
