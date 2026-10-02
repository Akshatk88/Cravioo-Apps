import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/dining/domain/dining_dashboard_model.dart';
import 'package:food_user_application/features/dining/domain/dining_profile_model.dart';
import 'package:food_user_application/features/dining/domain/dining_table_model.dart';
import 'package:food_user_application/features/dining/presentation/controllers/dining_dashboard_controller.dart';

class DiningManagementScreen extends ConsumerStatefulWidget {
  const DiningManagementScreen({super.key});

  @override
  ConsumerState<DiningManagementScreen> createState() => _DiningManagementScreenState();
}

class _DiningManagementScreenState extends ConsumerState<DiningManagementScreen> {
  final _bookingWindowController = TextEditingController();
  final _slotDurationController = TextEditingController();
  final _maxGuestsController = TextEditingController();
  final _minAdvanceController = TextEditingController();

  bool _initializedInputs = false;
  bool _isSavingRules = false;

  @override
  void dispose() {
    _bookingWindowController.dispose();
    _slotDurationController.dispose();
    _maxGuestsController.dispose();
    _minAdvanceController.dispose();
    super.dispose();
  }

  void _syncInputs(DiningProfileModel? profile) {
    if (profile == null) return;
    if (!_initializedInputs) {
      _bookingWindowController.text = profile.bookingWindowDays.toString();
      _slotDurationController.text = profile.slotDurationMins.toString();
      _maxGuestsController.text = profile.maxGuestsPerBooking.toString();
      _minAdvanceController.text = profile.minAdvanceMins.toString();
      _initializedInputs = true;
    }
  }

