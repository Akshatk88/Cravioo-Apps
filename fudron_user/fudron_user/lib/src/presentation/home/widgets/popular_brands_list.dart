import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';

class PopularBrandsList extends StatelessWidget {
  final List<RestaurantModel> restaurants;

  const PopularBrandsList({
    super.key,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    if (restaurants.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sized to comfortably fit avatar + two text lines even on small screens or larger text scaling
    return SizedBox(
      height: 98.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          final name = restaurant.name;
          final time = restaurant.deliveryTime;
          final logo = restaurant.imageUrl;

          return GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.restaurantDetail, extra: restaurant);
            },
            child: Container(
              width: 76.w,
              margin: EdgeInsets.only(right: 12.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Circular Brand Logo Avatar Container
                  Container(
                    width: 50.r,
                    height: 50.r,
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                        width: 1.0,
                      ),
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
                    child: ClipOval(
                      child: SmartImage(
                        url: logo,
                        category: ImageCategory.restaurant,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),

                  // Brand Title
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      height: 1.15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 2.h),

                  // Delivery Time
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF757575),
                      height: 1.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
