import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';

const _days = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

class _DayTiming {
  _DayTiming({
    required this.isOpen,
    required this.openingTime,
    required this.closingTime,
  });
  bool isOpen;
  String openingTime;
  String closingTime;
}

class OutletTimingsScreen extends ConsumerStatefulWidget {
  const OutletTimingsScreen({super.key});

  @override
  ConsumerState<OutletTimingsScreen> createState() =>
      _OutletTimingsScreenState();
}

class _OutletTimingsScreenState extends ConsumerState<OutletTimingsScreen> {
  Map<String, _DayTiming>? _timings;
  String? _expandedDay;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final raw = await ref
          .read(restaurantRepositoryProvider)
          .getOutletTimings();
      final timings = <String, _DayTiming>{};
      for (final day in _days) {
        final entry = Map<String, dynamic>.from((raw[day] ?? {}) as Map);
        timings[day] = _DayTiming(
          isOpen: entry['isOpen'] == true,
          openingTime: (entry['openingTime'] ?? '09:00').toString(),
          closingTime: (entry['closingTime'] ?? '22:00').toString(),
        );
      }
      setState(() {
        _timings = timings;
        _expandedDay = _days.first;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadError = e is ApiException
            ? e.message
            : 'Failed to load outlet timings.';
      });
    }
  }

  Future<void> _save() async {
    final timings = _timings;
    if (timings == null) return;
    setState(() => _isSaving = true);
    try {
      final payload = {
        for (final day in _days)
          day: {
            'isOpen': timings[day]!.isOpen,
            'openingTime': timings[day]!.openingTime,
            'closingTime': timings[day]!.closingTime,
          },
      };
      await ref.read(restaurantRepositoryProvider).updateOutletTimings(payload);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Outlet timings saved.')));
      }
    } catch (e) {
      final message = e is ApiException
          ? e.message
          : 'Failed to save. Please try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime(String day, {required bool isOpening}) async {
    final timing = _timings![day]!;
    final current = isOpening ? timing.openingTime : timing.closingTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      if (isOpening) {
        timing.openingTime = formatted;
      } else {
        timing.closingTime = formatted;
      }
    });
  }

  String _formatTimeLabel(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Outlet timings',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: ElevatedButton(
              onPressed: (_timings == null || _isSaving) ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 0),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Save',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_loadError!, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                for (final day in _days) ...[
                  _buildDayTile(day),
                  const SizedBox(height: 8),
                ],
              ],
            ),
    );
  }

  Widget _buildDayTile(String day) {
    final timing = _timings![day]!;
    final isExpanded = _expandedDay == day;
    return Container(
      decoration: BoxDecoration(
        color: isExpanded
            ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)
            : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceVariantLight),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expandedDay = isExpanded ? null : day),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        day,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        timing.isOpen ? 'Open' : 'Closed',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: timing.isOpen,
                        onChanged: (val) => setState(() => timing.isOpen = val),
                        activeThumbColor: Theme.of(context).colorScheme.surface,
                        activeTrackColor: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded && timing.isOpen)
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimeField(
                      'Opening',
                      timing.openingTime,
                      () => _pickTime(day, isOpening: true),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeField(
                      'Closing',
                      timing.closingTime,
                      () => _pickTime(day, isOpening: false),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, String value, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatTimeLabel(value)),
                Icon(
                  Icons.schedule,
                  size: 16,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