  Future<void> _saveBookingRules(DiningProfileModel profile) async {
    final window = int.tryParse(_bookingWindowController.text.trim()) ?? profile.bookingWindowDays;
    final slot = int.tryParse(_slotDurationController.text.trim()) ?? profile.slotDurationMins;
    final maxG = int.tryParse(_maxGuestsController.text.trim()) ?? profile.maxGuestsPerBooking;
    final minAdv = int.tryParse(_minAdvanceController.text.trim()) ?? profile.minAdvanceMins;

    if (window < 1 || window > 90) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking window must be between 1 and 90 days')),
      );
      return;
    }
    if (slot < 15 || slot > 240) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slot duration must be between 15 and 240 minutes')),
      );
      return;
    }
    if (maxG < 1 || maxG > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max guests must be between 1 and 50')),
      );
      return;
    }
    if (minAdv < 0 || minAdv > 1440) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Min advance notice must be between 0 and 1440 minutes')),
      );
      return;
    }

    setState(() => _isSavingRules = true);
    final success = await ref.read(diningDashboardControllerProvider.notifier).updateSettings(
      bookingWindowDays: window,
      slotDurationMins: slot,
      maxGuestsPerBooking: maxG,
      minAdvanceMins: minAdv,
    );
    if (mounted) {
      setState(() => _isSavingRules = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Booking rules updated successfully' : 'Failed to update booking rules'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(diningDashboardControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final textSecondary = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Dining Management',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              ref.read(diningDashboardControllerProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                const SizedBox(height: 12),
                Text(
                  'Failed to load dining dashboard',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(diningDashboardControllerProvider.notifier).refresh(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
        data: (dashboard) {
          final profile = dashboard.profile;
          _syncInputs(profile);

          if (profile == null) {
            return _buildNoProfileView(isDark, cardBg, borderColor);
          }

          final isApproved = profile.status == 'approved';
          final stats = dashboard.stats;
          final tablesSummary = dashboard.tables;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(diningDashboardControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Dining Status Card
                _buildStatusCard(profile, isDark, cardBg, borderColor, textSecondary),
                const SizedBox(height: 16),

                if (isApproved) ...[
                  // 2. Accepting Bookings Switch Card
                  _buildAcceptingBookingsCard(profile, isDark, cardBg, borderColor, textSecondary),
                  const SizedBox(height: 16),

                  // 3. Stats Grid (2x2)
                  _buildStatsGrid(stats, isDark, cardBg, borderColor, textSecondary),
                  const SizedBox(height: 16),

                  // 4. Quick Navigation Hub
                  _buildNavHub(stats, tablesSummary, isDark, cardBg, borderColor, textSecondary),
                  const SizedBox(height: 16),

                  // 5. Booking Rules Settings Card
                  _buildBookingRulesCard(profile, isDark, cardBg, borderColor, textSecondary),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoProfileView(bool isDark, Color cardBg, Color borderColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withAlpha(50)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  size: 40,
                  color: AppColors.primaryDeep,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Start Taking Table Bookings',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Send a dining request with your photos, timing, and seating details. Once approved by Cravioo, you can manage tables, slots, and instant bookings right here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push('/dining-request'),
                  icon: const Icon(Icons.add_business_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Raise Dining Request',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    DiningProfileModel profile,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    Color statusBg;
    Color statusText;
    String statusLabel = profile.status.toUpperCase();

    switch (profile.status) {
      case 'approved':
        statusBg = const Color(0xFFDCFCE7);
        statusText = const Color(0xFF15803D);
        statusLabel = 'Approved & Active';
        break;
      case 'pending':
        statusBg = const Color(0xFFFEF3C7);
        statusText = const Color(0xFFB45309);
        statusLabel = 'Under Review';
        break;
      case 'rejected':
        statusBg = const Color(0xFFFEE2E2);
        statusText = const Color(0xFFB91C1C);
        statusLabel = 'Rejected';
        break;
      default:
        statusBg = const Color(0xFFF3F4F6);
        statusText = const Color(0xFF374151);
        statusLabel = profile.status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dining Status',
                      style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (profile.coverImage.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    profile.coverImage,
                    width: 72,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
          if (profile.status == 'pending') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFB45309)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your request is currently under review by our admin team. You will be notified once activated.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (profile.status == 'rejected' && profile.rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.cancel_outlined, size: 18, color: Color(0xFFB91C1C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${profile.rejectionReason}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/dining-request'),
              icon: Icon(
                profile.status == 'rejected' ? Icons.edit_note_rounded : Icons.tune_rounded,
                size: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
              label: Text(
                profile.status == 'rejected' ? 'Edit & Resubmit Request' : 'Edit Dining Profile Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptingBookingsCard(
    DiningProfileModel profile,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: profile.isOnline ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.power_settings_new_rounded,
              size: 20,
              color: profile.isOnline ? AppColors.primaryDeep : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accepting Reservations',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  profile.isOnline
                      ? 'Online • Guests can book tables'
                      : 'Paused • Reservations temporarily stopped',
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: profile.isOnline,
            activeTrackColor: AppColors.primary,
            onChanged: (val) async {
              await ref.read(diningDashboardControllerProvider.notifier).toggleOnline(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(
    DiningStatsModel stats,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    final items = [
      {'label': "Today's Bookings", 'value': stats.todayBookings.toString(), 'icon': Icons.calendar_today_rounded, 'color': const Color(0xFF2563EB)},
      {'label': "Today's Guests", 'value': stats.todayGuests.toString(), 'icon': Icons.people_alt_rounded, 'color': const Color(0xFF7C3AED)},
      {'label': 'Pending Requests', 'value': stats.pending.toString(), 'icon': Icons.hourglass_top_rounded, 'color': const Color(0xFFD97706)},
      {'label': 'Confirmed', 'value': stats.confirmed.toString(), 'icon': Icons.check_circle_rounded, 'color': const Color(0xFF16A34A)},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final Color itemColor = item['color'] as Color;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item['label'] as String,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary),
                  ),
                  Icon(item['icon'] as IconData, size: 16, color: itemColor),
                ],
              ),
              Text(
                item['value'] as String,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavHub(
    DiningStatsModel stats,
    DiningTableSummary tablesSummary,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    final navItems = [
      {
        'title': 'Bookings & Requests',
        'subtitle': stats.pending > 0 ? '${stats.pending} awaiting your response' : 'View active & history bookings',
        'icon': Icons.menu_book_rounded,
        'badge': stats.pending > 0 ? stats.pending.toString() : null,
        'route': '/dining-bookings',
      },
      {
        'title': 'Slots & Availability',
        'subtitle': 'Set weekly open days, timings & holidays',
        'icon': Icons.access_time_rounded,
        'badge': null,
        'route': '/dining-slots',
      },
      {
        'title': 'Tables & Seating',
        'subtitle': '${tablesSummary.tables} tables · ${tablesSummary.seats} bookable seats',
        'icon': Icons.table_bar_rounded,
        'badge': null,
        'route': '/dining-tables',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: navItems.asMap().entries.map((entry) {
          final idx = entry.key;
          final item = entry.value;
          final isLast = idx == navItems.length - 1;

          return InkWell(
            onTap: () => context.push(item['route'] as String),
            borderRadius: BorderRadius.vertical(
              top: idx == 0 ? const Radius.circular(18) : Radius.zero,
              bottom: isLast ? const Radius.circular(18) : Radius.zero,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: isLast ? null : Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      size: 20,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item['subtitle'] as String,
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (item['badge'] != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        item['badge'] as String,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(Icons.chevron_right_rounded, size: 20, color: textSecondary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBookingRulesCard(
    DiningProfileModel profile,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: isDark ? Colors.white : Colors.black87),
              const SizedBox(width: 8),
              Text(
                'Booking Rules & Settings',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Booking window (days)',
                  controller: _bookingWindowController,
                  hint: '30',
                  isDark: isDark,
                  borderColor: borderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  label: 'Slot duration (mins)',
                  controller: _slotDurationController,
                  hint: '60',
                  isDark: isDark,
                  borderColor: borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Max guests / booking',
                  controller: _maxGuestsController,
                  hint: '10',
                  isDark: isDark,
                  borderColor: borderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  label: 'Min advance notice (mins)',
                  controller: _minAdvanceController,
                  hint: '30',
                  isDark: isDark,
                  borderColor: borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auto-confirm bookings',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Skip manual approval when tables are available',
                      style: TextStyle(fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: profile.autoConfirm,
                activeTrackColor: AppColors.primary,
                onChanged: (val) async {
                  await ref.read(diningDashboardControllerProvider.notifier).updateSettings(autoConfirm: val);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSavingRules ? null : () => _saveBookingRules(profile),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSavingRules
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save Rules',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            filled: true,
            fillColor: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
