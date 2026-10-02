import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/dining_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/dining_bookings_state.dart';
import '../viewmodels/dining_bookings_viewmodel.dart';
import '../viewmodels/dining_viewmodel.dart';
import '../widgets/table_booking_sheet.dart';

class DiningBookingsScreen extends ConsumerStatefulWidget {
  const DiningBookingsScreen({super.key});

  @override
  ConsumerState<DiningBookingsScreen> createState() => _DiningBookingsScreenState();
}

class _DiningBookingsScreenState extends ConsumerState<DiningBookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(diningBookingsViewModelProvider.notifier).loadBookings();
    });
  }

  static String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('EEE, d MMM yyyy').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(diningBookingsViewModelProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
            size: 20.sp,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.dining);
            }
          },
        ),
        title: Text(
          'My Dining Bookings',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.textPrimaryLight,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: AppColors.primary,
              size: 22.sp,
            ),
            tooltip: 'Refresh',
            onPressed: () {
              Haptics.light();
              ref.read(diningBookingsViewModelProvider.notifier).loadBookings();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filter Tabs
            _buildFilterTabs(isDark, state),

            // Content
            Expanded(
              child: AppRefreshIndicator(
                onRefresh: () async {
                  await ref.read(diningBookingsViewModelProvider.notifier).loadBookings();
                },
                child: state.isLoading && state.bookings.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : state.filteredBookings.isEmpty
                        ? _buildEmptyState(isDark, state.filter)
                        : ListView.separated(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: state.filteredBookings.length,
                            separatorBuilder: (_, _) => SizedBox(height: 14.h),
                            itemBuilder: (ctx, index) {
                              final booking = state.filteredBookings[index];
                              return _buildBookingCard(isDark, booking);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(bool isDark, DiningBookingsState state) {
    final filters = [
      {'label': 'All', 'filter': DiningBookingsFilter.all, 'count': state.allCount},
      {'label': 'Upcoming', 'filter': DiningBookingsFilter.upcoming, 'count': state.upcomingCount},
      {'label': 'Completed', 'filter': DiningBookingsFilter.completed, 'count': state.completedCount},
      {'label': 'Cancelled', 'filter': DiningBookingsFilter.cancelled, 'count': state.cancelledCount},
    ];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 16.w),
      color: isDark ? AppColors.surfaceDark : Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((item) {
            final f = item['filter'] as DiningBookingsFilter;
            final isSelected = state.filter == f;
            final count = item['count'] as int;

            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () {
                  Haptics.light();
                  ref.read(diningBookingsViewModelProvider.notifier).setFilter(f);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isDark ? const Color(0xFF232323) : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                        ),
                      ),
                      if (count > 0) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : AppColors.textSecondaryLight),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, DiningBookingsFilter filter) {
    String title = 'No Reservations Found';
    String desc = 'You don\'t have any table bookings yet.';
    if (filter == DiningBookingsFilter.upcoming) {
      title = 'No Upcoming Bookings';
      desc = 'You have no pending or confirmed table reservations right now.';
    } else if (filter == DiningBookingsFilter.completed) {
      title = 'No Past Bookings';
      desc = 'Your completed dining experiences will appear here.';
    } else if (filter == DiningBookingsFilter.cancelled) {
      title = 'No Cancelled Bookings';
      desc = 'Any cancelled or declined reservations will appear here.';
    }

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(28.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24.r),
              decoration: BoxDecoration(
                color: AppColors.primaryAlpha(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.restaurant_rounded,
                size: 56.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RouteNames.dining);
                }
              },
              icon: const Icon(Icons.table_restaurant_rounded, color: Colors.white),
              label: const Text(
                'Explore Dining & Book',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 22.w, vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(bool isDark, DiningUserBookingModel booking) {
    Color statusBg;
    Color statusColor;
    IconData statusIcon;

    switch (booking.status) {
      case 'confirmed':
        statusBg = const Color(0xFFDCFCE7);
        statusColor = const Color(0xFF15803D);
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'pending':
        statusBg = const Color(0xFFFEF3C7);
        statusColor = const Color(0xFFB45309);
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'seated':
        statusBg = const Color(0xFFE0E7FF);
        statusColor = const Color(0xFF4338CA);
        statusIcon = Icons.airline_seat_recline_normal_rounded;
        break;
      case 'completed':
        statusBg = const Color(0xFFCCFBF1);
        statusColor = const Color(0xFF0F766E);
        statusIcon = Icons.task_alt_rounded;
        break;
      case 'cancelled':
      case 'rejected':
      case 'no_show':
        statusBg = const Color(0xFFFEE2E2);
        statusColor = const Color(0xFFB91C1C);
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusBg = Colors.grey.shade200;
        statusColor = Colors.grey.shade700;
        statusIcon = Icons.info_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
        ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: () {
            Haptics.light();
            _showBookingDetailsSheet(booking);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Image, Restaurant Name, Status Badge
              Padding(
                padding: EdgeInsets.all(14.r),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        width: 52.w,
                        height: 52.h,
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        child: booking.restaurantImage.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: booking.restaurantImage,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Icon(
                                  Icons.restaurant_rounded,
                                  color: AppColors.primary,
                                  size: 26.sp,
                                ),
                              )
                            : Icon(
                                Icons.restaurant_rounded,
                                color: AppColors.primary,
                                size: 26.sp,
                              ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.restaurantName.isNotEmpty
                                ? booking.restaurantName
                                : 'Restaurant',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (booking.restaurantAddress.isNotEmpty) ...[
                            SizedBox(height: 2.h),
                            Text(
                              booking.restaurantAddress,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Text(
                                '#${booking.bookingCode}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: booking.bookingCode));
                                  Haptics.light();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      behavior: SnackBarBehavior.floating,
                                      content: Text('Booking Code copied!'),
                                      duration: Duration(seconds: 1),
                                    ),
                                  );
                                },
                                child: Icon(Icons.copy_rounded, size: 13.sp, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12.sp, color: statusColor),
                          SizedBox(width: 4.w),
                          Text(
                            booking.displayStatus,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Divider(
                height: 1,
                color: isDark ? AppColors.borderDark : const Color(0xFFF1F5F9),
              ),

              // Details Grid (Date, Time, Guests, Tables)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                child: Container(
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              icon: Icons.calendar_today_rounded,
                              label: 'Date',
                              value: _formatDate(booking.date),
                              isDark: isDark,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30.h,
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 12.w),
                              child: _buildDetailItem(
                                icon: Icons.access_time_filled_rounded,
                                label: 'Time Slot',
                                value: booking.formattedSlotRange,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDetailItem(
                              icon: Icons.people_alt_rounded,
                              label: 'Guests',
                              value: '${booking.guests} Guests',
                              isDark: isDark,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 30.h,
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: 12.w),
                              child: _buildDetailItem(
                                icon: Icons.table_bar_rounded,
                                label: 'Table',
                                value: booking.tables.isNotEmpty
                                    ? booking.tables.map((t) => t.name).join(', ')
                                    : (booking.status == 'confirmed' ? 'Assigned upon arrival' : 'Pending assign'),
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (booking.specialRequest.isNotEmpty || booking.occasion.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.notes_rounded, size: 14.sp, color: Colors.grey),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                [
                                  if (booking.occasion.isNotEmpty) 'Occasion: ${booking.occasion}',
                                  if (booking.specialRequest.isNotEmpty) 'Note: ${booking.specialRequest}',
                                ].join(' • '),
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontStyle: FontStyle.italic,
                                  color: isDark ? Colors.white70 : Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (booking.cancelReason.isNotEmpty) ...[
                        SizedBox(height: 8.h),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14.sp, color: Colors.red.shade400),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                'Reason: ${booking.cancelReason}',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Tap hint strip
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 10.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'View all details',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10.sp,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),

              // Actions Row (Cancel, Rate, Book Again)
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
                child: Row(
                  children: [
                    if (booking.canCancel) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCancelDialog(booking),
                          icon: Icon(Icons.close_rounded, size: 16.sp, color: Colors.red.shade600),
                          label: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade300),
                            padding: EdgeInsets.symmetric(vertical: 9.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                    ],
                    if (booking.canRate) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showRatingDialog(booking),
                          icon: Icon(Icons.star_rounded, size: 16.sp, color: Colors.white),
                          label: Text(
                            'Rate Visit',
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 9.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _bookAgain(booking),
                        icon: Icon(Icons.repeat_rounded, size: 16.sp, color: Colors.white),
                        label: Text(
                          'Book Again',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 9.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15.sp, color: AppColors.primary),
        SizedBox(width: 6.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _bookAgain(DiningUserBookingModel booking) {
    Haptics.light();
    final diningState = ref.read(diningViewModelProvider);
    final rest = diningState.restaurants.firstWhere(
      (r) => r.id == booking.restaurantId || r.restaurantId == booking.restaurantId,
      orElse: () => DiningRestaurantModel(
        id: booking.restaurantId,
        restaurantId: booking.restaurantId,
        name: booking.restaurantName,
        city: '',
        about: '',
        coverImage: booking.restaurantImage,
      ),
    );
    TableBookingSheet.show(context, rest);
  }

  void _showBookingDetailsSheet(DiningUserBookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        Color bannerBg;
        Color bannerText;
        IconData bannerIcon;
        String bannerMsg;

        switch (booking.status) {
          case 'confirmed':
            bannerBg = const Color(0xFFDCFCE7);
            bannerText = const Color(0xFF15803D);
            bannerIcon = Icons.check_circle_rounded;
            bannerMsg = 'Your table is confirmed! Please arrive on time and show your booking ID.';
            break;
          case 'pending':
            bannerBg = const Color(0xFFFEF3C7);
            bannerText = const Color(0xFFB45309);
            bannerIcon = Icons.hourglass_top_rounded;
            bannerMsg = 'Reservation request sent. The restaurant will review and confirm your table shortly.';
            break;
          case 'seated':
            bannerBg = const Color(0xFFE0E7FF);
            bannerText = const Color(0xFF4338CA);
            bannerIcon = Icons.airline_seat_recline_normal_rounded;
            bannerMsg = 'You are currently seated. Enjoy your dining experience!';
            break;
          case 'completed':
            bannerBg = const Color(0xFFCCFBF1);
            bannerText = const Color(0xFF0F766E);
            bannerIcon = Icons.task_alt_rounded;
            bannerMsg = 'This dining experience is completed. Hope you had a great time!';
            break;
          case 'cancelled':
          case 'rejected':
          case 'no_show':
            bannerBg = const Color(0xFFFEE2E2);
            bannerText = const Color(0xFFB91C1C);
            bannerIcon = Icons.cancel_rounded;
            bannerMsg = booking.cancelReason.isNotEmpty
                ? 'Reservation cancelled: ${booking.cancelReason}'
                : 'This reservation has been cancelled.';
            break;
          default:
            bannerBg = Colors.grey.shade200;
            bannerText = Colors.grey.shade800;
            bannerIcon = Icons.info_outline_rounded;
            bannerMsg = 'Reservation status: ${booking.displayStatus}';
        }

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.90,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                  width: 44.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Booking Details',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, size: 22.sp),
                      onPressed: () => Navigator.pop(ctx),
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),

              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 24.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Banner
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: bannerBg,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(bannerIcon, size: 18.sp, color: bannerText),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Text(
                                bannerMsg,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: bannerText,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Restaurant Details Box
                      Container(
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10.r),
                              child: Container(
                                width: 56.w,
                                height: 56.h,
                                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                                child: booking.restaurantImage.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: booking.restaurantImage,
                                        fit: BoxFit.cover,
                                        errorWidget: (ctx, url, error) => Icon(
                                          Icons.restaurant_rounded,
                                          color: AppColors.primary,
                                          size: 28.sp,
                                        ),
                                      )
                                    : Icon(
                                        Icons.restaurant_rounded,
                                        color: AppColors.primary,
                                        size: 28.sp,
                                      ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    booking.restaurantName,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  if (booking.restaurantAddress.isNotEmpty) ...[
                                    SizedBox(height: 2.h),
                                    Text(
                                      booking.restaurantAddress,
                                      style: TextStyle(
                                        fontSize: 11.5.sp,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 6.h),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryAlpha(0.1),
                                          borderRadius: BorderRadius.circular(6.r),
                                        ),
                                        child: Text(
                                          'ID: #${booking.bookingCode}',
                                          style: TextStyle(
                                            fontSize: 11.5.sp,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6.w),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: booking.bookingCode));
                                          Haptics.light();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              behavior: SnackBarBehavior.floating,
                                              content: Text('Booking Code copied!'),
                                              duration: Duration(seconds: 1),
                                            ),
                                          );
                                        },
                                        child: Icon(Icons.copy_rounded, size: 14.sp, color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Schedule & Seating Information
                      Text(
                        'Reservation Details',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            _buildSheetRow(
                              icon: Icons.calendar_today_rounded,
                              label: 'Date',
                              value: _formatDate(booking.date),
                              isDark: isDark,
                            ),
                            Divider(height: 16.h, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                            _buildSheetRow(
                              icon: Icons.access_time_rounded,
                              label: 'Time Slot',
                              value: booking.formattedSlotRange,
                              isDark: isDark,
                            ),
                            Divider(height: 16.h, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                            _buildSheetRow(
                              icon: Icons.people_alt_rounded,
                              label: 'Party Size',
                              value: '${booking.guests} Guests',
                              isDark: isDark,
                            ),
                            Divider(height: 16.h, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                            _buildSheetRow(
                              icon: Icons.table_bar_rounded,
                              label: 'Table Allocation',
                              value: booking.tables.isNotEmpty
                                  ? booking.tables
                                      .map((t) => t.seats > 0 ? '${t.name} (${t.seats} seats)' : t.name)
                                      .join(', ')
                                  : (booking.status == 'confirmed' ? 'Assigned upon arrival' : 'Pending assign'),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16.h),

                      // Guest Contact Information
                      Text(
                        'Guest Details',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            _buildSheetRow(
                              icon: Icons.person_rounded,
                              label: 'Guest Name',
                              value: booking.guestName.isNotEmpty ? booking.guestName : 'Guest',
                              isDark: isDark,
                            ),
                            if (booking.guestPhone.isNotEmpty) ...[
                              Divider(height: 16.h, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                              Row(
                                children: [
                                  Icon(Icons.phone_rounded, size: 16.sp, color: AppColors.primary),
                                  SizedBox(width: 10.w),
                                  Text(
                                    'Contact',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    booking.guestPhone,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  SizedBox(width: 6.w),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: booking.guestPhone));
                                      Haptics.light();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content: Text('Phone number copied!'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    },
                                    child: Icon(Icons.copy_rounded, size: 14.sp, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Special Requests / Occasion
                      if (booking.occasion.isNotEmpty || booking.specialRequest.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Text(
                          'Preferences & Special Requests',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(14.r),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (booking.occasion.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.celebration_rounded, size: 16.sp, color: Colors.amber.shade700),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'Occasion: ${booking.occasion}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (booking.occasion.isNotEmpty && booking.specialRequest.isNotEmpty)
                                SizedBox(height: 8.h),
                              if (booking.specialRequest.isNotEmpty) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.notes_rounded, size: 16.sp, color: Colors.grey),
                                    SizedBox(width: 8.w),
                                    Expanded(
                                      child: Text(
                                        'Note: ${booking.specialRequest}',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Payment & Billing Summary
                      SizedBox(height: 16.h),
                      Text(
                        'Payment Details',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.all(14.r),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          children: [
                            _buildSheetRow(
                              icon: Icons.payments_rounded,
                              label: 'Reservation Fee',
                              value: booking.reservationFee > 0
                                  ? '₹${booking.reservationFee.toStringAsFixed(0)}'
                                  : 'Free Reservation',
                              isDark: isDark,
                            ),
                            Divider(height: 16.h, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                            _buildSheetRow(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Payment Method',
                              value: booking.paymentMethod.toUpperCase(),
                              isDark: isDark,
                            ),
                            Divider(height: 16.h, color: isDark ? Colors.white10 : const Color(0xFFE5E7EB)),
                            _buildSheetRow(
                              icon: Icons.verified_rounded,
                              label: 'Payment Status',
                              value: booking.paymentStatus.toUpperCase(),
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),

                      // Created Timestamp
                      if (booking.createdAt != null) ...[
                        SizedBox(height: 14.h),
                        Center(
                          child: Text(
                            'Booked on ${DateFormat('d MMM yyyy, h:mm a').format(booking.createdAt!)}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                      SizedBox(height: 20.h),

                      // Action Buttons
                      Row(
                        children: [
                          if (booking.canCancel) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showCancelDialog(booking);
                                },
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.red.shade400),
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                                child: Text(
                                  'Cancel Booking',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade600,
                                    fontSize: 12.5.sp,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                          ],
                          if (booking.canRate) ...[
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showRatingDialog(booking);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                  padding: EdgeInsets.symmetric(vertical: 12.h),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                                ),
                                child: Text(
                                  'Rate Experience',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 12.5.sp,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                          ],
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _bookAgain(booking);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: EdgeInsets.symmetric(vertical: 12.h),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                              ),
                              child: Text(
                                'Book Again',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 12.5.sp,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSheetRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: AppColors.primary),
        SizedBox(width: 10.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCancelDialog(DiningUserBookingModel booking) async {
    final reasonController = TextEditingController();
    String selectedReason = 'Change of plans';
    final commonReasons = [
      'Change of plans',
      'Booked wrong date/time',
      'Personal emergency',
      'Found another place',
      'Other',
    ];

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                left: 20.w,
                right: 20.w,
                top: 16.h,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Cancel Table Reservation',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Reservation at ${booking.restaurantName} for ${booking.guests} guests on ${_formatDate(booking.date)} at ${booking.formattedSlotRange}.',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Please select a reason for cancellation:',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: commonReasons.map((r) {
                        final isSel = selectedReason == r;
                        return ChoiceChip(
                          label: Text(r),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedReason = r;
                              });
                            }
                          },
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            fontSize: 11.5.sp,
                            color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    if (selectedReason == 'Other') ...[
                      SizedBox(height: 12.h),
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter specific reason...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                      ),
                    ],
                    SizedBox(height: 20.h),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Keep Reservation'),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Confirm Cancel'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final reason = selectedReason == 'Other' && reasonController.text.trim().isNotEmpty
          ? reasonController.text.trim()
          : selectedReason;

      Haptics.medium();
      final ok = await ref.read(diningBookingsViewModelProvider.notifier).cancelBooking(
            booking.id,
            reason,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? Colors.black87 : Colors.red.shade700,
          content: Text(
            ok ? 'Reservation cancelled successfully.' : 'Failed to cancel reservation.',
          ),
        ),
      );
    }
  }

  Future<void> _showRatingDialog(DiningUserBookingModel booking) async {
    int rating = 5;
    final reviewController = TextEditingController();

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20.h,
                left: 20.w,
                right: 20.w,
                top: 16.h,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rate Your Dining Experience',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      booking.restaurantName,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 16.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final star = index + 1;
                        return IconButton(
                          iconSize: 36.sp,
                          icon: Icon(
                            star <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                            color: Colors.amber.shade600,
                          ),
                          onPressed: () {
                            setModalState(() {
                              rating = star;
                            });
                          },
                        );
                      }),
                    ),
                    SizedBox(height: 14.h),
                    TextField(
                      controller: reviewController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Share your experience (food, ambiance, service)...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                      ),
                    ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        child: const Text(
                          'Submit Review',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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

    if (submitted == true) {
      final ok = await ref.read(diningBookingsViewModelProvider.notifier).rateBooking(
            booking.id,
            rating,
            reviewController.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? 'Thank you for your rating!' : 'Failed to submit rating.'),
        ),
      );
    }
  }
}
