import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/menu_categories/presentation/controllers/category_controller.dart';
import 'package:food_user_application/features/menu_items/data/menu_repository.dart';
import 'package:food_user_application/features/menu_items/domain/food_item_model.dart';
import 'package:food_user_application/features/menu_items/domain/food_variant_model.dart';
import 'package:food_user_application/features/menu_items/presentation/controllers/menu_controller.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/registration/presentation/widgets/segmented_toggle.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

Future<void> showFoodItemFormSheet(
  BuildContext context, {
  FoodItemModel? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FoodItemFormSheet(existing: existing),
  );
}

class _VariantDraft {
  _VariantDraft({
    this.id,
    required this.nameController,
    required this.priceController,
    required this.otherPriceController,
    this.unit = 'piece',
  });

  final String? id;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController otherPriceController;
  String unit;

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    otherPriceController.dispose();
  }
}

class FoodItemFormSheet extends ConsumerStatefulWidget {
  const FoodItemFormSheet({super.key, this.existing});

  final FoodItemModel? existing;

  @override
  ConsumerState<FoodItemFormSheet> createState() => _FoodItemFormSheetState();
}

class _FoodItemFormSheetState extends ConsumerState<FoodItemFormSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.existing != null && widget.existing!.price > 0
        ? widget.existing!.price.toStringAsFixed(0)
        : '',
  );
  late final _otherPrice = TextEditingController(
    text: widget.existing != null && widget.existing!.otherPrice > 0
        ? widget.existing!.otherPrice.toStringAsFixed(0)
        : '',
  );
  late final _preparationTime = TextEditingController(
    text: (widget.existing?.preparationTime ?? '')
        .replaceAll(RegExp(r'[^0-9]'), ''),
  );

  late bool _isVeg = widget.existing?.isVeg ?? true;
  late bool _isAvailable = widget.existing?.isAvailable ?? true;
  late bool _isRecommended = widget.existing?.isRecommended ?? false;
  late bool _hasVariants = widget.existing?.hasVariants ?? false;

  String? _categoryId;
  String? _itemSlotTimingId;

  final List<String> _existingImages = [];
  final List<XFile> _newPickedImages = [];

  final List<_VariantDraft> _variants = [];
  bool _isSaving = false;

  bool get _isEditing => widget.existing != null;
  int get _totalImagesCount => _existingImages.length + _newPickedImages.length;

  static const List<int> _quickPrepTimes = [10, 15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId;
    _itemSlotTimingId = widget.existing?.itemSlotTimingId;

    if (widget.existing != null) {
      if (widget.existing!.images.isNotEmpty) {
        _existingImages.addAll(widget.existing!.images);
      } else if (widget.existing!.image.isNotEmpty) {
        _existingImages.add(widget.existing!.image);
      }

      if (widget.existing!.variants.isNotEmpty) {
        _hasVariants = true;
        for (final v in widget.existing!.variants) {
          _variants.add(
            _VariantDraft(
              id: v.id,
              nameController: TextEditingController(text: v.name),
              priceController: TextEditingController(
                text: v.price > 0 ? v.price.toStringAsFixed(0) : '',
              ),
              otherPriceController: TextEditingController(
                text: v.otherPrice > 0 ? v.otherPrice.toStringAsFixed(0) : '',
              ),
              unit: v.unit.isNotEmpty ? v.unit : 'piece',
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _otherPrice.dispose();
    _preparationTime.dispose();
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  void _addVariant() {
    setState(() {
      _variants.add(
        _VariantDraft(
          nameController: TextEditingController(),
          priceController: TextEditingController(),
          otherPriceController: TextEditingController(),
          unit: 'piece',
        ),
      );
    });
  }

  void _removeVariant(int index) {
    setState(() {
      final v = _variants.removeAt(index);
      v.dispose();
      if (_variants.isEmpty) {
        _hasVariants = false;
      }
    });
  }

  Future<void> _pickImage() async {
    if (_totalImagesCount >= 5) {
      _showError('You can add up to 5 photos only.');
      return;
    }
    final file = await pickImageWithSourceSheet(context);
    if (file != null) {
      setState(() => _newPickedImages.add(file));
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImages.removeAt(index));
  }

  void _removePickedImage(int index) {
    setState(() => _newPickedImages.removeAt(index));
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _showError('Item name is required.');
      return;
    }

    if (_categoryId == null || _categoryId!.isEmpty) {
      _showError('Please select a category for this item.');
      return;
    }

    final double basePrice = double.tryParse(_price.text.trim()) ?? 0;
    final double strikePrice = double.tryParse(_otherPrice.text.trim()) ?? 0;

    final List<FoodVariantModel> parsedVariants = [];
    if (_hasVariants) {
      if (_variants.isEmpty) {
        _showError('Please add at least one variant or turn off variants.');
        return;
      }
      for (int i = 0; i < _variants.length; i++) {
        final draft = _variants[i];
        final vName = draft.nameController.text.trim();
        final vPrice = double.tryParse(draft.priceController.text.trim());
        final vOtherPrice = double.tryParse(draft.otherPriceController.text.trim()) ?? 0;

        if (vName.isEmpty) {
          _showError('Please enter a name for variant #${i + 1}');
          return;
        }
        if (vPrice == null || vPrice <= 0) {
          _showError('Variant "$vName" must have a price greater than 0');
          return;
        }

        parsedVariants.add(
          FoodVariantModel(
            id: draft.id,
            name: vName,
            unit: draft.unit,
            price: vPrice,
            otherPrice: vOtherPrice,
          ),
        );
      }
    } else {
      if (basePrice <= 0) {
        _showError('Please enter a valid price greater than 0.');
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      final List<String> finalImageUrls = List<String>.from(_existingImages);

      // Upload newly picked photos
      if (_newPickedImages.isNotEmpty) {
        final repo = ref.read(restaurantRepositoryProvider);
        for (final xfile in _newPickedImages) {
          try {
            final uploadedUrl = await repo.uploadAttachment(xfile, folder: 'menu');
            if (uploadedUrl.isNotEmpty) {
              finalImageUrls.add(uploadedUrl);
            }
          } catch (uploadError) {
            _handleError(uploadError);
            setState(() => _isSaving = false);
            return;
          }
        }
      }

      final mainImage = finalImageUrls.isNotEmpty ? finalImageUrls.first : '';
      final foodType = _isVeg ? 'Veg' : 'Non-Veg';
      final prepTimeStr = _preparationTime.text.trim().isNotEmpty
          ? '${_preparationTime.text.trim()} mins'
          : '';

      // If item is Non-Veg and restaurant is currently marked pure veg, auto-switch profile
      if (foodType == 'Non-Veg') {
        final currentRestaurant = ref.read(restaurantProfileControllerProvider).value;
        if (currentRestaurant?.pureVegRestaurant == true) {
          try {
            await ref.read(restaurantRepositoryProvider).updateProfile({'pureVegRestaurant': false});
            ref.invalidate(restaurantProfileControllerProvider);
          } catch (_) {}
        }
      }

      final double effectivePrice = _hasVariants
          ? (parsedVariants.isNotEmpty
              ? parsedVariants.map((v) => v.price).reduce((a, b) => a < b ? a : b)
              : 0)
          : basePrice;
      final double effectiveOtherPrice = _hasVariants
          ? (parsedVariants.isNotEmpty ? parsedVariants.first.otherPrice : 0)
          : strikePrice;

      if (_isEditing) {
        await ref.read(menuControllerProvider.notifier).updateFood(
              widget.existing!.id,
              name: name,
              foodType: foodType,
              description: _description.text.trim(),
              price: effectivePrice,
              otherPrice: effectiveOtherPrice,
              image: mainImage,
              images: finalImageUrls,
              categoryId: _categoryId,
              isAvailable: _isAvailable,
              isRecommended: _isRecommended,
              preparationTime: prepTimeStr,
              itemSlotTimingId: _itemSlotTimingId,
              variants: parsedVariants,
            );
      } else {
        await ref.read(menuControllerProvider.notifier).createFood(
              name: name,
              foodType: foodType,
              description: _description.text.trim(),
              price: effectivePrice,
              otherPrice: effectiveOtherPrice,
              image: mainImage,
              images: finalImageUrls,
              categoryId: _categoryId,
              isAvailable: _isAvailable,
              isRecommended: _isRecommended,
              preparationTime: prepTimeStr,
              itemSlotTimingId: _itemSlotTimingId,
              variants: parsedVariants,
            );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              _isEditing
                  ? 'Item updated successfully!'
                  : 'Item added and submitted for approval.',
            ),
          ),
        );
      }
    } catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _handleError(dynamic e) {
    String errorMessage = 'Something went wrong. Please try again.';
    if (e is ApiException) {
      errorMessage = e.message;
    } else if (e is DioException) {
      if (e.error is ApiException) {
        errorMessage = (e.error as ApiException).message;
      } else if (e.response?.data is Map) {
        final map = e.response!.data as Map;
        final serverMsg = map['message'] ?? map['error'];
        if (serverMsg != null && serverMsg.toString().isNotEmpty) {
          errorMessage = serverMsg.toString();
        }
      } else if (e.message != null && e.message!.isNotEmpty) {
        errorMessage = e.message!;
      }
    } else if (e != null) {
      final str = e.toString();
      errorMessage = str.startsWith('Exception: ') ? str.substring(11) : str;
    }
    _showError(errorMessage);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleDietaryChange(bool value) async {
    if (value == _isVeg) return;
    final restaurant = ref.read(restaurantProfileControllerProvider).value;
    final isPureVeg = restaurant?.pureVegRestaurant ?? false;

    if (!value && isPureVeg) {
      final shouldSwitch = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.restaurant_menu_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Enable Non-Veg Menu?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: const Text(
            'Your restaurant is currently set to Pure Veg.\n\nTo add Non-Veg items, your restaurant profile will be updated to a Mixed Menu (Veg & Non-Veg). Would you like to proceed?',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enable Non-Veg'),
            ),
          ],
        ),
      );

      if (shouldSwitch == true) {
        try {
          await ref.read(restaurantRepositoryProvider).updateProfile({'pureVegRestaurant': false});
          ref.invalidate(restaurantProfileControllerProvider);
          if (mounted) {
            setState(() => _isVeg = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Mixed Menu enabled! Non-Veg items can now be added.')),
            );
          }
        } catch (e) {
          _handleError(e);
        }
      }
      return;
    }

    setState(() => _isVeg = value);
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = ref.watch(restaurantProfileControllerProvider).value;
    final isPureVeg = restaurant?.pureVegRestaurant ?? false;

    final categoriesAsync = ref.watch(categoryControllerProvider);
    final approvedCategories = (categoriesAsync.value ?? [])
        .where(
          (c) =>
              c.isApproved &&
              c.isActive &&
              (!isPureVeg || c.foodTypeScope == 'Veg'),
        )
        .toList();

    final slotTimingsAsync = ref.watch(itemSlotTimingsProvider);
    final slotTimings = slotTimingsAsync.value ?? [];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditing ? 'Edit Item' : 'Add New Item',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Item details, pricing, photos & availability',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable Form Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Photos Section (Multiple Images)
                  _buildPhotosSection(),
                  const SizedBox(height: 20),

                  // 2. Item Name & Veg/Non-Veg
                  LabeledTextField(
                    label: 'Item name *',
                    controller: _name,
                    hint: 'e.g. Paneer Butter Masala, Chicken Biryani',
                    required: true,
                  ),
                  const SizedBox(height: 16),

                  // Food Type Toggle
                  const Text(
                    'Dietary Type *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedToggle<bool>(
                    options: const [
                      SegmentedOption(true, '🟢  Veg'),
                      SegmentedOption(false, '🔴  Non-Veg'),
                    ],
                    value: _isVeg,
                    onChanged: (v) => _handleDietaryChange(v),
                  ),
                  if (isPureVeg) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () => _handleDietaryChange(false),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.eco, size: 14, color: Colors.green.shade700),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Pure Veg Restaurant: Tap to enable Mixed Menu (Veg & Non-Veg).',
                                style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.green.shade700),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Description
                  LabeledTextField(
                    label: 'Description (optional)',
                    controller: _description,
                    hint: 'Tell customers about ingredients, taste, spice level...',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),

                  // 3. Category & Availability Slot Timings
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Category *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: approvedCategories.any((c) => c.id == _categoryId)
                                      ? _categoryId
                                      : null,
                                  hint: const Text(
                                    'Select category',
                                    style: TextStyle(fontSize: 13, color: Colors.black45),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Select category', style: TextStyle(fontSize: 13)),
                                    ),
                                    ...approvedCategories.map(
                                      (c) => DropdownMenuItem<String?>(
                                        value: c.id,
                                        child: Text(
                                          c.name,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setState(() => _categoryId = value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Availability Slot Timing
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Meal Timing',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  isExpanded: true,
                                  value: slotTimings.any((s) => s.id == _itemSlotTimingId)
                                      ? _itemSlotTimingId
                                      : null,
                                  hint: const Text(
                                    'All Day',
                                    style: TextStyle(fontSize: 13, color: Colors.black45),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All Day (Default)', style: TextStyle(fontSize: 13)),
                                    ),
                                    ...slotTimings.map(
                                      (s) => DropdownMenuItem<String?>(
                                        value: s.id,
                                        child: Text(
                                          s.displayLabel,
                                          style: const TextStyle(fontSize: 13),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) => setState(() => _itemSlotTimingId = value),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 4. Pricing & Variants Section
                  _buildPricingAndVariantsSection(),
                  const SizedBox(height: 20),

                  // 5. Preparation Time
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preparation Time (mins)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _preparationTime,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: 'e.g. 20',
                          suffixText: 'mins',
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Quick Chips
                      Wrap(
                        spacing: 8,
                        children: _quickPrepTimes.map((mins) {
                          final isSelected = _preparationTime.text.trim() == mins.toString();
                          return InkWell(
                            onTap: () => setState(() {
                              _preparationTime.text = mins.toString();
                            }),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                '${mins}m',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.primary : Colors.black87,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 6. Settings (Availability & Recommended)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isAvailable
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined,
                                color: _isAvailable ? Colors.green : Colors.red,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Available for order',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    _isAvailable
                                        ? 'Customers can order this dish right now'
                                        : 'Marked as Out of Stock',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isAvailable,
                              activeThumbColor: Colors.white,
                              activeTrackColor: AppColors.primary,
                              onChanged: (v) => setState(() => _isAvailable = v),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _isRecommended
                                    ? Colors.amber.shade50
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.star_rounded,
                                color: _isRecommended ? Colors.amber.shade700 : Colors.grey,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Recommended dish',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Highlight as Chef Special / Popular recommendation',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isRecommended,
                              activeThumbColor: Colors.white,
                              activeTrackColor: Colors.amber.shade700,
                              onChanged: (v) => setState(() => _isRecommended = v),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Saving...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          _isEditing ? 'Update Item' : 'Create Item',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Photos Section Widget (Supports multiple images)
  Widget _buildPhotosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Item Photos',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            Text(
              '$_totalImagesCount/5 photos',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _totalImagesCount > 0 ? AppColors.primary : Colors.grey,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'First photo will be used as the main display image.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // Add button if under limit
              if (_totalImagesCount < 5)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 90,
                    height: 90,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        style: BorderStyle.solid,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_a_photo_outlined,
                          color: AppColors.primary,
                          size: 26,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+ Add Photo',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Existing remote images
              ...List.generate(_existingImages.length, (index) {
                final url = _existingImages[index];
                final isCover = index == 0;
                return Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          placeholder: (context, _) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.fastfood, color: Colors.grey),
                          ),
                        ),
                      ),
                      // Cover badge
                      if (isCover)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Cover',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // Delete button
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeExistingImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Newly picked images (XFile)
              ...List.generate(_newPickedImages.length, (index) {
                final xfile = _newPickedImages[index];
                final overallIndex = _existingImages.length + index;
                final isCover = overallIndex == 0;
                return Container(
                  width: 90,
                  height: 90,
                  margin: const EdgeInsets.only(right: 10),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: kIsWeb
                            ? Image.network(xfile.path, width: 90, height: 90, fit: BoxFit.cover)
                            : Image.file(File(xfile.path), width: 90, height: 90, fit: BoxFit.cover),
                      ),
                      if (isCover)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Cover',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removePickedImage(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black87,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Pricing and Variants Widget
  Widget _buildPricingAndVariantsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Does this item have variants?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    'e.g. Half / Full, Small / Large, 500g / 1kg',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Switch(
                value: _hasVariants,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _hasVariants = val;
                    if (_hasVariants && _variants.isEmpty) {
                      _addVariant();
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // If Single Price
          if (!_hasVariants) ...[
            Row(
              children: [
                Expanded(
                  child: LabeledTextField(
                    label: 'Selling Price *',
                    controller: _price,
                    required: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    prefixText: '₹ ',
                    hint: '199',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledTextField(
                    label: 'Strike / MRP Price',
                    controller: _otherPrice,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    prefixText: '₹ ',
                    hint: '249 (optional)',
                  ),
                ),
              ],
            ),
          ],

          // If Variants
          if (_hasVariants) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Customers will see the lowest variant price as starting price.',
                      style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            ...List.generate(_variants.length, (index) {
              final variant = _variants[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Variant Name
                        Expanded(
                          flex: 3,
                          child: LabeledTextField(
                            label: 'Variant Name *',
                            controller: variant.nameController,
                            hint: 'e.g. Half, Full, 500g',
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Unit Dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Unit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: kFoodVariantUnits.any((u) => u.value == variant.unit)
                                        ? variant.unit
                                        : 'piece',
                                    items: kFoodVariantUnits.map((u) {
                                      return DropdownMenuItem<String>(
                                        value: u.value,
                                        child: Text(u.label, style: const TextStyle(fontSize: 12)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => variant.unit = val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Remove variant
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Remove',
                          onPressed: () => _removeVariant(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: LabeledTextField(
                            label: 'Price *',
                            controller: variant.priceController,
                            keyboardType: TextInputType.number,
                            prefixText: '₹ ',
                            hint: '120',
                            required: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: LabeledTextField(
                            label: 'Strike Price',
                            controller: variant.otherPriceController,
                            keyboardType: TextInputType.number,
                            prefixText: '₹ ',
                            hint: '150 (optional)',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),

            OutlinedButton.icon(
              onPressed: _addVariant,
              icon: const Icon(Icons.add, color: AppColors.primary, size: 18),
              label: const Text(
                'Add Another Variant',
                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
