import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/registration/presentation/controllers/registration_controller.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/registration/presentation/widgets/segmented_toggle.dart';

class Step1RestaurantInfo extends ConsumerStatefulWidget {
  const Step1RestaurantInfo({super.key, required this.onValidityChanged});

  final ValueChanged<bool> onValidityChanged;

  @override
  ConsumerState<Step1RestaurantInfo> createState() =>
      _Step1RestaurantInfoState();
}

class _Step1RestaurantInfoState extends ConsumerState<Step1RestaurantInfo> {
  late final form = ref.read(registrationControllerProvider.notifier).form;

  late final _restaurantName = TextEditingController(text: form.restaurantName);
  late final _ownerName = TextEditingController(text: form.ownerName);
  late final _ownerEmail = TextEditingController(text: form.ownerEmail);
  late final _primaryContact = TextEditingController(
    text: form.primaryContactNumber,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _notify() => widget.onValidityChanged(form.isStep1Valid);

  @override
  void dispose() {
    _restaurantName.dispose();
    _ownerName.dispose();
    _ownerEmail.dispose();
    _primaryContact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        _sectionCard(
          title: 'Restaurant information',
          children: [
            LabeledTextField(
              label: 'Restaurant name',
              controller: _restaurantName,
              hint: "e.g. Ujjwal's Restro",
              required: true,
              onChanged: (v) {
                form.restaurantName = v;
                _notify();
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Pure veg restaurant? *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedToggle<bool>(
              options: const [
                SegmentedOption(true, 'Yes, Pure Veg'),
                SegmentedOption(false, 'No, Mixed Menu'),
              ],
              value: form.pureVegRestaurant,
              onChanged: (v) {
                setState(() => form.pureVegRestaurant = v);
                _notify();
              },
            ),
            const SizedBox(height: 6),
            const Text(
              'This helps users filter restaurants by dietary preference.',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'Owner details',
          subtitle:
              'These details will be used for all business communications and updates.',
          children: [
            LabeledTextField(
              label: 'Full name',
              controller: _ownerName,
              hint: 'Owner full name',
              required: true,
              onChanged: (v) {
                form.ownerName = v;
                _notify();
              },
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Email address',
              controller: _ownerEmail,
              hint: 'owner@example.com',
              keyboardType: TextInputType.emailAddress,
              onChanged: (v) {
                form.ownerEmail = v;
                _notify();
              },
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Phone number',
              controller: TextEditingController(text: form.ownerPhone),
              required: true,
              enabled: false,
              readOnly: true,
              prefixText: '+91  ',
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Primary contact number (if different)',
              controller: _primaryContact,
              hint: 'Same as owner phone if left blank',
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: (v) {
                form.primaryContactNumber = v;
                _notify();
              },
            ),
          ],
        ),
      ],
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
