import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/order_history_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(orderHistoryControllerProvider.notifier).search(value.trim());
    });
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final backgroundColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    final restaurantName =
        ref.watch(restaurantProfileControllerProvider).value?.restaurantName ??
        '—';

    final ordersAsync = ref.watch(orderHistoryControllerProvider);

    return Scaffold(
      backgroundColor: backgroundColor,

      // ==========================================================
      // APP BAR
      // ==========================================================
      appBar: AppBar(
        backgroundColor: backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),

        titleSpacing: 0,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Showing order history for',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              restaurantName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================
      body: Column(
        children: [
          _buildSearchBar(
            context,
            secondaryText: secondaryText,
            textColor: textColor,
          ),

          Expanded(
            child: AppRefreshIndicator(
              onRefresh: () {
                return ref
                    .read(orderHistoryControllerProvider.notifier)
                    .refresh();
              },

              child: ordersAsync.when(
                // ==================================================
                // LOADING
                // ==================================================

                loading: () {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                },

                // ==================================================
                // ERROR
                // ==================================================
                error: (error, _) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 90),

                      Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.symmetric(horizontal: 150),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.error.withValues(alpha: 0.15)
                              : AppColors.errorLight,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 38,
                          color: AppColors.error,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          error is ApiException
                              ? error.message
                              : 'Failed to load orders.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Pull down to try again.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: secondaryText, fontSize: 12),
                      ),
                    ],
                  );
                },

                // ==================================================
                // DATA
                // ==================================================
                data: (page) {
                  if (page.orders.isEmpty) {
                    return _buildEmptyState(
                      context,
                      isDark: isDark,
                      textColor: textColor,
                      secondaryText: secondaryText,
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),

                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),

                    itemCount: page.orders.length,

                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 14);
                    },

                    itemBuilder: (context, index) {
                      return _buildOrderCard(context, page.orders[index]);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
    BuildContext context, {
    required bool isDark,
    required Color textColor,
    required Color secondaryText,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),

        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.primaryTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppColors.primaryButton,
            ),
          ),
        ),

        const SizedBox(height: 18),

        Text(
          'No orders found',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),

        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            _searchController.text.trim().isEmpty
                ? 'Your completed orders will appear here.'
                : 'Try searching with a different order ID.',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryText, fontSize: 13, height: 1.4),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar(
    BuildContext context, {
    required Color secondaryText,
    required Color textColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Container(
        height: 54,

        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceVariantDark
              : AppColors.surfaceVariantLight,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),

          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),

        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,

          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),

          textInputAction: TextInputAction.search,

          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.transparent,

            hintText: 'Search by order ID',

            hintStyle: TextStyle(
              color: secondaryText.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),

            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primaryButton,
              size: 23,
            ),

            prefixIconConstraints: const BoxConstraints(
              minWidth: 52,
              minHeight: 52,
            ),

            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,

              builder: (context, value, child) {
                if (value.text.isEmpty) {
                  return const SizedBox.shrink();
                }

                return IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: secondaryText,
                    size: 20,
                  ),

                  onPressed: () {
                    _searchController.clear();

                    ref
                        .read(orderHistoryControllerProvider.notifier)
                        .search('');
                  },
                );
              },
            ),

            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,

            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ORDER CARD
  // ============================================================

  Widget _buildOrderCard(BuildContext context, OrderModel order) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;

    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: borderColor, width: 1),

        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),

      clipBehavior: Clip.antiAlias,

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          onTap: () {
            context.push('/order-details/${order.id}');
          },

          splashColor: AppColors.primary.withValues(alpha: 0.06),
          highlightColor: AppColors.primary.withValues(alpha: 0.03),

          child: Padding(
            padding: const EdgeInsets.all(16),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                // ==================================================
                // TOP ROW
                // ==================================================

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,

                        children: [
                          _buildTag(
                            order.orderStatus.toUpperCase(),
                            order.isCancelled
                                ? AppColors.neutral600
                                : AppColors.primaryButton,
                          ),

                          if (order.sendCutlery)
                            _buildTag('CUTLERY', AppColors.info),

                          if (order.isAllVeg)
                            _buildTag('VEG ONLY', AppColors.success),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      DateFormat(
                        'd MMM,\nh:mm a',
                      ).format(order.createdAt.toLocal()),
                      textAlign: TextAlign.right,

                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ==================================================
                // ORDER ID
                // ==================================================
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,

                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.primaryTint,

                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primaryButton,
                        size: 19,
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        order.displayId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),

                    Icon(
                      Icons.chevron_right_rounded,
                      color: secondaryText,
                      size: 22,
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                // ==================================================
                // CUSTOMER
                // ==================================================
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 17,
                      color: secondaryText,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        'Ordered by ${order.customerName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // ==================================================
                // DIVIDER
                // ==================================================
                Divider(
                  color: isDark ? AppColors.borderDark : AppColors.dividerLight,

                  height: 1,
                ),

                const SizedBox(height: 14),

                // ==================================================
                // ITEMS
                // ==================================================
                for (final item in order.items) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),

                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),

                          width: 6,
                          height: 6,

                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),

                        const SizedBox(width: 9),

                        Expanded(
                          child: Text(
                            '${item.quantity} x ${item.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,

                            style: TextStyle(
                              fontSize: 13,
                              color: textColor,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 7),

                // ==================================================
                // PAYMENT + TOTAL
                // ==================================================
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),

                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark
                        : AppColors.surfaceVariantLight,

                    borderRadius: BorderRadius.circular(12),

                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                      width: 0.8,
                    ),
                  ),

                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,

                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 16,
                              color: secondaryText,
                            ),

                            const SizedBox(width: 6),

                            Flexible(
                              child: Text(
                                'Payment: ${order.paymentMethod}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,

                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      Text(
                        '₹${order.total.toStringAsFixed(2)}',

                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.primaryButton,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAG
  // ============================================================

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),

      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),

      child: Text(
        text,

        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
