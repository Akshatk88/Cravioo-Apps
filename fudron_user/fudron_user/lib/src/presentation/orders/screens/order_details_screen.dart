import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/back_navigation.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/order_model.dart';
import '../../branding/app_colors.dart';
import '../../cart/utils/cart_restaurant_guard.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../common_widgets/app_snackbar.dart';
import '../../common_widgets/skeleton_loading.dart';
import '../../navigation/route_names.dart';
import '../utils/reorder.dart';
import '../viewmodels/orders_viewmodel.dart';
import '../widgets/order_details_header.dart';
import '../widgets/order_timeline_card.dart';
import '../widgets/price_details_card.dart';
import '../widgets/previous_conversations_card.dart';
import '../../common_widgets/expandable_text.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to cancel this order?'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Reason for cancellation (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('NO, KEEP ORDER'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final err = await ref
                    .read(ordersViewModelProvider.notifier)
                    .cancelOrder(orderId, reason: reasonController.text.trim());
                if (context.mounted) {
                  if (err != null) {
                    AppSnackbar.error(context, err);
                  } else {
                    AppSnackbar.success(
                      context,
                      'Order cancelled successfully.',
                    );
                  }
                }
              },
              child: const Text(
                'CANCEL ORDER',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleReorder(BuildContext context, WidgetRef ref, OrderModel order) async {
    final allowed = await ensureCartRestaurant(
      context,
      ref,
      order.restaurantId,
    );
    if (!allowed || !context.mounted) return;

    Haptics.medium();
    final items = await resolveReorderItems(ref, order);
    if (!context.mounted) return;
    final cartNotifier = ref.read(cartViewModelProvider.notifier);
    for (final item in items) {
      cartNotifier.addItem(
        item.food,
        quantity: item.quantity,
        selectedVariant: item.selectedVariant,
        selectedVariantPrice: item.selectedVariantPrice,
        selectedAddons: item.selectedAddons,
        selectedAddonsPrice: item.selectedAddonsPrice,
      );
    }
    context.go(RouteNames.cart);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    final scaffoldBg = isDark ? AppColors.backgroundDark : const Color(0xFFF4F5F7);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: orderAsync.when(
        loading: () => Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.surfaceLight,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimaryLight),
              onPressed: () => context.backOr(),
            ),
          ),
          body: const SkeletonOrderTracking(),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.surfaceLight,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimaryLight),
              onPressed: () => context.backOr(),
            ),
          ),
          body: Center(
            child: Text(
              'Could not load order details.',
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
            ),
          ),
        ),
        data: (order) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            appBar: OrderDetailsHeader(order: order),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Restaurant & Delivery Address Timeline Card
                  OrderTimelineCard(order: order),

                  const SizedBox(height: 16),

                  // Cooking request, when the customer left one.
                  if (order.note.trim().isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _CookingRequestCard(note: order.note.trim()),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bill Details Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PriceDetailsCard(order: order),
                  ),

                  const SizedBox(height: 16),

                  // Previous Conversations Threads Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PreviousConversationsCard(orderId: order.id),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Bottom Action Bar
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: order.isActive
                    ? Row(
                        children: [
                          if (order.canCancel)
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _showCancelDialog(context, ref),
                                child: const Text(
                                  'CANCEL',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          if (order.canCancel) const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Haptics.medium();
                                context.push('/orders/track/${order.id}');
                              },
                              child: const Text(
                                'TRACK LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => _handleReorder(context, ref, order),
                          child: Text(
                            'REORDER',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}


/// Shows the cooking request the customer sent with the order.
///
/// Clamped to two lines with a Read more toggle: these run long, and a wall of
/// text pushes the bill and the actions off the first screen.
class _CookingRequestCard extends StatelessWidget {
  final String note;

  const _CookingRequestCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Cooking request',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ExpandableText(
            note,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
