import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/addons/domain/addon_model.dart';
import 'package:food_user_application/features/addons/presentation/controllers/addon_controller.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/registration/presentation/widgets/segmented_toggle.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';

Future<void> showAddonFormSheet(BuildContext context, {AddonModel? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => AddonFormSheet(existing: existing),
  );
}

class AddonFormSheet extends ConsumerStatefulWidget {
  const AddonFormSheet({super.key, this.existing});

  final AddonModel? existing;

  @override
  ConsumerState<AddonFormSheet> createState() => _AddonFormSheetState();
}

class _AddonFormSheetState extends ConsumerState<AddonFormSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.existing != null
        ? widget.existing!.price.toStringAsFixed(0)
        : '',
  );
  late bool _isVeg = widget.existing?.isVeg ?? true;
  String _existingImageUrl = '';
  XFile? _pickedImage;
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _existingImageUrl = widget.existing?.image ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _showError('Add-on name is required.');
      return;
    }
    final price = double.tryParse(_price.text.trim());
    if (price == null || price < 0) {
      _showError('Enter a valid price.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      var imageUrl = _existingImageUrl;
      if (_pickedImage != null) {
        imageUrl = await ref
            .read(restaurantRepositoryProvider)
            .uploadAttachment(_pickedImage!, folder: 'menu');
      }
      final foodType = _isVeg ? 'veg' : 'non-veg';

      if (_isEditing) {
        await ref
            .read(addonControllerProvider.notifier)
            .updateAddon(
              widget.existing!.id,
              name: name,
              foodType: foodType,
              description: _description.text.trim(),
              price: price,
              image: imageUrl,
            );
      } else {
        await ref
            .read(addonControllerProvider.notifier)
            .create(
              name: name,
              foodType: foodType,
              description: _description.text.trim(),
              price: price,
              image: imageUrl,
            );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? 'Add-on updated — pending re-approval.'
                  : 'Add-on submitted for approval.',
            ),
          ),
        );
      }
    } catch (e) {
      _showError(
        e is ApiException
            ? e.message
            : 'Something went wrong. Please try again.',
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Edit Add-on' : 'Add Add-on',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LabeledTextField(
              label: 'Add-on name',
              controller: _name,
              hint: 'e.g. Extra Cheese',
              required: true,
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Description',
              controller: _description,
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            LabeledTextField(
              label: 'Price',
              controller: _price,
              required: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              prefixText: '₹ ',
            ),
            const SizedBox(height: 16),
            const Text(
              'Food type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            SegmentedToggle<bool>(
              options: const [
                SegmentedOption(true, 'Veg'),
                SegmentedOption(false, 'Non-Veg'),
              ],
              value: _isVeg,
              onChanged: (v) => setState(() => _isVeg = v),
            ),
            const SizedBox(height: 16),
            ImagePickerTile(
              label: 'Add-on photo',
              image: _pickedImage,
              height: 120,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);
                if (file != null) setState(() => _pickedImage = file);
              },
              onRemove: () => setState(() {
                _pickedImage = null;
                _existingImageUrl = '';
              }),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
                    : Text(
                        _isEditing ? 'Save' : 'Create',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
