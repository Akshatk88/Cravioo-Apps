import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../data/models/delivery_order.dart';

class IncomingOrderBottomSheet extends StatefulWidget {
  final DeliveryOrder order;
  final ValueListenable<int> secondsLeft;
  final Future<void> Function() onAccept;
  final VoidCallback onReject;

  const IncomingOrderBottomSheet({
    super.key,
    required this.order,
    required this.secondsLeft,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<IncomingOrderBottomSheet> createState() =>
      _IncomingOrderBottomSheetState();
}

class _IncomingOrderBottomSheetState
    extends State<IncomingOrderBottomSheet> {
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 24.h),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main Card
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 16.h), // Space for the overlapping badge
            padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 20.h),
            decoration: BoxDecoration(
              color: const Color(0xFF141414), // Dark grey background
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Estimated earnings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '₹${order.riderEarning.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (order.riderEarning == 0) ...[
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.amber, width: 1),
                    ),
                    child: Text(
                      'Free Delivery Order (₹0 Earnings)',
                      style: TextStyle(
                        color: Colors.amber.shade200,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                SizedBox(height: 12.h),
                // Pickup / Drop distances
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pickup: ${order.pickupDistanceKm?.toStringAsFixed(2) ?? '--'} kms',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Text('|',
                          style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
                    ),
                    Text(
                      'Drop: ${order.tripDistanceKm?.toStringAsFixed(2) ?? '--'} kms',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                const Divider(color: Colors.white12, thickness: 1, height: 1),
                SizedBox(height: 24.h),
                // Restaurant info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF332014),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'Pick up',
                        style: TextStyle(
                          color: const Color(0xFFFF7A00),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.restaurant.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            order.restaurant.address,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Icon(Icons.schedule,
                                  color: Colors.white54, size: 14.sp),
                              SizedBox(width: 4.w),
                              Text(
                                '0 mins away',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 12.sp),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),
                // Accept button
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: ElevatedButton(
                    onPressed: _isAccepting
                        ? null
                        : () async {
                            setState(() => _isAccepting = true);
                            await widget.onAccept();
                            if (mounted) setState(() => _isAccepting = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1EBE5D),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF1EBE5D).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 0,
                    ),
                    child: _isAccepting
                        ? SizedBox(
                            width: 24.sp,
                            height: 24.sp,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Accept order',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 16.h),
                TextButton(
                  onPressed: widget.onReject,
                  child: Text(
                    'Decline',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Floating "New order" Badge
          Positioned(
            top: 0,
            left: 20.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'New order',
                style: TextStyle(
                  color: const Color(0xFF1EBE5D),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          // Timer badge
          Positioned(
            top: 0,
            right: 20.w,
            child: ValueListenableBuilder<int>(
              valueListenable: widget.secondsLeft,
              builder: (context, seconds, _) {
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF7A00),
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    '${seconds}s',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
