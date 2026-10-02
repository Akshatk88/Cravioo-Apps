import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/offers/presentation/controllers/offer_controller.dart';

class CreateCouponScreen extends ConsumerStatefulWidget {
  const CreateCouponScreen({super.key});

  @override
  ConsumerState<CreateCouponScreen> createState() => _CreateCouponScreenState();
}

class _CreateCouponScreenState extends ConsumerState<CreateCouponScreen> {
  String _discountType = '%';
  final _couponCode = TextEditingController();
  final _discountValue = TextEditingController();
  final _minOrderValue = TextEditingController();
  final _maxDiscount = TextEditingController();
  final _usageLimit = TextEditingController();
  final _perUserLimit = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSaving = false;

  @override
  void dispose() {
    _couponCode.dispose();
    _discountValue.dispose();
    _minOrderValue.dispose();
    _maxDiscount.dispose();
    _usageLimit.dispose();
    _perUserLimit.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? now)
          : (_endDate ?? now.add(const Duration(days: 30))),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _submit() async {
    final couponCode = _couponCode.text.trim();
    final discountValue = double.tryParse(_discountValue.text.trim());
    final isPercentage = _discountType == '%';

    if (couponCode.isEmpty) {
      _showError('Coupon code is required.');
      return;
    }
    if (discountValue == null || discountValue <= 0) {
      _showError('Enter a valid discount amount.');
      return;
    }
    if (_startDate == null || _endDate == null) {
      _showError('Select a start and end date.');
      return;
    }
    if (!_endDate!.isAfter(_startDate!)) {
      _showError('End date must be after the start date.');
      return;
    }
    if (_endDate!.isBefore(DateTime.now())) {
      _showError('End date must be in the future.');
      return;
    }
    final maxDiscount = double.tryParse(_maxDiscount.text.trim());
    if (isPercentage && (maxDiscount == null || maxDiscount <= 0)) {
      _showError('Max discount cap is required for percentage coupons.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(offerControllerProvider.notifier)
          .create(
            couponCode: couponCode,
            discountType: isPercentage ? 'percentage' : 'flat-price',
            discountValue: discountValue,
            minOrderValue: double.tryParse(_minOrderValue.text.trim()),
            maxDiscount: isPercentage ? maxDiscount : null,
            usageLimit: int.tryParse(_usageLimit.text.trim()),
            perUserLimit: int.tryParse(_perUserLimit.text.trim()),
            startDate: _startDate!,
            endDate: _endDate!,
          );
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      _showError(
        e is ApiException
            ? e.message
            : 'Failed to create coupon. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy');

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
              'Create Coupon',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Restaurant-sponsored offer',
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
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
          children: [
            _buildSection(
              context: context,
              title: 'COUPON DETAILS',
              children: [
                _buildLabelWithAsterisk(context, 'Coupon Code'),
                _buildTextField(
                  context,
                  _couponCode,
                  hint: 'e.g. SAVE20',
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                _buildLabelWithAsterisk(context, 'Discount'),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTextField(
                        context,
                        _discountValue,
                        hint: 'Enter amount',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(flex: 1, child: _buildDropdown(context)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel(context, 'Minimum Order Value'),
                _buildTextField(
                  context,
                  _minOrderValue,
                  hint: '₹ 0',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildLabel(context, 'Max Discount Cap')),
                    if (_discountType == '%')
                      const Text('*', style: TextStyle(color: AppColors.error)),
                  ],
                ),
                _buildTextField(
                  context,
                  _maxDiscount,
                  hint: '₹ No cap',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'USAGE LIMITS',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(context, 'Total Uses'),
                          _buildTextField(
                            context,
                            _usageLimit,
                            hint: 'Unlimited',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel(context, 'Per User'),
                          _buildTextField(
                            context,
                            _perUserLimit,
                            hint: 'Unlimited',
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              context: context,
              title: 'VALIDITY PERIOD',
              children: [
                _buildLabelWithAsterisk(context, 'Start Date'),
                _buildDateField(
                  context,
                  _startDate,
                  dateFormat,
                  () => _pickDate(isStart: true),
                ),
                const SizedBox(height: 16),
                _buildLabelWithAsterisk(context, 'End Date'),
                _buildDateField(
                  context,
                  _endDate,
                  dateFormat,
                  () => _pickDate(isStart: false),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Create',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Widget> children,
  }) {
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
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.5,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildLabelWithAsterisk(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          children: const [
            TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    TextEditingController controller, {
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceVariantDark
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
            : null,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.transparent,
          hintText: hint,
          hintStyle: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : const Color(0xFF9CA3AF),
            fontSize: 14,
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

  Widget _buildDateField(
    BuildContext context,
    DateTime? value,
    DateFormat dateFormat,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceVariantDark
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              value != null ? dateFormat.format(value) : 'Select date',
              style: TextStyle(
                color: value != null
                    ? Theme.of(context).colorScheme.onSurface
                    : (Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF9CA3AF)),
                fontSize: 14,
              ),
            ),
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.surfaceVariantDark
            : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _discountType,
          items: ['%', '₹']
              .map(
                (value) => DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (newValue) {
            if (newValue != null) setState(() => _discountType = newValue);
          },
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
}
