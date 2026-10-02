import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/complaints/domain/complaint_model.dart';
import 'package:food_user_application/features/complaints/presentation/controllers/complaint_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';

class ComplaintsScreen extends ConsumerStatefulWidget {
  const ComplaintsScreen({super.key, this.initialTab = 'complaints'});

  final String initialTab;

  @override
  ConsumerState<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends ConsumerState<ComplaintsScreen> {
  late bool _isComplaintsTab = widget.initialTab != 'reviews';

  @override
  Widget build(BuildContext context) {
    final restaurantName =
        ref.watch(restaurantProfileControllerProvider).value?.restaurantName ??
        '—';

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
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SHOWING DATA FOR',
                  style: TextStyle(
                    color: AppColors.textSecondaryLight,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  restaurantName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTabs(context),
            const SizedBox(height: 24),
            Expanded(
              child: _isComplaintsTab
                  ? _buildComplaintsList(context)
                  : _buildReviewsEmptyState(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isComplaintsTab = true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isComplaintsTab
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _isComplaintsTab
                      ? AppColors.primary
                      : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  'Complaints',
                  style: TextStyle(
                    color: _isComplaintsTab
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _isComplaintsTab = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: !_isComplaintsTab
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: !_isComplaintsTab
                      ? AppColors.primary
                      : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                ),
              ),
              child: Center(
                child: Text(
                  'Reviews',
                  style: TextStyle(
                    color: !_isComplaintsTab
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintsList(BuildContext context) {
    final complaintsAsync = ref.watch(complaintControllerProvider);

    return AppRefreshIndicator(
      onRefresh: () => ref.read(complaintControllerProvider.notifier).refresh(),
      child: complaintsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error is ApiException
                    ? error.message
                    : 'Failed to load complaints.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (complaints) => complaints.isEmpty
            ? _buildEmptyState(context, 'No complaints found')
            : ListView.separated(
                itemCount: complaints.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildComplaintCard(context, complaints[index]),
              ),
      ),
    );
  }

  Widget _buildComplaintCard(BuildContext context, ComplaintModel complaint) {
    final statusColor = switch (complaint.status) {
      'resolved' => Colors.green,
      'in-progress' => Colors.blue,
      _ => Colors.orange,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  complaint.issueType.isEmpty
                      ? 'Complaint'
                      : complaint.issueType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  complaint.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (complaint.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              complaint.description,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (complaint.orderDisplayId.isNotEmpty) ...[
                Icon(
                  Icons.receipt_long_outlined,
                  size: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  complaint.orderDisplayId,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Icon(
                Icons.person_outline,
                size: 14,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 4),
              Text(
                complaint.customerName,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('d MMM, h:mm a').format(complaint.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          if (complaint.adminResponse.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Support: ${complaint.adminResponse}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewsEmptyState(BuildContext context) {
    return _buildEmptyState(
      context,
      'Reviews appear per-order',
      subtitle:
          'Customer ratings are attached to individual orders — check Order History to see them.',
      icon: Icons.chat_bubble_outline,
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    String title, {
    String? subtitle,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 40,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
