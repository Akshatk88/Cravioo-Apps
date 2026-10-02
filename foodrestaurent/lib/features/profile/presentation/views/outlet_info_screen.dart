import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/widgets/edit_field_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_media_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

class OutletInfoScreen extends ConsumerWidget {
  const OutletInfoScreen({super.key});

  static const Color chocolateColor = Color(0xFF6B3E26);
  static const Color lightChocolate = Color(0xFFF7EFEA);
  static const Color darkChocolate = Color(0xFF4A291B);

  Color _textColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _secondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
  }

  Color _cardColor(BuildContext context) {
    return Theme.of(context).cardColor;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,

        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _textColor(context),
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),

        title: Text(
          'Outlet info',
          style: TextStyle(
            color: _textColor(context),
            fontWeight: FontWeight.w800,
            fontSize: 19,
          ),
        ),

        actions: [
          if (restaurantAsync.value != null)
            Flexible(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    'ID: ${restaurantAsync.value!.restaurantId.isNotEmpty ? restaurantAsync.value!.restaurantId : restaurantAsync.value!.id.substring(0, restaurantAsync.value!.id.length.clamp(0, 6))}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _secondaryTextColor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),

      body: restaurantAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),

        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  error is ApiException
                      ? error.message
                      : 'Failed to load outlet info.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        data: (restaurant) => AppRefreshIndicator(
          onRefresh: () =>
              ref.read(restaurantProfileControllerProvider.notifier).refresh(),

          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBanner(context, restaurant),

                _buildLogoCard(context, ref, restaurant),

                SizedBox(height: restaurant.isApproved ? 20 : 4),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context,
                        title: 'Restaurant Information',
                        subtitle:
                            'All onboarding and profile details at one place.',
                      ),

                      const SizedBox(height: 20),

                      _buildRestaurantNameCard(context, ref, restaurant),

                      const SizedBox(height: 14),

                      _buildBasicDetailsCard(context, ref, restaurant),

                      const SizedBox(height: 14),

                      _buildAddressCard(context, restaurant),

                      const SizedBox(height: 14),

                      _buildComplianceCard(context, ref, restaurant),

                      const SizedBox(height: 14),

                      _buildBankDetailsCard(context, ref, restaurant),

                      const SizedBox(height: 14),

                      _buildMediaCard(context, ref, restaurant),

                      const SizedBox(height: 32),
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
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 22,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _textColor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS BANNER
  // ============================================================

  Widget _buildBanner(BuildContext context, RestaurantModel restaurant) {
    if (restaurant.isApproved) {
      return const SizedBox.shrink();
    }

    final message = restaurant.isRejected
        ? (restaurant.rejectionReason.isNotEmpty
              ? restaurant.rejectionReason
              : 'Your application was rejected. Please contact support.')
        : "Your restaurant is still under review — customers can't order from you yet.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF49315B), Color(0xFF714878)],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              restaurant.isRejected
                  ? Icons.error_outline_rounded
                  : Icons.hourglass_top_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            restaurant.isRejected
                ? 'Application Rejected'
                : "We'll be there soon - hang tight!",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGO CARD
  // ============================================================

  Widget _buildLogoCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return Transform.translate(
      offset: restaurant.isApproved ? Offset.zero : const Offset(0, -18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),

          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange.shade100, Colors.orange.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),

          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -12,
                bottom: -12,
                child: Opacity(
                  opacity: 0.12,
                  child: Image.asset(
                    'assets/image/shopman.webp',
                    width: 125,
                    height: 125,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.storefront_rounded,
                      size: 90,
                      color: Colors.orange.shade400,
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LOGO
                      ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: restaurant.profileImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: restaurant.profileImage,
                                width: 62,
                                height: 62,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) =>
                                    _logoPlaceholder(size: 62),
                              )
                            : _logoPlaceholder(size: 62),
                      ),

                      const SizedBox(width: 11),

                      // NAME
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                restaurant.restaurantName.isNotEmpty
                                    ? restaurant.restaurantName
                                    : '—',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  height: 1.15,
                                ),
                              ),

                              if (restaurant.isApproved) ...[
                                const SizedBox(height: 6),

                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.green.shade600,
                                        size: 13,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Verified',
                                        style: TextStyle(
                                          color: Colors.green.shade700,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // CHANGE LOGO
                      GestureDetector(
                        onTap: () async {
                          if (restaurant.isApproved) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                title: const Text(
                                  'Change restaurant logo?',
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                content: const Text(
                                  'Your restaurant is currently approved. '
                                  'Changing the logo will send your profile '
                                  'back for admin review, and ordering will '
                                  'pause until re-approved.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: _secondaryTextColor(context),
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text(
                                      'Continue',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true) {
                              return;
                            }
                          }

                          final file = await pickImageWithSourceSheet(context);

                          if (file == null) {
                            return;
                          }

                          try {
                            await ref
                                .read(
                                  restaurantProfileControllerProvider.notifier,
                                )
                                .uploadProfileImage(file);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Logo updated.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showError(context, e);
                            }
                          }
                        },

                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 14,
                                color: Colors.black87,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Change logo',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // RATING
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              restaurant.totalRatings > 0
                                  ? restaurant.rating.toStringAsFixed(1)
                                  : 'New',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                            if (restaurant.totalRatings > 0) ...[
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      Flexible(
                        child: Text(
                          '${restaurant.totalRatings} Ratings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      const Text(
                        '|',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),

                      const SizedBox(width: 8),

                      Flexible(
                        child: Text(
                          'Be the first to review!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logoPlaceholder({double size = 60}) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF5B3B68),
      child: const Center(
        child: Icon(Icons.storefront_rounded, color: Colors.white70, size: 28),
      ),
    );
  }

  // ============================================================
  // RESTAURANT NAME
  // ============================================================

  Widget _buildRestaurantNameCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Restaurant name',
      icon: Icons.storefront_outlined,
      showApprovedBadge: restaurant.isApproved,

      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit restaurant name',
          fields: [
            EditFieldSpec(
              key: 'restaurantName',
              label: 'Restaurant name',
              initialValue: restaurant.restaurantName,
            ),
          ],
        );

        if (result == null) {
          return;
        }

        await _saveProfile(context, ref, result);
      },

      children: [
        _buildDetailRow(
          context,
          'Restaurant Name',
          restaurant.restaurantName,
          icon: Icons.storefront_outlined,
          iconColor: chocolateColor,
          showDivider: false,
        ),
      ],
    );
  }

  // ============================================================
  // BASIC DETAILS
  // ============================================================

  Widget _buildBasicDetailsCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Basic details',
      icon: Icons.person_outline_rounded,
      showApprovedBadge: restaurant.isApproved,

      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit basic details',
          fields: [
            EditFieldSpec(
              key: 'ownerName',
              label: 'Owner name',
              initialValue: restaurant.ownerName,
            ),
            EditFieldSpec(
              key: 'primaryContactNumber',
              label: 'Primary contact',
              initialValue: restaurant.primaryContactNumber,
              keyboardType: TextInputType.phone,
            ),
            EditFieldSpec(
              key: 'ownerEmail',
              label: 'Email',
              initialValue: restaurant.ownerEmail,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        );

        if (result == null) {
          return;
        }

        await _saveProfile(context, ref, result);
      },

      children: [
        _buildDetailRow(
          context,
          'Owner name',
          restaurant.ownerName,
          icon: Icons.person_outline,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'Primary contact',
          restaurant.primaryContactNumber,
          icon: Icons.phone_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'Email',
          restaurant.ownerEmail.isEmpty ? 'Not set' : restaurant.ownerEmail,
          icon: Icons.mail_outline,
          showDivider: true,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'Menu Type',
          restaurant.pureVegRestaurant ? 'Pure Veg' : 'Mixed (Veg & Non-Veg)',
          icon: restaurant.pureVegRestaurant ? Icons.eco_outlined : Icons.restaurant_menu_outlined,
          iconColor: restaurant.pureVegRestaurant ? Colors.green : Colors.deepOrange,
          trailing: SizedBox(
            height: 30,
            child: Switch.adaptive(
              value: !restaurant.pureVegRestaurant,
              activeTrackColor: AppColors.primary,
              onChanged: (allowsNonVeg) async {
                try {
                  await ref
                      .read(restaurantProfileControllerProvider.notifier)
                      .updateProfile({'pureVegRestaurant': !allowsNonVeg});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          allowsNonVeg
                              ? 'Switched to Mixed Menu (Veg & Non-Veg allowed).'
                              : 'Switched to Pure Veg Menu.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) _showError(context, e);
                }
              },
            ),
          ),
          showDivider: false,
        ),
      ],
    );
  }

  // ============================================================
  // ADDRESS
  // ============================================================

  Widget _buildAddressCard(BuildContext context, RestaurantModel restaurant) {
    return _buildInfoCard(
      context: context,
      title: 'Address and location',
      icon: Icons.location_on_outlined,
      showApprovedBadge: false,
      hideEdit: true,

      children: [
        _buildDetailRow(
          context,
          'Full address',
          restaurant.fullAddress.isNotEmpty
              ? restaurant.fullAddress
              : 'Not set yet',
          isVertical: true,
          showDivider: false,
        ),

        if (restaurant.hasPendingLocationUpdate) ...[
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 17,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A location update is pending admin review.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 16),

        GestureDetector(
          onTap: () => context.push('/zone-setup'),

          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Update via Zone Setup',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // COMPLIANCE
  // ============================================================

  Widget _buildComplianceCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Compliance details',
      icon: Icons.verified_user_outlined,
      showApprovedBadge: restaurant.isApproved,

      onEdit: () => _openComplianceSheet(context, ref, restaurant),

      children: [
        _buildDetailRow(
          context,
          'PAN number',
          restaurant.panNumber.isEmpty ? 'Not set' : restaurant.panNumber,
          icon: Icons.credit_card_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'GST registered',
          restaurant.gstRegistered ? 'Yes' : 'No',
          icon: Icons.receipt_long_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'FSSAI number',
          restaurant.fssaiNumber.isEmpty ? 'Not set' : restaurant.fssaiNumber,
          icon: Icons.shield_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'FSSAI expiry',
          restaurant.fssaiExpiry.isEmpty ? 'Not set' : restaurant.fssaiExpiry,
          icon: Icons.event_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  // ============================================================
  // BANK
  // ============================================================

  Widget _buildBankDetailsCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Bank and UPI details',
      icon: Icons.account_balance_outlined,
      showApprovedBadge: restaurant.isApproved,

      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit bank & UPI details',
          fields: [
            EditFieldSpec(
              key: 'accountHolderName',
              label: 'Account holder',
              initialValue: restaurant.accountHolderName,
            ),
            EditFieldSpec(
              key: 'accountNumber',
              label: 'Account number',
              initialValue: restaurant.accountNumber,
              keyboardType: TextInputType.number,
            ),
            EditFieldSpec(
              key: 'ifscCode',
              label: 'IFSC code',
              initialValue: restaurant.ifscCode,
            ),
            EditFieldSpec(
              key: 'upiId',
              label: 'UPI ID',
              initialValue: restaurant.upiId,
            ),
          ],
        );

        if (result == null) {
          return;
        }

        await _saveProfile(context, ref, result);
      },

      children: [
        _buildDetailRow(
          context,
          'Account holder',
          restaurant.accountHolderName.isEmpty
              ? 'Not set'
              : restaurant.accountHolderName,
          icon: Icons.person_outline,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'Account number',
          _maskAccount(restaurant.accountNumber),
          icon: Icons.account_balance_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'IFSC code',
          restaurant.ifscCode.isEmpty ? 'Not set' : restaurant.ifscCode,
          icon: Icons.pin_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'UPI ID',
          restaurant.upiId.isEmpty ? 'Not set' : restaurant.upiId,
          icon: Icons.qr_code_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  String _maskAccount(String accountNumber) {
    if (accountNumber.isEmpty) {
      return 'Not set';
    }

    if (accountNumber.length <= 4) {
      return accountNumber;
    }

    return '•••• •••• ${accountNumber.substring(accountNumber.length - 4)}';
  }

  // ============================================================
  // MEDIA
  // ============================================================

  Widget _buildMediaCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    final mediaState = ref.watch(restaurantMediaControllerProvider);

    return _buildInfoCard(
      context: context,
      title: 'Restaurant media',
      icon: Icons.photo_library_outlined,
      showApprovedBadge: false,
      hideEdit: true,

      children: [
        mediaState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),

          error: (err, _) => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Unable to load media at the moment.',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: () => ref.read(restaurantMediaControllerProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),

          data: (media) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cover Image',
                  style: TextStyle(
                    color: _textColor(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 9),

                GestureDetector(
                  onTap: () async {
                    final file = await pickImageWithSourceSheet(context);

                    if (file == null) {
                      return;
                    }

                    try {
                      await ref
                          .read(restaurantMediaControllerProvider.notifier)
                          .uploadCoverImage(file);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cover image updated.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showError(context, e);
                      }
                    }
                  },

                  child: Container(
                    width: double.infinity,
                    height: 150,

                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: 0.35),
                      ),
                    ),

                    clipBehavior: Clip.hardEdge,

                    child: media.coverImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _resolveMediaUrl(media.coverImage),
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: _secondaryTextColor(context),
                                size: 32,
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 34,
                                color: _secondaryTextColor(context),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Cover Image',
                                style: TextStyle(
                                  color: _secondaryTextColor(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gallery Images',
                      style: TextStyle(
                        color: _textColor(context),
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${media.galleryImages.length}/${media.maxGalleryImages}',
                      style: TextStyle(
                        color: _secondaryTextColor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 9),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final url in media.galleryImages)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 82,
                            height: 82,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.3),
                              ),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: CachedNetworkImage(
                              imageUrl: _resolveMediaUrl(url),
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: _secondaryTextColor(context),
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            top: -6,
                            right: -6,
                            child: GestureDetector(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    title: const Text(
                                      'Delete Image?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    content: const Text(
                                      'Are you sure you want to delete this image?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true) {
                                  return;
                                }

                                try {
                                  await ref
                                      .read(
                                        restaurantMediaControllerProvider
                                            .notifier,
                                      )
                                      .deleteGalleryImage(url);
                                } catch (e) {
                                  if (context.mounted) {
                                    _showError(context, e);
                                  }
                                }
                              },

                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cancel_rounded,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    if (media.galleryImages.length < media.maxGalleryImages)
                      GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();

                          final List<XFile> images = await picker
                              .pickMultiImage(
                                limit:
                                    media.maxGalleryImages -
                                    media.galleryImages.length,
                              );

                          if (images.isEmpty) {
                            return;
                          }

                          try {
                            await ref
                                .read(
                                  restaurantMediaControllerProvider.notifier,
                                )
                                .uploadGalleryImages(images);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gallery images uploaded.'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showError(context, e);
                            }
                          }
                        },

                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: _secondaryTextColor(context),
                                size: 25,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  color: _secondaryTextColor(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // COMMON INFO CARD
  // ============================================================

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    IconData? icon,
    required bool showApprovedBadge,
    required List<Widget> children,
    bool hideEdit = false,
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: _cardColor(context),
        borderRadius: BorderRadius.circular(17),

        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.25),
        ),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 19),
                ),

                const SizedBox(width: 10),
              ],

              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textColor(context),
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),

                    if (showApprovedBadge) ...[
                      const SizedBox(width: 6),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Approved',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (!hideEdit) ...[
                const SizedBox(width: 7),

                GestureDetector(
                  onTap: onEdit,

                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_rounded,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 15),

          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? iconColor,
    bool isVertical = false,
    bool showDivider = true,
    Widget? trailing,
  }) {
    if (isVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _secondaryTextColor(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            value,
            style: TextStyle(
              color: _textColor(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
              height: 1.35,
            ),
          ),

          if (showDivider) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 17,
                color: iconColor ?? _secondaryTextColor(context),
              ),

              const SizedBox(width: 11),
            ],

            Flexible(
              flex: 4,
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _secondaryTextColor(context),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              flex: 6,
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: _textColor(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  height: 1.25,
                ),
              ),
            ),

            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing,
            ],
          ],
        ),

        if (showDivider) ...[
          const SizedBox(height: 12),

          Divider(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.18),
            height: 1,
          ),
        ],
      ],
    );
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> patch,
  ) async {
    try {
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile(patch);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved successfully.')));
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e);
      }
    }
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(BuildContext context, Object error) {
    final message = error is ApiException
        ? error.message
        : 'Something went wrong. Please try again.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ============================================================
  // COMPLIANCE SHEET
  // ============================================================

  Future<void> _openComplianceSheet(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ComplianceEditSheet(restaurant: restaurant),
    );
  }

  String _resolveMediaUrl(String path) {
    if (path.isEmpty) {
      return '';
    }

    if (path.startsWith('http')) {
      return path;
    }

    return 'https://cravioo.in$path';
  }
}

