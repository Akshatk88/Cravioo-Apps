import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/support/domain/support_ticket_model.dart';
import 'package:food_user_application/features/support/presentation/controllers/support_controller.dart';

const _categories = [
  'orders',
  'payments',
  'menu',
  'restaurant',
  'technical',
  'other',
];
const _priorities = ['low', 'medium', 'high'];

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  String? _category;
  String _priority = 'medium';
  final _issueType = TextEditingController();
  final _subject = TextEditingController();
  final _orderRef = TextEditingController();
  final _description = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _issueType.dispose();
    _subject.dispose();
    _orderRef.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_category == null) {
      _showError('Please select a category.');
      return;
    }
    if (_issueType.text.trim().isEmpty) {
      _showError('Please describe the issue type.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(supportControllerProvider.notifier)
          .createTicket(
            category: _category!,
            issueType: _issueType.text.trim(),
            subject: _subject.text.trim(),
            description: _description.text.trim(),
            orderRef: _orderRef.text.trim(),
            priority: _priority,
          );
      if (mounted) {
        _issueType.clear();
        _subject.clear();
        _orderRef.clear();
        _description.clear();
        setState(() {
          _category = null;
          _priority = 'medium';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support ticket submitted.')),
        );
      }
    } catch (e) {
      _showError(
        e is ApiException
            ? e.message
            : 'Failed to submit ticket. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(supportControllerProvider);

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Support',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Create or check ticket status',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help and Support',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            ticketsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text(
                error is ApiException
                    ? error.message
                    : 'Failed to load tickets.',
              ),
              data: (tickets) => _buildStatsRow(context, tickets),
            ),
            const SizedBox(height: 32),
            Text(
              'Raise support ticket',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              context,
              hint: 'Category',
              value: _category,
              items: _categories,
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              context,
              hint: 'Priority',
              value: _priority,
              items: _priorities,
              onChanged: (v) => setState(() => _priority = v ?? 'medium'),
            ),
            const SizedBox(height: 16),
            _buildTextField(context, _issueType, 'Issue type'),
            const SizedBox(height: 16),
            _buildTextField(context, _subject, 'Short subject'),
            const SizedBox(height: 16),
            _buildTextField(context, _orderRef, 'Order id (optional)'),
            const SizedBox(height: 16),
            _buildTextField(context, _description, 'Description', maxLines: 4),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Ticket',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            if (ticketsAsync.value != null &&
                ticketsAsync.value!.isNotEmpty) ...[
              Text(
                'Your tickets',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              for (final ticket in ticketsAsync.value!) ...[
                _buildTicketCard(context, ticket),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(
    BuildContext context,
    List<SupportTicketModel> tickets,
  ) {
    final open = tickets.where((t) => t.status == 'open').length;
    final inProgress = tickets.where((t) => t.status == 'in-progress').length;
    final resolved = tickets.where((t) => t.status == 'resolved').length;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildStatCard(
          context,
          'Total',
          '${tickets.length}',
          Icons.confirmation_number_outlined,
          AppColors.primary,
        ),
        _buildStatCard(
          context,
          'Open',
          '$open',
          Icons.lock_open_outlined,
          Colors.orange,
        ),
        _buildStatCard(
          context,
          'In progress',
          '$inProgress',
          Icons.autorenew,
          Colors.blue,
        ),
        _buildStatCard(
          context,
          'Resolved',
          '$resolved',
          Icons.check_circle_outline,
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String count,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      width: (MediaQuery.of(context).size.width - 32 - 36) / 4,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketCard(BuildContext context, SupportTicketModel ticket) {
    final statusColor = switch (ticket.status) {
      'resolved' => Colors.green,
      'in-progress' => Colors.blue,
      _ => Colors.orange,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
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
                  ticket.subject.isNotEmpty ? ticket.subject : ticket.issueType,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ticket.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${ticket.category} • ${ticket.priority} priority',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    BuildContext context, {
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          items: items
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(
                    v,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
