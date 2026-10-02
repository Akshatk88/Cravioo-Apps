import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';

class LiveOrderCard extends ConsumerStatefulWidget {
  const LiveOrderCard({super.key, required this.order});

  final OrderModel order;

  @override
  ConsumerState<LiveOrderCard> createState() => _LiveOrderCardState();
}

class _LiveOrderCardState extends ConsumerState<LiveOrderCard> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          if (_isExpanded) ...[
            const SizedBox(height: 16),
            _buildTimeline(context),
            const SizedBox(height: 16),
            // Same dispatchStatus bug as the timeline: this condition was never
            // true, so the live-tracking banner never appeared once the rider was
            // actually on the road with the food.
            if (widget.order.isPickedUp && !widget.order.isDelivered)
              _buildMapBanner(context),
            _buildInfoGrid(context),
            const SizedBox(height: 16),
            _buildActionButtons(context),
          ] else
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(widget.order.createdAt.toLocal());
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color pillColor;
    Color pillTextColor;
    IconData pillIcon;
    String pillText;

    switch (widget.order.orderStatus) {
      case 'created':
      case 'confirmed':
        pillColor = AppColors.successLight;
        pillTextColor = AppColors.primaryDeep;
        pillIcon = Icons.check_circle;
        pillText = 'Accepted';
        break;
      case 'preparing':
        pillColor = AppColors.primaryTint;
        pillTextColor = AppColors.primaryDark;
        pillIcon = Icons.soup_kitchen;
        pillText = 'Preparing Food';
        break;
      case 'ready_for_pickup':
        pillColor = AppColors.successLight;
        pillTextColor = AppColors.primaryDeep;
        pillIcon = Icons.shopping_bag;
        pillText = 'Ready for Pickup';
        break;
      case 'reached_pickup':
        pillColor = Colors.blue.shade50;
        pillTextColor = Colors.blue.shade700;
        pillIcon = Icons.two_wheeler;
        pillText = 'Rider Arrived';
        break;
      case 'picked_up':
      case 'reached_drop':
        pillColor = Colors.blue.shade50;
        pillTextColor = Colors.blue.shade700;
        pillIcon = Icons.two_wheeler;
        pillText = 'Picked Up';
        break;
      // Previously fell through to `default`, which prints the raw status — so a
      // finished order showed the pill text "delivered" in lowercase.
      case 'delivered':
      case 'completed':
        pillColor = AppColors.successLight;
        pillTextColor = AppColors.primaryDeep;
        pillIcon = Icons.check_circle;
        pillText = 'Delivered';
        break;
      default:
        pillColor = Colors.grey.shade100;
        pillTextColor = Colors.grey.shade700;
        pillIcon = Icons.info;
        pillText = widget.order.orderStatus;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#FOD-${widget.order.displayId}',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$timeStr  •  ${widget.order.items.length} items',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(pillIcon, color: pillTextColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      pillText,
                      style: TextStyle(
                        color: pillTextColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade700,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (widget.order.orderStatus == 'preparing' || widget.order.orderStatus == 'ready_for_pickup')
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 12, color: pillTextColor),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.order.orderStatus == 'preparing' ? 'Preparing' : 'Ready'} since $timeStr', // Mocking timestamp
                      style: TextStyle(color: pillTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (widget.order.isPickedUp)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time, size: 12, color: pillTextColor),
                    const SizedBox(width: 4),
                    Text(
                      widget.order.pickedUpAt != null
                          ? 'Picked up at ${DateFormat('h:mm a').format(widget.order.pickedUpAt!.toLocal())}'
                          : 'Picked up',
                      style: TextStyle(color: pillTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    // Single source of truth, derived from orderStatus in the model. The previous
    // chain here keyed the last two steps off dispatchStatus, which never holds
    // 'picked_up' or 'reached_drop' — see OrderModel.deliveryStepIndex.
    final int currentStep = widget.order.deliveryStepIndex;

    /// Real time this step was reached, or null while it is still pending.
    /// Every step used to print createdAt, so an order showed the same clock time
    /// against Accepted, Preparing and Ready no matter when each actually happened.
    String timeFor(int step, String status) {
      if (currentStep < step) return 'Pending';
      final at = step == 0
          ? (widget.order.statusTimes[status] ?? widget.order.createdAt)
          : widget.order.statusTimes[status];
      if (at == null) return '--';
      return DateFormat('h:mm a').format(at.toLocal());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimelineStep(
            title: 'Accepted',
            time: timeFor(0, 'confirmed'),
            icon: Icons.check,
            isActive: currentStep >= 0,
            isCurrent: currentStep == 0,
            color: Colors.green,
            isFirst: true,
          ),
          _TimelineLine(isActive: currentStep >= 1),
          _TimelineStep(
            title: 'Preparing',
            time: timeFor(1, 'preparing'),
            icon: Icons.soup_kitchen,
            isActive: currentStep >= 1,
            isCurrent: currentStep == 1,
            color: Colors.orange,
          ),
          _TimelineLine(isActive: currentStep >= 2),
          _TimelineStep(
            title: 'Ready',
            time: timeFor(2, 'ready_for_pickup'),
            icon: Icons.shopping_bag,
            isActive: currentStep >= 2,
            isCurrent: currentStep == 2,
            color: Colors.green,
          ),
          _TimelineLine(isActive: currentStep >= 3),
          _TimelineStep(
            title: 'Picked Up',
            time: timeFor(3, 'picked_up'),
            icon: Icons.two_wheeler,
            isActive: currentStep >= 3,
            isCurrent: currentStep == 3,
            color: Colors.blue,
          ),
          _TimelineLine(isActive: currentStep >= 4),
          _TimelineStep(
            title: 'Delivered',
            time: timeFor(4, 'delivered'),
            icon: Icons.check_circle_outline,
            isActive: currentStep >= 4,
            isCurrent: currentStep == 4,
            color: Colors.green,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMapBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        image: const DecorationImage(
          image: AssetImage('assets/image/map_placeholder.png'), // Need a placeholder or just a generic background
          fit: BoxFit.cover,
        ),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          // Simulated map path and icons
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.store, color: Colors.orange.shade700, size: 24),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Divider(color: Colors.blue, thickness: 2, height: 2), // Dashed in real map
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.two_wheeler, color: Colors.blue, size: 20),
                ),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Divider(color: Colors.blue, thickness: 2, height: 2), // Dashed in real map
                  ),
                ),
                Icon(Icons.location_on, color: Colors.red.shade700, size: 24),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 8, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('Live Tracking', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('Customer', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.order.customerName,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 12, color: AppColors.primaryDark),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.order.customerPhone.isNotEmpty ? '+91 ${widget.order.customerPhone}' : 'No phone',
                        style: const TextStyle(color: AppColors.primaryDark, fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: Colors.grey.shade200),
          const SizedBox(width: 12),
          // Delivery Partner
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.order.hasRider ? Icons.circle : Icons.circle_outlined, size: 10, color: widget.order.hasRider ? AppColors.primary : Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text('Delivery Partner', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                if (widget.order.hasRider) ...[
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade200,
                        ),
                        child: const Icon(Icons.person, size: 16, color: Colors.grey),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    widget.order.riderName,
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDarkMode ? Colors.white : Colors.black87),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.order.riderRating != null) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.star, size: 12, color: AppColors.rating),
                                  Text(widget.order.riderRating!.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone, size: 10, color: AppColors.primaryDark),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '+91 ${widget.order.riderPhone}',
                                    style: const TextStyle(color: AppColors.primaryDark, fontSize: 11, fontWeight: FontWeight.w500),
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
                ] else
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text('Looking for partner...', style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Colors.grey)),
                  ),
              ],
            ),
          ),
          Container(width: 1, height: 50, color: Colors.grey.shade200),
          const SizedBox(width: 12),
          // ETA
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text('ETA', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '15 mins', // Mocked ETA
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dist: 2.1 km', // Mocked distance
                  style: TextStyle(color: Colors.grey, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.order.hasRider ? () {} : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: BorderSide(color: AppColors.primaryAlpha(0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Icon(Icons.phone_outlined, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: BorderSide(color: AppColors.primaryAlpha(0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Icon(Icons.chat_bubble_outline, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.push('/order-details/${widget.order.id}'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                side: BorderSide(color: AppColors.primaryAlpha(0.35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Icon(Icons.visibility_outlined, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;
  final bool isActive;
  final bool isCurrent;
  final Color color;
  final bool isFirst;
  final bool isLast;

  const _TimelineStep({
    required this.title,
    required this.time,
    required this.icon,
    required this.isActive,
    required this.isCurrent,
    required this.color,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? color : Colors.grey.shade200,
            boxShadow: isCurrent
                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)]
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive ? Colors.white : Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isActive ? Colors.black87 : Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          time,
          style: TextStyle(
            fontSize: 10,
            color: isActive ? (isCurrent ? color : Colors.grey.shade600) : Colors.grey.shade400,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _TimelineLine extends StatelessWidget {
  final bool isActive;

  const _TimelineLine({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(top: 15), // Align with center of 32px circle
        height: 2,
        color: isActive ? Colors.green : Colors.grey.shade300,
      ),
    );
  }
}
