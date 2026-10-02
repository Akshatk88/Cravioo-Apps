import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/services/new_order_action_channel.dart';
import 'package:food_user_application/core/services/order_resolution_tracker.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/features/orders/data/order_repository.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

/// Destination for FCM/local-notification taps (`new_order`,
/// `order_status_update`) and for anyone deep-linking to a single order —
/// the notification payload only carries an id, so this screen is
/// responsible for resolving it to a full [OrderModel].
class OrderDetailsScreen extends ConsumerStatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  OrderModel? _order;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Fast path: the order is very likely already sitting in the live-orders
    // cache (socket/FCM just refreshed it) — avoids a spinner for the common
    // case of tapping a notification while the app is warm.
    final cached = ref.read(liveOrdersControllerProvider).value;
    final match = cached?.where(
      (o) => o.id == widget.orderId || o.displayId == widget.orderId,
    );
    if (match != null && match.isNotEmpty) {
      setState(() {
        _order = match.first;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await ref
          .read(orderRepositoryProvider)
          .getById(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final order = _order;
    if (order == null) return;
    OrderResolutionTracker.markResolved(order.id);
    await NewOrderActionChannel.stopSound(order.id);
    await NewOrderActionChannel.dismiss(order.id);
    await cancelFcmTrayCopy(order.id);
    try {
      final updated = await ref
          .read(orderRepositoryProvider)
          .updateStatus(order.id, newStatus);
      await ref.read(liveOrdersControllerProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _order = updated);
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Failed to update order. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: Text(
          _order != null ? 'Order FOD-${_order!.displayId}' : 'Order Details',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/orders'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error is ApiException
                          ? (_error as ApiException).message
                          : 'Failed to load order.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _order == null
          ? const Center(child: Text('Order not found.'))
          : AppRefreshIndicator(
              onRefresh: _load,
              child: _buildContent(context, _order!),
            ),
    );
  }

  Widget _buildContent(BuildContext context, OrderModel order) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDarkMode ? AppColors.surfaceDark : Colors.white;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusHeaderCard(order: order, cardColor: cardColor),
        const SizedBox(height: 16),
        _SectionCard(
          cardColor: cardColor,
          title: 'Customer',
          icon: Icons.person_outline,
          child: CustomerInfo(order: order),
        ),
        if (!order.deliveryAddress.isEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            cardColor: cardColor,
            title: 'Delivery address',
            icon: Icons.location_on_outlined,
            child: AddressInfo(order: order),
          ),
        ],
        if (order.hasRider) ...[
          const SizedBox(height: 16),
          _SectionCard(
            cardColor: cardColor,
            title: 'Delivery partner',
            icon: Icons.delivery_dining_outlined,
            child: RiderInfo(order: order),
          ),
        ],
        const SizedBox(height: 16),
        _SectionCard(
          cardColor: cardColor,
          title: 'Items',
          icon: Icons.receipt_long_outlined,
          child: ItemsList(order: order),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          cardColor: cardColor,
          title: 'Bill details',
          icon: Icons.payments_outlined,
          child: BillDetails(order: order),
        ),
        if (order.note.isNotEmpty || order.deliveryInstructions.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionCard(
            cardColor: cardColor,
            title: 'Notes',
            icon: Icons.sticky_note_2_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.note.isNotEmpty)
                  Text(order.note, style: const TextStyle(fontSize: 14)),
                if (order.note.isNotEmpty &&
                    order.deliveryInstructions.isNotEmpty)
                  const SizedBox(height: 8),
                if (order.deliveryInstructions.isNotEmpty)
                  Text(
                    'Delivery instructions: ${order.deliveryInstructions}',
                    style: const TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        _buildActions(context, order),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildActions(BuildContext context, OrderModel order) {
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
                    await _updateStatus('cancelled_by_restaurant');
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.close, size: 18),
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
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _updateStatus('confirmed'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 18),
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
          child: ElevatedButton(
            onPressed: () => _updateStatus('preparing'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'Start Preparing',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );
      case 'preparing':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _updateStatus('ready_for_pickup'),
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
      default:
        if (order.isCancelled) {
          return Text(
            order.cancellationReason.isNotEmpty
                ? 'Cancelled: ${order.cancellationReason}'
                : 'Cancelled',
            style: const TextStyle(color: AppColors.error, fontSize: 14),
          );
        }
        return const SizedBox.shrink();
    }
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'created':
    case 'confirmed':
      return AppColors.primary;
    case 'preparing':
      return AppColors.rating;
    case 'ready_for_pickup':
    case 'reached_pickup':
    case 'picked_up':
    case 'reached_drop':
      return Colors.blue;
    case 'delivered':
      return AppColors.success;
    default:
      return AppColors.error;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'created':
      return 'Awaiting acceptance';
    case 'confirmed':
      return 'Accepted';
    case 'preparing':
      return 'Preparing';
    case 'ready_for_pickup':
      return 'Ready for pickup';
    case 'reached_pickup':
      return 'Rider at restaurant';
    case 'picked_up':
      return 'Out for delivery';
    case 'reached_drop':
      return 'Arriving';
    case 'delivered':
      return 'Delivered';
    case 'cancelled_by_user':
      return 'Cancelled by customer';
    case 'cancelled_by_restaurant':
      return 'Cancelled by restaurant';
    case 'cancelled_by_admin':
      return 'Cancelled';
    default:
      return status;
  }
}

class _StatusHeaderCard extends StatelessWidget {
  const _StatusHeaderCard({required this.order, required this.cardColor});

  final OrderModel order;
  final Color cardColor;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(order.orderStatus);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _statusLabel(order.orderStatus),
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                DateFormat(
                  'd MMM  •  h:mm a',
                ).format(order.createdAt.toLocal()),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'FOD-${order.displayId}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                '₹${order.total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (order.orderStatus == 'created' &&
              order.acceptanceDeadlineAt != null) ...[
            const SizedBox(height: 12),
            AcceptanceCountdown(deadline: order.acceptanceDeadlineAt!),
          ],
        ],
      ),
    );
  }
}

