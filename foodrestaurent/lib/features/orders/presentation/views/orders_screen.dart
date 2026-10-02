import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/notifications/presentation/controllers/notifications_controller.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/features/orders/presentation/widgets/live_order_card.dart'; // NEW
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';
import 'package:food_user_application/core/widgets/app_drawer.dart';

class _TabConfig {
  final String label;
  final IconData icon;
  const _TabConfig(this.label, this.icon);
}

const _tabs = [
  _TabConfig('New Orders', Icons.receipt_long_outlined),
  _TabConfig('All', Icons.layers_outlined),
  _TabConfig('Preparing', Icons.soup_kitchen_outlined),
  _TabConfig('Ready', Icons.shopping_bag_outlined),
  _TabConfig('Out for delivery', Icons.delivery_dining_outlined),
  _TabConfig('Completed', Icons.check_circle_outline),
  _TabConfig('Cancelled', Icons.cancel_outlined),
];

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(liveOrdersControllerProvider);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: const AppDrawer(),
        appBar: _buildAppBar(context),
        body: Column(
          children: [
            _buildTabBar(context),
            Expanded(
              child: ordersAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      error is ApiException
                          ? error.message
                          : 'Failed to load orders.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (orders) => _buildTabViews(context, orders),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabViews(BuildContext context, List<OrderModel> orders) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;
    final isOffline = restaurant?.isAcceptingOrders == false;

    final newOrders = orders.where((o) => ['new', 'preparing', 'ready', 'out_for_delivery'].contains(o.restaurantBucket)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final all = [...orders]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final preparing = orders
        .where((o) => o.restaurantBucket == 'preparing')
        .toList();
    final ready = orders.where((o) => o.restaurantBucket == 'ready').toList();
    final outForDelivery = orders
        .where((o) => o.restaurantBucket == 'out_for_delivery')
        .toList();
    final completed = orders
        .where((o) => o.restaurantBucket == 'completed')
        .toList();
    final cancelled = orders
        .where((o) => o.restaurantBucket == 'cancelled')
        .toList();

    return TabBarView(
      children: [
        _buildLiveOrderList(
          context,
          newOrders,
          emptyImage: isOffline
              ? 'assets/image/closestore.gif'
              : 'assets/image/online.gif',
          emptyText: isOffline
              ? 'Make Online for New order'
              : 'You are Online waiting for Order',
        ),
        _buildOrderList(context, all, emptyText: 'No orders yet'),
        _buildOrderList(
          context,
          preparing,
          emptyText: 'No orders being prepared',
        ),
        _buildOrderList(
          context,
          ready,
          emptyText: 'No orders ready for pickup',
        ),
        _buildOrderList(
          context,
          outForDelivery,
          emptyText: 'No orders out for delivery',
        ),
        _buildOrderList(
          context,
          completed,
          emptyText: 'No completed orders yet',
        ),
        _buildOrderList(context, cancelled, emptyText: 'No cancelled orders'),
      ],
    );
  }

  Widget _buildLiveOrderList(
    BuildContext context,
    List<OrderModel> orders, {
    required String emptyText,
    String? emptyImage,
  }) {
    return AppRefreshIndicator(
      onRefresh: () =>
          ref.read(liveOrdersControllerProvider.notifier).refresh(),
      child: orders.isEmpty
          ? ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 100,
                    horizontal: 10,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (emptyImage != null) ...[
                          ClipOval(
                            child: Image.asset(
                              emptyImage,
                              width: 350,
                              height: 350,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        Text(
                          emptyText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length + 1, // +1 for header
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return const _LiveOrderHeader();
                }
                return LiveOrderCard(order: orders[index - 1]);
              },
            ),
    );
  }

  Widget _buildOrderList(
    BuildContext context,
    List<OrderModel> orders, {
    required String emptyText,
    String? headerCount,
    String? emptyImage,
  }) {
    return AppRefreshIndicator(
      onRefresh: () =>
          ref.read(liveOrdersControllerProvider.notifier).refresh(),
      child: orders.isEmpty
          ? ListView(
              children: [
                if (headerCount != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text(
                      headerCount,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 100,
                    horizontal: 10,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (emptyImage != null) ...[
                          ClipOval(
                            child: Image.asset(
                              emptyImage,
                              width: 350,
                              height: 350,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],
                        Text(
                          emptyText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length + 1, // +1 for banner
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index == orders.length) {
                  return const _DeliveryBanner();
                }
                return _OrderCard(order: orders[index]);
              },
            ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      titleSpacing: 16,
      toolbarHeight: 70,
      title: GestureDetector(
        onTap: () => context.push('/restaurant-status'),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFF5B3B68),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.hardEdge,
                child: restaurant?.profileImage.isNotEmpty == true
                    ? CachedNetworkImage(
                        imageUrl: restaurant!.profileImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, _, _) =>
                            const Icon(Icons.storefront, color: Colors.white70),
                      )
                    : const Icon(Icons.storefront, color: Colors.white70),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Hello, ${restaurant?.restaurantName ?? '—'} 👋',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            restaurant?.fullAddress.isNotEmpty == true
                                ? restaurant!.fullAddress
                                : 'Address not set',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
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
            ],
          ),
        ),
      ),
      actions: [
        const _AvailabilityToggle(),
        const SizedBox(width: 8),
        Builder(
          builder: (context) {
            final unreadCount =
                ref.watch(notificationsControllerProvider).value?.unreadCount ??
                0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_none,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  onPressed: () => context.push('/notifications'),
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).appBarTheme.backgroundColor,
      child: TabBar(
        isScrollable: true,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: isDarkMode ? AppColors.surfaceDark : Colors.white,
          border: Border.all(color: AppColors.primary),
          borderRadius: BorderRadius.circular(30),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        tabs: _tabs
            .map(
              (tab) => Tab(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(tab.icon, size: 18),
                    const SizedBox(width: 6),
                    Text(tab.label),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Online/offline pill shown in the orders app bar — mirrors the switch on
/// the restaurant status screen but lives here too since this is the screen
/// restaurant owners keep open, and going offline mid-rush needs to be one
/// tap away rather than buried in settings.
class _AvailabilityToggle extends ConsumerStatefulWidget {
  const _AvailabilityToggle();

  @override
  ConsumerState<_AvailabilityToggle> createState() =>
      _AvailabilityToggleState();
}

class _AvailabilityToggleState extends ConsumerState<_AvailabilityToggle> {
  bool _isSaving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _isSaving = true);
    try {
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateAvailability(value);
    } catch (e) {
      if (context.mounted) {
        final message = e is ApiException
            ? e.message
            : 'Failed to update status. Please try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;
    final isOnline = restaurant?.isAcceptingOrders ?? false;

    return Container(
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: isOnline
            ? AppColors.success.withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOnline ? AppColors.success : Colors.grey.shade400,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              color: isOnline ? AppColors.success : Colors.grey.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Transform.scale(
              scale: 0.7,
              child: Switch(
                value: isOnline,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.success,
                onChanged: _toggle,
              ),
            ),
        ],
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isCancelled =
        order.orderStatus == 'cancelled' ||
        order.orderStatus == 'cancelled_by_restaurant';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: isDarkMode ? AppColors.surfaceDark : Colors.white,
          child: InkWell(
            onTap: () => context.push('/order-details/${order.id}'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row 1: ID, Badge, Date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isCancelled
                              ? Colors.grey.shade100
                              : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: isCancelled
                              ? Colors.grey
                              : Colors.orange.shade700,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                'FOD-${order.displayId}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (order.restaurantBucket == 'new') ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('d MMM  •  h:mm a').format(order.createdAt.toLocal()),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row 2: Customer info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCancelled
                              ? Colors.grey.shade100
                              : Colors.orange.shade50,
                        ),
                        child: Icon(
                          Icons.person,
                          color: isCancelled
                              ? Colors.grey
                              : Colors.orange.shade700,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.customerName,
                              style: TextStyle(
                                fontSize: 15,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (order.customerPhone.isNotEmpty)
                              Text(
                                order.customerPhone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDarkMode
                                      ? Colors.white54
                                      : Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.phone_outlined,
                          size: 20,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const _DashedDivider(),
                  const SizedBox(height: 16),

                  // Row 3: Order Amount & Illustration
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isCancelled
                          ? const Color(0xFFFFF0F0)
                          : const Color(0xFFF0F8F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Order Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${order.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        Image.asset(
                          isCancelled
                              ? 'assets/image/cancled.webp'
                              : 'assets/image/neworder.webp',
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Actions
                  _buildActions(context, ref, order),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref, OrderModel order) {
    Future<void> updateStatus(String newStatus) async {
      try {
        await ref
            .read(liveOrdersControllerProvider.notifier)
            .updateStatus(order.id, newStatus);
      } catch (e) {
        if (context.mounted) {
          final message = e is ApiException
              ? e.message
              : 'Failed to update order. Please try again.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.error),
          );
        }
      }
    }

    switch (order.orderStatus) {
      case 'created':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reject this order?'),
                      content: const Text(
                        'The customer will be notified and refunded per policy.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text(
                            'Reject',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await updateStatus('cancelled_by_restaurant');
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () => updateStatus('confirmed'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.orange.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Accept',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case 'confirmed':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => updateStatus('preparing'),
            icon: const Icon(Icons.soup_kitchen, size: 20),
            label: const Text(
              'Start Preparing',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        );
      case 'preparing':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => updateStatus('ready_for_pickup'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Mark Ready for Pickup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      case 'ready_for_pickup':
        return Row(
          children: [
            Icon(
              order.dispatchStatus == 'unassigned'
                  ? Icons.hourglass_top
                  : Icons.delivery_dining,
              size: 20,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.dispatchStatus == 'unassigned'
                    ? 'Waiting for a delivery partner'
                    : 'Delivery partner assigned',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            if (order.dispatchStatus == 'unassigned')
              TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(liveOrdersControllerProvider.notifier)
                        .resendNotification(order.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notified delivery partners again.'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final message = e is ApiException
                          ? e.message
                          : 'Failed to resend notification.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text(
                  'Resend',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
          ],
        );
      case 'reached_pickup':
      case 'picked_up':
      case 'reached_drop':
        // Was interpolating dispatchStatus, which tracks the assignment and not the
        // food — so a rider already carrying the order read "On the way — accepted".
        return Text(
          switch (order.orderStatus) {
            'reached_pickup' => 'Rider at restaurant',
            'reached_drop' => 'Rider reached the customer',
            _ => 'On the way to the customer',
          },
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        );
      case 'delivered':
        return const Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: Colors.green),
            SizedBox(width: 8),
            Text(
              'Delivered',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        );
      case 'cancelled':
      case 'cancelled_by_restaurant':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0F0),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Cancelled',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );
      default:
        return Text(
          order.cancellationReason.isNotEmpty
              ? 'Cancelled: ${order.cancellationReason}'
              : 'Cancelled',
          style: const TextStyle(color: AppColors.error, fontSize: 14),
        );
    }
  }
}

class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.deadline, required this.onExpired});

  final DateTime deadline;
  final VoidCallback onExpired;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _timer;
  late Duration _remaining = widget.deadline.difference(DateTime.now());
  bool _hasExpired = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = widget.deadline.difference(DateTime.now());
      if (remaining.isNegative) {
        _timer?.cancel();
        if (!_hasExpired) {
          _hasExpired = true;
          widget.onExpired();
        }
      }
      if (mounted) setState(() => _remaining = remaining);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) {
      return const Text(
        'Expired',
        style: TextStyle(
          color: AppColors.error,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      );
    }
    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return Text(
      '$minutes:$seconds',
      style: TextStyle(
        color: _remaining.inSeconds < 60 ? AppColors.error : AppColors.primary,
        fontWeight: FontWeight.w900,
        fontSize: 18,
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 6.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.grey[800]
                      : const Color(0xFFE0E0E0),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _DeliveryBanner extends StatelessWidget {
  const _DeliveryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 32),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delivery_dining,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivering happiness',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fast  •  Reliable  •  Always',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white54
                        : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Learn More',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveOrderHeader extends StatelessWidget {
  const _LiveOrderHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.sensors, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Live Order Status',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Track all accepted orders in real-time',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.refresh, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Last updated', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                    Row(
                      children: [
                        const Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
                        const SizedBox(width: 4),
                        const _BlinkingDot(),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlinkingDot extends StatefulWidget {
  const _BlinkingDot();

  @override
  _BlinkingDotState createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Icon(Icons.circle, size: 6, color: Colors.green.shade600),
    );
  }
}
