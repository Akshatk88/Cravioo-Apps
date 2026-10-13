import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/models/delivery_order.dart';

/// The customer's order as the rider needs it: who and where to deliver, what is
/// in the bag, the order value and whether cash has to be collected.
///
/// Used on the incoming-offer sheet (dark) and the active-trip card (light), so
/// the rider sees the same facts before accepting and while delivering.
class OrderSummarySection extends StatelessWidget {
  const OrderSummarySection({
    super.key,
    required this.order,
    this.dark = false,
    this.showCustomer = true,
    this.maxItems = 6,
  });

  final DeliveryOrder order;
  final bool dark;
  final bool showCustomer;
  final int maxItems;

  Color get _text => dark ? Colors.white : const Color(0xFF1E1E1E);
  Color get _muted => dark ? Colors.white54 : Colors.grey[600]!;
  Color get _divider => dark ? Colors.white12 : Colors.grey[200]!;

  Widget _label(String text) => Padding(
        padding: EdgeInsets.only(bottom: 6.h),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: _muted,
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final items = order.items.where((i) => i.name.trim().isNotEmpty).toList();
    final address = order.deliveryAddress.fullAddress.trim();
    final hasCustomer = showCustomer && (order.customerName.trim().isNotEmpty || address.isNotEmpty);
    final cod = order.isCashOnDelivery && !order.isPaid;
    final itemsTotal = items.fold<double>(0, (sum, i) => sum + i.price * i.quantity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasCustomer) ...[
          _label('Deliver to'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.person_pin_circle_outlined, color: const Color(0xFF1EBE5D), size: 20.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName.trim().isNotEmpty ? order.customerName : 'Customer',
                      style: TextStyle(color: _text, fontSize: 15.sp, fontWeight: FontWeight.w800),
                    ),
                    if (address.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(address, style: TextStyle(color: _muted, fontSize: 12.5.sp, height: 1.3)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Divider(height: 1, color: _divider),
          SizedBox(height: 14.h),
        ],
        _label(items.isEmpty ? 'Items' : 'Items (${items.length})'),
        if (items.isEmpty)
          Text('Item details not available', style: TextStyle(color: _muted, fontSize: 13.sp))
        else ...[
          for (final item in items.take(maxItems))
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1EBE5D).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: TextStyle(
                        color: const Color(0xFF1EBE5D),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      [item.name, if ((item.variantName ?? '').trim().isNotEmpty) '(${item.variantName})'].join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _text, fontSize: 13.5.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (item.price > 0)
                    Text(
                      '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                      style: TextStyle(color: _muted, fontSize: 12.5.sp),
                    ),
                ],
              ),
            ),
          if (items.length > maxItems)
            Text('+ ${items.length - maxItems} more', style: TextStyle(color: _muted, fontSize: 12.sp)),
        ],
        if ((order.cookingNote ?? '').trim().isNotEmpty || (order.deliveryInstructions ?? '').trim().isNotEmpty) ...[
          SizedBox(height: 8.h),
          Text(
            [
              if ((order.cookingNote ?? '').trim().isNotEmpty) 'Note: ${order.cookingNote!.trim()}',
              if ((order.deliveryInstructions ?? '').trim().isNotEmpty) 'Delivery: ${order.deliveryInstructions!.trim()}',
            ].join('\n'),
            style: TextStyle(color: _muted, fontSize: 12.sp, fontStyle: FontStyle.italic),
          ),
        ],
        SizedBox(height: 14.h),
        Divider(height: 1, color: _divider),
        SizedBox(height: 14.h),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Order value'),
                  Text(
                    order.total > 0
                        ? '₹${order.total.toStringAsFixed(2)}'
                        : (itemsTotal > 0 ? '₹${itemsTotal.toStringAsFixed(2)}' : '—'),
                    style: TextStyle(color: _text, fontSize: 17.sp, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: (cod ? const Color(0xFFFF9F43) : const Color(0xFF1EBE5D)).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                cod
                    ? 'Collect cash${order.total > 0 ? ' ₹${order.total.toStringAsFixed(0)}' : ''}'
                    : 'Prepaid • nothing to collect',
                style: TextStyle(
                  color: cod ? const Color(0xFFE67E00) : const Color(0xFF0E8A40),
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
