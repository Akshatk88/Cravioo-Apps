import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/config/theme/theme_mode_provider.dart';
import 'package:food_user_application/core/widgets/app_drawer.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      drawer: const AppDrawer(),
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          _buildBackgroundDecoration(context),

          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ==================================================
                // RESTAURANT HEADER
                // ==================================================

                _buildHeaderCard(context, ref),

                const SizedBox(height: 30),

                // ==================================================
                // MANAGE OUTLET
                // ==================================================
                _buildSectionTitle(context, 'MANAGE OUTLET'),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Outlet info',
                      subtitle: 'View and edit outlet\ninformation',
                      icon: Icons.info_outline_rounded,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/outlet-info'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Outlet timings',
                      subtitle: 'Manage your outlet\nopening hours',
                      icon: Icons.access_time_rounded,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/outlet-timings'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Menu categories',
                      subtitle: 'Add & manage\nmenu categories',
                      icon: Icons.restaurant_menu_rounded,
                      iconBgColor: AppColors.primaryTint,
                      iconColor: AppColors.primaryDark,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/menu-categories'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Offers & Coupons',
                      subtitle: 'Create & manage offers\nand coupons',
                      icon: Icons.local_offer_rounded,
                      iconBgColor: AppColors.primaryTint,
                      iconColor: AppColors.primaryDark,
                      width: _getCardWidth(context, 2),
                      onTap: () => context.push('/offers'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Dining',
                      subtitle: 'Table reservations\n& dining setup',
                      icon: Icons.table_restaurant_rounded,
                      iconBgColor: AppColors.primaryTint,
                      iconColor: AppColors.primaryDark,
                      width: _getCardWidth(context, 2),
                      onTap: () {
                        context.push('/dining');
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ==================================================
                // SETTINGS
                // ==================================================
                _buildSectionTitle(context, 'SETTINGS'),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Delivery settings',
                      subtitle: 'Manage delivery\npreferences',
                      icon: Icons.delivery_dining_rounded,
                      iconBgColor: AppColors.successLight,
                      iconColor: AppColors.success,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/delivery-settings'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Zone Setup',
                      subtitle: 'Manage delivery\nzones & areas',
                      icon: Icons.map_rounded,
                      iconBgColor: AppColors.primaryTint,
                      iconColor: AppColors.primaryDark,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/zone-setup'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Appearance',
                      subtitle: 'Theme settings\nLight & Dark',
                      icon: Icons.palette_outlined,
                      iconBgColor: AppColors.primaryTint,
                      iconColor: AppColors.primaryDark,
                      width: _getCardWidth(context, 3),
                      onTap: () => _showAppearanceSheet(context),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ==================================================
                // ORDERS
                // ==================================================
                _buildSectionTitle(context, 'ORDERS'),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Order history',
                      subtitle: 'View past orders',
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.primaryDark,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/order-history'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Complaints',
                      subtitle: 'Manage issues',
                      icon: Icons.chat_bubble_outline_rounded,
                      iconColor: AppColors.primaryDark,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/complaints'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Reviews',
                      subtitle: 'Customer reviews',
                      icon: Icons.star_rounded,
                      iconColor: AppColors.primaryDark,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () =>
                          context.push('/complaints', extra: 'reviews'),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ==================================================
                // HELP
                // ==================================================
                _buildSectionTitle(context, 'HELP'),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Support',
                      subtitle: 'Get help and support',
                      icon: Icons.support_agent_rounded,
                      iconColor: AppColors.primaryDark,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/support'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Feedback',
                      subtitle: 'Share your feedback',
                      icon: Icons.edit_note_rounded,
                      iconColor: AppColors.primaryDark,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/feedback'),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ==================================================
                // FINANCE
                // ==================================================
                _buildSectionTitle(context, 'FINANCE'),

                const SizedBox(height: 14),

                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Payout',
                      subtitle: 'View payout details',
                      icon: Icons.currency_rupee_rounded,
                      iconColor: AppColors.primaryDark,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/payouts', extra: 'payouts'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Invoices',
                      subtitle: 'View your invoices',
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppColors.primaryDark,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/payouts', extra: 'invoices'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Bank details',
                      subtitle: 'Manage bank details',
                      icon: Icons.account_balance_rounded,
                      iconColor: AppColors.primaryDark,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/bank-details'),
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                // ==================================================
                // LOGOUT
                // ==================================================
                _buildLogoutCard(context, ref),

                const SizedBox(height: 14),

                // ==================================================
                // DELETE ACCOUNT
                // ==================================================
                _buildDeleteAccountCard(context, ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // APPEARANCE SHEET
  // ============================================================

  void _showAppearanceSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => Consumer(
        builder: (context, ref, _) {
          final currentMode = ref.watch(themeModeProvider);

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primaryAlpha(0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.palette_outlined,
                          color: AppColors.primaryDark,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Text(
                        'Appearance',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  _buildAppearanceOption(
                    ref: ref,
                    sheetContext: sheetContext,
                    title: 'System Default',
                    icon: Icons.brightness_auto_rounded,
                    value: ThemeMode.system,
                    groupValue: currentMode,
                  ),

                  _buildAppearanceOption(
                    ref: ref,
                    sheetContext: sheetContext,
                    title: 'Light',
                    icon: Icons.light_mode_rounded,
                    value: ThemeMode.light,
                    groupValue: currentMode,
                  ),

                  _buildAppearanceOption(
                    ref: ref,
                    sheetContext: sheetContext,
                    title: 'Dark',
                    icon: Icons.dark_mode_rounded,
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // APPEARANCE OPTION
  // ============================================================

  Widget _buildAppearanceOption({
    required WidgetRef ref,
    required BuildContext sheetContext,
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
  }) {
    final isSelected = value == groupValue;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),

      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : AppColors.neutral400,
      ),

      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primaryDark : null,
        ),
      ),

      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : const Icon(Icons.circle_outlined, color: AppColors.neutral400),

      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(value);

        Navigator.pop(sheetContext);
      },
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,

      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leadingWidth: 70,

      leading: Center(
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(left: 16),

          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.primaryAlpha(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),

          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              size: 20,
            ),

            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/orders');
              }
            },
          ),
        ),
      ),

      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore',
            style: TextStyle(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),

          Text(
            'Manage your outlet & grow your business',
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 11,
            ),
          ),
        ],
      ),

      actions: [
        Container(
          width: 44,
          height: 44,

          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.primaryAlpha(0.15)),
          ),

          child: IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              size: 21,
            ),
            onPressed: () => context.push('/order-history'),
          ),
        ),

        const SizedBox(width: 12),

        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => context.push('/outlet-info'),

            child: Container(
              width: 44,
              height: 44,

              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryLight, width: 2),
              ),

              child: const Icon(
                Icons.person_rounded,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HEADER CARD
  // ============================================================

  Widget _buildHeaderCard(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/outlet-info'),

      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF17321F), Color(0xFF121E17)]
                : const [Color(0xFFE8F8EC), Color(0xFFFFF9F0)],

            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),

          borderRadius: BorderRadius.circular(24),

          border: Border.all(color: AppColors.primaryAlpha(0.25)),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================================================
            // RESTAURANT IMAGE / ICON
            // ==================================================

                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryAlpha(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // ==================================================
                // RESTAURANT DETAILS
                // ==================================================
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        restaurantAsync.value?.restaurantName ?? '—',

                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Row(
                        children: [
                          // ACTIVE
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),

                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(10),
                            ),

                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 14,
                                ),

                                const SizedBox(width: 4),

                                const Text(
                                  'Active',
                                  style: TextStyle(
                                    color: AppColors.primaryDeep,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (restaurantAsync.value != null &&
                              restaurantAsync.value!.rating > 0) ...[
                            const SizedBox(width: 7),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),

                              decoration: BoxDecoration(
                                color: AppColors.warningLight,
                                borderRadius: BorderRadius.circular(10),
                              ),

                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: AppColors.rating,
                                    size: 14,
                                  ),

                                  const SizedBox(width: 4),

                                  Text(
                                    '${restaurantAsync.value!.rating.toStringAsFixed(1)} (${restaurantAsync.value!.totalRatings})',

                                    style: const TextStyle(
                                      color: AppColors.neutral700,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 13),

                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primaryDark,
                            size: 16,
                          ),

                          const SizedBox(width: 4),

                          Expanded(
                            child: Text(
                              restaurantAsync.value?.fullAddress.isNotEmpty ==
                                      true
                                  ? restaurantAsync.value!.fullAddress
                                  : 'Address not set yet',

                              style: TextStyle(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontSize: 11,
                              ),

                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceVariantDark
                        : Colors.white.withValues(alpha: 0.95),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.07),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.primaryDeep,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 4,
          height: 17,

          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),

        const SizedBox(width: 8),

        Text(
          title,

          style: TextStyle(
            color: isDark ? AppColors.textPrimaryDark : AppColors.primaryDeep,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Container(height: 1, color: AppColors.primaryAlpha(0.16)),
        ),
      ],
    );
  }

  // ============================================================
  // CARD WIDTH
  // ============================================================

  double _getCardWidth(BuildContext context, int count) {
    final screenWidth = MediaQuery.of(context).size.width;

    return (screenWidth - 32 - (14 * (count - 1))) / count;
  }

  // ============================================================
  // VERTICAL CARD
  // ============================================================

  Widget _buildVerticalCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required double width,
    Color? iconBgColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedIconColor = iconColor ?? AppColors.primaryDark;

    final resolvedBgColor = iconBgColor ?? AppColors.primaryTint;

    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(20),

        child: Container(
          width: width,

          padding: const EdgeInsets.fromLTRB(8, 15, 8, 13),

          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,

            borderRadius: BorderRadius.circular(20),

            border: Border.all(
              color: AppColors.primaryAlpha(isDark ? 0.13 : 0.10),
            ),

            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.045),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              // ==================================================
              // ICON
              // ==================================================

              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  color: resolvedBgColor,
                  shape: BoxShape.circle,
                ),

                child: Center(
                  child: Icon(icon, color: resolvedIconColor, size: 24),
                ),
              ),

              const SizedBox(height: 11),

              // ==================================================
              // TITLE
              // ==================================================
              Text(
                title,

                textAlign: TextAlign.center,

                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 4),

              // ==================================================
              // SUBTITLE
              // ==================================================
              Text(
                subtitle,

                textAlign: TextAlign.center,

                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark.withValues(alpha: 0.70)
                      : AppColors.textSecondaryLight.withValues(alpha: 0.70),
                  fontSize: 8.5,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 10),

              // ==================================================
              // ARROW
              // ==================================================
              Container(
                width: 25,
                height: 25,

                decoration: BoxDecoration(
                  color: resolvedIconColor.withValues(alpha: 0.08),

                  shape: BoxShape.circle,

                  border: Border.all(
                    color: resolvedIconColor.withValues(alpha: 0.20),
                  ),
                ),

                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: resolvedIconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT CARD
  // ============================================================

  Widget _buildLogoutCard(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,

          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),

            title: const Text('Logout?'),

            content: const Text(
              'You will need to verify your phone number again to log back in.',
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),

                child: const Text('Cancel'),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context, true),

                child: const Text(
                  'Logout',

                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          await ref.read(authControllerProvider.notifier).logout();
        }
      },

      borderRadius: BorderRadius.circular(22),

      child: _buildActionCard(
        context: context,
        icon: Icons.logout_rounded,
        title: 'Logout',
        subtitle: 'Tap to sign out from this device',
        color: AppColors.error,
      ),
    );
  }

  // ============================================================
  // DELETE ACCOUNT CARD
  // ============================================================

  Widget _buildDeleteAccountCard(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () async {
        final confirmed = await showDialog<bool>(
          context: context,

          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),

            title: const Text('Delete Account?'),

            content: const Text(
              'Are you sure you want to delete your account? This will permanently delete your restaurant profile, menu items, order history, and account data. This action cannot be undone.',
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),

                child: const Text('Cancel'),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context, true),

                child: const Text(
                  'Delete Account',

                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        if (confirmed == true && context.mounted) {
          try {
            await ref.read(authControllerProvider.notifier).deleteAccount();
          } catch (e) {
            if (context.mounted) {
              final message = e is ApiException
                  ? e.message
                  : 'Failed to delete account. Please try again.';

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
        }
      },

      borderRadius: BorderRadius.circular(22),

      child: _buildActionCard(
        context: context,
        icon: Icons.delete_outline_rounded,
        title: 'Delete Account',
        subtitle: 'Permanently delete your account',
        color: AppColors.error,
      ),
    );
  }

  // ============================================================
  // COMMON ACTION CARD
  // ============================================================

  Widget _buildActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),

      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,

        borderRadius: BorderRadius.circular(22),

        border: Border.all(color: color.withValues(alpha: 0.10)),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.13 : 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),

      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,

            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),

            child: Icon(icon, color: color, size: 23),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  subtitle,

                  style: TextStyle(
                    color: color.withValues(alpha: 0.65),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            Icons.arrow_forward_ios_rounded,

            color: color.withValues(alpha: 0.45),

            size: 15,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BACKGROUND DECORATION
  // ============================================================

  Widget _buildBackgroundDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Stack(
        children: [
          // ======================================================
          // TOP RIGHT CIRCLE
          // ======================================================

          Positioned(
            top: 80,
            right: -130,

            child: Container(
              width: 280,
              height: 280,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                border: Border.all(
                  color: AppColors.primaryAlpha(isDark ? 0.08 : 0.14),
                  width: 1.5,
                ),
              ),
            ),
          ),

          // ======================================================
          // DECORATIVE DOTS
          // ======================================================
          Positioned(
            top: 125,
            right: 24,

            child: SizedBox(
              width: 45,

              child: Wrap(
                spacing: 10,
                runSpacing: 10,

                children: List.generate(
                  12,

                  (index) => Container(
                    width: 3.5,
                    height: 3.5,

                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha(0.22),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // BOTTOM LEFT CIRCLE
          // ======================================================
          Positioned(
            bottom: 120,
            left: -170,

            child: Container(
              width: 300,
              height: 300,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                border: Border.all(
                  color: AppColors.primaryAlpha(isDark ? 0.06 : 0.10),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
