import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

class RestaurantStatusScreen extends ConsumerWidget {
  const RestaurantStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,

      // ============================================================
      // APP BAR
      // ============================================================
      appBar: AppBar(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : AppColors.backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: Container(
          margin: const EdgeInsets.only(left: 12, top: 6, bottom: 6),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceVariantDark
                : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              size: 21,
            ),
            onPressed: () => context.pop(),
          ),
        ),

        titleSpacing: 14,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Restaurant status',
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w800,
                fontSize: 19,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              'You are mapped to 1 restaurant',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),

      // ============================================================
      // BODY
      // ============================================================
      body: restaurantAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),

        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              error is ApiException
                  ? error.message
                  : 'Failed to load restaurant status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 14,
              ),
            ),
          ),
        ),

        data: (restaurant) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),

          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),

          child: Column(
            children: [
              // ========================================================
              // RESTAURANT CARD
              // ========================================================

              Container(
                width: double.infinity,

                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,

                  borderRadius: BorderRadius.circular(24),

                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),

                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.16 : 0.045,
                      ),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),

                padding: const EdgeInsets.all(18),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==================================================
                    // RESTAURANT HEADER
                    // ==================================================

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Restaurant icon
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: AppColors.primaryDark,
                            size: 27,
                          ),
                        ),

                        const SizedBox(width: 13),

                        // Restaurant details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant.restaurantName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                  height: 1.2,
                                ),
                              ),

                              const SizedBox(height: 6),

                              Text(
                                'ID: ${restaurant.restaurantId.isNotEmpty ? restaurant.restaurantId : restaurant.id} • ${restaurant.city}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 10),

                        // Settings icon
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceVariantDark
                                : AppColors.surfaceVariantLight,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            Icons.settings_outlined,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            size: 20,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // DIVIDER
                    // ==================================================
                    Container(
                      height: 1,
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.dividerLight,
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // DELIVERY STATUS
                    // ==================================================
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Status icon
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: restaurant.isAcceptingOrders
                                ? AppColors.successLight
                                : AppColors.errorLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            restaurant.isAcceptingOrders
                                ? Icons.delivery_dining_rounded
                                : Icons.pause_circle_outline_rounded,
                            color: restaurant.isAcceptingOrders
                                ? AppColors.success
                                : AppColors.error,
                            size: 25,
                          ),
                        ),

                        const SizedBox(width: 13),

                        // Status text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery status',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: restaurant.isAcceptingOrders
                                          ? AppColors.success
                                          : AppColors.error,
                                      shape: BoxShape.circle,
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  Flexible(
                                    child: Text(
                                      restaurant.isAcceptingOrders
                                          ? 'Receiving orders'
                                          : 'Not receiving orders',
                                      style: TextStyle(
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ==================================================
                        // SWITCH
                        // ==================================================
                        Switch(
                          value: restaurant.isAcceptingOrders,

                          activeThumbColor: Colors.white,

                          activeTrackColor: AppColors.primary,

                          inactiveThumbColor: isDark
                              ? AppColors.neutral300
                              : Colors.white,

                          inactiveTrackColor: isDark
                              ? AppColors.surfaceVariantDark
                              : AppColors.neutral300,

                          onChanged: (value) async {
                            try {
                              await ref
                                  .read(
                                    restaurantProfileControllerProvider
                                        .notifier,
                                  )
                                  .updateAvailability(value);
                            } catch (e) {
                              if (context.mounted) {
                                final message = e is ApiException
                                    ? e.message
                                    : 'Failed to update. Please try again.';

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(message),

                                    backgroundColor: AppColors.error,

                                    behavior: SnackBarBehavior.floating,

                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // WEEKLY SCHEDULE
                    // ==================================================
                    Container(
                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceVariantDark
                            : AppColors.surfaceVariantLight,

                        borderRadius: BorderRadius.circular(17),

                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderSubtle,
                        ),
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,

                            decoration: BoxDecoration(
                              color: AppColors.primaryTint,
                              borderRadius: BorderRadius.circular(12),
                            ),

                            child: const Icon(
                              Icons.calendar_month_rounded,
                              color: AppColors.primaryDark,
                              size: 21,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weekly schedule',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  'Manage your outlet timings',
                                  style: TextStyle(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Details button
                          Material(
                            color: Colors.transparent,

                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),

                              onTap: () => context.push('/outlet-timings'),

                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 8,
                                ),

                                decoration: BoxDecoration(
                                  color: AppColors.primaryTint,

                                  borderRadius: BorderRadius.circular(12),
                                ),

                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Details',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),

                                    SizedBox(width: 3),

                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.primaryDark,
                                      size: 17,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ========================================================
              // STATUS INFORMATION CARD
              // ========================================================
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,

                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),

                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,

                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.info,
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keep your status updated',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Turn delivery status off when your outlet is temporarily unavailable to stop receiving new orders.',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
