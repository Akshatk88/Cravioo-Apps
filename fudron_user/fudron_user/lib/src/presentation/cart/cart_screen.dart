import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../navigation/route_names.dart';
import '../branding/app_colors.dart';
import '../common_widgets/app_snackbar.dart';
import '../common_widgets/expandable_text.dart';
import '../common_widgets/smart_image.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/food_variant.dart';
import '../../data/models/order_pricing.dart';
import '../../data/models/restaurant_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../address/viewmodels/address_viewmodel.dart';
import '../../data/models/address_model.dart';
import '../../di/catalog_providers.dart';
import 'viewmodels/cart_viewmodel.dart';
import '../checkout/viewmodels/checkout_viewmodel.dart';
import '../wallet/viewmodels/wallet_viewmodel.dart';
import '../wallet/viewmodels/pay_later_viewmodel.dart';
import '../restaurant/widgets/food_detail_sheet.dart';
import 'widgets/cart_recommendations_section.dart';
import 'widgets/coupon_sheet.dart';
import 'widgets/empty_cart_view.dart';
import '../../../generated/l10n/app_localizations.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final GlobalKey _cartItemsCardKey = GlobalKey();

  // State for interactive UI elements
  String? _cookingRequest;
  bool _isBillExpanded = true;
  bool _isGovtTaxesExpanded = false;
  bool _isProcessing = false;
  // Values are the API's own payment method strings, so they can be sent as-is.
  // This used to be 'cod', which the backend never accepted -- the enum is
  // razorpay | razorpay_qr | card | wallet | cash -- so the COD button always failed.
  String _selectedPaymentMethod = 'razorpay'; // 'razorpay' | 'cash' | 'wallet'
  String? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authViewModelProvider.notifier).refreshProfile();
    });
  }

  AddressModel? _resolveSelectedAddress() {
    final addresses = ref.read(addressViewModelProvider);
    if (addresses.isEmpty) return null;
    if (_selectedAddressId != null) {
      for (final a in addresses) {
        if (a.id == _selectedAddressId) return a;
      }
    }
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.first;
  }

  String get _customerName =>
      ref.read(authViewModelProvider).value?.displayName ?? 'Customer';

  Future<String> _restaurantNameForCart(List<CartItemModel> items) async {
    if (items.isEmpty) return '';
    final id = items.first.food.restaurantId;
    final restaurant = await ref.read(restaurantByIdProvider(id).future);
    return restaurant?.name ?? '';
  }

  Future<void> _proceedToPayment() async {
    // Guard set immediately (before any await) so a fast double-tap can't
    // launch a second overlapping submission while the first is still
    // resolving address/pricing — that race left a stale `context` behind
    // for the error SnackBar and crashed with "deactivated widget's ancestor".
    if (_isProcessing) return;
    Haptics.light();
    setState(() => _isProcessing = true);
    try {
      final isLoggedIn = ref.read(authViewModelProvider).value != null;
      if (!isLoggedIn) {
        context.push(
          '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.cart)}',
        );
        return;
      }

      var address = _resolveSelectedAddress();
      if (address == null) {
        // Empty could mean "genuinely no saved address" or "the last load
        // attempt failed" (e.g. a timeout) — retry once so a transient
        // failure doesn't get mistaken for having no address at all.
        final addressNotifier = ref.read(addressViewModelProvider.notifier);
        if (addressNotifier.error != null) {
          await addressNotifier.load();
          address = _resolveSelectedAddress();
        }
      }
      if (address == null) {
        final addressNotifier = ref.read(addressViewModelProvider.notifier);
        final loadFailed = addressNotifier.error != null;
        final hasSavedAddress = ref.read(addressViewModelProvider).isNotEmpty;
        if (!mounted) return;
        AppSnackbar.error(
          context,
          loadFailed
              ? AppLocalizations.of(context)!.couldNotLoadAddress
              : hasSavedAddress
              ? AppLocalizations.of(context)!.pleaseSelectDeliveryAddress
              : AppLocalizations.of(context)!.addDeliveryAddressToProceed,
        );
        // With nothing saved, the picker would just be an empty list.
        if (!loadFailed && !hasSavedAddress) {
          unawaited(_openAddAddressScreen());
        } else {
          _showAddressSelectionBottomSheet(context);
        }
        return;
      }

      var checkoutState = ref.read(checkoutViewModelProvider);
      if (checkoutState.addressId != address.id) {
        await ref
            .read(checkoutViewModelProvider.notifier)
            .setAddress(address.id);
        checkoutState = ref.read(checkoutViewModelProvider);
      }

      if (checkoutState.pricing == null || checkoutState.isCalculating) {
        await ref.read(checkoutViewModelProvider.notifier).recalculate();
        checkoutState = ref.read(checkoutViewModelProvider);
      }

      final pricing = checkoutState.pricing;
      if (pricing == null) {
        if (!mounted) return;
        AppSnackbar.error(
          context,
          checkoutState.error ??
              AppLocalizations.of(context)!.couldNotCalculateBill,
        );
        return;
      }

      if (checkoutState.needsPriceConfirmation) {
        await ref.read(checkoutViewModelProvider.notifier).acceptPriceChanges();
      }

      // Validate COD permission if user has selected COD
      final isCodAllowed =
          ref.read(authViewModelProvider).value?.isCodAllowed ?? true;
      if (_selectedPaymentMethod == 'cash' && !isCodAllowed) {
        if (!mounted) return;
        AppSnackbar.warning(
          context,
          'Cash on Delivery is currently disabled for your account. Please select another payment method.',
        );
        setState(() => _selectedPaymentMethod = 'razorpay');
        return;
      }

      // Fudron Wallet balance validation
      if (_selectedPaymentMethod == 'wallet') {
        final walletState = ref.read(walletViewModelProvider);
        final walletBalance = walletState.wallet.balance;
        final totalToPay = pricing.total;
        if (walletBalance < totalToPay) {
          if (!mounted) return;
          AppSnackbar.warning(
            context,
            AppLocalizations.of(context)!.insufficientWalletBalance(
              '₹${walletBalance.toStringAsFixed(2)}',
              '₹${totalToPay.toStringAsFixed(2)}',
            ),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.addMoney,
              textColor: Colors.white,
              onPressed: () {
                context.push(RouteNames.wallet);
              },
            ),
          );
          return;
        }
      }

      final cartItems = ref.read(cartViewModelProvider).items;
      if (cartItems.isEmpty) return;

      final result = await ref
          .read(checkoutViewModelProvider.notifier)
          .payAndPlaceOrder(
            address: address.toOrderPayload(customerName: _customerName),
            restaurantName: await _restaurantNameForCart(cartItems),
            paymentMethod: _selectedPaymentMethod,
            // The cooking request was collected and shown, but never left the
            // screen — so the kitchen never saw it and it was absent from order
            // history. The payload, the API and OrderModel all already carried
            // `note`; only this hand-off was missing.
            note: _cookingRequest,
          );

      if (!mounted) return;

      if (result.isPlaced) {
        Haptics.success();
        final orderId = result.orderId;
        if (orderId != null && orderId.isNotEmpty) {
          context.go('/orders/success/$orderId');
        } else {
          context.push(RouteNames.orders);
        }
        return;
      }

      AppSnackbar.error(context, result.message);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showCookingRequestDialog(BuildContext context) {
    final textController = TextEditingController(text: _cookingRequest ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.cookingRequests,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.cookingRequestHint,
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _cookingRequest = textController.text.trim().isEmpty
                            ? null
                            : textController.text.trim();
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      AppLocalizations.of(context)!.saveRequest,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
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
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    if (cartState.items.isEmpty) {
      return const EmptyCartView();
    }

    // Group cart items by restaurant
    final groupOrder = <String>[];
    final groups = <String, List<CartItemModel>>{};
    for (final item in cartState.items) {
      final rid = item.food.restaurantId;
      groups
          .putIfAbsent(rid, () {
            groupOrder.add(rid);
            return [];
          })
          .add(item);
    }

    final cartRestaurant = groupOrder.isNotEmpty
        ? ref.watch(restaurantByIdProvider(groupOrder.first)).asData?.value
        : null;

    // Fees and the payable total come from POST /food/orders/calculate.
    final checkoutState = ref.watch(checkoutViewModelProvider);
    final pricing = checkoutState.pricing;
    final itemTotal = pricing?.subtotal ?? cartState.subtotal;
    final bool isFreeDelivery = (cartRestaurant?.isFreeDelivery == true) ||
        (pricing != null && pricing.deliveryFee == 0);
    final double defaultDeliveryFee = isFreeDelivery
        ? 0.0
        : (pricing?.deliveryFee ?? cartRestaurant?.deliveryFee ?? 25.0);
    final double totalDeliveryFee = defaultDeliveryFee;
    final platformFee = pricing?.platformFee ?? 18.18;
    final localPackagingFee = cartState.items.fold<double>(
      0.0,
      (sum, item) => sum + ((item.food.packagingFee) * item.quantity),
    );
    final packingCharges = pricing?.packagingFee ?? localPackagingFee;

    final otherPlatformSubtotal = cartState.items.fold<double>(
      0.0,
      (sum, item) {
        final otherPrice = (item.food.originalPrice != null && item.food.originalPrice! > item.food.price)
            ? item.food.originalPrice!
            : item.food.price;
        return sum + (otherPrice * item.quantity);
      },
    );
    final otherPlatformSavings = (otherPlatformSubtotal - itemTotal).clamp(0.0, double.infinity);

    final resolvedDistanceKm = pricing?.roadDistanceKm ??
        (cartRestaurant?.distanceKm != null && cartRestaurant!.distanceKm > 0
            ? cartRestaurant.distanceKm
            : 0.1);

    final savings = pricing?.discount ?? cartState.totalSavings;
    final double calculatedTaxes = (pricing?.tax ?? ((itemTotal * 0.10) + (platformFee * 0.10)));
    final toPay = pricing?.total ?? (itemTotal + totalDeliveryFee + platformFee + packingCharges + calculatedTaxes - savings);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1B1B1B) : AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Header Bar with Watermark
            _buildHeader(context, cartRestaurant, isDark),

            // Main Content Area with Curved Top
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.backgroundDark
                      : const Color(0xFFF4F5F7),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    children: [
                      // Card 1: Cart Items & Action Chips
                      _buildCartItemsCard(
                        cartState,
                        textColor,
                        secondaryColor,
                        isDark,
                      ),

                      const SizedBox(height: 12),

                      // Recommendation Section: Complete your meal with
                      CartRecommendationsSection(
                        restaurantId: groupOrder.isNotEmpty
                            ? groupOrder.first
                            : '1',
                        targetCartKey: _cartItemsCardKey,
                      ),

                      const SizedBox(height: 12),

                      // Card 3: Payment Offers & More Card
                      _buildPaymentOffersCard(
                        pricing,
                        checkoutState.couponCode,
                        textColor,
                        secondaryColor,
                        isDark,
                      ),

                      const SizedBox(height: 12),

                      // Card 4: To Pay / Bill Details Card
                      _buildBillDetailsCard(
                        itemTotal: itemTotal,
                        deliveryFee: totalDeliveryFee,
                        isFreeDelivery: isFreeDelivery,
                        resolvedDistanceKm: resolvedDistanceKm,
                        platformFee: platformFee,
                        packingCharges: packingCharges,
                        savings: savings,
                        couponApplied: pricing?.hasCouponApplied ?? false,
                        toPay: toPay,
                        otherPlatformSubtotal: otherPlatformSubtotal,
                        otherPlatformSavings: otherPlatformSavings,
                        textColor: textColor,
                        secondaryColor: secondaryColor,
                        isDark: isDark,
                        pricing: pricing,
                      ),

                      const SizedBox(height: 12),

                      // Card 5: Delivery Address Selection Card
                      _buildDeliveryAddressCard(
                        textColor,
                        secondaryColor,
                        isDark,
                      ),

                      const SizedBox(height: 16),

                      // Cancellation Policy Section
                      _buildCancellationPolicy(secondaryColor),

                      const SizedBox(height: 80), // Space for bottom footer
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildBottomDeliveryFooter(
        context,
        toPay,
        isDark,
        textColor,
      ),
    );
  }

  /// Header with Back Button and the restaurant every cart line belongs to.
  Widget _buildHeader(
    BuildContext context,
    RestaurantModel? restaurant,
    bool isDark,
  ) {
    final restaurantName = restaurant?.name ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 16),
      color: isDark ? const Color(0xFF1B1B1B) : AppColors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Back arrow
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 22,
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
            ],
          ),

          // Row 2: Optional restaurant logo + restaurant name
          if (restaurantName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Row(
                children: [
                  if (restaurant?.imageUrl.isNotEmpty == true) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SmartImage(
                        url: restaurant!.imageUrl,
                        category: ImageCategory.restaurant,
                        width: 28,
                        height: 28,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      restaurantName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Card 1: Items list with Veg indicator, image, stepper, price, delete, and Action Chips
  Widget _buildCartItemsCard(
    CartState cartState,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    return Container(
      key: _cartItemsCardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items List
          for (int i = 0; i < cartState.items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  height: 24,
                  thickness: 1,
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFF0F2F5),
                ),
              ),
            _buildCartItemRow(
              cartState.items[i],
              textColor,
              secondaryColor,
              isDark,
            ),
          ],

          const SizedBox(height: 20),

          // Action Chips Row (Add Items, Cooking requests, Cutlery)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Add Items Chip
                _buildActionChip(
                  icon: Icons.add_rounded,
                  label: 'Add Items',
                  isDark: isDark,
                  onTap: () {
                    Haptics.light();
                    if (cartState.items.isNotEmpty) {
                      final restaurantId =
                          cartState.items.first.food.restaurantId;
                      if (restaurantId.isNotEmpty) {
                        context.push(
                          '${RouteNames.restaurantDetail}/$restaurantId',
                        );
                        return;
                      }
                    }
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go(RouteNames.home);
                    }
                  },
                ),
                const SizedBox(width: 10),

                // Cooking Requests Chip
                _buildActionChip(
                  icon: Icons.edit_note_rounded,
                  // The request itself no longer rides in the label: a long one
                  // stretched this chip off the side of the row. It gets its own
                  // block below, where it can wrap and be expanded.
                  label: _cookingRequest == null
                      ? AppLocalizations.of(context)!.cookingRequests
                      : AppLocalizations.of(context)!.editRequest,
                  isDark: isDark,
                  isSelected: _cookingRequest != null,
                  onTap: () {
                    Haptics.light();
                    _showCookingRequestDialog(context);
                  },
                ),
              ],
            ),
          ),

          if (_cookingRequest != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.10)
                      : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.cookingRequest,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.primary
                            : AppColors.primaryDeep,
                      ),
                    ),
                    const SizedBox(height: 3),
                    ExpandableText(
                      _cookingRequest!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        color: isDark ? Colors.white : const Color(0xFF374151),
                      ),
                      linkColor: isDark
                          ? AppColors.primary
                          : AppColors.primaryDeep,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItemRow(
    CartItemModel item,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final food = item.food;
    final stepperBg = isDark ? const Color(0xFF2A2A2A) : AppColors.primaryTint;
    final stepperBorder = isDark
        ? const Color(0xFF3D3D3D)
        : AppColors.primary.withValues(alpha: 0.3);
    final stepperTextColor = isDark ? Colors.white : AppColors.primary;

    // Resolve selected add-on details (name & individual price)
    List<FoodAddon> resolvedAddons = item.selectedAddonDetails;
    if (resolvedAddons.isEmpty && item.selectedAddons.isNotEmpty) {
      final catalogAddons =
          ref.watch(restaurantAddonsProvider(food.restaurantId)).value ??
          const <FoodAddon>[];
      resolvedAddons = item.selectedAddons.map((idOrName) {
        final match = catalogAddons
            .where((a) => a.id == idOrName || a.name == idOrName)
            .firstOrNull;
        if (match != null) return match;
        return FoodAddon(
          id: idOrName,
          name: idOrName,
          price: item.selectedAddons.length == 1
              ? item.selectedAddonsPrice
              : 0.0,
        );
      }).toList();
    }

    final hasVariant =
        item.selectedVariant != null && item.selectedVariant!.isNotEmpty;
    final hasAddons = resolvedAddons.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Product image + Item Name (Tap opens FoodDetailSheet)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Haptics.light();
                FoodDetailSheet.show(context, food, existingCartItem: item);
              },
              child: Row(
                crossAxisAlignment: (hasVariant || hasAddons)
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFE5E7EB),
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: food.imageUrl.isNotEmpty
                            ? SmartImage(
                                url: food.imageUrl,
                                category: ImageCategory.food,
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                              )
                            : Container(
                                color: isDark
                                    ? AppColors.darkContainer
                                    : AppColors.lightContainer,
                                child: Icon(
                                  Icons.fastfood_rounded,
                                  size: 22,
                                  color: secondaryColor.withValues(alpha: 0.5),
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          food.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                            letterSpacing: -0.2,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasVariant) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Variant: ${item.selectedVariant}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                        ],
                        if (hasAddons) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Add-ons:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: secondaryColor,
                            ),
                          ),
                          for (final addon in resolvedAddons)
                            Padding(
                              padding: const EdgeInsets.only(top: 1.5),
                              child: Text(
                                '• ${addon.name} (+₹${addon.price % 1 == 0 ? addon.price.toStringAsFixed(0) : addon.price.toStringAsFixed(2)})',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: secondaryColor.withValues(alpha: 0.85),
                                  height: 1.2,
                                ),
                              ),
                            ),
                        ],
                        if (food.packagingFee > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Packing Charge: ₹${(food.packagingFee * item.quantity).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.amber[300] : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Orange stepper pill
          Container(
            height: 36,
            decoration: BoxDecoration(
              color: stepperBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: stepperBorder, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                  onTap: () {
                    Haptics.light();
                    ref
                        .read(cartViewModelProvider.notifier)
                        .updateQuantity(item.id, item.quantity - 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '−',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: stepperTextColor,
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: stepperTextColor,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(18),
                  ),
                  onTap: () {
                    Haptics.light();
                    ref
                        .read(cartViewModelProvider.notifier)
                        .updateQuantity(item.id, item.quantity + 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: stepperTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Item total price
          Text(
            '₹${item.totalPrice.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final chipBg = isSelected
        ? (isDark
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.primaryTint)
        : (isDark ? const Color(0xFF222222) : Colors.white);
    final chipBorder = isSelected
        ? AppColors.primary.withValues(alpha: 0.6)
        : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB));
    final chipIconColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280));
    final chipLabelColor = isSelected
        ? (isDark ? AppColors.primary : AppColors.primaryDeep)
        : (isDark ? Colors.white : const Color(0xFF374151));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: chipBorder, width: 1.2),
          boxShadow: isSelected || isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: chipIconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: chipLabelColor,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 3: Payment Offers & More Card
  Widget _buildPaymentOffersCard(
    OrderPricing? pricing,
    String? couponCode,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final applied = pricing?.hasCouponApplied ?? false;
    final label = applied
        ? '$couponCode applied · You saved ₹${pricing!.discount.toStringAsFixed(0)}'
        : 'Payment offers & more';

    return InkWell(
      onTap: () {
        Haptics.light();
        CouponSheet.show(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Tag Icon in rounded square
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF00875A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.local_offer_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),

            // Text Label
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: applied ? const Color(0xFF00875A) : textColor,
                ),
              ),
            ),

            // Chevron Right Icon
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.textSecondaryDark : Colors.black87,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildBillDetailsCard({
    required double itemTotal,
    required double deliveryFee,
    required bool isFreeDelivery,
    required double resolvedDistanceKm,
    required double platformFee,
    required double packingCharges,
    required double savings,
    required bool couponApplied,
    required double toPay,
    required double otherPlatformSubtotal,
    required double otherPlatformSavings,
    required Color textColor,
    required Color secondaryColor,
    required bool isDark,
    required OrderPricing? pricing,
  }) {
    final foodGst = pricing?.foodGst ??
        (pricing?.tax != null && pricing!.tax > 0
            ? (pricing.tax - (pricing.platformFeeGst)).clamp(0.0, pricing.tax)
            : (itemTotal * 0.10));
    final platformFeeGst =
        pricing?.platformFeeGst ?? (platformFee > 0 ? (platformFee * 0.10) : 1.82);
    final packagingFeeGst = pricing?.packagingFeeGst ?? 0.0;
    final totalTaxes =
        pricing?.tax ?? (foodGst + platformFeeGst + packagingFeeGst);

    final foodGstRate = pricing?.foodGstRate ?? 10.0;
    final platformFeeGstRate = pricing?.platformFeeGstRate ?? 10.0;
    final platformFeeGross =
        pricing?.platformFeeGross ?? (platformFee + platformFeeGst);
    final packagingFeeGstRate = pricing?.packagingFeeGstRate ?? 0.0;
    final packagingFeeGross =
        pricing?.packagingFeeGross ?? (packingCharges + packagingFeeGst);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 15,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Haptics.light();
              setState(() => _isBillExpanded = !_isBillExpanded);
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Receipt icon
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.description_outlined,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Total Bill, subtitle, savings
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Total Bill ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          Text(
                            '₹${toPay.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Incl. taxes and charges',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (otherPlatformSavings > 0) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Other platform item total ₹${otherPlatformSubtotal.toStringAsFixed(0)} • Save ₹${otherPlatformSavings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Chevron
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    _isBillExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : const Color(0xFF94A3B8),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),

          if (_isBillExpanded) ...[
            const SizedBox(height: 16),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 14),

            // Item Total Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Total',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (otherPlatformSubtotal > itemTotal) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: isDark
                                ? AppColors.borderDark
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          'Other: ₹${otherPlatformSubtotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? Colors.grey[400]
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '₹${itemTotal.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Delivery Fee Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Delivery Fee | ${resolvedDistanceKm.toStringAsFixed(1)} kms',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  isFreeDelivery
                      ? 'FREE'
                      : '₹${deliveryFee.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isFreeDelivery
                        ? const Color(0xFF16A34A)
                        : textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Platform Fee Row
            if (platformFee > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Platform Fee',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: secondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '₹${platformFee.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Packaging Fee Row
            if (packingCharges > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Packaging Fee',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: secondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '₹${packingCharges.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Government Taxes Row (Clickable Accordion)
            InkWell(
              onTap: () {
                Haptics.light();
                setState(() => _isGovtTaxesExpanded = !_isGovtTaxesExpanded);
              },
              borderRadius: BorderRadius.circular(6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Government Taxes',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: secondaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isGovtTaxesExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                  Text(
                    '₹${totalTaxes.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),

            // Inline Government Taxes Breakdown (when expanded)
            if (_isGovtTaxesExpanded) ...[
              Container(
                margin: const EdgeInsets.only(top: 8, left: 4, bottom: 4),
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // GST on food items
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'GST on food items (${foodGstRate.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey[400]
                                : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₹${foodGst.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // GST on Platform Fee
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GST on Platform Fee (${platformFeeGstRate.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'included in your ₹${platformFeeGross.toStringAsFixed(2)} fee',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.grey[500]
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '₹${platformFeeGst.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // GST on Packaging Fee (if applicable)
                    if (packagingFeeGst > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GST on Packaging Fee (${packagingFeeGstRate.toStringAsFixed(0)}%)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'included in your ₹${packagingFeeGross.toStringAsFixed(2)} fee',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.grey[500]
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '₹${packagingFeeGst.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: isDark
                          ? AppColors.borderDark
                          : const Color(0xFFE2E8F0),
                    ),
                    const SizedBox(height: 8),

                    // Total Government Taxes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Government Taxes',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                        Text(
                          '₹${totalTaxes.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Coupon / Discount
            if (savings > 0) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    couponApplied &&
                            (pricing?.couponCode?.isNotEmpty ?? false)
                        ? 'Coupon (${pricing!.couponCode})'
                        : 'Item Discount',
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '−₹${savings.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),
            Divider(
              height: 1,
              thickness: 1,
              color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
            ),
            const SizedBox(height: 14),

            // To Pay
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'To Pay',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                Text(
                  '₹${toPay.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
              ],
            ),

            // Price Comparison box below To Pay
            if (otherPlatformSubtotal > itemTotal) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF231818)
                      : const Color(0xFFFFF5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF3F2020)
                        : const Color(0xFFFFE4E6),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'OTHER PLATFORM PRICE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          '₹${otherPlatformSubtotal.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'YOUR SAVINGS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          '₹${otherPlatformSavings.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Cancellation Policy Text Section
  Widget _buildCancellationPolicy(Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancellation policy:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: secondaryColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Please double-check your order and address details. Orders are non-refundable once placed.',
            style: TextStyle(
              fontSize: 12,
              color: secondaryColor.withValues(alpha: 0.8),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens the add-address screen and selects whatever it saved.
  ///
  /// AddAddressScreen already persists through addressViewModelProvider before
  /// popping, so the newly appended entry is the one to select.
  Future<void> _openAddAddressScreen() async {
    final result = await context.push<dynamic>(RouteNames.addAddress);
    if (result == null || !mounted) return;

    final saved = ref.read(addressViewModelProvider);
    if (saved.isEmpty) return;
    setState(() => _selectedAddressId = saved.last.id);
    Haptics.medium();
    // The bill is priced against the chosen address, so it is now stale.
    unawaited(
      ref.read(checkoutViewModelProvider.notifier).setAddress(saved.last.id),
    );
  }

  void _showAddressSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
        final secondaryColor = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;

        // Consumer so the list rebuilds itself once addAddress/deleteAddress
        // updates the real backend-driven addressViewModelProvider state.
        return Consumer(
          builder: (context, ref, _) {
            final addresses = ref.watch(addressViewModelProvider);
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Choose a delivery address + Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Choose a delivery address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(sheetContext),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2E2E2E)
                                : const Color(0xFFF2F4F7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.dividerLight,
                  ),
                  const SizedBox(height: 12),

                  // Item 1: Add new Address
                  InkWell(
                    onTap: () {
                      Haptics.light();
                      Navigator.pop(sheetContext);
                      unawaited(_openAddAddressScreen());
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          // Square Primary Theme Box with + Icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primary
                                    : const Color(0xFFD0D5DD),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Add new Address',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.dividerLight,
                  ),
                  const SizedBox(height: 8),

                  // Dynamic Saved Addresses List — sourced from the real,
                  // backend-driven addressViewModelProvider.
                  if (addresses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No saved addresses yet. Add one to continue.',
                        style: TextStyle(fontSize: 13.5, color: secondaryColor),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: addresses.length,
                        separatorBuilder: (context, index) => Column(
                          children: [
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.dividerLight,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                        itemBuilder: (context, index) {
                          final addr = addresses[index];
                          final resolvedId =
                              _selectedAddressId ??
                              (addresses.firstWhere(
                                (a) => a.isDefault,
                                orElse: () => addresses.first,
                              )).id;
                          final isSelected = addr.id == resolvedId;

                          IconData icon = Icons.navigation_outlined;
                          if (addr.type == 'Home' ||
                              addr.title.toLowerCase().contains('home')) {
                            icon = Icons.home_outlined;
                          } else if (addr.type == 'Office' ||
                              addr.title.toLowerCase().contains('office')) {
                            icon = Icons.work_outline;
                          }

                          return _buildSavedAddressTile(
                            sheetContext: sheetContext,
                            addressId: addr.id,
                            title: addr.title,
                            address: addr.fullAddress,
                            icon: icon,
                            isSelected: isSelected,
                            isDark: isDark,
                            textColor: textColor,
                            secondaryColor: secondaryColor,
                            onDelete: () {
                              _showDeleteConfirmationDialog(
                                context: sheetContext,
                                title: addr.title,
                                onConfirm: () async {
                                  Haptics.medium();
                                  final deleted = await ref
                                      .read(addressViewModelProvider.notifier)
                                      .deleteAddress(addr.id);
                                  if (!deleted) return;
                                  if (_selectedAddressId == addr.id) {
                                    setState(() => _selectedAddressId = null);
                                  }
                                  if (!context.mounted) return;
                                  AppSnackbar.success(
                                    context,
                                    '"${addr.title}" deleted',
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog({
    required BuildContext context,
    required String title,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Address',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            'Are you sure you want to delete "$title"?',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                onConfirm();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavedAddressTile({
    required BuildContext sheetContext,
    required String addressId,
    required String title,
    required String address,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
    required VoidCallback onDelete,
  }) {
    return InkWell(
      onTap: () {
        Haptics.light();
        setState(() => _selectedAddressId = addressId);
        Navigator.pop(sheetContext);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                    : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF2F4F7)),
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1.2)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white : Colors.black87),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : textColor,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Delete Icon Button
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              tooltip: 'Delete address',
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentButtonLabel(double toPay) {
    final amount = toPay.toStringAsFixed(0);
    final isCodAllowed =
        ref.watch(authViewModelProvider).value?.isCodAllowed ?? true;
    final activeMethod = (!isCodAllowed && _selectedPaymentMethod == 'cash')
        ? 'razorpay'
        : _selectedPaymentMethod;
    switch (activeMethod) {
      case 'cash':
        return 'PLACE COD ORDER (₹$amount)';
      case 'wallet':
        return 'PAY WITH WALLET (₹$amount)';
      case 'razorpay':
      default:
        return 'PROCEED TO PAYMENT (₹$amount)';
    }
  }

  /// Card 5: Delivery Address Selection Card
  Widget _buildDeliveryAddressCard(
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final resolvedAddress = _resolveSelectedAddress();
    // Nothing saved yet: offering to "change" or "select" an address points at
    // an empty list. Send these customers straight to the add screen instead.
    final hasSavedAddress = ref.watch(addressViewModelProvider).isNotEmpty;
    final addressTitle =
        resolvedAddress?.title ??
        (hasSavedAddress ? 'Delivery Address' : 'No address added yet');
    final addressDisplay = resolvedAddress != null
        ? (resolvedAddress.city.isNotEmpty
              ? '${resolvedAddress.title} · ${resolvedAddress.city}, ${resolvedAddress.fullAddress}'
              : '${resolvedAddress.title} · ${resolvedAddress.fullAddress}')
        : (hasSavedAddress
              ? 'Select a delivery address'
              : 'Add a delivery address to see the delivery fee and place your order');

    void openAddressPicker() {
      Haptics.light();
      if (hasSavedAddress) {
        _showAddressSelectionBottomSheet(context);
      } else {
        unawaited(_openAddAddressScreen());
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [
                const BoxShadow(
                  color: AppColors.shadow2,
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Delivery Address',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: openAddressPicker,
                child: Text(
                  hasSavedAddress ? 'CHANGE' : '+ ADD',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: openAddressPicker,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.secondarySurfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          addressTitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          addressDisplay,
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: secondaryColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Payment Method Selection Bottom Sheet
  void _showPaymentMethodBottomSheet(
    BuildContext context,
    double toPay,
    double walletBalance,
    bool isDark,
  ) {
    // walletViewModelProvider only fetches once, on first creation. If that
    // fetch lost a race with auth (e.g. it ran while a session had just
    // expired), it fails once and never retries — leaving the balance stuck
    // at 0, which then falsely flags LOW BALANCE here for good. Refresh right
    // as the sheet that actually depends on this number opens.
    ref.read(walletViewModelProvider.notifier).loadWallet(isRefresh: true);
    unawaited(ref.read(payLaterViewModelProvider.notifier).refresh());
    unawaited(ref.read(authViewModelProvider.notifier).refreshProfile());

    final currentUser = ref.read(authViewModelProvider).value;
    if (currentUser?.isCodAllowed == false &&
        _selectedPaymentMethod == 'cash') {
      _selectedPaymentMethod = 'razorpay';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final modalTextColor = isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight;
            final modalSecondaryColor = isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                // FIX (overflow): this sheet's content (title + all payment
                // tiles + the optional Pay Later card) could be taller than
                // the visible screen space, especially once the keyboard-safe
                // area or a smaller phone height is involved — that produced
                // the "BOTTOM OVERFLOWED BY N PIXELS" strip in the screenshot.
                // Wrapping the Column in a SingleChildScrollView lets the
                // sheet scroll instead of overflowing, while still sizing
                // itself to content on screens tall enough to fit it all.
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.borderDark
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.selectPaymentMethod,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: modalTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.totalPayableAmount('₹${toPay.toStringAsFixed(2)}'),
                        style: TextStyle(
                          fontSize: 13,
                          color: modalSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Option 1: Online Payment (Razorpay / UPI / Cards)
                      _paymentOptionTile(
                        ctx: modalCtx,
                        methodKey: 'razorpay',
                        icon: Icons.credit_card_rounded,
                        title: AppLocalizations.of(context)!.onlinePayment,
                        subtitle: AppLocalizations.of(
                          context,
                        )!.paySecurelyRazorpay,
                        isDark: isDark,
                        modalTextColor: modalTextColor,
                        modalSecondaryColor: modalSecondaryColor,
                      ),

                      // Option 2: Cash on Delivery (COD) - hidden if admin turned off COD access for user
                      Consumer(
                        builder: (context, consumerRef, _) {
                          final isCodAllowed = consumerRef
                                  .watch(authViewModelProvider)
                                  .value
                                  ?.isCodAllowed ??
                              true;
                          if (!isCodAllowed) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: _paymentOptionTile(
                              ctx: modalCtx,
                              methodKey: 'cash',
                              icon: Icons.payments_outlined,
                              title:
                                  AppLocalizations.of(context)!.cashOnDelivery,
                              subtitle: AppLocalizations.of(
                                context,
                              )!.payInCashOnDelivery,
                              isDark: isDark,
                              modalTextColor: modalTextColor,
                              modalSecondaryColor: modalSecondaryColor,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      // Flagged only when the wallet is the chosen method: see
                      // the subtitle note below.
                      // Option 3: Fudron Wallet — watches the provider directly
                      // rather than the `walletBalance` captured when the sheet
                      // was opened, so the refresh triggered above actually
                      // reaches this tile once it resolves.
                      Consumer(
                        builder: (context, consumerRef, _) {
                          final liveBalance = consumerRef
                              .watch(walletViewModelProvider)
                              .wallet
                              .balance;
                          final isLow =
                              _selectedPaymentMethod == 'wallet' &&
                              liveBalance < toPay;
                          return _paymentOptionTile(
                            ctx: modalCtx,
                            methodKey: 'wallet',
                            icon: Icons.account_balance_wallet_outlined,
                            title: AppLocalizations.of(context)!.fudronWallet,
                            // The shortfall only matters once the user is
                            // actually paying by wallet. Flagging LOW BALANCE
                            // while they are paying by card or cash is noise
                            // about a balance that has no bearing on the order.
                            // The badge already says "insufficient" — the
                            // subtitle just states the balance once, not the
                            // same fact twice.
                            subtitle:
                                'Available balance: ₹${liveBalance.toStringAsFixed(2)}',
                            badgeText: isLow ? 'LOW BALANCE' : 'INSTANT',
                            badgeColor: isLow
                                ? AppColors.error
                                : AppColors.success,
                            isDark: isDark,
                            modalTextColor: modalTextColor,
                            modalSecondaryColor: modalSecondaryColor,
                          );
                        },
                      ),

                      // Option 4: Pay Later — only shown once eligibility is
                      // earned (3+ delivered orders, no bad COD history). An
                      // outstanding due blocks every payment method at checkout
                      // (order.service.js asserts this server-side too), so a
                      // due here routes to the repay screen instead of letting
                      // the user pick a method that will just get rejected.
                      Consumer(
                        builder: (context, consumerRef, _) {
                          final payLater = consumerRef
                              .watch(payLaterViewModelProvider)
                              .account;
                          if (!payLater.eligible) {
                            return const SizedBox.shrink();
                          }
                          final hasDue = payLater.amountDue > 0;

                          return Column(
                            children: [
                              const SizedBox(height: 10),
                              if (hasDue)
                                InkWell(
                                  onTap: () {
                                    Haptics.light();
                                    Navigator.pop(modalCtx);
                                    context.push(RouteNames.payLater);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.error.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.credit_score_outlined,
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.payLater,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: modalTextColor,
                                                ),
                                              ),
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.clearDueToUseAgain(
                                                  '₹${payLater.amountDue.toStringAsFixed(2)}',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: modalSecondaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                _paymentOptionTile(
                                  ctx: modalCtx,
                                  methodKey: 'pay_later',
                                  icon: Icons.credit_score_outlined,
                                  title: AppLocalizations.of(context)!.payLater,
                                  subtitle: AppLocalizations.of(context)!
                                      .availableCreditPayNextTime(
                                        '₹${payLater.availableCredit.toStringAsFixed(2)}',
                                      ),
                                  isDark: isDark,
                                  modalTextColor: modalTextColor,
                                  modalSecondaryColor: modalSecondaryColor,
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _paymentOptionTile({
    required BuildContext ctx,
    required String methodKey,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    Color? badgeColor,
    required bool isDark,
    required Color modalTextColor,
    required Color modalSecondaryColor,
  }) {
    final isSelected = _selectedPaymentMethod == methodKey;

    return InkWell(
      onTap: () {
        Haptics.light();
        setState(() => _selectedPaymentMethod = methodKey);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.cardDark : AppColors.secondarySurfaceLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: modalTextColor,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: badgeColor ?? AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: modalSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : modalSecondaryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom Delivery / Payment Sticky Bar Footer
  Widget _buildBottomDeliveryFooter(
    BuildContext context,
    double toPay,
    bool isDark,
    Color textColor,
  ) {
    final walletState = ref.watch(walletViewModelProvider);
    final walletBalance = walletState.wallet.balance;
    final isCodAllowed =
        ref.watch(authViewModelProvider).value?.isCodAllowed ?? true;
    final activeMethod = (!isCodAllowed && _selectedPaymentMethod == 'cash')
        ? 'razorpay'
        : _selectedPaymentMethod;

    IconData paymentIcon;
    String paymentDisplay;

    switch (activeMethod) {
      case 'cash':
        paymentIcon = Icons.payments_outlined;
        paymentDisplay = 'Cash on Delivery (COD)';
        break;
      case 'wallet':
        paymentIcon = Icons.account_balance_wallet_outlined;
        paymentDisplay = 'Fudron Wallet (₹${walletBalance.toStringAsFixed(0)})';
        break;
      case 'razorpay':
      default:
        paymentIcon = Icons.credit_card_rounded;
        paymentDisplay = 'Online Payment (UPI/Cards)';
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Method row — tapping opens payment method bottom sheet
            InkWell(
              onTap: () {
                Haptics.light();
                _showPaymentMethodBottomSheet(
                  context,
                  toPay,
                  walletBalance,
                  isDark,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        paymentIcon,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        paymentDisplay,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.change,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Proceed to Payment Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: _isProcessing ? null : _proceedToPayment,
                // FIX (overflow): previously this Row's Text could be wider
                // than the button (e.g. "PLACE COD ORDER (₹1234.00)"), which
                // overflowed past the button's bounds and rendered the
                // yellow/black "RIGHT OVERFLOWED BY N PIXELS" strip seen in
                // the screenshot. Wrapping the label in Flexible + FittedBox
                // lets it shrink to fit instead of overflowing, while short
                // labels still render at full size.
                child: _isProcessing
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Text(
                                  _getPaymentButtonLabel(toPay),
                                  maxLines: 1,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
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
