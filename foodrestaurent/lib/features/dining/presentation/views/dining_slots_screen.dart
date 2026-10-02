import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/dining/domain/dining_slot_model.dart';
import 'package:food_user_application/features/dining/presentation/controllers/dining_slots_controller.dart';

class DiningSlotsScreen extends ConsumerStatefulWidget {
  const DiningSlotsScreen({super.key});

  @override
  ConsumerState<DiningSlotsScreen> createState() => _DiningSlotsScreenState();
}

class _DiningSlotsScreenState extends ConsumerState<DiningSlotsScreen> {
  static String _formatTime12(String timeStr) {
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

  void _showAddSlotModal(int dayOfWeek, String dayName) {
    TimeOfDay startTime = const TimeOfDay(hour: 12, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 15, minute: 0);
    final capacityCtrl = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? AppColors.surfaceDark : Colors.white;
            final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);

            String formatPicker(TimeOfDay t) {
              final h = t.hour.toString().padLeft(2, '0');
              final m = t.minute.toString().padLeft(2, '0');
              return '$h:$m';
            }

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
                        Text(
                          'Add Slot for $dayName',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Time Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Start Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: startTime,
                                  );
                                  if (picked != null) {
                                    setModalState(() => startTime = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(12),
                                    color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatTime12(formatPicker(startTime)),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'End Time',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: endTime,
                                  );
                                  if (picked != null) {
                                    setModalState(() => endTime = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(12),
                                    color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatTime12(formatPicker(endTime)),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const Icon(Icons.access_time_rounded, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Max Capacity (Optional)
                    Text(
                      'Max Capacity (0 = unlimited / auto by tables)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: capacityCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Add Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final startStr = formatPicker(startTime);
                          final endStr = formatPicker(endTime);
                          if (startStr.compareTo(endStr) >= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('End time must be after start time')),
                            );
                            return;
                          }
                          final cap = int.tryParse(capacityCtrl.text.trim()) ?? 0;
                          ref.read(diningSlotsControllerProvider.notifier).addSlot(
                            dayOfWeek,
                            DiningSlotItemModel(
                              startTime: startStr,
                              endTime: endStr,
                              capacity: cap,
                              isActive: true,
                            ),
                          );
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Add Slot', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

  void _showAddBlockedDateModal() {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final reasonCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final bg = isDark ? AppColors.surfaceDark : Colors.white;
            final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
            final dateStr =
                '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

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
                        Text(
                          'Block Holiday / Date',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Select Date *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setModalState(() => selectedDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(12),
                          color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      'Reason (e.g. Diwali Holiday, Private Event)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. Renovation / Closed',
                        filled: true,
                        fillColor: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(ctx);
                          final ok = await ref.read(diningSlotsControllerProvider.notifier).addBlockedDate(
                                dateStr,
                                reasonCtrl.text.trim(),
                              );
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(ok ? 'Date blocked' : 'Failed to block date'),
                              backgroundColor: ok ? AppColors.success : AppColors.error,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Block Date', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

  @override
  Widget build(BuildContext context) {
    final slotsAsync = ref.watch(diningSlotsControllerProvider);
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Slots & Availability',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => ref.read(diningSlotsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      bottomNavigationBar: slotsAsync.maybeWhen(
        data: (state) => Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: BoxDecoration(
            color: cardBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(12),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: state.isSaving
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ok = await ref.read(diningSlotsControllerProvider.notifier).saveWeeklySlots();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(ok ? 'Weekly dining slots saved successfully!' : 'Failed to save slots. Please check timings.'),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                      ),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text(
                    'Save Weekly Slots',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
      body: slotsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load slots',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(diningSlotsControllerProvider.notifier).refresh(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (state) {
          final days = state.days;
          final blockedDates = state.blockedDates;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(diningSlotsControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryTintStrong),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryDeep),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Configure daily operating hours and slot capacities. Remember to click "Save Weekly Slots" when done.',
                          style: TextStyle(fontSize: 12, color: AppColors.primaryDeep, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Weekly Days Accordion
                ...days.map((day) => _buildDayCard(day, isDark, cardBg, borderColor, textSecondary)),

                const SizedBox(height: 24),

                // Blocked Dates / Holidays Section
                _buildBlockedDatesSection(blockedDates, isDark, cardBg, borderColor, textSecondary),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDayCard(
    DiningDaySlotsModel day,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Day Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          day.day,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: day.isOpen ? const Color(0xFFDCFCE7) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          day.isOpen ? 'Open' : 'Closed',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: day.isOpen ? const Color(0xFF15803D) : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (day.isOpen && day.slots.isNotEmpty) ...[
                  InkWell(
                    onTap: () {
                      ref.read(diningSlotsControllerProvider.notifier).copyToAllDays(day.dayOfWeek);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${day.day}\'s timings copied to all 7 days'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_rounded, size: 12, color: AppColors.primaryDark),
                          SizedBox(width: 4),
                          Text(
                            'Copy all',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                SizedBox(
                  height: 30,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Switch.adaptive(
                      value: day.isOpen,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        ref.read(diningSlotsControllerProvider.notifier).updateDayOpen(day.dayOfWeek, val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (day.isOpen) ...[
            Divider(height: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (day.slots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No time slots added. Tap "+ Add Slot" below.',
                        style: TextStyle(fontSize: 13, color: textSecondary, fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ...day.slots.asMap().entries.map((entry) {
                      final sIdx = entry.key;
                      final slot = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_formatTime12(slot.startTime)} - ${_formatTime12(slot.endTime)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (slot.capacity > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.cardDark : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Text(
                                  '${slot.capacity} cap',
                                  style: TextStyle(fontSize: 11, color: textSecondary),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: AppColors.error,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () {
                                ref.read(diningSlotsControllerProvider.notifier).removeSlot(day.dayOfWeek, sIdx);
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () => _showAddSlotModal(day.dayOfWeek, day.day),
                    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Add Slot',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockedDatesSection(
    List<DiningBlockedDateModel> blockedDates,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.event_busy_rounded, size: 20, color: AppColors.error),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Holidays & Blocked Dates',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                onPressed: _showAddBlockedDateModal,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Guests cannot book tables on blocked dates.',
            style: TextStyle(fontSize: 12, color: textSecondary),
          ),
          const SizedBox(height: 12),

          if (blockedDates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No dates blocked. Tap "+" to add holidays or closures.',
                style: TextStyle(fontSize: 13, color: textSecondary, fontStyle: FontStyle.italic),
              ),
            )
          else
            ...blockedDates.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF6B7280)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.date,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (entry.reason.isNotEmpty)
                            Text(
                              entry.reason,
                              style: TextStyle(fontSize: 11, color: textSecondary),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      color: AppColors.error,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final ok = await ref.read(diningSlotsControllerProvider.notifier).removeBlockedDate(entry.id);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Date unblocked' : 'Failed to unblock date'),
                            backgroundColor: ok ? AppColors.success : AppColors.error,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
