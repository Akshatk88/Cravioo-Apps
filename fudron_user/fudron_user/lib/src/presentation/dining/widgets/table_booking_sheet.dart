import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/dining_model.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';
import '../../wallet/viewmodels/wallet_viewmodel.dart';
import '../viewmodels/dining_bookings_viewmodel.dart';
import '../viewmodels/dining_state.dart';
import '../viewmodels/dining_viewmodel.dart';

class TableBookingSheet extends ConsumerStatefulWidget {
  final DiningRestaurantModel restaurant;

  const TableBookingSheet({super.key, required this.restaurant});

  static Future<void> show(BuildContext context, DiningRestaurantModel restaurant) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TableBookingSheet(restaurant: restaurant),
    );
  }

  @override
  ConsumerState<TableBookingSheet> createState() => _TableBookingSheetState();
}

class _TableBookingSheetState extends ConsumerState<TableBookingSheet> {
  DateTime _selectedDate = DateTime.now();
  DiningSlotModel? _selectedSlot;
  int _guestCount = 2;
  String _selectedPaymentMethod = 'wallet'; // 'wallet' or 'online'
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _requestController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  static const List<DiningSlotModel> _defaultSlots = [
    // Morning / Breakfast & Brunch (AM)
    DiningSlotModel(startTime: '09:00', endTime: '10:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '10:00', endTime: '11:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '11:00', endTime: '12:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    // Afternoon / Lunch (PM)
    DiningSlotModel(startTime: '12:00', endTime: '13:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '13:00', endTime: '14:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '14:00', endTime: '15:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    // Evening / Dinner (PM)
    DiningSlotModel(startTime: '17:00', endTime: '18:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '18:00', endTime: '19:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '19:00', endTime: '20:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '20:00', endTime: '21:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '21:00', endTime: '22:00', capacity: 20, seatsLeft: 12, isAvailable: true),
    DiningSlotModel(startTime: '22:00', endTime: '23:00', capacity: 20, seatsLeft: 12, isAvailable: true),
  ];

  static String _formatTime12Hour(String timeStr) {
    if (timeStr.isEmpty) return '';
    final trimmed = timeStr.trim();
    if (trimmed.toUpperCase().contains('AM') || trimmed.toUpperCase().contains('PM')) {
      return trimmed;
    }
    final parts = trimmed.split(':');
    if (parts.isEmpty) return trimmed;
    final hour = int.tryParse(parts[0]);
    if (hour == null) return trimmed;
    final minuteStr = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '00';
    final minute = int.tryParse(minuteStr) ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mStr = minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill user info from auth and load wallet balance
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletViewModelProvider.notifier).loadWallet();
      final user = ref.read(authViewModelProvider).value;
      if (user != null) {
        _nameController.text = user.name;
        _phoneController.text = user.phone?.replaceAll('+91', '').trim() ?? '';
      }
      _loadAvailability();
    });
  }

  void _loadAvailability() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final targetRid = widget.restaurant.restaurantId.isNotEmpty
        ? widget.restaurant.restaurantId
        : widget.restaurant.id;
    ref.read(diningViewModelProvider.notifier).loadAvailability(
          restaurantId: targetRid,
          date: dateStr,
          guests: _guestCount,
        );
  }

  Future<void> _openCalendarPicker() async {
    Haptics.light();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: isDark ? AppColors.surfaceDark : Colors.white,
              onSurface: isDark ? Colors.white : Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      Haptics.light();
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
      });
      _loadAvailability();
    }
  }

  List<DateTime> _buildDateChips() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dates = List.generate(7, (i) => today.add(Duration(days: i)));
    final hasSelected = dates.any((d) => DateUtils.isSameDay(d, _selectedDate));
    if (!hasSelected) {
      dates.insert(0, DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day));
    }
    return dates;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _requestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final diningState = ref.watch(diningViewModelProvider);
    final availability = diningState.availability;
    final availableSlots = availability?.slots.where((s) => s.isAvailable).toList() ?? [];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
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
      child: Form(
        key: _formKey,
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
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Book a Table',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.restaurant.name,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              // Date Selection Header with Calendar button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Select Date',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAlpha(0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          DateFormat('d MMM, EEE').format(_selectedDate),
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _openCalendarPicker,
                    borderRadius: BorderRadius.circular(8.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF252525) : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.primaryAlpha(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            size: 15.sp,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'Calendar',
                            style: TextStyle(
                              fontSize: 11.5.sp,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              Builder(
                builder: (context) {
                  final dateList = _buildDateChips();
                  return SizedBox(
                    height: 48.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: dateList.length + 1,
                      separatorBuilder: (_, _) => SizedBox(width: 8.w),
                      itemBuilder: (ctx, index) {
                        if (index == dateList.length) {
                          return GestureDetector(
                            onTap: _openCalendarPicker,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: AppColors.primaryAlpha(0.5),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.date_range_rounded, size: 15.sp, color: AppColors.primary),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'More Dates',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final date = dateList[index];
                        final isSelected = DateUtils.isSameDay(date, _selectedDate);
                        final isToday = DateUtils.isSameDay(date, DateTime.now());
                        final isTomorrow = DateUtils.isSameDay(date, DateTime.now().add(const Duration(days: 1)));
                        final label = isToday
                            ? 'Today'
                            : (isTomorrow ? 'Tomorrow' : DateFormat('EEE, d MMM').format(date));

                        return GestureDetector(
                          onTap: () {
                            Haptics.light();
                            setState(() {
                              _selectedDate = date;
                              _selectedSlot = null;
                            });
                            _loadAvailability();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : (isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5)),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark ? AppColors.borderDark : const Color(0xFFE0E0E0)),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? Colors.white70 : Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              SizedBox(height: 18.h),

              // Guests Count
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Number of Guests',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Table will be reserved accordingly',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          constraints: BoxConstraints(minWidth: 34.w, minHeight: 34.h),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.remove, size: 18),
                          onPressed: _guestCount > 1
                              ? () {
                                  Haptics.light();
                                  setState(() {
                                    _guestCount--;
                                    _selectedSlot = null;
                                  });
                                  _loadAvailability();
                                }
                              : null,
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          child: Text(
                            '$_guestCount Guests',
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        IconButton(
                          constraints: BoxConstraints(minWidth: 34.w, minHeight: 34.h),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.add, size: 18),
                          onPressed: _guestCount < (availability?.maxGuestsPerBooking ?? 20)
                              ? () {
                                  Haptics.light();
                                  setState(() {
                                    _guestCount++;
                                    _selectedSlot = null;
                                  });
                                  _loadAvailability();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              // Time Slots — fetched from backend
              Text(
                'Select Time Slot',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              SizedBox(height: 10.h),
              _buildSlotsSection(isDark, diningState, availability, availableSlots),
              SizedBox(height: 18.h),

              // Guest Name
              TextFormField(
                controller: _nameController,
                validator: (v) {
                  if (v == null || v.trim().length < 2) return 'Name is required';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Your Name *',
                  hintText: 'Enter your full name',
                  hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF222222) : const Color(0xFFF9F9F9),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE0E0E0),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                validator: (v) {
                  final clean = v?.replaceAll('+91', '').replaceAll(' ', '').trim() ?? '';
                  if (clean.length != 10) return 'Enter valid 10-digit phone';
                  return null;
                },
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: 'Enter 10-digit mobile number',
                  hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF222222) : const Color(0xFFF9F9F9),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE0E0E0),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // Special Request
              TextField(
                controller: _requestController,
                decoration: InputDecoration(
                  hintText: 'Any special request? (e.g. Window seat, anniversary)',
                  hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF222222) : const Color(0xFFF9F9F9),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.borderDark : const Color(0xFFE0E0E0),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              SizedBox(height: 20.h),

              // Seat Booking Charges & Bill Summary Card
              _buildChargesSummaryCard(isDark, availability),
              SizedBox(height: 16.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48.h,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  onPressed: (diningState.isBooking || _selectedSlot == null)
                      ? null
                      : () => _submitBooking(availability?.reservationFee ?? 0.0),
                  child: diningState.isBooking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selectedSlot != null
                                  ? ((availability?.reservationFee ?? 0) > 0
                                      ? 'Pay ₹${(availability!.reservationFee).toStringAsFixed(0)} • ${_formatTime12Hour(_selectedSlot!.startTime)}'
                                      : 'Book Table • ${_formatTime12Hour(_selectedSlot!.startTime)} ($_guestCount Guests)')
                                  : 'Select a Time Slot',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_selectedSlot != null && (availability?.reservationFee ?? 0) <= 0) ...[
                              SizedBox(width: 8.w),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4.r),
                                ),
                                child: Text(
                                  'FREE',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              ),
              SizedBox(height: 8.h),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 12.sp, color: Colors.grey),
                    SizedBox(width: 4.w),
                    Text(
                      (availability?.reservationFee ?? 0) > 0
                          ? 'Secured booking • Instant reservation confirmation'
                          : 'Zero advance payment • Pay at restaurant after dining',
                      style: TextStyle(fontSize: 10.5.sp, color: Colors.grey),
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

  Widget _buildChargesSummaryCard(bool isDark, DiningAvailabilityModel? availability) {
    final costForTwo = widget.restaurant.costForTwo;
    final isAutoConfirm = availability?.autoConfirm ?? false;
    final reservationFee = availability?.reservationFee ?? 0.0;
    final walletState = ref.watch(walletViewModelProvider);
    final walletBalance = walletState.wallet.balance;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 16.sp,
                color: AppColors.primary,
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  'Booking & Charges Breakdown',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: (reservationFee > 0 ? AppColors.primary : const Color(0xFF059669))
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6.r),
                  border: Border.all(
                    color: (reservationFee > 0 ? AppColors.primary : const Color(0xFF059669))
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  reservationFee > 0
                      ? 'PAID BOOKING'
                      : '100% FREE BOOKING',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w800,
                    color: reservationFee > 0 ? AppColors.primary : const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          const Divider(height: 1),
          SizedBox(height: 10.h),

          // Charge Row 1: Seat Reservation Charges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seat / Table Reservation Charges',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              if (reservationFee > 0)
                Text(
                  '₹${reservationFee.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                )
              else
                Row(
                  children: [
                    Text(
                      '₹99',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.grey,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'FREE',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          SizedBox(height: 6.h),

          // Charge Row 2: Advance Deposit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                reservationFee > 0 ? 'Total Payable Now' : 'Advance Deposit Required',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              Text(
                reservationFee > 0 ? '₹${reservationFee.toStringAsFixed(0)}' : '₹0',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: reservationFee > 0 ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),

          if (costForTwo > 0) ...[
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Approx Cost for Two (Food & Drinks)',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '₹$costForTwo',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],

          // Payment Options (Only shown if seat reservation requires payment)
          if (reservationFee > 0) ...[
            SizedBox(height: 12.h),
            Text(
              'Select Payment Option',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: 8.h),
            // Option 1: Cravioo Wallet
            GestureDetector(
              onTap: () => setState(() => _selectedPaymentMethod = 'wallet'),
              child: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: _selectedPaymentMethod == 'wallet'
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : (isDark ? const Color(0xFF252525) : Colors.white),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: _selectedPaymentMethod == 'wallet'
                        ? AppColors.primary
                        : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                    width: _selectedPaymentMethod == 'wallet' ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 20.sp,
                      color: _selectedPaymentMethod == 'wallet' ? AppColors.primary : Colors.grey,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cravioo Wallet',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'Available Balance: ₹${walletBalance.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              color: walletBalance >= reservationFee ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _selectedPaymentMethod == 'wallet'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _selectedPaymentMethod == 'wallet' ? AppColors.primary : Colors.grey,
                      size: 20.sp,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8.h),
            // Option 2: Online Payment (UPI, Cards, NetBanking)
            GestureDetector(
              onTap: () => setState(() => _selectedPaymentMethod = 'online'),
              child: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: _selectedPaymentMethod == 'online'
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : (isDark ? const Color(0xFF252525) : Colors.white),
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: _selectedPaymentMethod == 'online'
                        ? AppColors.primary
                        : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
                    width: _selectedPaymentMethod == 'online' ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.payment_rounded,
                      size: 20.sp,
                      color: _selectedPaymentMethod == 'online' ? AppColors.primary : Colors.grey,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Online Payment',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            'UPI, Google Pay, PhonePe, Cards, NetBanking',
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _selectedPaymentMethod == 'online'
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _selectedPaymentMethod == 'online' ? AppColors.primary : Colors.grey,
                      size: 20.sp,
                    ),
                  ],
                ),
              ),
            ),
          ],

          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isAutoConfirm
                  ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
                  : (isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  isAutoConfirm ? Icons.bolt_rounded : Icons.info_outline_rounded,
                  size: 16.sp,
                  color: isAutoConfirm ? const Color(0xFF059669) : const Color(0xFF2563EB),
                ),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    isAutoConfirm
                        ? 'Instant Confirmation — Table confirmed upon booking'
                        : 'Booking request will be sent to ${widget.restaurant.name} for confirmation',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w500,
                      color: isAutoConfirm
                          ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46))
                          : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsSection(
    bool isDark,
    DiningState diningState,
    DiningAvailabilityModel? availability,
    List<DiningSlotModel> availableSlots,
  ) {
    if (diningState.isLoadingAvailability) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final hasCustomSlots = (availability?.slots ?? []).isNotEmpty;
    final allSlots = hasCustomSlots ? availability!.slots : _defaultSlots;

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    final displaySlots = allSlots.where((slot) {
      if (!isToday) return true; // Future dates show all slots
      final parts = slot.startTime.split(':');
      if (parts.isEmpty) return true;
      final slotHour = int.tryParse(parts[0]) ?? 0;
      final minuteStr = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^0-9]'), '') : '00';
      final slotMinute = int.tryParse(minuteStr) ?? 0;
      final slotMinutes = slotHour * 60 + slotMinute;
      // Filter out slots that have already passed (allowing min 10 min lead time)
      final currentMinutesWithBuffer = (now.hour * 60 + now.minute) + 10;
      return slotMinutes >= currentMinutesWithBuffer;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (diningState.availabilityError != null && !hasCustomSlots)
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: 10.h),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E2415) : const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Standard booking slots available for this date.',
                    style: TextStyle(fontSize: 11.sp, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
                GestureDetector(
                  onTap: _loadAvailability,
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

        if (displaySlots.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252525) : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                Icon(Icons.access_time_rounded, size: 30.sp, color: Colors.amber.shade700),
                SizedBox(height: 8.h),
                Text(
                  isToday
                      ? 'No more slots available for today'
                      : 'No slots available for this date',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5.sp,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  isToday
                      ? 'All reservation slots for today have concluded. Please reserve a table for tomorrow.'
                      : 'Please choose another date or number of guests.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                if (isToday) ...[
                  SizedBox(height: 12.h),
                  ElevatedButton.icon(
                    onPressed: () {
                      Haptics.light();
                      setState(() {
                        _selectedDate = DateTime.now().add(const Duration(days: 1));
                        _selectedSlot = null;
                      });
                      _loadAvailability();
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 15, color: Colors.white),
                    label: const Text(
                      'Book for Tomorrow',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                    ),
                  ),
                ],
              ],
            ),
          )
        else
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: displaySlots.map((slot) {
              final isSelected = _selectedSlot?.startTime == slot.startTime;
              final isAvailable = slot.isAvailable;

              return GestureDetector(
                onTap: isAvailable
                    ? () {
                        Haptics.light();
                        setState(() => _selectedSlot = slot);
                      }
                    : null,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: !isAvailable
                        ? (isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF3F3F3))
                        : isSelected
                            ? AppColors.primary
                            : (isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5)),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: !isAvailable
                          ? Colors.grey.withValues(alpha: 0.2)
                          : isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : const Color(0xFFE0E0E0)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_formatTime12Hour(slot.startTime)} - ${_formatTime12Hour(slot.endTime)}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: !isAvailable
                              ? Colors.grey
                              : isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                      if (!isAvailable && slot.unavailableReason.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text(
                            slot.unavailableReason,
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: Colors.red.shade400,
                            ),
                          ),
                        )
                      else if (isAvailable && slot.seatsLeft > 0)
                        Padding(
                          padding: EdgeInsets.only(top: 2.h),
                          child: Text(
                            '${slot.seatsLeft} seats left',
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: isSelected
                                  ? Colors.white70
                                  : (slot.seatsLeft <= 4 ? Colors.orange : Colors.green),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Future<void> _submitBooking(double reservationFee) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSlot == null) return;

    final phone = _phoneController.text.replaceAll('+91', '').replaceAll(' ', '').trim();

    // Check payment if reservation fee applies
    if (reservationFee > 0) {
      if (_selectedPaymentMethod == 'wallet') {
        final walletBalance = ref.read(walletViewModelProvider).wallet.balance;
        if (walletBalance < reservationFee) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade800,
              content: Text(
                'Insufficient wallet balance (₹${walletBalance.toStringAsFixed(0)}). Required: ₹${reservationFee.toStringAsFixed(0)}. Please choose Online Payment or top up.',
              ),
            ),
          );
          return;
        }
      }
    }

    Haptics.medium();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final targetRid = widget.restaurant.restaurantId.isNotEmpty
        ? widget.restaurant.restaurantId
        : widget.restaurant.id;

    final result = await ref.read(diningViewModelProvider.notifier).bookTable(
          restaurantId: targetRid,
          date: dateStr,
          slotStart: _selectedSlot!.startTime,
          guests: _guestCount,
          guestName: _nameController.text.trim(),
          guestPhone: phone,
          specialRequest: _requestController.text.trim(),
          paymentMethod: reservationFee > 0 ? _selectedPaymentMethod : 'free',
        );

    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          backgroundColor: Colors.red.shade800,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  result.errorMessage?.isNotEmpty == true
                      ? result.errorMessage!
                      : 'Unable to reserve table. Please check slot availability and try again.',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final rootNav = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);

    // Refresh dining bookings history immediately and add locally
    if (result.booking != null) {
      ref.read(diningBookingsViewModelProvider.notifier).addBooking(result.booking!);
    }
    ref.read(diningBookingsViewModelProvider.notifier).loadBookings();

    // Clear any previous snackbars
    messenger.hideCurrentSnackBar();

    if (!rootNav.context.mounted) return;

    // Show clean Booking Confirmation Dialog
    _showBookingSuccessDialog(
      context: rootNav.context,
      booking: result.booking,
      restaurantName: widget.restaurant.name,
      formattedDate: DateFormat('EEE, d MMM yyyy').format(_selectedDate),
      slotTime: _formatTime12Hour(_selectedSlot!.startTime),
      guests: _guestCount,
    );
  }

  void _showBookingSuccessDialog({
    required BuildContext context,
    required DiningUserBookingModel? booking,
    required String restaurantName,
    required String formattedDate,
    required String slotTime,
    required int guests,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
        final code = booking?.bookingCode ?? '';
        final isConfirmed = booking?.status == 'confirmed';

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top close button
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () {
                      Haptics.light();
                      Navigator.pop(dialogCtx);
                    },
                    child: Container(
                      padding: EdgeInsets.all(4.r),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 20.sp, color: isDark ? Colors.white70 : Colors.black54),
                    ),
                  ),
                ),
                // Green checkmark
                Container(
                  width: 58.r,
                  height: 58.r,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: const Color(0xFF16A34A),
                    size: 34.sp,
                  ),
                ),
                SizedBox(height: 14.h),
                Text(
                  isConfirmed ? 'Table Reserved!' : 'Reservation Request Sent!',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 6.h),
                Text(
                  isConfirmed
                      ? 'Your table at $restaurantName is confirmed.'
                      : 'Request sent to $restaurantName. You will be notified once confirmed.',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (code.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.primaryAlpha(0.08),
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: AppColors.primaryAlpha(0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Booking ID: #$code',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: code));
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
                  ),
                ],
                SizedBox(height: 16.h),
                // Summary Box
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 14.sp, color: AppColors.primary),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14.sp, color: AppColors.primary),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              slotTime,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        children: [
                          Icon(Icons.people_alt_rounded, size: 14.sp, color: AppColors.primary),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              '$guests Guests',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20.h),
                // Action Buttons: Done (dismisses) and View Bookings
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Haptics.light();
                          Navigator.pop(dialogCtx);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Haptics.light();
                          Navigator.pop(dialogCtx);
                          context.push(RouteNames.diningBookings);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        child: Text(
                          'View Bookings',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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
  }
}
