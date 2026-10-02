import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/haptics.dart';
import '../../core/services/review_service.dart';
import '../navigation/route_names.dart';
import '../branding/app_colors.dart';
import '../common_widgets/app_snackbar.dart';
import '../../data/models/user_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../address/viewmodels/address_viewmodel.dart';
import '../address/widgets/saved_addresses_bottom_sheet.dart';
import '../coupons/viewmodels/coupons_viewmodel.dart';
import 'viewmodels/notifications_viewmodel.dart';
import '../orders/viewmodels/orders_viewmodel.dart';
import '../wallet/viewmodels/wallet_viewmodel.dart';
import '../../core/utils/localizations.dart';
import '../branding/theme_provider.dart';
import '../home/viewmodels/veg_filter_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  // ================================================================
  // REFER & EARN ANIMATION
  // ================================================================

  late AnimationController _referAnimationController;
  late Animation<double> _referScaleAnimation;
  late Animation<double> _referRotationAnimation;

  @override
  void initState() {
    super.initState();

    _referAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _referScaleAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(
        parent: _referAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _referRotationAnimation = Tween<double>(begin: -0.012, end: 0.012).animate(
      CurvedAnimation(
        parent: _referAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    // Animation will run for EVERYONE,
    // logged-in and guest users both.
    _referAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _referAnimationController.dispose();
    super.dispose();
  }

  // ================================================================
  // THEME TEXT
  // ================================================================

  String _getThemeString(ThemeMode mode) {
    if (mode == ThemeMode.light) return 'Light';
    if (mode == ThemeMode.dark) return 'Dark';
    return 'System';
  }

  // ================================================================
  // PROTECTED NAVIGATION
  // ================================================================

  void _protectedNavigation(String route, bool isLoggedIn) {
    if (isLoggedIn) {
      context.push(route);
    } else {
      context.push('${RouteNames.login}?from=${Uri.encodeComponent(route)}');
    }
  }

  // ================================================================
  // APPEARANCE MODAL - WORKING
  // ================================================================

  void _showAppearanceModal() {
    final currentTheme = ref.read(themeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        final modalColor = isDark ? AppColors.cardDark : Colors.white;

        final modalTextColor = isDark
            ? Colors.white
            : AppColors.textPrimaryLight;

        final modalSecondaryColor = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;

        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
            decoration: BoxDecoration(
              color: modalColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: modalSecondaryColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 22),

                // Header
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.palette_outlined,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Appearance',
                            style: TextStyle(
                              color: modalTextColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Choose your preferred theme',
                            style: TextStyle(
                              color: modalSecondaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // SYSTEM
                _buildThemeOption(
                  sheetContext,
                  title: 'System',
                  subtitle: 'Follow your phone settings',
                  icon: Icons.phone_android_outlined,
                  mode: ThemeMode.system,
                  selected: currentTheme == ThemeMode.system,
                  textColor: modalTextColor,
                  secondaryColor: modalSecondaryColor,
                ),

                const SizedBox(height: 10),

                // LIGHT
                _buildThemeOption(
                  sheetContext,
                  title: 'Light',
                  subtitle: 'Use light appearance',
                  icon: Icons.light_mode_outlined,
                  mode: ThemeMode.light,
                  selected: currentTheme == ThemeMode.light,
                  textColor: modalTextColor,
                  secondaryColor: modalSecondaryColor,
                ),

                const SizedBox(height: 10),

                // DARK
                _buildThemeOption(
                  sheetContext,
                  title: 'Dark',
                  subtitle: 'Use dark appearance',
                  icon: Icons.dark_mode_outlined,
                  mode: ThemeMode.dark,
                  selected: currentTheme == ThemeMode.dark,
                  textColor: modalTextColor,
                  secondaryColor: modalSecondaryColor,
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================================================================
  // THEME OPTION
  // ================================================================

  Widget _buildThemeOption(
    BuildContext sheetContext, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool selected,
    required Color textColor,
    required Color secondaryColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Haptics.light();

        // ACTUAL THEME CHANGE
        ref.read(themeProvider.notifier).setTheme(mode);

        Navigator.of(sheetContext).pop();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.10)
              : secondaryColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : secondaryColor.withValues(alpha: 0.12),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 25,
              color: selected ? AppColors.primary : secondaryColor,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Radio
            Container(
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : secondaryColor.withValues(alpha: 0.45),
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // RATING MODAL - WORKING
  // ================================================================

  void _showRateAppModal() {
    int selectedRating = 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        final modalColor = isDark ? AppColors.cardDark : Colors.white;

        final modalTextColor = isDark
            ? Colors.white
            : AppColors.textPrimaryLight;

        final modalSecondaryColor = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 25),
                decoration: BoxDecoration(
                  color: modalColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: modalSecondaryColor.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Star Icon
                    Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.star_rounded,
                        color: Colors.amber,
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'Rate Cravioo',
                      style: TextStyle(
                        color: modalTextColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'How was your experience with us?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: modalSecondaryColor,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // STARS
                    // ==================================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final rating = index + 1;

                        final isSelected = selectedRating >= rating;

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Haptics.light();

                            setModalState(() {
                              selectedRating = rating;
                            });
                          },
                          child: AnimatedScale(
                            scale: isSelected ? 1.12 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Icon(
                                isSelected
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: isSelected
                                    ? Colors.amber
                                    : modalSecondaryColor.withValues(
                                        alpha: 0.45,
                                      ),
                                size: 43,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      selectedRating == 0
                          ? 'Tap a star to rate'
                          : _ratingText(selectedRating),
                      style: TextStyle(
                        color: selectedRating == 0
                            ? modalSecondaryColor
                            : AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ==================================================
                    // SUBMIT
                    // ==================================================
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: selectedRating == 0
                            ? null
                            : () async {
                                Haptics.medium();

                                Navigator.of(sheetContext).pop();

                                await Future.delayed(
                                  const Duration(milliseconds: 250),
                                );

                                try {
                                  // Native app review
                                  await ReviewService.requestReviewIfQualified(
                                    selectedRating,
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  AppSnackbar.success(
                                    context,
                                    'Thanks for rating Cravioo!',
                                  );
                                } catch (_) {
                                  if (!mounted) {
                                    return;
                                  }

                                  AppSnackbar.success(
                                    context,
                                    'Thanks for your feedback!',
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: modalSecondaryColor
                              .withValues(alpha: 0.12),
                          disabledForegroundColor: modalSecondaryColor
                              .withValues(alpha: 0.45),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: Text(
                          selectedRating == 0
                              ? 'Select a rating'
                              : 'Submit rating',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================================================================
  // RATING TEXT
  // ================================================================

  String _ratingText(int rating) {
    switch (rating) {
      case 1:
        return 'We’ll try to do better';
      case 2:
        return 'Thanks for your feedback';
      case 3:
        return 'Glad you liked it';
      case 4:
        return 'Great! Thank you';
      case 5:
        return 'Awesome! Thank you ❤️';
      default:
        return '';
    }
  }

  // ================================================================
  // ADDRESS
  // ================================================================

  void _showAddressManagerModal() {
    showSavedAddressesSheet(context);
  }

  // ================================================================
  // COUPONS
  // ================================================================

  void _showCouponsModal() {
    AppSnackbar.success(context, 'Coupons section opened');
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    final cardColor = isDark ? AppColors.cardDark : Colors.white;

    final user = ref.watch(authViewModelProvider).value;

    final isLoggedIn = user != null;

    final addresses = ref.watch(addressViewModelProvider);

    final coupons = ref.watch(couponsViewModelProvider);

    final notificationSettings = ref.watch(notificationsViewModelProvider);

    final walletState = isLoggedIn ? ref.watch(walletViewModelProvider) : null;

    final walletBalance = walletState?.wallet.balance ?? 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
          children: [
            // =========================================================
            // BACK BUTTON
            // =========================================================

            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: textColor,
                  size: 27,
                ),
                onPressed: () {
                  Haptics.light();

                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RouteNames.home);
                  }
                },
              ),
            ),

            const SizedBox(height: 8),

            // =========================================================
            // PROFILE HEADER
            // =========================================================
            if (isLoggedIn)
              _buildProfileHeaderCard(user, isDark, textColor, secondaryColor)
            else
              _buildGuestHeaderCard(context, isDark, textColor, secondaryColor),

            const SizedBox(height: 14),

            // =========================================================
            // GOLD BANNER
            // =========================================================
            _buildGoldBanner(isDark, textColor),

            const SizedBox(height: 14),

            // =========================================================
            // MONEY + COUPONS
            // =========================================================
            _buildMoneyCouponsRow(
              walletBalance: walletBalance,
              couponCount: coupons.length,
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              isLoggedIn: isLoggedIn,
            ),

            const SizedBox(height: 14),

            // =========================================================
            // CART
            // =========================================================
            _buildSingleMenuCard(
              icon: Icons.shopping_cart_outlined,
              title: 'Your cart',
              subtitle: 'View items in your cart',
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              onTap: () {
                Haptics.light();
                context.go(RouteNames.cart);
              },
            ),

            const SizedBox(height: 14),

            // =========================================================
            // ORDERS (My Orders)
            // =========================================================
            _buildOrderHistoryCard(
              cardColor,
              isDark,
              textColor,
              secondaryColor,
              isLoggedIn,
            ),

            const SizedBox(height: 12),

            // =========================================================
            // DINING RESERVATIONS
            // =========================================================
            _buildSingleMenuCard(
              icon: Icons.table_restaurant_outlined,
              title: 'Dining Bookings',
              subtitle: 'Table reservations & history',
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              onTap: () {
                Haptics.light();
                _protectedNavigation(RouteNames.diningBookings, isLoggedIn);
              },
            ),

            const SizedBox(height: 12),

            // =========================================================
            // PROFILE
            // =========================================================
            _buildSingleMenuCard(
              icon: Icons.person_outline_rounded,
              title: 'Your profile',
              subtitle: 'Edit your personal details',
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              trailing: isLoggedIn
                  ? Text(
                      '48% completed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        backgroundColor: Colors.yellow.withValues(alpha: 0.8),
                      ),
                    )
                  : null,
              onTap: () {
                Haptics.light();

                if (isLoggedIn) {
                  context.push(RouteNames.editProfile);
                } else {
                  context.push(
                    '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.profile)}',
                  );
                }
              },
            ),

            const SizedBox(height: 12),

            // =========================================================
            // VEG MODE
            // =========================================================
            _buildVegModeCard(
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
            ),

            const SizedBox(height: 12),

            // =========================================================
            // APPEARANCE
            // =========================================================
            _buildSingleMenuCard(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              subtitle: _getThemeString(ref.watch(themeProvider)),
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              onTap: _showAppearanceModal,
            ),

            const SizedBox(height: 12),

            // =========================================================
            // RATING
            // =========================================================
            _buildSingleMenuCard(
              icon: Icons.star_border_rounded,
              title: 'Your rating',
              subtitle: 'Rate your Cravioo experience',
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              iconColor: Colors.amber,
              onTap: _showRateAppModal,
            ),

            const SizedBox(height: 22),

            // =========================================================
            // COLLECTIONS
            // =========================================================
            Row(
              children: [
                Container(
                  width: 5,
                  height: 25,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Collections',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            _buildSingleMenuCard(
              icon: Icons.bookmark_border_rounded,
              title: 'Your collections',
              subtitle: 'Saved restaurants and dishes',
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              onTap: () {
                Haptics.light();
                context.push(RouteNames.favorites);
              },
            ),

            const SizedBox(height: 14),

            // =========================================================
            // PAY LATER
            // =========================================================
            if (isLoggedIn) ...[
              _buildPayLaterTile(cardColor, isDark, textColor, secondaryColor),
              const SizedBox(height: 14),
            ],

            // =========================================================
            // ADDRESSES
            // =========================================================
            _buildSingleMenuCard(
              icon: Icons.location_on_outlined,
              title: 'Saved addresses',
              subtitle: '${addresses.length} saved',
              cardColor: cardColor,
              isDark: isDark,
              textColor: textColor,
              secondaryColor: secondaryColor,
              onTap: () {
                Haptics.light();

                if (isLoggedIn) {
                  _showAddressManagerModal();
                } else {
                  context.push(
                    '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.addAddress)}',
                  );
                }
              },
            ),

            const SizedBox(height: 14),

            // =========================================================
            // PREFERENCES
            // =========================================================
            _buildPreferencesGroupCard(
              notificationSettings,
              cardColor,
              isDark,
              textColor,
              secondaryColor,
              isLoggedIn,
            ),

            const SizedBox(height: 14),

            // =========================================================
            // REFER & EARN
            // ALWAYS VISIBLE + ANIMATED
            // =========================================================
            _buildRewardsSharingGroupCard(
              user?.referralCode ?? '',
              cardColor,
              isDark,
              textColor,
              secondaryColor,
              isLoggedIn,
            ),

            const SizedBox(height: 14),

            // =========================================================
            // HELP
            // =========================================================
            _buildHelpLegalGroupCard(
              cardColor,
              isDark,
              textColor,
              secondaryColor,
            ),

            const SizedBox(height: 20),

            // =========================================================
            // LOGOUT / LOGIN
            // =========================================================
            if (isLoggedIn)
              _buildLogoutButton(cardColor, isDark)
            else
              _buildLoginButton(cardColor),

            // =========================================================
            // DELETE ACCOUNT
            // =========================================================
            if (isLoggedIn) ...[
              const SizedBox(height: 12),
              _buildDeleteAccountButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ==================================================================
  // PROFILE HEADER
  // ==================================================================

  Widget _buildProfileHeaderCard(
    UserModel? user,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    final avatarUrl = user?.avatarUrl;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: AppColors.primaryAlpha(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: ClipOval(
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Image.asset(
                      'assets/images/user_avatar_3d.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 42,
                        );
                      },
                    )
                  : avatarUrl.startsWith('/')
                  ? Image.file(
                      File(avatarUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 42,
                        );
                      },
                    )
                  : avatarUrl.startsWith('assets/')
                  ? Image.asset(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 42,
                        );
                      },
                    )
                  : Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Icon(
                          Icons.person_rounded,
                          color: AppColors.primary,
                          size: 42,
                        );
                      },
                    ),
            ),
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name.isNotEmpty == true ? user!.name : 'John Doe',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user?.email.isNotEmpty == true
                      ? user!.email
                      : 'john@example.com',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, color: secondaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // GUEST HEADER
  // ==================================================================

  Widget _buildGuestHeaderCard(
    BuildContext context,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          Haptics.light();
          context.push(RouteNames.login);
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: AppColors.shadow1,
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  color: AppColors.primaryAlpha(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),

              const SizedBox(width: 18),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login to account',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Login to access your profile, orders and more',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: secondaryColor),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right_rounded,
                color: secondaryColor,
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================================
  // GOLD BANNER
  // ==================================================================

  Widget _buildGoldBanner(bool isDark, Color textColor) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Haptics.light();

          AppSnackbar.success(
            context,
            'Cravioo Gold coming soon 👑',
            duration: const Duration(seconds: 2),
          );
        },
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Text('👑', style: TextStyle(fontSize: 25)),
              const SizedBox(width: 13),
              const Expanded(
                child: Text(
                  'Join Cravioo Gold',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFFFD21F),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white,
                size: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================================
  // MONEY + COUPONS
  // ==================================================================

  Widget _buildMoneyCouponsRow({
    required double walletBalance,
    required int couponCount,
    required Color cardColor,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
    required bool isLoggedIn,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildSmallInfoCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Cravio\nMoney',
            value: isLoggedIn ? '₹${walletBalance.toStringAsFixed(0)}' : '₹0',
            cardColor: cardColor,
            isDark: isDark,
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: () {
              Haptics.light();

              _protectedNavigation(RouteNames.wallet, isLoggedIn);
            },
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildSmallInfoCard(
            icon: Icons.local_offer_outlined,
            title: 'Your\ncoupons',
            value: 'View all',
            cardColor: cardColor,
            isDark: isDark,
            textColor: textColor,
            secondaryColor: secondaryColor,
            onTap: () {
              Haptics.light();
              _showCouponsModal();
            },
          ),
        ),
      ],
    );
  }

  // ==================================================================
  // SMALL INFO CARD
  // ==================================================================

  Widget _buildSmallInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color cardColor,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: AppColors.shadow1,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF7F7F7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isDark ? textColor : const Color(0xFF4B4B4B),
                  size: 22,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================================
  // SINGLE MENU CARD
  // ==================================================================

  Widget _buildSingleMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color cardColor,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
    required VoidCallback onTap,
    Color? iconColor,
    Widget? trailing,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: AppColors.shadow1,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFF8F8F8),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color:
                      iconColor ??
                      (isDark ? textColor : const Color(0xFF454545)),
                  size: 23,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: secondaryColor),
                    ),
                  ],
                ),
              ),

              if (trailing != null) ...[
                Flexible(child: trailing),
                const SizedBox(width: 10),
              ],

              Icon(
                Icons.chevron_right_rounded,
                color: secondaryColor,
                size: 25,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================================================================
  // VEG MODE
  // ==================================================================

  Widget _buildVegModeCard({
    required Color cardColor,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF39C96B).withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.eco_outlined,
              color: Color(0xFF39C96B),
              size: 24,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.vegMode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.vegModeSubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: secondaryColor),
                ),
              ],
            ),
          ),

          Switch(
            value: ref.watch(vegFilterProvider),
            activeThumbColor: const Color(0xFF39C96B),
            onChanged: (value) {
              Haptics.light();

              ref.read(vegFilterProvider.notifier).set(value);
            },
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // ORDER HISTORY
  // ==================================================================

  Widget _buildOrderHistoryCard(
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    bool isLoggedIn,
  ) {
    final ordersState = ref.watch(ordersViewModelProvider);

    final upcoming = isLoggedIn ? ordersState.upcomingCount.toString() : '0';

    final completed = isLoggedIn ? ordersState.completedCount.toString() : '0';

    final cancelled = isLoggedIn ? ordersState.cancelledCount.toString() : '0';

    final refunded = isLoggedIn ? ordersState.refundedCount.toString() : '0';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'My Orders',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              InkWell(
                onTap: () {
                  Haptics.light();

                  _protectedNavigation(RouteNames.orders, isLoggedIn);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOrderStatusItem(
                'Active',
                upcoming,
                textColor,
                secondaryColor,
              ),
              _buildOrderStatusItem(
                'Completed',
                completed,
                textColor,
                secondaryColor,
              ),
              _buildOrderStatusItem(
                'Cancelled',
                cancelled,
                textColor,
                secondaryColor,
              ),
              _buildOrderStatusItem(
                'Refunded',
                refunded,
                textColor,
                secondaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // ORDER STATUS
  // ==================================================================

  Widget _buildOrderStatusItem(
    String label,
    String count,
    Color textColor,
    Color secondaryColor,
  ) {
    return Flexible(
      child: Column(
        children: [
          Text(
            count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: secondaryColor),
          ),
        ],
      ),
    );
  }

  // ==================================================================
  // PAY LATER
  // ==================================================================

  Widget _buildPayLaterTile(
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    return _buildSingleMenuCard(
      icon: Icons.credit_score_outlined,
      title: 'Pay Later',
      subtitle: 'Manage credit & limits',
      cardColor: cardColor,
      isDark: isDark,
      textColor: textColor,
      secondaryColor: secondaryColor,
      onTap: () {
        Haptics.light();
        context.push(RouteNames.payLater);
      },
    );
  }

  // ==================================================================
  // PREFERENCES
  // ==================================================================

  Widget _buildPreferencesGroupCard(
    dynamic settings,
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    bool isLoggedIn,
  ) {
    return _buildSingleMenuCard(
      icon: Icons.notifications_none_rounded,
      title: 'Notification Settings',
      subtitle: 'Manage push notifications',
      cardColor: cardColor,
      isDark: isDark,
      textColor: textColor,
      secondaryColor: secondaryColor,
      onTap: () {
        Haptics.light();

        _protectedNavigation(RouteNames.notifications, isLoggedIn);
      },
    );
  }

  // ==================================================================
  // REFER & EARN
  // ANIMATED + AVAILABLE WITHOUT LOGIN
  // ==================================================================

  Widget _buildRewardsSharingGroupCard(
    String code,
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
    bool isLoggedIn,
  ) {
    return AnimatedBuilder(
      animation: _referAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _referScaleAnimation.value,
          child: Transform.rotate(
            angle: _referRotationAnimation.value,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Haptics.light();

            if (!isLoggedIn) {
              // Guest -> Login
              context.push(
                '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.referral)}',
              );
              return;
            }

            // Logged-in -> Referral
            context.push(RouteNames.referral);
          },
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary.withValues(alpha: 0.14), cardColor],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.20),
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.shadow1,
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                // Gift icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Refer & Earn',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        isLoggedIn
                            ? (code.isNotEmpty
                                  ? 'Code: $code'
                                  : 'Invite friends and earn rewards')
                            : 'Login to refer friends & earn rewards',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondaryColor, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.primary,
                    size: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================================================================
  // HELP
  // ==================================================================

  Widget _buildHelpLegalGroupCard(
    Color cardColor,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    return _buildSingleMenuCard(
      icon: Icons.help_outline_rounded,
      title: 'Help & Support',
      subtitle: 'FAQs & Customer Support',
      cardColor: cardColor,
      isDark: isDark,
      textColor: textColor,
      secondaryColor: secondaryColor,
      onTap: () {
        Haptics.light();

        context.push(RouteNames.helpSupport);
      },
    );
  }

  // ==================================================================
  // LOGOUT
  // ==================================================================

  Widget _buildLogoutButton(Color cardColor, bool isDark) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade50,
        foregroundColor: AppColors.primary,
        elevation: 0,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () async {
        Haptics.light();

        await ref.read(authViewModelProvider.notifier).logout();

        if (!mounted) return;

        context.go(RouteNames.home);
      },
      child: const Text(
        'Logout',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  // ==================================================================
  // LOGIN BUTTON
  // ==================================================================

  Widget _buildLoginButton(Color cardColor) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      onPressed: () {
        Haptics.light();

        context.push(RouteNames.login);
      },
      child: const Text(
        'Guest User',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  // ==================================================================
  // DELETE ACCOUNT
  // ==================================================================

  Widget _buildDeleteAccountButton() {
    return TextButton(
      onPressed: () {
        Haptics.light();

        AppSnackbar.success(context, 'Delete account option selected');
      },
      child: const Text(
        'Delete Account',
        style: TextStyle(color: Colors.lightGreen, fontSize: 13),
      ),
    );
  }
}
