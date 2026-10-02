import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/registration/presentation/controllers/registration_controller.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/registration/presentation/widgets/segmented_toggle.dart';

class Step4BankReview extends ConsumerStatefulWidget {
  const Step4BankReview({super.key, required this.onValidityChanged});

  final ValueChanged<bool> onValidityChanged;

  @override
  ConsumerState<Step4BankReview> createState() => _Step4BankReviewState();
}

class _Step4BankReviewState extends ConsumerState<Step4BankReview> {
  late final form = ref.read(registrationControllerProvider.notifier).form;

  late final _accountHolderName = TextEditingController(
    text: form.accountHolderName,
  );
  late final _accountNumber = TextEditingController(text: form.accountNumber);
  late final _ifscCode = TextEditingController(text: form.ifscCode);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _notify() => widget.onValidityChanged(form.isStep4Valid);

  @override
  void dispose() {
    _accountHolderName.dispose();
    _accountNumber.dispose();
    _ifscCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        _sectionCard(
          title: 'Bank details',
          subtitle:
              'Used for delivery payouts. You can also add this later from your dashboard.',
          children: [
            LabeledTextField(
              label: 'Account holder name',
              controller: _accountHolderName,
              onChanged: (v) {
                form.accountHolderName = v;
                _notify();
              },
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Account number',
              controller: _accountNumber,
              keyboardType: TextInputType.number,
              onChanged: (v) {
                form.accountNumber = v;
                _notify();
              },
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'IFSC code',
              controller: _ifscCode,
              inputFormatters: [_UpperCaseTextFormatter()],
              onChanged: (v) {
                form.ifscCode = v;
                _notify();
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Account type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedToggle<String>(
              options: const [
                SegmentedOption('savings', 'Savings'),
                SegmentedOption('current', 'Current'),
              ],
              value: form.accountType,
              onChanged: (v) => setState(() => form.accountType = v),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Review your application',
          children: [
            _reviewRow('Restaurant', form.restaurantName),
            _reviewRow(
              'Type',
              form.pureVegRestaurant == true ? 'Pure Veg' : 'Mixed Menu',
            ),
            _reviewRow('Owner', form.ownerName),
            _reviewRow('Phone', '+91 ${form.ownerPhone}'),
            _reviewRow(
              'Address',
              [
                form.addressLine1,
                form.city,
                form.state,
                form.pincode,
              ].where((s) => s.isNotEmpty).join(', '),
            ),
            _reviewRow(
              'Cuisines',
              form.cuisines.isEmpty ? '—' : form.cuisines.join(', '),
            ),
            _reviewRow(
              'Open days',
              form.openDays.isEmpty ? '—' : form.openDays.join(', '),
            ),
            _reviewRow('Hours', '${form.openingTime} – ${form.closingTime}'),
            _reviewRow(
              'Logo uploaded',
              form.profileImage != null ? 'Yes' : 'No',
            ),
            _reviewRow('Menu photos', '${form.menuImages.length} uploaded'),
            _reviewRow(
              'PAN',
              form.panNumber.isEmpty ? 'Not provided' : form.panNumber,
            ),
            _reviewRow(
              'GST',
              form.gstRegistered
                  ? (form.gstNumber.isEmpty ? 'Registered' : form.gstNumber)
                  : 'Not registered',
            ),
            _reviewRow(
              'FSSAI',
              form.fssaiNumber.isEmpty ? 'Not provided' : form.fssaiNumber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.black45),
            ),
          ],
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