class AcceptanceCountdown extends StatefulWidget {
  const AcceptanceCountdown({super.key, required this.deadline});

  final DateTime deadline;

  @override
  State<AcceptanceCountdown> createState() => _AcceptanceCountdownState();
}

class _AcceptanceCountdownState extends State<AcceptanceCountdown> {
  late Duration _remaining = widget.deadline.difference(DateTime.now());

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _remaining = widget.deadline.difference(DateTime.now()));
      return !_remaining.isNegative;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining.isNegative) return const SizedBox.shrink();
    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return Row(
      children: [
        const Icon(Icons.timer_outlined, size: 16, color: AppColors.error),
        const SizedBox(width: 6),
        Text(
          'Accept within $minutes:$seconds',
          style: const TextStyle(
            color: AppColors.error,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.cardColor,
    required this.title,
    required this.icon,
    required this.child,
  });

  final Color cardColor;
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class CustomerInfo extends StatelessWidget {
  const CustomerInfo({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.customerName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (order.customerPhone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  order.customerPhone,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        if (order.customerPhone.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.copy_outlined, size: 18, color: Colors.grey),
            tooltip: 'Copy number',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: order.customerPhone));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Phone number copied')),
              );
            },
          ),
      ],
    );
  }
}

class AddressInfo extends StatelessWidget {
  const AddressInfo({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final address = order.deliveryAddress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (address.label.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              address.label,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        Text(address.fullAddress, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}

class RiderInfo extends StatelessWidget {
  const RiderInfo({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                order.riderName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (order.riderPhone.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  order.riderPhone,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        if (order.riderRating != null)
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: AppColors.rating),
              const SizedBox(width: 4),
              Text(
                order.riderRating!.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class ItemsList extends StatelessWidget {
  const ItemsList({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  item.isVeg ? Icons.circle_outlined : Icons.change_history,
                  size: 14,
                  color: item.isVeg ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item.quantity} x ${item.name}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (item.variantName.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.variantName,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (item.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Note: ${item.notes}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  '₹${(item.price * item.quantity).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        if (order.sendCutlery) ...[
          const Divider(height: 8),
          const Row(
            children: [
              Icon(Icons.restaurant_outlined, size: 16, color: Colors.grey),
              SizedBox(width: 8),
              Text(
                'Cutlery requested',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class BillDetails extends StatelessWidget {
  const BillDetails({super.key, required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final pricing = order.pricing;

    Widget row(String label, double amount, {bool isDiscount = false}) {
      if (amount == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            Text(
              '${isDiscount ? '- ' : ''}₹${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                color: isDiscount ? AppColors.success : null,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        row('Subtotal', pricing.subtotal),
        row('Packaging fee', pricing.packagingFee),
        row('Delivery fee', pricing.deliveryFee),
        row('Platform fee', pricing.platformFee),
        row('Tax', pricing.tax),
        if (pricing.discount > 0)
          row(
            pricing.couponCode.isNotEmpty
                ? 'Discount (${pricing.couponCode})'
                : 'Discount',
            pricing.discount,
            isDiscount: true,
          ),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Total',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              '₹${order.total.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Payment method',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            Text(
              order.paymentMethod.isEmpty
                  ? '—'
                  : order.paymentMethod.toUpperCase(),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        if (order.paymentStatus.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment status',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              Text(
                order.paymentStatus.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