// ============================================================================
// COMPLIANCE EDIT SHEET
// ============================================================================

class _ComplianceEditSheet extends ConsumerStatefulWidget {
  const _ComplianceEditSheet({required this.restaurant});

  final RestaurantModel restaurant;

  @override
  ConsumerState<_ComplianceEditSheet> createState() =>
      _ComplianceEditSheetState();
}

class _ComplianceEditSheetState extends ConsumerState<_ComplianceEditSheet> {
  late final _panNumber = TextEditingController(
    text: widget.restaurant.panNumber,
  );

  late final _nameOnPan = TextEditingController(
    text: widget.restaurant.nameOnPan,
  );

  late final _gstNumber = TextEditingController(
    text: widget.restaurant.gstNumber,
  );

  late final _fssaiNumber = TextEditingController(
    text: widget.restaurant.fssaiNumber,
  );

  late bool _gstRegistered = widget.restaurant.gstRegistered;

  XFile? _panImage;
  XFile? _gstImage;
  XFile? _fssaiImage;

  bool _isSaving = false;

  @override
  void dispose() {
    _panNumber.dispose();
    _nameOnPan.dispose();
    _gstNumber.dispose();
    _fssaiNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(restaurantRepositoryProvider);

      final patch = <String, dynamic>{
        'panNumber': _panNumber.text.trim(),
        'nameOnPan': _nameOnPan.text.trim(),
        'gstRegistered': _gstRegistered,
        'gstNumber': _gstNumber.text.trim(),
        'fssaiNumber': _fssaiNumber.text.trim(),
      };

      if (_panImage != null) {
        patch['panImage'] = await repository.uploadAttachment(
          _panImage!,
          folder: 'pan',
        );
      }

      if (_gstImage != null) {
        patch['gstImage'] = await repository.uploadAttachment(
          _gstImage!,
          folder: 'gst',
        );
      }

      if (_fssaiImage != null) {
        patch['fssaiImage'] = await repository.uploadAttachment(
          _fssaiImage!,
          folder: 'fssai',
        );
      }

      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile(patch);

      if (mounted) {
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compliance details saved.')),
        );
      }
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Something went wrong. Please try again.';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetColor = isDark ? Theme.of(context).cardColor : Colors.white;

