import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/registration/presentation/controllers/registration_controller.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';

class Step3Documents extends ConsumerStatefulWidget {
  const Step3Documents({super.key, required this.onValidityChanged});

  final ValueChanged<bool> onValidityChanged;

  @override
  ConsumerState<Step3Documents> createState() => _Step3DocumentsState();
}

class _Step3DocumentsState extends ConsumerState<Step3Documents> {
  late final form = ref.read(registrationControllerProvider.notifier).form;

  late final _panNumber = TextEditingController(text: form.panNumber);
  late final _nameOnPan = TextEditingController(text: form.nameOnPan);
  late final _gstNumber = TextEditingController(text: form.gstNumber);
  late final _gstLegalName = TextEditingController(text: form.gstLegalName);
  late final _gstAddress = TextEditingController(text: form.gstAddress);
  late final _fssaiNumber = TextEditingController(text: form.fssaiNumber);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  void _notify() => widget.onValidityChanged(form.isStep3Valid);

  @override
  void dispose() {
    _panNumber.dispose();
    _nameOnPan.dispose();
    _gstNumber.dispose();
    _gstLegalName.dispose();
    _gstAddress.dispose();
    _fssaiNumber.dispose();
    super.dispose();
  }

  Future<void> _pickFssaiExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      form.fssaiExpiry =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        _sectionCard(
          title: 'Restaurant photos',
          children: [
            ImagePickerTile(
              label: 'Restaurant logo / profile photo',
              image: form.profileImage,
              required: true,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);
                if (file != null) {
                  setState(() => form.profileImage = file);
                  _notify();
                }
              },
              onRemove: () {
                setState(() => form.profileImage = null);
                _notify();
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Menu photos (up to 10)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            MultiImagePickerGrid(
              images: form.menuImages,
              onAdd: () async {
                final file = await pickImageWithSourceSheet(context);
                if (file != null) setState(() => form.menuImages.add(file));
              },
              onRemove: (index) =>
                  setState(() => form.menuImages.removeAt(index)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'PAN details',
          children: [
            LabeledTextField(
              label: 'PAN number',
              controller: _panNumber,
              hint: 'ABCDE1234F',
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                LengthLimitingTextInputFormatter(10),
                _UpperCaseTextFormatter(),
              ],
              onChanged: (v) {
                form.panNumber = v;
                _notify();
              },
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Name on PAN',
              controller: _nameOnPan,
              onChanged: (v) => form.nameOnPan = v,
            ),
            const SizedBox(height: 16),
            ImagePickerTile(
              label: 'PAN card image',
              image: form.panImage,
              height: 100,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);
                if (file != null) {
                  setState(() => form.panImage = file);
                  _notify();
                }
              },
              onRemove: () {
                setState(() => form.panImage = null);
                _notify();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'GST details',
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Registered for GST?',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Switch(
                  value: form.gstRegistered,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => form.gstRegistered = v);
                    _notify();
                  },
                ),
              ],
            ),
            if (form.gstRegistered) ...[
              const SizedBox(height: 12),
              LabeledTextField(
                label: 'GST number',
                controller: _gstNumber,
                required: true,
                inputFormatters: [_UpperCaseTextFormatter()],
                onChanged: (v) {
                  form.gstNumber = v;
                  _notify();
                },
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: 'GST legal name',
                controller: _gstLegalName,
                onChanged: (v) => form.gstLegalName = v,
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: 'GST address',
                controller: _gstAddress,
                maxLines: 2,
                onChanged: (v) => form.gstAddress = v,
              ),
              const SizedBox(height: 16),
              ImagePickerTile(
                label: 'GST certificate image',
                image: form.gstImage,
                height: 100,
                required: true,
                onPick: () async {
                  final file = await pickImageWithSourceSheet(context);
                  if (file != null) {
                    setState(() => form.gstImage = file);
                    _notify();
                  }
                },
                onRemove: () {
                  setState(() => form.gstImage = null);
                  _notify();
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _sectionCard(
          title: 'FSSAI license',
          children: [
            LabeledTextField(
              label: 'FSSAI number',
              controller: _fssaiNumber,
              keyboardType: TextInputType.number,
              onChanged: (v) => form.fssaiNumber = v,
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Expiry date',
              controller: TextEditingController(text: form.fssaiExpiry),
              readOnly: true,
              hint: 'Select expiry date',
              onTap: _pickFssaiExpiry,
              suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            ),
            const SizedBox(height: 16),
            ImagePickerTile(
              label: 'FSSAI license image',
              image: form.fssaiImage,
              height: 100,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);
                if (file != null) setState(() => form.fssaiImage = file);
              },
              onRemove: () => setState(() => form.fssaiImage = null),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
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
