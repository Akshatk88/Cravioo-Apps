import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/dining/data/dining_repository.dart';
import 'package:food_user_application/features/dining/domain/dining_booking_model.dart';
import 'package:food_user_application/features/dining/domain/dining_table_model.dart';
import 'package:food_user_application/features/dining/presentation/controllers/dining_controller.dart';
import 'package:food_user_application/features/dining/presentation/controllers/dining_profile_controller.dart';

class DiningBookingsScreen extends ConsumerStatefulWidget {
  const DiningBookingsScreen({super.key});

  @override
  ConsumerState<DiningBookingsScreen> createState() => _DiningBookingsScreenState();
}

class _DiningBookingsScreenState extends ConsumerState<DiningBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static String _formatTime12Hour(String timeStr) {
    if (timeStr.isEmpty) return '';
    final parts = timeStr.trim().split(':');
    if (parts.isEmpty) return timeStr;
    final hour = int.tryParse(parts[0]);
    if (hour == null) return timeStr;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mStr = minute.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(diningControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bookingsState = bookingsAsync.value;
    final pendingBookings = bookingsState?.pending ?? [];
    final confirmedBookings = bookingsState?.confirmed ?? [];
    final seatedBookings = bookingsState?.seated ?? [];
    final historyBookings = bookingsState?.history ?? [];

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: 20,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/explore');
            }
          },
        ),
        title: const Text(
          'Dining Bookings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        actions: [
          IconButton(
            icon: const Icon(Icons.dashboard_customize_rounded),
            tooltip: 'Dining Management Hub',
            onPressed: () => context.push('/dining'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () => ref.read(diningControllerProvider.notifier).refresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primaryDark,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'Requests (${pendingBookings.length})'),
            Tab(text: 'Confirmed (${confirmedBookings.length})'),
            Tab(text: 'Seated (${seatedBookings.length})'),
            Tab(text: 'History (${historyBookings.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildOnlineToggleBanner(),
          Expanded(
            child: bookingsAsync.isLoading && bookingsState == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildBookingList(pendingBookings, 'No pending booking requests'),
                      _buildBookingList(confirmedBookings, 'No confirmed bookings'),
                      _buildBookingList(seatedBookings, 'No currently seated guests'),
                      _buildBookingList(historyBookings, 'No past booking history'),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineToggleBanner() {
    final profileAsync = ref.watch(diningProfileControllerProvider);
    final profile = profileAsync.value?.profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (profile == null) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.table_restaurant_rounded, color: Color(0xFF2563EB), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dining Setup Required',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF1E3A8A),
                    ),
                  ),
                  Text(
                    'Submit your dining request to Cravioo Admin for approval.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[300] : const Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => context.push('/dining-request'),
              child: const Text('Setup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (profile.isPending) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Request Submitted & Under Review',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF92400E),
                    ),
                  ),
                  Text(
                    'Once Cravioo admin approves, your restaurant will be visible in user app.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[300] : const Color(0xFFB45309),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_note_rounded, color: Color(0xFFD97706)),
              tooltip: 'Edit Request',
              onPressed: () => context.push('/dining-request'),
            ),
          ],
        ),
      );
    }

    if (profile.isRejected) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: Color(0xFFDC2626), size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dining Request Rejected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF991B1B),
                    ),
                  ),
                  Text(
                    profile.rejectionReason.isNotEmpty
                        ? 'Reason: ${profile.rejectionReason}'
                        : 'Please update details and re-submit for review.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[300] : const Color(0xFFB91C1C),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => context.push('/dining-request'),
              child: const Text('Re-submit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    final isOnline = profile.isOnline;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isOnline
            ? (isDark ? const Color(0xFF064E3B) : AppColors.primaryTint)
            : (isDark ? const Color(0xFF3F3F46) : const Color(0xFFF3F4F6)),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOnline
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.table_restaurant_rounded : Icons.store_mall_directory_outlined,
            color: isOnline ? AppColors.primaryDark : Colors.grey[600],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Dining is Active & Visible' : 'Dining is Paused (Offline)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isOnline ? AppColors.primaryDark : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
                Text(
                  isOnline
                      ? 'Approved by Admin • Visible to nearby customers'
                      : 'Paused • Hidden from user dining section',
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnline ? AppColors.primaryDark.withValues(alpha: 0.8) : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isOnline,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primaryTintStrong,
            onChanged: (val) async {
              final ok = await ref
                  .read(diningProfileControllerProvider.notifier)
                  .updateSettings({'isOnline': val});
              if (mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      val
                          ? 'Dining turned ON — visible to users'
                          : 'Dining turned OFF — hidden from users',
                    ),
                    backgroundColor: val ? AppColors.primaryDark : Colors.grey[800],
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookingList(List<DiningBookingModel> list, String emptyMessage) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.table_restaurant_rounded,
                size: 48,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(diningControllerProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final booking = list[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(DiningBookingModel booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    Color statusBgColor;
    final String statusLabel = booking.status.toUpperCase();

    switch (booking.status) {
      case 'pending':
        statusColor = const Color(0xFFD97706);
        statusBgColor = const Color(0xFFFEF3C7);
        break;
      case 'confirmed':
        statusColor = AppColors.primaryDark;
        statusBgColor = AppColors.primaryTint;
        break;
      case 'seated':
        statusColor = const Color(0xFF2563EB);
        statusBgColor = const Color(0xFFDBEAFE);
        break;
      case 'completed':
        statusColor = const Color(0xFF059669);
        statusBgColor = const Color(0xFFD1FAE5);
        break;
      case 'cancelled':
      case 'rejected':
      case 'no_show':
      default:
        statusColor = const Color(0xFFDC2626);
        statusBgColor = const Color(0xFFFEE2E2);
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code & Status Pill (Clean responsive layout that prevents any horizontal overflow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.table_restaurant_rounded,
                  color: AppColors.primaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${booking.bookingCode}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.date,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: booking.paymentStatus == 'paid'
                          ? const Color(0xFFD1FAE5)
                          : (booking.paymentStatus == 'free'
                              ? (isDark ? Colors.grey[800] : const Color(0xFFF3F4F6))
                              : const Color(0xFFFEF3C7)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      booking.paymentStatus == 'paid'
                          ? 'PAID ₹${booking.paidAmount.toStringAsFixed(0)} • ${booking.paymentMethod.toUpperCase()}'
                          : (booking.paymentStatus == 'free' ? 'FREE BOOKING' : 'PAYMENT PENDING'),
                      style: TextStyle(
                        color: booking.paymentStatus == 'paid'
                            ? const Color(0xFF059669)
                            : (booking.paymentStatus == 'free'
                                ? (isDark ? Colors.grey[300] : Colors.grey[700])
                                : const Color(0xFFD97706)),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Guest & Time details
          Row(
            children: [
              Expanded(
                child: _buildDetailRow(
                  Icons.person_rounded,
                  booking.guestName,
                  '${booking.guests} Guests',
                ),
              ),
              Expanded(
                child: _buildDetailRow(
                  Icons.access_time_rounded,
                  '${_formatTime12Hour(booking.slotStart)} - ${_formatTime12Hour(booking.slotEnd)}',
                  'Time Slot',
                ),
              ),
            ],
          ),

          if (booking.tables.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.table_bar_rounded, size: 16, color: Color(0xFF15803D)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Table: ${booking.tables.map((t) => '${t.name} (${t.seats}s)').join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (booking.isConfirmed) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _confirmBookingWithTable(booking),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.table_bar_rounded, size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No table assigned yet. Tap to assign table',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2563EB),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
          ],

          if (booking.guestPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _callPhone(booking.guestPhone),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 16, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.guestPhone,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryDark,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Call Guest',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          if (booking.occasion.isNotEmpty || booking.specialRequest.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (booking.occasion.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.celebration_rounded, size: 15, color: Colors.amber),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Occasion: ${booking.occasion}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (booking.specialRequest.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes_rounded, size: 15, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Note: ${booking.specialRequest}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],

          // Actions
          if (booking.isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _updateStatusWithReason(booking.id, 'rejected', 'Reject Booking'),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryButton,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _confirmBookingWithTable(booking),
                    child: const Text('Confirm Table', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else if (booking.isConfirmed) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _updateStatusWithReason(booking.id, 'no_show', 'Mark as No-Show'),
                    child: const Text('No Show'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => ref.read(diningControllerProvider.notifier).updateStatus(booking.id, 'seated'),
                    child: const Text('Mark Seated', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ] else if (booking.isSeated) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryButton,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => ref.read(diningControllerProvider.notifier).updateStatus(booking.id, 'completed'),
                label: const Text('Complete Dining', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String primary, String secondary) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDark),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                primary,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                secondary,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _callPhone(String phone) async {
    if (Platform.isAndroid) {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.DIAL',
          data: 'tel:$phone',
        );
        await intent.launch();
        return;
      } catch (_) {}
    }
    // Fallback: Copy to clipboard
    await Clipboard.setData(ClipboardData(text: phone));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number copied to clipboard')),
      );
    }
  }

  Future<void> _confirmBookingWithTable(DiningBookingModel booking) async {
    // 1. Fetch active tables from repository
    List<DiningTableModel> activeTables = [];
    try {
      final res = await ref.read(diningRepositoryProvider).listTables();
      final items = res['items'] as List<DiningTableModel>? ?? [];
      activeTables = items.where((t) => t.isActive).toList();
    } catch (_) {}

    if (!mounted) return;

    final selectedTableIds = <String>{};
    final noteCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? AppColors.surfaceDark : Colors.white;
            final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
            final totalAssignedSeats = activeTables
                .where((t) => selectedTableIds.contains(t.id))
                .fold(0, (sum, t) => sum + t.seats);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confirm & Assign Table',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${booking.guestName} • ${booking.guests} Guests • ${_formatTime12Hour(booking.slotStart)}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Table selection section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Table (Optional)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (selectedTableIds.isNotEmpty)
                          Text(
                            '$totalAssignedSeats / ${booking.guests} seats selected',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: totalAssignedSeats >= booking.guests
                                  ? AppColors.primaryDark
                                  : Colors.amber[800],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (activeTables.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: const Text(
                          'No active tables configured. You can still confirm the booking and assign seating on arrival.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: activeTables.map((t) {
                          final isSelected = selectedTableIds.contains(t.id);
                          return FilterChip(
                            label: Text('${t.name} (${t.seats}s) • ${t.sectionLabel}'),
                            selected: isSelected,
                            selectedColor: AppColors.primaryTint,
                            checkmarkColor: AppColors.primaryDeep,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? AppColors.primaryDeep : (isDark ? Colors.white70 : Colors.black87),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: isSelected ? AppColors.primary : borderColor),
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                if (val) {
                                  selectedTableIds.add(t.id);
                                } else {
                                  selectedTableIds.remove(t.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),

                    // Note field
                    Text(
                      'Internal Note (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: noteCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Near window reserved',
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Actions
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryButton,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          final ok = await ref.read(diningControllerProvider.notifier).updateStatus(
                                booking.id,
                                'confirmed',
                                note: noteCtrl.text.trim(),
                                tableIds: selectedTableIds.isNotEmpty ? selectedTableIds.toList() : null,
                              );
                          if (ok) {
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Booking confirmed successfully!'),
                                backgroundColor: AppColors.primaryDark,
                              ),
                            );
                          }
                        },
                        child: Text(
                          selectedTableIds.isNotEmpty
                              ? 'Confirm with Assigned Table(s)'
                              : 'Confirm Booking',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
  }

  Future<void> _updateStatusWithReason(String bookingId, String status, String title) async {
    final noteCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                hintText: 'Enter reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref
          .read(diningControllerProvider.notifier)
          .updateStatus(bookingId, status, note: noteCtrl.text.trim());
    }
  }
}
