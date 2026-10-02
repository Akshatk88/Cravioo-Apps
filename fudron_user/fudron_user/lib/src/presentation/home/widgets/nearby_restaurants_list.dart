import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/veg_filter_provider.dart';

class NearbyRestaurantsList extends ConsumerWidget {
  final List<RestaurantModel> restaurants;

  const NearbyRestaurantsList({super.key, required this.restaurants});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVegOnly = ref.watch(vegFilterProvider);
    final displayList = isVegOnly
        ? restaurants.where((r) => r.isPureVeg).toList()
        : restaurants;

    if (displayList.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 165.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: displayList.length,
        separatorBuilder: (context, index) => SizedBox(width: 14.w),
        itemBuilder: (context, index) {
          final target = displayList[index];
          final infoParts = <String>[
            if (target.priceForOne > 0) '₹${target.priceForOne.toStringAsFixed(0)} for one',
            if (target.isFreeDelivery)
              'Free Delivery'
            else if (target.deliveryFee > 0)
              '₹${target.deliveryFee.toStringAsFixed(0)} Delivery',
            if (target.tags.isNotEmpty) target.tags.first,
          ];
          final info = infoParts.join(' • ');
          return GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.restaurantDetail, extra: target);
            },
            child: SizedBox(
              width: 160.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Image + Brand Logo Badge
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: SmartImage(
                          url: target.imageUrl,
                          category: ImageCategory.restaurant,
                          height: 105.h,
                          width: 160.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Brand Logo Overlay Bottom Left
                      Positioned(
                        bottom: 6.h,
                        left: 6.w,
                        child: Container(
                          width: 32.w,
                          height: 32.h,
                          padding: EdgeInsets.all(2.r),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: ClipOval(
                            child: SmartImage(
                              url: target.imageUrl,
                              category: ImageCategory.brand,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          target.name,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (target.rating > 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 9.sp),
                              SizedBox(width: 2.w),
                              Text(
                                target.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    info,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