    final textColor = Theme.of(context).colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),

      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),

      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // DRAG HANDLE
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit compliance details',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 19,
                    ),
                  ),
                ),

                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 12),

            LabeledTextField(label: 'PAN number', controller: _panNumber),

            const SizedBox(height: 16),

            LabeledTextField(label: 'Name on PAN', controller: _nameOnPan),

            const SizedBox(height: 16),

            ImagePickerTile(
              label: 'PAN card image',
              image: _panImage,
              height: 100,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);

                if (file != null) {
                  setState(() {
                    _panImage = file;
                  });
                }
              },
              onRemove: () {
                setState(() {
                  _panImage = null;
                });
              },
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Registered for GST?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  Switch(
                    value: _gstRegistered,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) {
                      setState(() {
                        _gstRegistered = v;
                      });
                    },
                  ),
                ],
              ),
            ),

            if (_gstRegistered) ...[
              const SizedBox(height: 14),

              LabeledTextField(label: 'GST number', controller: _gstNumber),

              const SizedBox(height: 16),

              ImagePickerTile(
                label: 'GST certificate image',
                image: _gstImage,
                height: 100,
                onPick: () async {
                  final file = await pickImageWithSourceSheet(context);

                  if (file != null) {
                    setState(() {
                      _gstImage = file;
                    });
                  }
                },
                onRemove: () {
                  setState(() {
                    _gstImage = null;
                  });
                },
              ),
            ],

            const SizedBox(height: 20),

            LabeledTextField(
              label: 'FSSAI number',
              controller: _fssaiNumber,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            ImagePickerTile(
              label: 'FSSAI license image',
              image: _fssaiImage,
              height: 100,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);

                if (file != null) {
                  setState(() {
                    _fssaiImage = file;
                  });
                }
              },
              onRemove: () {
                setState(() {
                  _fssaiImage = null;
                });
              },
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 53,

              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),

                child: _isSaving
                    ? const SizedBox(
                        height: 21,
                        width: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
